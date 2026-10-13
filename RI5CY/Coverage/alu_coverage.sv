`ifndef ALU_COVERAGE_SV
`define ALU_COVERAGE_SV

`define ALU_ADD  7'b0011000
`define ALU_SUB  7'b0011001
`define ALU_XOR  7'b0101111
`define ALU_OR   7'b0101110
`define ALU_AND  7'b0010101
`define ALU_SRA  7'b0100100
`define ALU_SRL  7'b0100101
`define ALU_SLL  7'b0100111
`define ALU_SLTS 7'b0000010
`define ALU_SLTU 7'b0000011
`define ALU_DIVU 7'b0110000
`define ALU_DIV  7'b0110001
`define ALU_REMU 7'b0110010
`define ALU_REM  7'b0110011
// Branch compares: the decoder maps BEQ/BNE/BLT/BGE/BLTU/BGEU onto these
`define ALU_LTS  7'b0000000
`define ALU_LTU  7'b0000001
`define ALU_GES  7'b0001010
`define ALU_GEU  7'b0001011
`define ALU_EQ   7'b0001100
`define ALU_NE   7'b0001101

//------------------------------------------------------------------------------
// alu_coverage : plan "Coverage" sheet items that can be built from alu_item
//
//   addsub_cg  : RV32I_ALUI_1                 (addi_overflow_cov)
//   slt_cg     : RV32I_ALUI_2, ALUI_3         (slti_cov, sltiu_cov, SEQZ idiom)
//   bitwise_cg : RV32I_ALUI_4                 (bitwise_imm_cov)
//   shift_cg   : RV32I_SHFT_1..3              (slli_cov, srli_cov, srai_cov)
//   branch_cg  : RV32I_BR_1                   (branch_cov)            <- NEW
//   div_cg     : RV32M_DIV_1, DIVU_2..5       (div_*_cov)
//   rem_cg     : RV32M_REM_1..5               (rem_*_cov)
//
// Notes
//  * ALU_ADD is also used by the core for load/store address generation, the
//    JALR/JAL link (PC+4) and AUIPC, so addsub_cg samples those too, not only
//    ADD/ADDI.
//  * DIV/DIVU/REM/REMU: the CV32E40P decoder SWAPS the operands on the way into
//    the ALU (operand_a = rs2 = divisor, operand_b = rs1 = dividend).
//    div_operands_swapped = 1 (default) makes every div/rem coverpoint use the
//    architectural rs1/rs2. Set it to 0 only if your alu monitor swaps back.
//  * Branch outcome (taken / not taken) is predicted from the operands, so no
//    change to alu_if / alu_item is needed.
//------------------------------------------------------------------------------
class alu_coverage extends uvm_subscriber #(alu_item);
  `uvm_component_utils(alu_coverage)

  alu_item item;

  bit div_operands_swapped = 1;

  //----------------------------------------------------------------------------
  // helpers
  //----------------------------------------------------------------------------
  function bit is_neg(bit [31:0] v);
    return v[31];
  endfunction

  function int pattern_of(bit [31:0] v);
    if (v == 32'h0)                     return 0;
    if (v == 32'hFFFF_FFFF)             return 1;
    if ((v & (v - 1)) == 0)             return 2;
    if (((~v) & ((~v) - 1)) == 0)       return 3;
    return 4;
  endfunction

  function bit add_overflowed();
    return (item.operand_a[31] == item.operand_b[31]) &&
           (item.result[31]    != item.operand_a[31]);
  endfunction

  function bit sub_overflowed();
    return (item.operand_a[31] != item.operand_b[31]) &&
           (item.result[31]    != item.operand_a[31]);
  endfunction

  function bit [4:0] shamt();
    return item.operand_b[4:0];
  endfunction

  // architectural rs1 / rs2 of a DIV/DIVU/REM/REMU item
  function bit [31:0] dividend();   // rs1
    return div_operands_swapped ? item.operand_b : item.operand_a;
  endfunction

  function bit [31:0] divisor();    // rs2
    return div_operands_swapped ? item.operand_a : item.operand_b;
  endfunction

  // Branch: rs1 = operand_a, rs2 = operand_b (decoder default operand muxes)
  // relation classes: 0 equal, 1 rs1<rs2, 2 rs1>rs2, 3 sign bits differ
  // (the "unsigned-wrap" corner: signed and unsigned order disagree)
  function int branch_rel();
    bit [31:0] a = item.operand_a;
    bit [31:0] b = item.operand_b;
    if (a == b)       return 0;
    if (a[31] != b[31]) return 3;
    return (a < b) ? 1 : 2;
  endfunction

  function bit branch_taken();
    bit [31:0] a = item.operand_a;
    bit [31:0] b = item.operand_b;
    case (item.operator)
      `ALU_EQ:  return (a == b);
      `ALU_NE:  return (a != b);
      `ALU_LTS: return ($signed(a) <  $signed(b));
      `ALU_GES: return ($signed(a) >= $signed(b));
      `ALU_LTU: return (a <  b);
      `ALU_GEU: return (a >= b);
      default:  return 1'b0;
    endcase
  endfunction

  //----------------------------------------------------------------------------
  // ADDI overflow                                                  RV32I_ALUI_1
  //----------------------------------------------------------------------------
  covergroup addsub_cg;
    option.per_instance = 1;

    cp_op: coverpoint item.operator {
      bins add = {`ALU_ADD};
      bins sub = {`ALU_SUB};
    }
    cp_sign_a: coverpoint is_neg(item.operand_a) { bins pos = {0}; bins neg = {1}; }
    cp_sign_b: coverpoint is_neg(item.operand_b) { bins pos = {0}; bins neg = {1}; }

    cp_overflow: coverpoint ((item.operator == `ALU_ADD) ? add_overflowed() : sub_overflowed()) {
      bins no_overflow = {0};
      bins overflow    = {1};
    }

    addi_overflow_cov: cross cp_op, cp_sign_a, cp_sign_b, cp_overflow {
      // ADD overflows only when both inputs have the same sign
      ignore_bins add_diff_sign_ovf =
        (binsof(cp_op.add) && binsof(cp_sign_a.pos) && binsof(cp_sign_b.neg) && binsof(cp_overflow.overflow)) ||
        (binsof(cp_op.add) && binsof(cp_sign_a.neg) && binsof(cp_sign_b.pos) && binsof(cp_overflow.overflow));
      // SUB overflows only when the inputs have different signs
      ignore_bins sub_same_sign_ovf =
        (binsof(cp_op.sub) && binsof(cp_sign_a.pos) && binsof(cp_sign_b.pos) && binsof(cp_overflow.overflow)) ||
        (binsof(cp_op.sub) && binsof(cp_sign_a.neg) && binsof(cp_sign_b.neg) && binsof(cp_overflow.overflow));
    }
  endgroup

  //----------------------------------------------------------------------------
  // SLTI / SLTIU                                          RV32I_ALUI_2, ALUI_3
  //----------------------------------------------------------------------------
  covergroup slt_cg;
    option.per_instance = 1;

    cp_op: coverpoint item.operator {
      bins slt  = {`ALU_SLTS};
      bins sltu = {`ALU_SLTU};
    }
    cp_sign_a: coverpoint is_neg(item.operand_a) { bins pos = {0}; bins neg = {1}; }
    cp_sign_b: coverpoint is_neg(item.operand_b) { bins pos = {0}; bins neg = {1}; }
    cp_result: coverpoint item.result[0]         { bins zero = {0}; bins one = {1}; }

    // signed: neg < pos is always 1, pos < neg is always 0
    slti_cov: cross cp_sign_a, cp_sign_b, cp_result iff (item.operator == `ALU_SLTS) {
      ignore_bins neg_pos_never_0 = binsof(cp_sign_a.neg) && binsof(cp_sign_b.pos) && binsof(cp_result.zero);
      ignore_bins pos_neg_never_1 = binsof(cp_sign_a.pos) && binsof(cp_sign_b.neg) && binsof(cp_result.one);
    }
    // unsigned: MSB-set is the larger number, so neg < pos is always 0, pos < neg always 1
    sltiu_cov: cross cp_sign_a, cp_sign_b, cp_result iff (item.operator == `ALU_SLTU) {
      ignore_bins neg_pos_never_1 = binsof(cp_sign_a.neg) && binsof(cp_sign_b.pos) && binsof(cp_result.one);
      ignore_bins pos_neg_never_0 = binsof(cp_sign_a.pos) && binsof(cp_sign_b.neg) && binsof(cp_result.zero);
    }

    // SEQZ idiom: SLTIU rd, rs1, 1 with rs1 == 0 and rs1 != 0
    cp_seqz_imm: coverpoint item.operand_b iff (item.operator == `ALU_SLTU) {
      bins imm_one = {32'h1};
    }
    cp_seqz_rs1: coverpoint (item.operand_a == 32'h0) iff (item.operator == `ALU_SLTU) {
      bins rs1_zero    = {1};
      bins rs1_nonzero = {0};
    }
    sltiu_seqz_cov: cross cp_seqz_imm, cp_seqz_rs1;
  endgroup

  //----------------------------------------------------------------------------
  // ANDI / ORI / XORI                                              RV32I_ALUI_4
  //----------------------------------------------------------------------------
  covergroup bitwise_cg;
    option.per_instance = 1;

    cp_op: coverpoint item.operator {
      bins and_ = {`ALU_AND};
      bins or_  = {`ALU_OR};
      bins xor_ = {`ALU_XOR};
    }
    cp_pat_a: coverpoint pattern_of(item.operand_a) {
      bins zero      = {0};
      bins all_ones  = {1};
      bins walking_1 = {2};
      bins walking_0 = {3};
      ignore_bins other = {4};
    }
    cp_pat_b: coverpoint pattern_of(item.operand_b) {
      bins zero      = {0};
      bins all_ones  = {1};
      bins walking_1 = {2};
      bins walking_0 = {3};
      ignore_bins other = {4};
    }

    bitwise_imm_cov: cross cp_op, cp_pat_a, cp_pat_b;
  endgroup

  //----------------------------------------------------------------------------
  // SLLI / SRLI / SRAI                                        RV32I_SHFT_1..3
  //----------------------------------------------------------------------------
  covergroup shift_cg;
    option.per_instance = 1;

    cp_op: coverpoint item.operator {
      bins sll = {`ALU_SLL};
      bins srl = {`ALU_SRL};
      bins sra = {`ALU_SRA};
    }
    cp_shamt: coverpoint shamt() {
      bins s0  = {0};
      bins s1  = {1};
      bins s15 = {15};
      bins s31 = {31};
      bins other = default;
    }
    cp_rs1_msb: coverpoint item.operand_a[31] { bins zero = {0}; bins one = {1}; }

    slli_cov: coverpoint shamt() iff (item.operator == `ALU_SLL) {
      bins s0  = {0};
      bins s1  = {1};
      bins s15 = {15};
      bins s31 = {31};
    }
    srli_cov: cross cp_shamt, cp_rs1_msb iff (item.operator == `ALU_SRL);
    srai_cov: cross cp_shamt, cp_rs1_msb iff (item.operator == `ALU_SRA);
  endgroup

  //----------------------------------------------------------------------------
  // Conditional branches                                            RV32I_BR_1
  //   6 mnemonics x {taken, not-taken} x {equal, rs1<rs2, rs1>rs2, msb-differ}
  //   Combinations that no operand pair can produce are ignored, otherwise the
  //   cross could never reach 100 %. 28 reachable bins remain.
  //----------------------------------------------------------------------------
  covergroup branch_cg;
    option.per_instance = 1;

    cp_op: coverpoint item.operator {
      bins beq  = {`ALU_EQ};
      bins bne  = {`ALU_NE};
      bins blt  = {`ALU_LTS};
      bins bge  = {`ALU_GES};
      bins bltu = {`ALU_LTU};
      bins bgeu = {`ALU_GEU};
    }
    cp_taken: coverpoint branch_taken() {
      bins not_taken = {0};
      bins taken     = {1};
    }
    cp_rel: coverpoint branch_rel() {
      bins equal       = {0};
      bins lt          = {1};
      bins gt          = {2};
      bins msb_differ  = {3};
    }

    branch_cov: cross cp_op, cp_taken, cp_rel {
      // BEQ taken only when equal
      ignore_bins beq_impossible =
          (binsof(cp_op.beq) && binsof(cp_taken.taken)     && !binsof(cp_rel.equal)) ||
          (binsof(cp_op.beq) && binsof(cp_taken.not_taken) &&  binsof(cp_rel.equal));
      // BNE taken only when not equal
      ignore_bins bne_impossible =
          (binsof(cp_op.bne) && binsof(cp_taken.taken)     &&  binsof(cp_rel.equal)) ||
          (binsof(cp_op.bne) && binsof(cp_taken.not_taken) && !binsof(cp_rel.equal));
      // BLT / BLTU: taken when rs1 < rs2 (equal and rs1>rs2 are never taken)
      ignore_bins lt_impossible =
          ((binsof(cp_op.blt) || binsof(cp_op.bltu)) && binsof(cp_taken.taken) &&
              (binsof(cp_rel.equal) || binsof(cp_rel.gt))) ||
          ((binsof(cp_op.blt) || binsof(cp_op.bltu)) && binsof(cp_taken.not_taken) &&
              binsof(cp_rel.lt));
      // BGE / BGEU: taken when rs1 >= rs2 (rs1<rs2 is never taken)
      ignore_bins ge_impossible =
          ((binsof(cp_op.bge) || binsof(cp_op.bgeu)) && binsof(cp_taken.taken) &&
              binsof(cp_rel.lt)) ||
          ((binsof(cp_op.bge) || binsof(cp_op.bgeu)) && binsof(cp_taken.not_taken) &&
              (binsof(cp_rel.equal) || binsof(cp_rel.gt)));
    }
  endgroup

  //----------------------------------------------------------------------------
  // DIV / DIVU                                    RV32M_DIV_1, DIVU_2 .. DIVU_5
  //----------------------------------------------------------------------------
  covergroup div_cg;
    option.per_instance = 1;

    cp_op: coverpoint item.operator {
      bins div  = {`ALU_DIV};
      bins divu = {`ALU_DIVU};
    }
    cp_sign_rs1: coverpoint is_neg(dividend()) { bins pos = {0}; bins neg = {1}; }
    cp_sign_rs2: coverpoint is_neg(divisor())  { bins pos = {0}; bins neg = {1}; }

    cp_res_sign: coverpoint item.result[31] { bins pos = {0}; bins neg = {1}; }

    // DIV_1: sign(rs1) x sign(rs2) x result_sign (signed DIV only)
    div_sign_cross_cov: cross cp_op, cp_sign_rs1, cp_sign_rs2, cp_res_sign {
      ignore_bins divu_cross = binsof(cp_op) intersect {`ALU_DIVU};
    }

    // DIVU_2: msb(rs1) x msb(rs2) for DIVU
    divu_msb_cross_cov: cross cp_sign_rs1, cp_sign_rs2 iff (item.operator == `ALU_DIVU);

    // DIVU_3: boundary values
    cp_boundary_rs1: coverpoint dividend() {
      bins zero    = {32'h0000_0000};
      bins pos_one = {32'h0000_0001};
      bins neg_one = {32'hFFFF_FFFF};
      bins max_pos = {32'h7FFF_FFFF};
      bins min_neg = {32'h8000_0000};
    }
    cp_boundary_rs2: coverpoint divisor() {
      bins zero    = {32'h0000_0000};
      bins pos_one = {32'h0000_0001};
      bins neg_one = {32'hFFFF_FFFF};
      bins max_pos = {32'h7FFF_FFFF};
      bins min_neg = {32'h8000_0000};
    }
    div_boundary_val_cov: cross cp_op, cp_boundary_rs1, cp_boundary_rs2;

    // DIVU_4: divisor == 0
    cp_div_zero: coverpoint (divisor() == 32'h0) { bins zero = {1}; }
    div_zero_cov: cross cp_op, cp_div_zero;

    // DIV_5: signed overflow, rs1 = MIN_INT and rs2 = -1 (DIV only)
    div_overflow_cov: coverpoint item.operator
        iff (item.operator == `ALU_DIV &&
             dividend() == 32'h8000_0000 &&
             divisor()  == 32'hFFFF_FFFF) {
      bins int_min_div_minus1 = {`ALU_DIV};
    }
  endgroup

  //----------------------------------------------------------------------------
  // REM / REMU                                                    RV32M_REM_1..5
  //----------------------------------------------------------------------------
  covergroup rem_cg;
    option.per_instance = 1;

    cp_op: coverpoint item.operator {
      bins rem  = {`ALU_REM};
      bins remu = {`ALU_REMU};
    }
    cp_sign_rs1: coverpoint is_neg(dividend()) { bins pos = {0}; bins neg = {1}; }
    cp_sign_rs2: coverpoint is_neg(divisor())  { bins pos = {0}; bins neg = {1}; }

    cp_res_sign: coverpoint item.result[31] { bins pos = {0}; bins neg = {1}; }

    // REM_1: sign(rs1) x sign(rs2) x result_sign (signed REM only)
    rem_sign_cross_cov: cross cp_op, cp_sign_rs1, cp_sign_rs2, cp_res_sign {
      ignore_bins remu_cross = binsof(cp_op) intersect {`ALU_REMU};
      // the remainder takes the dividend's sign (and rem-by-zero returns the
      // dividend), so a non-negative dividend can never give a negative result
      ignore_bins pos_dividend_neg_result =
          binsof(cp_sign_rs1.pos) && binsof(cp_res_sign.neg);
    }

    // REM_2: msb(rs1) x msb(rs2) for REMU
    remu_msb_cross_cov: cross cp_sign_rs1, cp_sign_rs2 iff (item.operator == `ALU_REMU);

    // REM_3: boundary values
    cp_boundary_rs1: coverpoint dividend() {
      bins zero    = {32'h0000_0000};
      bins pos_one = {32'h0000_0001};
      bins neg_one = {32'hFFFF_FFFF};
      bins max_pos = {32'h7FFF_FFFF};
      bins min_neg = {32'h8000_0000};
    }
    cp_boundary_rs2: coverpoint divisor() {
      bins zero    = {32'h0000_0000};
      bins pos_one = {32'h0000_0001};
      bins neg_one = {32'hFFFF_FFFF};
      bins max_pos = {32'h7FFF_FFFF};
      bins min_neg = {32'h8000_0000};
    }
    rem_boundary_val_cov: cross cp_op, cp_boundary_rs1, cp_boundary_rs2;

    // REM_4: divisor == 0
    cp_div_zero: coverpoint (divisor() == 32'h0) { bins zero = {1}; }
    rem_div_zero_cov: cross cp_op, cp_div_zero;

    // REM_5: signed overflow, rs1 = MIN_INT and rs2 = -1 (REM only)
    rem_overflow_cov: coverpoint item.operator
        iff (item.operator == `ALU_REM &&
             dividend() == 32'h8000_0000 &&
             divisor()  == 32'hFFFF_FFFF) {
      bins int_min_rem_minus1 = {`ALU_REM};
    }
  endgroup

  // (constructor sits after the covergroup declarations: instances are created here)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    addsub_cg  = new();
    slt_cg     = new();
    bitwise_cg = new();
    shift_cg   = new();
    branch_cg  = new();
    div_cg     = new();
    rem_cg     = new();
  endfunction

  //----------------------------------------------------------------------------
  function void write(alu_item t);
    item = t;
    case (item.operator)
      `ALU_ADD, `ALU_SUB:               addsub_cg.sample();
      `ALU_SLTS, `ALU_SLTU:             slt_cg.sample();
      `ALU_AND, `ALU_OR, `ALU_XOR:      bitwise_cg.sample();
      `ALU_SLL, `ALU_SRL, `ALU_SRA:     shift_cg.sample();
      `ALU_EQ, `ALU_NE, `ALU_LTS,
      `ALU_GES, `ALU_LTU, `ALU_GEU:     branch_cg.sample();
      `ALU_DIV, `ALU_DIVU:              div_cg.sample();
      `ALU_REM, `ALU_REMU:              rem_cg.sample();
      default: ; // other ALU opcodes are out of scope (COREV_PULP = 0)
    endcase
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("ALU_COV", $sformatf(
      "coverage %%: addsub=%0.1f slt=%0.1f bitwise=%0.1f shift=%0.1f branch=%0.1f div=%0.1f rem=%0.1f",
      addsub_cg.get_inst_coverage(), slt_cg.get_inst_coverage(),
      bitwise_cg.get_inst_coverage(), shift_cg.get_inst_coverage(),
      branch_cg.get_inst_coverage(), div_cg.get_inst_coverage(),
      rem_cg.get_inst_coverage()), UVM_LOW)
  endfunction
endclass

`endif
