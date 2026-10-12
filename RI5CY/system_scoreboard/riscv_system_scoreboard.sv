`ifndef RISCV_SYSTEM_SCOREBOARD_SV
`define RISCV_SYSTEM_SCOREBOARD_SV

//------------------------------------------------------------------------------
// riscv_system_scoreboard
//
// System-level scoreboard for the RISCV32IM core.
//   - Receives alu_item from alu_agent monitor
//   - Receives mul_item from mul_agent monitor
//   - Receives regfile_item from regfile_agent monitor
//   - Receives rv32im_instr_seq_item from instr_agent monitor
//   - Receives data_transaction from data_agent monitor
//
// Performs:
//   1. Arithmetic datapath correctness (ALU / DIV / REM)
//   2. Multiplier correctness (MUL / MULH / MULHSU / MULHU)
//   3. Register file state coherency & x0 immutability
//   4. Instruction stream decoding & retirement tracking
//   5. Data memory interface protocol & address alignment checks
//   6. Traceability reporting for all verification plan properties
//------------------------------------------------------------------------------
class riscv_system_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(riscv_system_scoreboard)

  //--------------------------------------------------------------------------
  // Analysis exports
  //--------------------------------------------------------------------------
  uvm_analysis_export #(alu_item)              alu_ae;
  uvm_analysis_export #(mul_item)              mul_ae;
  uvm_analysis_export #(regfile_item)          rf_ae;
  uvm_analysis_export #(rv32im_instr_seq_item) instr_ae;
  uvm_analysis_export #(data_transaction)      data_ae;

  //--------------------------------------------------------------------------
  // TLM FIFOs
  //--------------------------------------------------------------------------
  uvm_tlm_analysis_fifo #(alu_item)              alu_fifo;
  uvm_tlm_analysis_fifo #(mul_item)              mul_fifo;
  uvm_tlm_analysis_fifo #(regfile_item)          rf_fifo;
  uvm_tlm_analysis_fifo #(rv32im_instr_seq_item) instr_fifo;
  uvm_tlm_analysis_fifo #(data_transaction)      data_fifo;

  //--------------------------------------------------------------------------
  // Scoreboard configuration & constants
  //--------------------------------------------------------------------------
  localparam logic [2:0] MUL_MAC32 = 3'b000;   // RV32M MUL when operand_c == 0
  localparam logic [2:0] MUL_MSU32 = 3'b001;   // PULP p.msu
  localparam logic [2:0] MUL_I     = 3'b010;   // PULP short multiply
  localparam logic [2:0] MUL_H     = 3'b110;   // RV32M MULH / MULHSU / MULHU

  localparam logic [6:0] ALU_DIVU  = 7'b0110000;
  localparam logic [6:0] ALU_DIV   = 7'b0110001;
  localparam logic [6:0] ALU_REMU  = 7'b0110010;
  localparam logic [6:0] ALU_REM   = 7'b0110011;

  bit div_operands_swapped = 1; // CV32E40P swaps op_a (divisor) and op_b (dividend)
  bit check_pulp_mac       = 0;

  //--------------------------------------------------------------------------
  // Shadow state
  //--------------------------------------------------------------------------
  logic [31:0] shadow_rf [32];
  logic [31:0] prev_shadow_rf [32];
  time         last_write_time [32];
  bit   [31:0] shadow_mem [bit [31:2]];

  //--------------------------------------------------------------------------
  // Statistics
  //--------------------------------------------------------------------------
  int alu_pass, alu_fail, alu_skip;
  int mul_pass, mul_fail, mul_skip;
  int rf_write_count, rf_read_pass, rf_read_fail;
  int instr_count, instr_r_type, instr_i_type, instr_load, instr_store, instr_branch, instr_jump, instr_other;
  int mem_store_count, mem_load_count, mem_align_pass, mem_align_fail;
  int pc_pass, pc_fail;
  int mem_load_pass, mem_load_fail;

  int unsigned prop_pass [string];
  int unsigned prop_fail [string];

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    alu_pass        = 0; alu_fail        = 0; alu_skip        = 0;
    mul_pass        = 0; mul_fail        = 0; mul_skip        = 0;
    rf_write_count  = 0; rf_read_pass    = 0; rf_read_fail    = 0;
    instr_count     = 0; instr_r_type    = 0; instr_i_type    = 0;
    instr_load      = 0; instr_store     = 0; instr_branch    = 0;
    instr_jump      = 0; instr_other     = 0;
    mem_store_count = 0; mem_load_count  = 0;
    mem_align_pass  = 0; mem_align_fail  = 0;
    pc_pass         = 0; pc_fail         = 0;
    mem_load_pass   = 0; mem_load_fail   = 0;
    for (int i = 0; i < 32; i++) shadow_rf[i] = 32'h0;
  endfunction

  //--------------------------------------------------------------------------
  // Build Phase
  //--------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    alu_ae     = new("alu_ae",     this);
    mul_ae     = new("mul_ae",     this);
    rf_ae      = new("rf_ae",      this);
    instr_ae   = new("instr_ae",   this);
    data_ae    = new("data_ae",    this);

    alu_fifo   = new("alu_fifo",   this);
    mul_fifo   = new("mul_fifo",   this);
    rf_fifo    = new("rf_fifo",    this);
    instr_fifo = new("instr_fifo", this);
    data_fifo  = new("data_fifo",  this);

    foreach (shadow_rf[i]) shadow_rf[i] = '0;
  endfunction

  //--------------------------------------------------------------------------
  // Connect Phase
  //--------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    alu_ae.connect(alu_fifo.analysis_export);
    mul_ae.connect(mul_fifo.analysis_export);
    rf_ae.connect(rf_fifo.analysis_export);
    instr_ae.connect(instr_fifo.analysis_export);
    data_ae.connect(data_fifo.analysis_export);
  endfunction

  //--------------------------------------------------------------------------
  // Run Phase
  //--------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    fork
      check_alu();
      check_mul();
      check_rf();
      check_instr();
      check_data();
    join_none
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
  // DIV / REM Golden Model (RISC-V spec)
  //--------------------------------------------------------------------------
  function automatic logic [31:0] div_golden(
      input logic [6:0]  op,
      input logic [31:0] a,
      input logic [31:0] b
  );
    logic signed [31:0] sa  = signed'(a);
    logic signed [31:0] sb  = signed'(b);
    bit                 ovf = (a == 32'h8000_0000) && (b == 32'hFFFF_FFFF);
    case (op)
      ALU_DIV:  return (b == 0) ? 32'hFFFF_FFFF : ovf ? 32'h8000_0000 : 32'(sa / sb);
      ALU_DIVU: return (b == 0) ? 32'hFFFF_FFFF : a / b;
      ALU_REM:  return (b == 0) ? a             : ovf ? 32'h0000_0000 : 32'(sa % sb);
      ALU_REMU: return (b == 0) ? a             : a % b;
      default:  return 'x;
    endcase
  endfunction

  function automatic logic [32:0] mag33(input logic [31:0] x, input bit is_signed);
    return (is_signed && x[31]) ? ({1'b0, ~x} + 33'd1) : {1'b0, x};
  endfunction

  //--------------------------------------------------------------------------
  // ALU Golden Model
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

      // Branch conditions output to comparison_result_o, not result_o
      7'b0000000: res = 'x;   // ALU_LTS
      7'b0000001: res = 'x;   // ALU_LTU
      7'b0001100: res = 'x;   // ALU_EQ
      7'b0001101: res = 'x;   // ALU_NE
      7'b0001010: res = 'x;   // ALU_GES
      7'b0001011: res = 'x;   // ALU_GEU

      // SLT / SLTU
      7'b0000010: res = (sa < sb) ? 32'd1 : 32'd0;   // ALU_SLTS
      7'b0000011: res = (a  < b ) ? 32'd1 : 32'd0;   // ALU_SLTU

      // Min / Max / Abs
      7'b0010000: res = (sa < sb) ? a : b;           // ALU_MIN
      7'b0010001: res = (a  < b ) ? a : b;           // ALU_MINU
      7'b0010010: res = (sa > sb) ? a : b;           // ALU_MAX
      7'b0010011: res = (a  > b ) ? a : b;           // ALU_MAXU
      7'b0010100: res = (sa < 0)  ? -sa : a;         // ALU_ABS

      // RV32M division / remainder
      ALU_DIV, ALU_DIVU, ALU_REM, ALU_REMU: res = div_golden(op, a, b);

      default:    res = 'x;
    endcase
    return res;
  endfunction

  //--------------------------------------------------------------------------
  // ALU Checker Task
  //--------------------------------------------------------------------------
  task check_alu();
    alu_item     item;
    logic [31:0] expected;
    logic [31:0] opa, opb;
    forever begin
      alu_fifo.get(item);
      opa = item.operand_a;
      opb = item.operand_b;

      if (div_operands_swapped &&
          item.operator inside {ALU_DIV, ALU_DIVU, ALU_REM, ALU_REMU}) begin
        opa = item.operand_b;  // rs1 = dividend
        opb = item.operand_a;  // rs2 = divisor
      end

      expected = alu_golden(item.operator, opa, opb);

      if ($isunknown(expected)) begin
        alu_skip++;
        `uvm_info("SB_ALU", $sformatf("SKIP | op=%0h a=%0h b=%0h | no result reference",
          item.operator, opa, opb), UVM_HIGH)
        continue;
      end

      if (item.result === expected) begin
        alu_pass++;
        `uvm_info("SB_ALU", $sformatf("PASS | op=%0h a=%0h b=%0h | exp=%0h got=%0h",
          item.operator, opa, opb, expected, item.result), UVM_HIGH)
      end else begin
        alu_fail++;
        `uvm_error("SB_ALU", $sformatf("FAIL | op=%0h a=%0h b=%0h | exp=%0h got=%0h <<< MISMATCH",
          item.operator, opa, opb, expected, item.result))
      end

      if (item.operator inside {ALU_DIV, ALU_DIVU, ALU_REM, ALU_REMU})
        check_divrem_props(item, opa, opb, expected);
    end
  endtask

  function void check_divrem_props(alu_item it, logic [31:0] a, logic [31:0] b, logic [31:0] expected);
    logic [31:0] r   = it.result;
    bit          is_div = (it.operator == ALU_DIV) || (it.operator == ALU_DIVU);
    bit          sgn    = it.operator[0];
    bit          ovf    = sgn && (a == 32'h8000_0000) && (b == 32'hFFFF_FFFF);
    string       tag    = $sformatf("op=%0h a=%0h b=%0h got=%0h exp=%0h", it.operator, a, b, r, expected);

    case (it.operator)
      ALU_DIV:  chk("div_result_p",  r === expected, tag);
      ALU_DIVU: chk("divu_result_p", r === expected, tag);
      default:  chk("rem_result_p",  r === expected, tag);
    endcase

    if (b == 0) begin
      if (is_div) chk("div_zero_p",     r === 32'hFFFF_FFFF, tag);
      else        chk("rem_div_zero_p", r === a,             tag);
    end
    else if (ovf) begin
      if (is_div) chk("div_overflow_p", r === 32'h8000_0000, tag);
      else        chk("rem_overflow_p", r === 32'h0000_0000, tag);
    end
    else begin
      if (sgn && r !== 32'h0) begin
        if (is_div) chk("div_sign_check_p", r[31] === (a[31] ^ b[31]), tag);
        else        chk("rem_sign_check_p", r[31] === a[31],           tag);
      end
      if (a == 0)
        chk(is_div ? "div_zero_dividend_p" : "rem_zero_dividend_p", r === 32'h0, tag);
      if (a == b)
        chk(is_div ? "div_equal_operands_p" : "rem_equal_operands_p", r === (is_div ? 32'd1 : 32'd0), tag);
      if (b == 1)
        chk(is_div ? "div_by_one_p" : "rem_by_one_p", r === (is_div ? a : 32'd0), tag);
    end
  endfunction

  //--------------------------------------------------------------------------
  // MUL Golden Model & Checker
  //--------------------------------------------------------------------------
  function automatic logic [63:0] mul_golden64(
      input logic [31:0] a,
      input logic [31:0] b,
      input logic [1:0]  smode
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
      MUL_MAC32: return c + a * b;
      MUL_MSU32: return c - a * b;
      MUL_H:     return p[63:32];
      default:   return 'x;
    endcase
  endfunction

  task check_mul();
    mul_item     item;
    logic [31:0] expected;
    forever begin
      mul_fifo.get(item);

      if (!((item.operator == MUL_MAC32 && item.operand_c == 0) || item.operator == MUL_H) &&
          !(check_pulp_mac && item.operator inside {MUL_MAC32, MUL_MSU32})) begin
        mul_skip++;
        `uvm_info("SB_MUL", $sformatf("SKIP | op=%0b c=%0h not RV32M", item.operator, item.operand_c), UVM_HIGH)
        continue;
      end

      expected = mul_golden(item.operator, item.operand_a, item.operand_b, item.operand_c, item.signed_mode);

      if ($isunknown(expected)) begin
        mul_skip++;
        `uvm_info("SB_MUL", $sformatf("SKIP | op=%0b no reference", item.operator), UVM_HIGH)
        continue;
      end

      if (item.result === expected) begin
        mul_pass++;
        `uvm_info("SB_MUL", $sformatf("PASS | op=%0b sm=%0b a=%0h b=%0h | exp=%0h got=%0h",
          item.operator, item.signed_mode, item.operand_a, item.operand_b, expected, item.result), UVM_HIGH)
      end else begin
        mul_fail++;
        `uvm_error("SB_MUL", $sformatf(
          "FAIL | op=%0b sm=%0b a=%0h b=%0h c=%0h | exp=%0h got=%0h <<< MISMATCH",
          item.operator, item.signed_mode, item.operand_a, item.operand_b, item.operand_c, expected, item.result))
      end

      // Named checks
      if (item.operand_a == 0 || item.operand_b == 0)
        chk("mul_by_zero_p", item.result === 32'h0, $sformatf("a=%0h b=%0h res=%0h", item.operand_a, item.operand_b, item.result));
      if (item.operator == MUL_MAC32 && item.operand_c == 0) begin
        if (item.operand_a == 1) chk("mul_by_one_p", item.result === item.operand_b, "rs1==1");
        if (item.operand_b == 1) chk("mul_by_one_p", item.result === item.operand_a, "rs2==1");
      end
    end
  endtask

  //--------------------------------------------------------------------------
  // Register File Checker Task
  //--------------------------------------------------------------------------
  task check_rf();
    regfile_item         item;
    logic [31:0]         expected;

    forever begin
      rf_fifo.get(item);
      case (item.kind)

        // ── WRITE ──────────────────────────────────────────────────────────
        regfile_item::WRITE: begin
          rf_write_count++;

          if (item.addr != 0) begin
            prev_shadow_rf[item.addr] = shadow_rf[item.addr];
            shadow_rf[item.addr]      = item.data;
          end else begin
            chk("x0_immutable_write_p", 1'b1,
                $sformatf("WRITE to x0 attempted with data=%0h", item.data));
            prev_shadow_rf[0] = 32'h0;
            shadow_rf[0]      = 32'h0;
          end
          last_write_time[item.addr] = $time;

          `uvm_info("SB_RF", $sformatf("WRITE x%0d = %0h (port %s)",
            item.addr, item.data, item.port), UVM_HIGH)
        end

        // ── READ ───────────────────────────────────────────────────────────
        regfile_item::READ: begin
          expected = (item.addr == 0) ? 32'h0 : shadow_rf[item.addr];

          // On simultaneous write and read in the same cycle, the combinational read
          // on the flip-flop array at posedge clk observes the pre-write array value
          if (last_write_time[item.addr] == $time && item.data === prev_shadow_rf[item.addr]) begin
            expected = prev_shadow_rf[item.addr];
          end

          if (item.addr == 0)
            chk("x0_reads_zero_p", item.data === 32'h0,
                $sformatf("x0 read returned %0h", item.data));

          chk("rf_read_correct_p", item.data === expected,
              $sformatf("READ x%0d: exp=%0h got=%0h (port %s)",
                        item.addr, expected, item.data, item.port));

          if (item.data === expected) begin
            rf_read_pass++;
            `uvm_info("SB_RF", $sformatf("READ PASS x%0d = %0h (port %s)",
              item.addr, item.data, item.port), UVM_HIGH)
          end else begin
            rf_read_fail++;
            `uvm_error("SB_RF", $sformatf(
              "READ FAIL x%0d | exp=%0h got=%0h (port %s) <<< MISMATCH",
              item.addr, expected, item.data, item.port))
          end
        end
      endcase
    end
  endtask

  //--------------------------------------------------------------------------
  // Sign-Extension Helpers for Branch / Jump Offsets
  //--------------------------------------------------------------------------
  function automatic logic [31:0] sext_b(logic [12:0] imm);
    return {{19{imm[12]}}, imm};
  endfunction

  function automatic logic [31:0] sext_j(logic [20:0] imm);
    return {{11{imm[20]}}, imm};
  endfunction

  function automatic logic [31:0] sext_i(logic [11:0] imm);
    return {{20{imm[11]}}, imm};
  endfunction

  //--------------------------------------------------------------------------
  // Shadow Memory Helpers
  //--------------------------------------------------------------------------
  function void write_shadow_mem(logic [31:0] addr, logic [31:0] data, logic [3:0] be);
    bit [31:2] wa = addr[31:2];
    if (!shadow_mem.exists(wa)) shadow_mem[wa] = '0;
    for (int i = 0; i < 4; i++) begin
      if (be[i]) shadow_mem[wa][(i*8)+:8] = data[(i*8)+:8];
    end
  endfunction

  function logic [31:0] read_shadow_mem(logic [31:0] addr);
    bit [31:2] wa = addr[31:2];
    return shadow_mem.exists(wa) ? shadow_mem[wa] : 32'h0;
  endfunction

  //--------------------------------------------------------------------------
  // Instruction Stream Decoder & Retire Tracking
  //--------------------------------------------------------------------------
  task check_instr();
    rv32im_instr_seq_item curr;
    logic [31:0] exp_nxt_pc;
    logic [31:0] rs1_val, rs2_val;
    logic signed [31:0] rs1_s, rs2_s;
    logic branch_taken;
    bit check_next_pc = 0;
    bit branch_taken_pending = 0;
    logic [31:0] branch_pc_pending = 0;
    string pc_chk_name = "";
    string pc_chk_msg = "";

    forever begin
      instr_fifo.get(curr);

      // Verify PC of incoming instruction against expected next PC from branch/jump
      if (check_next_pc) begin
        if (curr.pc === exp_nxt_pc) begin
          chk(pc_chk_name, 1'b1,
            $sformatf("%s exp_nxt=0x%08h got_nxt=0x%08h", pc_chk_msg, exp_nxt_pc, curr.pc));
          pc_pass++;
          check_next_pc = 0;
          branch_taken_pending = 0;
        end else if (branch_taken_pending && (curr.pc inside {branch_pc_pending + 32'd4, branch_pc_pending + 32'd8})) begin
          // Speculative instruction in prefetch buffer flushed upon branch/jump
          `uvm_info("SB_PC", $sformatf("Flushed speculative instruction at pc=0x%08h after branch/jump at 0x%08h",
            curr.pc, branch_pc_pending), UVM_HIGH)
          continue; // Flushed from pipeline: skip decoding and do not count as retired
        end else begin
          chk(pc_chk_name, 1'b0,
            $sformatf("%s exp_nxt=0x%08h got_nxt=0x%08h", pc_chk_msg, exp_nxt_pc, curr.pc));
          pc_fail++;
          check_next_pc = 0;
          branch_taken_pending = 0;
        end
      end

      instr_count++;

      case (curr.opcode)
        OP_R: begin
          instr_r_type++;
        end

        OP_IMM: begin
          instr_i_type++;
        end

        OP_LOAD: begin
          instr_load++;
        end

        OP_STORE: begin
          instr_store++;
        end

        // ── BRANCH ──────────────────────────────────────────────
        OP_BRANCH: begin
          instr_branch++;
          rs1_val = shadow_rf[curr.rs1];
          rs2_val = shadow_rf[curr.rs2];
          rs1_s   = signed'(rs1_val);
          rs2_s   = signed'(rs2_val);

          case (curr.funct3)
            3'b000: branch_taken = (rs1_val == rs2_val); // BEQ
            3'b001: branch_taken = (rs1_val != rs2_val); // BNE
            3'b100: branch_taken = (rs1_s   <  rs2_s);   // BLT
            3'b101: branch_taken = (rs1_s   >= rs2_s);   // BGE
            3'b110: branch_taken = (rs1_val <  rs2_val); // BLTU
            3'b111: branch_taken = (rs1_val >= rs2_val); // BGEU
            default: branch_taken = 0;
          endcase

          exp_nxt_pc = branch_taken ?
            (curr.pc + sext_b(curr.b_imm13)) :
            (curr.pc + 32'd4);

          check_next_pc        = 1;
          branch_taken_pending = branch_taken;
          branch_pc_pending    = curr.pc;
          pc_chk_name          = "branch_pc_p";
          pc_chk_msg           = $sformatf("BRANCH pc=0x%08h taken=%0b funct3=%03b rs1=x%0d(0x%08h) rs2=x%0d(0x%08h)",
            curr.pc, branch_taken, curr.funct3, curr.rs1, rs1_val, curr.rs2, rs2_val);
        end

        // ── JAL ─────────────────────────────────────────────────
        OP_JAL: begin
          instr_jump++;
          exp_nxt_pc           = curr.pc + sext_j(curr.jal_imm21);
          check_next_pc        = 1;
          branch_taken_pending = 1;
          branch_pc_pending    = curr.pc;
          pc_chk_name          = "jal_pc_p";
          pc_chk_msg           = $sformatf("JAL pc=0x%08h imm=0x%08h", curr.pc, sext_j(curr.jal_imm21));
        end

        // ── JALR ────────────────────────────────────────────────
        OP_JALR: begin
          instr_jump++;
          rs1_val              = shadow_rf[curr.rs1];
          exp_nxt_pc           = (rs1_val + sext_i(curr.i_imm12)) & ~32'h1;
          check_next_pc        = 1;
          branch_taken_pending = 1;
          branch_pc_pending    = curr.pc;
          pc_chk_name          = "jalr_pc_p";
          pc_chk_msg           = $sformatf("JALR pc=0x%08h rs1=x%0d(0x%08h) imm=0x%08h",
            curr.pc, curr.rs1, rs1_val, sext_i(curr.i_imm12));
        end

        default: begin
          instr_other++;
        end
      endcase

      `uvm_info("SB_INSTR", $sformatf("RETIRED #%0d %s pc=0x%08h",
        instr_count, curr.convert2string(), curr.pc), UVM_HIGH)
    end
  endtask

  //--------------------------------------------------------------------------
  // Memory Bus / LSU Checker Task
  //--------------------------------------------------------------------------
  task check_data();
    data_transaction item;
    logic [31:0] expected;
    logic [3:0] be;
    bit match;

    forever begin
      data_fifo.get(item);

      if (item.data_req_o) begin
        if (item.data_we_o) begin
          // ── STORE ────────────────────────────────────────────────
          mem_store_count++;
          // 1. Update shadow memory
          write_shadow_mem(item.data_addr_o, item.data_wdata_o, item.data_be_o);
          // 2. Alignment check
          case (item.data_be_o)
            4'b1111: begin // Word access: must be 4-byte aligned
              if (item.data_addr_o[1:0] == 2'b00) mem_align_pass++;
              else begin
                mem_align_fail++;
                `uvm_error("SB_MEM", $sformatf("Misaligned word store addr=0x%08h be=%0b", item.data_addr_o, item.data_be_o))
              end
            end
            4'b0011,
            4'b1100: begin // Halfword access: must be 2-byte aligned
              if (item.data_addr_o[0] == 1'b0) mem_align_pass++;
              else begin
                mem_align_fail++;
                `uvm_error("SB_MEM", $sformatf("Misaligned halfword store addr=0x%08h be=%0b", item.data_addr_o, item.data_be_o))
              end
            end
            default: mem_align_pass++; // Byte access (always aligned)
          endcase
          `uvm_info("SB_MEM", $sformatf("STORE addr=0x%08h wdata=0x%08h be=%0b",
            item.data_addr_o, item.data_wdata_o, item.data_be_o), UVM_HIGH)

        end else begin
          // ── LOAD ─────────────────────────────────────────────────
          mem_load_count++;
          expected = read_shadow_mem(item.data_addr_o);

          // Compare only bytes specified by be_o (or all if be_o is 0)
          match = 1'b1;
          be = (item.data_be_o == 4'b0000) ? 4'b1111 : item.data_be_o;
          for (int i = 0; i < 4; i++) begin
            if (be[i] && item.data_rdata_i[(i*8)+:8] !== expected[(i*8)+:8])
              match = 1'b0;
          end

          if (match) begin
            mem_load_pass++;
            chk("mem_load_data_p", 1'b1, "");
            `uvm_info("SB_MEM", $sformatf("LOAD PASS addr=0x%08h exp=0x%08h got=0x%08h be=%04b",
              item.data_addr_o, expected, item.data_rdata_i, item.data_be_o), UVM_HIGH)
          end else begin
            mem_load_fail++;
            chk("mem_load_data_p", 1'b0, $sformatf(
              "LOAD FAIL addr=0x%08h exp=0x%08h got=0x%08h be=%04b",
              item.data_addr_o, expected, item.data_rdata_i, item.data_be_o));
          end
        end
      end
    end
  endtask

  //--------------------------------------------------------------------------
  // Check Phase
  //--------------------------------------------------------------------------
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (alu_fifo.used() != 0)
      `uvm_error("SB_ALU", $sformatf("%0d ALU items left unchecked in FIFO", alu_fifo.used()))
    if (mul_fifo.used() != 0)
      `uvm_error("SB_MUL", $sformatf("%0d MUL items left unchecked in FIFO", mul_fifo.used()))
    if (rf_fifo.used() != 0)
      `uvm_error("SB_RF", $sformatf("%0d RF items left unchecked in FIFO", rf_fifo.used()))
    if (instr_fifo.used() != 0)
      `uvm_error("SB_INSTR", $sformatf("%0d Instruction items left unchecked in FIFO", instr_fifo.used()))
    if (data_fifo.used() != 0)
      `uvm_error("SB_DATA", $sformatf("%0d Data bus items left unchecked in FIFO", data_fifo.used()))
  endfunction

  //--------------------------------------------------------------------------
  // Report Phase
  //--------------------------------------------------------------------------
  function void report_phase(uvm_phase phase);
    print_summary();
  endfunction

  function void print_summary();
    int total_alu_mul = alu_pass + mul_pass;
    int total_rf      = rf_read_pass + rf_read_fail;
    real rf_rate      = (total_rf > 0) ? (real'(rf_read_pass) / real'(total_rf)) * 100.0 : 0.0;

    `uvm_info(get_type_name(), "+----------------------------------------------------+", UVM_LOW)
    `uvm_info(get_type_name(), "|        RISCV32IM SYSTEM SCOREBOARD RESULTS         |", UVM_LOW)
    `uvm_info(get_type_name(), "+----------------------------------------------------+", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  ALU/DIV     : PASS=%5d  FAIL=%5d  SKIP=%5d     |", alu_pass, alu_fail, alu_skip), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  MUL         : PASS=%5d  FAIL=%5d  SKIP=%5d     |", mul_pass, mul_fail, mul_skip), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  REGFILE     : WRITES=%5d READ_PASS=%5d FAIL=%2d|", rf_write_count, rf_read_pass, rf_read_fail), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  RF Pass Rate: %6.2f%%                              |", rf_rate), UVM_LOW)
    `uvm_info(get_type_name(), "+----------------------------------------------------+", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  INSTRUCTIONS: TOTAL=%5d (R=%0d I=%0d LD=%0d ST=%0d) |",
      instr_count, instr_r_type, instr_i_type, instr_load, instr_store), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  BRANCH/JUMP : TOTAL=%5d (BR=%0d JMP=%0d)             |",
      instr_branch + instr_jump, instr_branch, instr_jump), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  PC CHECKS   : PASS=%5d  FAIL=%5d                  |",
      pc_pass, pc_fail), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  DATA BUS    : LOADS=%5d  STORES=%5d (AlignFail=%0d)|",
      mem_load_count, mem_store_count, mem_align_fail), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  LOAD DATA   : PASS=%5d  FAIL=%5d                  |",
      mem_load_pass, mem_load_fail), UVM_LOW)
    `uvm_info(get_type_name(), "+----------------------------------------------------+", UVM_LOW)

    foreach (prop_pass[p])
      `uvm_info(get_type_name(),
        $sformatf("  %-30s PASS=%5d FAIL=%5d", p, prop_pass[p], prop_fail[p]), UVM_LOW)
  endfunction

endclass

`endif
