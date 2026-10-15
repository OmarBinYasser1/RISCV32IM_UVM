`ifndef RISCV_ALU_SCOREBOARD_SV
`define RISCV_ALU_SCOREBOARD_SV

//------------------------------------------------------------------------------
// riscv_alu_scoreboard
//
// Block-level scoreboard for the arithmetic datapath of the RV32I/RV32M DUT.
//   - Receives alu_item from the ALU(-DIV) agent
//   - Receives mul_item from the MUL agent
//
// Hierarchy position (see architecture diagram):
//   riscv_env
//     |-- alu_agent ----\
//     |                  >--> alu_scoreboard
//     |-- mul_agent ----/
//
// Scope: value correctness only. 
//
//------------------------------------------------------------------------------
class riscv_alu_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(riscv_alu_scoreboard)

  //--------------------------------------------------------------------------
  // Analysis exports (connected from the ALU / MUL agent monitors in env)
  //--------------------------------------------------------------------------
  uvm_analysis_export #(alu_item) alu_ae;
  uvm_analysis_export #(mul_item) mul_ae;

  //--------------------------------------------------------------------------
  // Internal FIFOs
  //--------------------------------------------------------------------------
  uvm_tlm_analysis_fifo #(alu_item) alu_fifo;
  uvm_tlm_analysis_fifo #(mul_item) mul_fifo;

  //--------------------------------------------------------------------------
  // MUL operator encodings (cv32e40p mult_operator_e)
  //--------------------------------------------------------------------------
  // How the CV32E40P decoder maps RV32M onto the multiplier:
  //   MUL    -> MUL_MAC32, regc = 0  (result = 0 + a*b, low 32 bits)
  //   MULH   -> MUL_H, short_signed_i = 2'b11
  //   MULHSU -> MUL_H, short_signed_i = 2'b01
  //   MULHU  -> MUL_H, short_signed_i = 2'b00
  // MUL_I / MUL_IR / MUL_DOT8 / MUL_DOT16 are PULP-only (never produced by RV32M).
  localparam logic [2:0] MUL_MAC32 = 3'b000;   // RV32M MUL when operand_c == 0; p.mac otherwise
  localparam logic [2:0] MUL_MSU32 = 3'b001;   // PULP p.msu
  localparam logic [2:0] MUL_I     = 3'b010;   // PULP short multiply (not RV32M)
  localparam logic [2:0] MUL_H     = 3'b110;   // RV32M MULH / MULHSU / MULHU

  // Divider operators (cv32e40p alu_opcode_e). bit0 = signed, bit1 = remainder.
  localparam logic [6:0] ALU_DIVU = 7'b0110000;
  localparam logic [6:0] ALU_DIV  = 7'b0110001;
  localparam logic [6:0] ALU_REMU = 7'b0110010;
  localparam logic [6:0] ALU_REM  = 7'b0110011;

  // Branch-condition comparison operators
  localparam logic [6:0] ALU_LTS  = 7'b0000000;
  localparam logic [6:0] ALU_LTU  = 7'b0000001;
  localparam logic [6:0] ALU_GES  = 7'b0001010;
  localparam logic [6:0] ALU_GEU  = 7'b0001011;
  localparam logic [6:0] ALU_EQ   = 7'b0001100;
  localparam logic [6:0] ALU_NE   = 7'b0001101;

  // CV32E40P decoder SWAPS the operands of DIV/DIVU/REM/REMU on the way into the
  // ALU (alu_op_a = rs2 = divisor, alu_op_b = rs1 = dividend; see the "inputs A
  // and B are swapped" comment in cv32e40p_alu.sv). With the swap flag = 1 the
  // scoreboard treats alu_item.operand_b as the dividend and operand_a as the
  // divisor. Set it to 0 only if your alu monitor already swaps them back.
  bit div_operands_swapped = 1;

  // Set to 1 from the env/test to also check PULP p.mac (operand_c != 0) and
  // p.msu. Default 0: only the four RV32M multiplies are checked.
  bit check_pulp_mac = 0;

  bit timing_check_enable   = 1;
  bit timing_check_is_error = 0;

  // CHK:C-06  MULH vs MULHU consistency tracking
  bit        mulh_pending = 0;
  bit [31:0] mulh_a, mulh_b, mulh_res;

  //--------------------------------------------------------------------------
  // Statistics
  //--------------------------------------------------------------------------
  int alu_pass, alu_fail, alu_skip;
  int mul_pass, mul_fail, mul_skip;

  // Per-plan-property statistics (names match the "property name" column of
  // the Checking sheet) -> traceability from regression log to test plan.
  int unsigned prop_pass [string];
  int unsigned prop_fail [string];

  // Last MULH/MULHU seen, kept for the {rdh,rdl} full-product check
  bit          hi_valid = 0;
  logic [31:0] hi_a, hi_b, hi_res;
  logic [1:0]  hi_sm;

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    alu_pass = 0; alu_fail = 0; alu_skip = 0;
    mul_pass = 0; mul_fail = 0; mul_skip = 0;
  endfunction

  //--------------------------------------------------------------------------
  // Build / Connect
  //--------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    alu_ae   = new("alu_ae",   this);
    mul_ae   = new("mul_ae",   this);
    alu_fifo = new("alu_fifo", this);
    mul_fifo = new("mul_fifo", this);

    void'(uvm_config_db#(bit)::get(this, "", "div_operands_swapped", div_operands_swapped));
    void'(uvm_config_db#(bit)::get(this, "", "check_pulp_mac",       check_pulp_mac));
    void'(uvm_config_db#(bit)::get(this, "", "timing_check_enable",   timing_check_enable));
    void'(uvm_config_db#(bit)::get(this, "", "timing_check_is_error", timing_check_is_error));
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    alu_ae.connect(alu_fifo.analysis_export);
    mul_ae.connect(mul_fifo.analysis_export);
  endfunction

  //--------------------------------------------------------------------------
  // Run: ALU and MUL streams are checked independently/concurrently
  //--------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    fork
      check_alu();
      check_mul();
    join_none
  endtask

  //--------------------------------------------------------------------------
  // DIV / DIVU / REM / REMU golden model (RISC-V spec, incl. corner cases)
  //   x / 0   : DIV, DIVU -> all ones          REM, REMU -> x (the dividend)
  //   MIN/-1  : DIV -> MIN_INT (0x80000000)     REM -> 0     (signed overflow)
  //   otherwise: quotient truncates toward zero; remainder takes the dividend's sign
  //   (SystemVerilog '/' and '%' already behave exactly like that)
  //--------------------------------------------------------------------------
  function automatic logic [31:0] div_golden(
      input logic [6:0]  op,
      input logic [31:0] a,
      input logic [31:0] b
  );
    logic signed [31:0] sa  = signed'(a);
    logic signed [31:0] sb  = signed'(b);
    bit                 ovf = (a == 32'h8000_0000) && (b == 32'hFFFF_FFFF);            // signed overflow: MIN_INT / -1
    case (op)
      ALU_DIV:  return (b == 0) ? 32'hFFFF_FFFF : ovf ? 32'h8000_0000 : 32'(sa / sb);  // signed division
      ALU_DIVU: return (b == 0) ? 32'hFFFF_FFFF : a / b;                               // unsigned division
      ALU_REM:  return (b == 0) ? a             : ovf ? 32'h0000_0000 : 32'(sa % sb);  // signed remainder
      ALU_REMU: return (b == 0) ? a             : a % b;                               // unsigned remainder
      default:  return 'x;
    endcase
  endfunction

  // Magnitude |x| as a 33-bit unsigned number (so |MIN_INT| = 2^31 fits)
  function automatic logic [32:0] mag33(input logic [31:0] x, input bit is_signed);
    return (is_signed && x[31]) ? ({1'b0, ~x} + 33'd1) : {1'b0, x};
  endfunction

  //--------------------------------------------------------------------------
  // ALU / DIV golden model
  //--------------------------------------------------------------------------
  function automatic logic [31:0] alu_golden(
      input logic [6:0]  op,
      input logic [31:0] a,
      input logic [31:0] b
  );
    logic signed [31:0] sa = signed'(a);
    logic signed [31:0] sb = signed'(b);
    logic [31:0] res;

    case (op)
      7'b0011000: res = a + b;                       // ALU_ADD
      7'b0011001: res = a - b;                       // ALU_SUB
      7'b0011010: res = a + b;                       // ALU_ADDU
      7'b0011011: res = a - b;                       // ALU_SUBU
      7'b0101111: res = a ^ b;                       // ALU_XOR
      7'b0101110: res = a | b;                       // ALU_OR
      7'b0010101: res = a & b;                       // ALU_AND
      7'b0100100: res = 32'(sa >>> b[4:0]);          // ALU_SRA
      7'b0100101: res = a >> b[4:0];                 // ALU_SRL
      7'b0100111: res = a << b[4:0];                 // ALU_SLL

      // Branch-condition comparisons drive comparison_result_o (checked via alu_cmp_golden)
      ALU_LTS, ALU_LTU, ALU_EQ, ALU_NE, ALU_GES, ALU_GEU: res = 'x;

      // SLT/SLTU write to result_o (rd destination)
      7'b0000010: res = (sa < sb) ? 1 : 0;           // ALU_SLTS
      7'b0000011: res = (a  < b ) ? 1 : 0;           // ALU_SLTU

      // Min / Max / Abs
      7'b0010000: res = (sa < sb) ? a : b;           // ALU_MIN
      7'b0010001: res = (a  < b ) ? a : b;           // ALU_MINU
      7'b0010010: res = (sa > sb) ? a : b;           // ALU_MAX
      7'b0010011: res = (a  > b ) ? a : b;           // ALU_MAXU
      7'b0010100: res = (sa < 0)  ? -sa : a;         // ALU_ABS

      // RV32M division / remainder: see div_golden()
      ALU_DIV, ALU_DIVU, ALU_REM, ALU_REMU: res = div_golden(op, a, b);

      default:    res = 'x;
    endcase
    return res;
  endfunction

  // Branch condition comparison golden model
  function automatic bit alu_cmp_golden(logic [6:0] op,
                                        logic [31:0] a, logic [31:0] b);
    case (op)
      ALU_EQ:  return (a == b);
      ALU_NE:  return (a != b);
      ALU_LTS: return ($signed(a) <  $signed(b));
      ALU_LTU: return (a <  b);
      ALU_GES: return ($signed(a) >= $signed(b));
      ALU_GEU: return (a >= b);
      default: return 1'b0;
    endcase
  endfunction

  // CHK:C-10  Timing failure reporter (warning-only by default).
  function void timing_msg(string prop, string msg);
    if (!timing_check_enable) return;
    if (timing_check_is_error)
      `uvm_error  ("SB_TIME", $sformatf("%s | %s", prop, msg))
    else
      `uvm_warning("SB_TIME", $sformatf("%s | %s", prop, msg))
  endfunction

  // CHK:C-10  Leading-one position (returns -1 for all-zero).
  function automatic int lo_pos(bit [31:0] v);
    for (int i = 31; i >= 0; i--) if (v[i]) return i;
    return -1;
  endfunction

  // DIV/REM latency check
  function void check_div_latency(alu_item it, logic [31:0] a, logic [31:0] b);
    int lo;
    int exp_lat;
    if (b == 32'h0) return;
    lo = lo_pos(b);
    if (lo < 0) return;
    if (lo == 31) return;
    exp_lat = 34 - lo;
    if (it.latency > exp_lat + 4)
      timing_msg("div_lat_p",
        $sformatf("op=%0h a=%08h b=%08h LO=%0d latency=%0d exp<=%0d",
                  it.operator, a, b, lo, it.latency, exp_lat + 4));
  endfunction

  //--------------------------------------------------------------------------
  // ALU checker
  //--------------------------------------------------------------------------
  task check_alu();
    alu_item     item;
    logic [31:0] expected;
    logic [31:0] opa, opb;     // opa = dividend, opb = divisor for DIV/REM ops
    bit          is_cmp;
    bit          exp_cmp;
    forever begin
      alu_fifo.get(item);
      opa = item.operand_a;
      opb = item.operand_b;
      if (div_operands_swapped &&
          item.operator inside {ALU_DIV, ALU_DIVU, ALU_REM, ALU_REMU}) begin
        opa = item.operand_b;  // rs1 = dividend
        opb = item.operand_a;  // rs2 = divisor
      end

      // Branch-condition comparison check
      is_cmp = item.operator inside {ALU_LTS, ALU_LTU, ALU_EQ,
                                     ALU_NE, ALU_GES, ALU_GEU};
      if (is_cmp) begin
        exp_cmp = alu_cmp_golden(item.operator, opa, opb);
        if (item.comparison_result === exp_cmp) begin
          alu_pass++;
          chk("branch_cmp_p", 1'b1,
              $sformatf("op=%0h a=%0h b=%0h cmp=%0b",
                        item.operator, opa, opb, exp_cmp));
        end else begin
          alu_fail++;
          chk("branch_cmp_p", 1'b0,
              $sformatf("op=%0h a=%0h b=%0h exp=%0b got=%0b",
                        item.operator, opa, opb, exp_cmp,
                        item.comparison_result));
        end
        continue;
      end

      expected = alu_golden(item.operator, opa, opb);

      // No reference value available (comparison ops / unknown opcode): skip
      if ($isunknown(expected)) begin
        alu_skip++;
        `uvm_info("SB_ALU", $sformatf("SKIP | op=%0h a=%0h b=%0h | no result_o reference",
          item.operator, opa, opb), UVM_HIGH)
        continue;
      end

      if (item.result === expected) begin
        alu_pass++;
        `uvm_info("SB_ALU", $sformatf("PASS | op=%0h a=%0h b=%0h | exp=%0h got=%0h",
          item.operator, opa, opb, expected, item.result), UVM_HIGH)
      end else begin
        alu_fail++;
        `uvm_error("SB_ALU", $sformatf("FAIL | op=%0h a=%0h b=%0h | exp=%0h got=%0h  <<< MISMATCH",
          item.operator, opa, opb, expected, item.result))
      end

      // Named plan properties for DIV / DIVU / REM / REMU
      if (item.operator inside {ALU_DIV, ALU_DIVU, ALU_REM, ALU_REMU}) begin
        check_divrem_props(item, opa, opb, expected);
        check_div_latency(item, opa, opb);
      end
    end
  endtask

  //--------------------------------------------------------------------------
  // Property bookkeeping
  //--------------------------------------------------------------------------
  function void chk(string prop, bit ok, string msg);
    if (!prop_pass.exists(prop)) begin
      prop_pass[prop] = 0;
      prop_fail[prop] = 0;
    end
    if (ok) prop_pass[prop]++;
    else begin
      prop_fail[prop]++;
      `uvm_error("SB_PROP", $sformatf("%s FAILED | %s", prop, msg))
    end
  endfunction

  //--------------------------------------------------------------------------
  // DIV / DIVU / REM / REMU plan properties (call only for those 4 operators)
  //--------------------------------------------------------------------------
  // a = dividend (rs1), b = divisor (rs2), already un-swapped by check_alu
  function void check_divrem_props(alu_item it, logic [31:0] a, logic [31:0] b,
                                   logic [31:0] expected);
    logic [31:0] r   = it.result;
    bit          is_div = (it.operator == ALU_DIV) || (it.operator == ALU_DIVU);
    bit          sgn    = it.operator[0];                       // DIV / REM
    bit          ovf    = sgn && (a == 32'h8000_0000) && (b == 32'hFFFF_FFFF);
    string       tag    = $sformatf("op=%0h a=%0h b=%0h got=%0h exp=%0h",
                                    it.operator, a, b, r, expected);

    // Primary result (DIV_1, DIVU_1, REM_1, REM_2)
    case (it.operator)
      ALU_DIV:  chk("div_result_p",  r === expected, tag);
      ALU_DIVU: chk("divu_result_p", r === expected, tag);
      default:  chk("rem_result_p",  r === expected, tag);     // REM and REMU
    endcase

    if (b == 0) begin
      // DIV_3 / REM_3: no trap; DIV,DIVU -> all ones; REM,REMU -> dividend
      if (is_div) chk("div_zero_p",     r === 32'hFFFF_FFFF, tag);
      else        chk("rem_div_zero_p", r === a,             tag);
    end
    else if (ovf) begin
      // DIV_4 / REM_4: MIN_INT / -1  (signed only)
      if (is_div) chk("div_overflow_p", r === 32'h8000_0000, tag);
      else        chk("rem_overflow_p", r === 32'h0000_0000, tag);
    end
    else begin
      // Sign rules (DIV_1 / REM_1)
      if (sgn && r !== 32'h0) begin
        if (is_div) chk("div_sign_check_p", r[31] === (a[31] ^ b[31]), tag);
        else        chk("rem_sign_check_p", r[31] === a[31],           tag);
      end

      // DIV_5 / REM_8: zero dividend (rs2 != 0)
      if (a == 0)
        chk(is_div ? "div_zero_dividend_p" : "rem_zero_dividend_p", r === 32'h0, tag);

      // DIV_6 / REM_9: equal non-zero operands -> quotient 1, remainder 0
      if (a == b)
        chk(is_div ? "div_equal_operands_p" : "rem_equal_operands_p",
            r === (is_div ? 32'd1 : 32'd0), tag);

      // DIV_8 / REM_10: divide by 1
      if (b == 1)
        chk(is_div ? "div_by_one_p" : "rem_by_one_p", r === (is_div ? a : 32'd0), tag);

      // DIV_11 / REM_10: divide by -1 (signed): quotient -A, remainder 0
      if (sgn && b == 32'hFFFF_FFFF)
        chk(is_div ? "div_by_neg_one_p" : "rem_by_neg_one_p",
            r === (is_div ? (32'h0 - a) : 32'd0), tag);

      // DIV_7 / DIVU_3 / DIVU_15: |rs2| > |rs1| -> quotient 0, remainder rs1
      if (mag33(b, sgn) > mag33(a, sgn))
        chk(is_div ? "div_truncation_p" : "rem_truncation_p",
            r === (is_div ? 32'd0 : a), tag);

      // DIVU_6: unsigned has no overflow; 0x80000000 / 0xFFFFFFFF = 0, rem = dividend
      if (!sgn && a == 32'h8000_0000 && b == 32'hFFFF_FFFF)
        chk("unsigned_no_overflow_p", r === (is_div ? 32'd0 : a), tag);

      // DIV_2: DIVU with bit 31 set is a large positive magnitude, not negative
      if (!sgn && is_div && (a[31] || b[31]))
        chk("divu_msb_operand_p", r === (a / b), tag);

      // DIV_9: alternating-bit patterns (carry/borrow stress)
      if ((a inside {32'h5555_5555, 32'hAAAA_AAAA, 32'hFFFF_FFFF}) ||
          (b inside {32'h5555_5555, 32'hAAAA_AAAA, 32'hFFFF_FFFF}))
        chk(is_div ? "div_toggle_pattern_p" : "rem_toggle_pattern_p", r === expected, tag);
    end
  endfunction

  //--------------------------------------------------------------------------
  // Classification helpers
  //--------------------------------------------------------------------------
  // RV32M MUL = MUL_MAC32 with the C operand forced to zero by the decoder
  function automatic bit is_rv32m_mul(mul_item it);
    return (it.operator == MUL_MAC32) && (it.operand_c == 32'h0);
  endfunction

  function automatic bit is_rv32m_mulh(mul_item it);
    return (it.operator == MUL_H);
  endfunction

  //--------------------------------------------------------------------------
  // MUL golden model
  //
  // Both operands are extended to 33 bits (sign bit = bit31 if that operand is
  // signed, else 0) so ONE 66-bit multiply covers MUL/MULH/MULHSU/MULHU:
  //   MUL (MAC32, c=0)     -> p[31:0]   (identical for any signedness)
  //   MULH/MULHSU/MULHU    -> p[63:32]  (signedness chosen by smode)
  //--------------------------------------------------------------------------
  function automatic logic [63:0] mul_golden64(
      input logic [31:0] a,
      input logic [31:0] b,
      input logic [1:0]  smode        // {b_signed, a_signed}
  );
    logic signed [32:0] ea = $signed({smode[0] & a[31], a});
    logic signed [32:0] eb = $signed({smode[1] & b[31], b});
    logic signed [65:0] p  = ea * eb;
    return p[63:0];
  endfunction

  function automatic logic [31:0] mul_golden(
      input logic [2:0]  op,
      input logic [31:0] a,
      input logic [31:0] b,
      input logic [31:0] c,
      input logic [1:0]  smode
  );
    logic [63:0] p = mul_golden64(a, b, smode);
    case (op)
      MUL_MAC32: return c + a * b;     // RV32M MUL when c == 0 (== p[31:0])
      MUL_MSU32: return c - a * b;     // PULP p.msu
      MUL_H:     return p[63:32];
      default:   return 'x;            // MUL_I / MUL_IR / DOT8 / DOT16: PULP, no model
    endcase
  endfunction

  //--------------------------------------------------------------------------
  // Plan-level MUL properties (GEN_4, GEN_5, MUL_1, MULH smode legality)
  //--------------------------------------------------------------------------
  function void check_mul_props(mul_item it);
    logic [31:0] a  = it.operand_a;
    logic [31:0] b  = it.operand_b;
    logic [1:0]  sm = it.signed_mode;
    logic [31:0] lo_s, lo_u;

    if (!(is_rv32m_mul(it) || is_rv32m_mulh(it))) return;

    // GEN_4: multiplication by 0 -> whole 64-bit product is 0
    if (a == 0 || b == 0)
      chk("mul_by_zero_p", it.result === 32'h0,
          $sformatf("a=%0h b=%0h res=%0h", a, b, it.result));

    if (is_rv32m_mul(it)) begin
      // MUL_1: signed and unsigned low words agree, and the DUT matches
      lo_s = 32'(64'(signed'(a)) * 64'(signed'(b)));
      lo_u = a * b;
      chk("mul_signed_xor_unsigned_p",
          ((lo_s ^ lo_u) == 0) && (it.result === lo_u),
          $sformatf("a=%0h b=%0h exp=%0h got=%0h", a, b, lo_u, it.result));

      // GEN_5: identity (MUL only: result is the other operand)
      if (a == 1)
        chk("mul_by_one_p", it.result === b, $sformatf("rs1==1 b=%0h got=%0h", b, it.result));
      if (b == 1)
        chk("mul_by_one_p", it.result === a, $sformatf("rs2==1 a=%0h got=%0h", a, it.result));
    end
    else begin
      // MULH/MULHSU/MULHU must use one of the three legal modes
      chk("mulh_smode_legal_p", sm inside {2'b11, 2'b01, 2'b00},
          $sformatf("illegal short_signed_i=%0b", sm));

      // GEN_5 for the H variants: product fits in 32 bits, so the high word is
      // pure sign extension of the OTHER operand (if that operand is signed)
      if (a == 1)
        chk("mulh_by_one_p", it.result === {32{sm[1] & b[31]}},
            $sformatf("rs1==1 b=%0h sm=%0b got=%0h", b, sm, it.result));
      if (b == 1)
        chk("mulh_by_one_p", it.result === {32{sm[0] & a[31]}},
            $sformatf("rs2==1 a=%0h sm=%0b got=%0h", a, sm, it.result));
    end
  endfunction

  //--------------------------------------------------------------------------
  // MULH_6 / MULHU_3: full 64-bit product from two instructions
  //   MULH  rdh, rs1, rs2   (or MULHU)  -> upper 32 bits
  //   MUL   rdl, rs1, rs2               -> lower 32 bits
  //   {rdh, rdl} must equal the full product (signed for MULH, unsigned for MULHU).
  // The MUL must follow the MULH/MULHU with the same rs1/rs2 values.
  // MULHSU is not part of this sequence in the spec, so it is not paired.
  //--------------------------------------------------------------------------
  function void track_pair(mul_item it);
    logic [63:0] full_exp;

    if (is_rv32m_mulh(it)) begin
      hi_valid = 1;
      hi_a     = it.operand_a;
      hi_b     = it.operand_b;
      hi_res   = it.result;
      hi_sm    = it.signed_mode;
    end
    else if (is_rv32m_mul(it)) begin
      if (hi_valid && hi_a === it.operand_a && hi_b === it.operand_b &&
          (hi_sm == 2'b11 || hi_sm == 2'b00)) begin
        full_exp = mul_golden64(it.operand_a, it.operand_b, hi_sm);
        chk((hi_sm == 2'b11) ? "mulh_full_product_p" : "mulhu_full_product_p",
            {hi_res, it.result} === full_exp,
            $sformatf("a=%0h b=%0h got={%0h,%0h} exp=%0h",
                      it.operand_a, it.operand_b, hi_res, it.result, full_exp));
      end
      hi_valid = 0;   // history is used once, or dropped if operands differ
    end
  endfunction

  //--------------------------------------------------------------------------
  // MUL checker
  //--------------------------------------------------------------------------
  task check_mul();
    mul_item     item;
    logic [31:0] expected;
    forever begin
      mul_fifo.get(item);

      // Scope: RV32M MUL (MAC32, c==0) and MULH/MULHSU/MULHU. p.mac (c!=0) and
      // p.msu are PULP: checked only when check_pulp_mac is set.
      if (!(is_rv32m_mul(item) || is_rv32m_mulh(item)) &&
          !(check_pulp_mac && item.operator inside {MUL_MAC32, MUL_MSU32})) begin
        mul_skip++;
        `uvm_info("SB_MUL", $sformatf("SKIP | op=%0b c=%0h not RV32M", item.operator, item.operand_c), UVM_HIGH)
        continue;
      end

      expected = mul_golden(item.operator, item.operand_a, item.operand_b,
                            item.operand_c, item.signed_mode);

      if ($isunknown(expected)) begin
        mul_skip++;
        `uvm_info("SB_MUL", $sformatf("SKIP | op=%0b no reference", item.operator), UVM_HIGH)
        continue;
      end

      if (item.result === expected) begin
        mul_pass++;
        `uvm_info("SB_MUL", $sformatf("PASS | op=%0b sm=%0b a=%0h b=%0h | exp=%0h got=%0h",
          item.operator, item.signed_mode, item.operand_a, item.operand_b,
          expected, item.result), UVM_HIGH)
      end else begin
        mul_fail++;
        `uvm_error("SB_MUL", $sformatf(
          "FAIL | op=%0b sm=%0b a=%0h b=%0h c=%0h | exp=%0h got=%0h  <<< MISMATCH",
          item.operator, item.signed_mode, item.operand_a, item.operand_b,
          item.operand_c, expected, item.result))
      end

      check_mul_props(item);    // GEN_4, GEN_5, MUL_1, smode legality
      track_pair(item);         // MULH_6, MULHU_3

      // CHK:C-06  MULH vs MULHU consistency for non-negative operands
      if (item.operator == MUL_H && item.signed_mode == 2'b11 &&
          !item.operand_a[31] && !item.operand_b[31]) begin
        mulh_pending = 1;
        mulh_a       = item.operand_a;
        mulh_b       = item.operand_b;
        mulh_res     = item.result;
      end
      else if (item.operator == MUL_H && item.signed_mode == 2'b00) begin
        if (mulh_pending &&
            mulh_a == item.operand_a && mulh_b == item.operand_b) begin
          chk("mulh_mulhu_agree_p", mulh_res === item.result,
              $sformatf("a=%08h b=%08h MULH=%08h MULHU=%08h",
                        item.operand_a, item.operand_b,
                        mulh_res, item.result));
        end
        mulh_pending = 0;
      end

      // CHK:C-10  Latency checks
      if (is_rv32m_mul(item)) begin
        if (item.latency != 1)
          timing_msg("mul_lat_p",
            $sformatf("MUL latency=%0d exp=1 a=%08h b=%08h",
                      item.latency, item.operand_a, item.operand_b));
      end
      else if (is_rv32m_mulh(item)) begin
        if (item.latency != 5)
          timing_msg("mulh_lat_p",
            $sformatf("MULH latency=%0d exp=5 sm=%02b a=%08h b=%08h",
                      item.latency, item.signed_mode,
                      item.operand_a, item.operand_b));
      end
    end
  endtask

  //--------------------------------------------------------------------------
  // Check phase: nothing should be left unchecked, and something must have run
  //--------------------------------------------------------------------------
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (alu_fifo.used() != 0)
      `uvm_error("SB_ALU", $sformatf("%0d ALU item(s) left unchecked in FIFO", alu_fifo.used()))
    if (mul_fifo.used() != 0)
      `uvm_error("SB_MUL", $sformatf("%0d MUL item(s) left unchecked in FIFO", mul_fifo.used()))
    if ((alu_pass + alu_fail + alu_skip) == 0)
      `uvm_warning("SB_ALU", "No ALU transactions were observed")
    if ((mul_pass + mul_fail + mul_skip) == 0)
      `uvm_warning("SB_MUL", "No MUL transactions were observed")
  endfunction

  //--------------------------------------------------------------------------
  // Report
  //--------------------------------------------------------------------------
  function void report_phase(uvm_phase phase);
    print_summary();
  endfunction

  function void print_summary();
    int total_p = alu_pass + mul_pass;
    int total_f = alu_fail + mul_fail;
    int total   = total_p + total_f;
    real rate   = (total > 0) ? (real'(total_p) / real'(total)) * 100.0 : 0.0;

    `uvm_info(get_type_name(), "+------------------------------------------------+", UVM_LOW)
    `uvm_info(get_type_name(), "|        RISCV32IM ALU/DIV & MUL SCOREBOARD      |", UVM_LOW)
    `uvm_info(get_type_name(), "+------------------------------------------------+", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  ALU : PASS=%5d  FAIL=%5d  SKIP=%5d     |", alu_pass, alu_fail, alu_skip), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  MUL : PASS=%5d  FAIL=%5d  SKIP=%5d     |", mul_pass, mul_fail, mul_skip), UVM_LOW)
    `uvm_info(get_type_name(), "+------------------------------------------------+", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  TOTAL CHECKS : %6d                       |", total),   UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  PASSED       : %6d                       |", total_p), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  FAILED       : %6d                       |", total_f), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  Pass Rate    : %6.2f%%                      |", rate),    UVM_LOW)
    `uvm_info(get_type_name(), "+------------------------------------------------+", UVM_LOW)

    // Per-property results (names = Checking-sheet "property name" column)
    foreach (prop_pass[p])
      `uvm_info(get_type_name(),
        $sformatf("  %-30s PASS=%5d FAIL=%5d", p, prop_pass[p], prop_fail[p]), UVM_LOW)
  endfunction

endclass

`endif
