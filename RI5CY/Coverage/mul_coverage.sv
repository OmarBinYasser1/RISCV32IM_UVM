`ifndef MUL_COVERAGE_SV
`define MUL_COVERAGE_SV

//------------------------------------------------------------------------------
// mul_coverage : plan "Coverage" sheet items for MUL / MULH / MULHSU / MULHU
//                that can be built from mul_item (subscribes to the mul monitor)
//
// How an RV32M multiply looks at the multiplier pins (CV32E40P decoder):
//   MUL    -> operator MUL_MAC32 (3'b000), operand_c == 0
//   MULH   -> operator MUL_H     (3'b110), signed_mode 2'b11
//   MULHSU -> operator MUL_H     (3'b110), signed_mode 2'b01
//   MULHU  -> operator MUL_H     (3'b110), signed_mode 2'b00
// Everything else (MUL_I, MUL_IR, dot products, MSU32, MAC32 with c != 0) is
// PULP-only and ignored.
//
// Plan item                         -> covergroup / coverpoint
//   RV32M_GEN_0   (4 instructions)  -> mul_cg.cp_instr   (unit level, see note 1)
//   RV32M_GEN_4   (x0 operand)      -> mul_cg.mul_by_zero_cov
//   RV32M_GEN_5   (x1 operand)      -> mul_cg.mul_by_one_cov
//   RV32M_GEN_8   (toggle product)  -> toggle_cg.toggle_cov
//   RV32M_MUL_1..5, MULH_1..4,
//   MULHSU_1..2,  MULHU_1           -> mul_cg.mul_sign_cov  (note 2)
//   RV32M_MUL_6   (overflow)        -> mul_cg.mul_overflow_cov, min_neg_x_m1_cov
//   RV32M_MULH_5, MULHSU_3, MULHU_2 -> mul_cg.hi_zero_cov
//   RV32M_MULH_6, MULHU_3           -> pair_cg.pair_cov
//
// Notes
//  1. The plan's GEN_0 cross uses opcode/funct7/funct3. That is decode level and
//     needs the instruction item, so here the four instructions are identified
//     from operator + signed_mode.
//  2. For MUL and MULH the "pos/neg" bins are the signs of the operands. For an
//     operand the instruction treats as UNSIGNED (rs2 of MULHSU, both of MULHU)
//     "neg" means "MSB set, i.e. value >= 2^31". Because MUL's low word is
//     identical for both interpretations, the four MUL bins also cover the
//     "signed range and unsigned range" request of RV32M_MUL_1.
//  3. Timing (GEN_1, GEN_2), forwarding (GEN_3) and the load/store/branch
//     dependencies (GEN_10..12) have no coverage in the plan (SVA items).
//  4. GEN_6, GEN_7, GEN_9 need rd / rs1 / rs2 register numbers: not in mul_item.
//------------------------------------------------------------------------------
class mul_coverage extends uvm_subscriber #(mul_item);
  `uvm_component_utils(mul_coverage)

  localparam logic [2:0] MUL_MAC32 = 3'b000;
  localparam logic [2:0] MUL_H     = 3'b110;

  localparam int K_MUL = 0, K_MULH = 1, K_MULHSU = 2, K_MULHU = 3, K_OTHER = 4;

  mul_item item;

  // toggle_cov history
  bit          prev_valid = 0;
  bit [31:0]   prev_result;

  // pair_cov history (MULH/MULHU followed by MUL with the same operands)
  bit          hi_valid = 0;
  bit [31:0]   hi_a, hi_b;
  bit [1:0]    hi_sm;
  int          pair_kind;     // 1 = MULH + MUL, 2 = MULHU + MUL

  //----------------------------------------------------------------------------
  // helpers
  //----------------------------------------------------------------------------
  function int mul_instr();
    if (item.operator == MUL_MAC32 && item.operand_c == 32'h0) return K_MUL;
    if (item.operator == MUL_H) begin
      case (item.signed_mode)
        2'b11:   return K_MULH;
        2'b01:   return K_MULHSU;
        2'b00:   return K_MULHU;
        default: return K_OTHER;
      endcase
    end
    return K_OTHER;
  endfunction

  // 64-bit product; sm = {rs2_signed, rs1_signed}
  function bit [63:0] prod64(bit [31:0] a, bit [31:0] b, bit [1:0] sm);
    bit signed [32:0] ea = $signed({sm[0] & a[31], a});
    bit signed [32:0] eb = $signed({sm[1] & b[31], b});
    bit signed [65:0] p  = ea * eb;
    return p[63:0];
  endfunction

  // 0 none, 1 rs1==0, 2 rs2==0, 3 both
  function int zero_which();
    return (item.operand_a == 32'h0 ? 1 : 0) | (item.operand_b == 32'h0 ? 2 : 0);
  endfunction

  // 0 none, 1 rs1==1, 2 rs2==1, 3 both
  function int one_which();
    return (item.operand_a == 32'h1 ? 1 : 0) | (item.operand_b == 32'h1 ? 2 : 0);
  endfunction

  // MUL: does the signed 64-bit product need more than 32 bits?
  function bit mul_overflows_32();
    bit [63:0] p = prod64(item.operand_a, item.operand_b, 2'b11);
    return (p[63:32] != {32{p[31]}});
  endfunction

  // class of the high word returned by MULH/MULHSU/MULHU: 0 zero, 1 all ones, 2 other
  function int hi_class();
    if (item.result == 32'h0)         return 0;
    if (item.result == 32'hFFFF_FFFF) return 1;
    return 2;
  endfunction

  function bit both_nonzero();
    return (item.operand_a != 32'h0) && (item.operand_b != 32'h0);
  endfunction

  //----------------------------------------------------------------------------
  // main multiplier covergroup
  //----------------------------------------------------------------------------
  covergroup mul_cg;
    option.per_instance = 1;

    // GEN_0 (unit level): all four RV32M multiplies seen
    cp_instr: coverpoint mul_instr() {
      bins mul    = {K_MUL};
      bins mulh   = {K_MULH};
      bins mulhsu = {K_MULHSU};
      bins mulhu  = {K_MULHU};
    }

    // GEN_4: multiplication by 0
    cp_zero: coverpoint zero_which() {
      bins rs1_zero  = {1};
      bins rs2_zero  = {2};
      bins both_zero = {3};
    }
    mul_by_zero_cov: cross cp_instr, cp_zero;

    // GEN_5: multiplication by 1
    cp_one: coverpoint one_which() {
      bins rs1_one  = {1};
      bins rs2_one  = {2};
      bins both_one = {3};
    }
    mul_by_one_cov: cross cp_instr, cp_one;

    // MUL_1..5, MULH_1..4, MULHSU_1..2, MULHU_1 : sign / MSB of rs1 x rs2
    //   MUL    : pos*pos MUL_2, pos*neg MUL_3, neg*pos MUL_4, neg*neg MUL_5
    //   MULH   : pos*pos MULH_1, pos*neg MULH_2, neg*pos MULH_3, neg*neg MULH_4
    //   MULHSU : pos*pos MULHSU_1, neg*pos MULHSU_2 (+ rs2 MSB set, extra)
    //   MULHU  : pos*pos MULHU_1 (+ MSB-set combinations, extra)
    cp_a_sign: coverpoint item.operand_a[31] { bins pos = {0}; bins neg = {1}; }
    cp_b_sign: coverpoint item.operand_b[31] { bins pos = {0}; bins neg = {1}; }
    mul_sign_cov: cross cp_instr, cp_a_sign, cp_b_sign;

    // MUL_6: upper 32 bits of the product != 0 (MUL only)
    mul_overflow_cov: coverpoint mul_overflows_32() iff (mul_instr() == K_MUL) {
      bins fits     = {0};
      bins overflow = {1};
    }
    // directed case: max_neg x -1
    min_neg_x_m1_cov: coverpoint (item.operand_a == 32'h8000_0000 && item.operand_b == 32'hFFFF_FFFF)
        iff (mul_instr() == K_MUL) {
      bins directed = {1};
    }

    // MULH_5 / MULHSU_3 / MULHU_2: non-zero x non-zero giving a zero high word
    cp_hi: coverpoint hi_class() iff (mul_instr() != K_MUL && both_nonzero()) {
      bins zero     = {0};
      bins all_ones = {1};
      bins other    = {2};
    }
    hi_zero_cov: cross cp_instr, cp_hi {
      ignore_bins mul_has_no_high_word = binsof(cp_instr.mul);
      // 0xFFFFFFFF x 0xFFFFFFFF = 0xFFFFFFFE_00000001: the unsigned high word can never be all ones
      ignore_bins mulhu_never_all_ones = binsof(cp_instr.mulhu) && binsof(cp_hi.all_ones);
    }
  endgroup

  //----------------------------------------------------------------------------
  // GEN_8: every bit of the product output rises and falls at least once
  //----------------------------------------------------------------------------
  covergroup toggle_cg with function sample(int unsigned bit_idx, bit rising);
    option.per_instance = 1;

    cp_bit: coverpoint bit_idx { bins b[] = {[0:31]}; }
    cp_dir: coverpoint rising  { bins rise = {1}; bins fall = {0}; }
    toggle_cov: cross cp_bit, cp_dir;
  endgroup

  //----------------------------------------------------------------------------
  // MULH_6 / MULHU_3: MULH (or MULHU) followed by MUL with the same operands,
  // so that {rdh, rdl} is the full 64-bit product
  //----------------------------------------------------------------------------
  covergroup pair_cg;
    option.per_instance = 1;

    pair_cov: coverpoint pair_kind {
      bins mulh_then_mul  = {1};
      bins mulhu_then_mul = {2};
    }
  endgroup

  // (constructor sits after the covergroup declarations: instances are created here)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    mul_cg    = new();
    toggle_cg = new();
    pair_cg   = new();
  endfunction

  //----------------------------------------------------------------------------
  function void sample_toggle();
    if (prev_valid) begin
      for (int unsigned i = 0; i < 32; i++)
        if (item.result[i] != prev_result[i])
          toggle_cg.sample(i, item.result[i]);
    end
    prev_result = item.result;
    prev_valid  = 1;
  endfunction

  function void track_pair();
    int k = mul_instr();
    if (k == K_MULH || k == K_MULHU) begin
      hi_valid = 1;
      hi_a     = item.operand_a;
      hi_b     = item.operand_b;
      hi_sm    = item.signed_mode;
    end
    else if (k == K_MUL) begin
      if (hi_valid && hi_a == item.operand_a && hi_b == item.operand_b) begin
        pair_kind = (hi_sm == 2'b11) ? 1 : 2;
        pair_cg.sample();
      end
      hi_valid = 0;
    end
  endfunction

  function void write(mul_item t);
    item = t;
    if (mul_instr() == K_OTHER) return;   // PULP-only operator: out of scope
    mul_cg.sample();
    sample_toggle();
    track_pair();
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("MUL_COV", $sformatf("coverage %%: mul=%0.1f toggle=%0.1f pair=%0.1f",
      mul_cg.get_inst_coverage(), toggle_cg.get_inst_coverage(),
      pair_cg.get_inst_coverage()), UVM_LOW)
  endfunction
endclass

`endif
