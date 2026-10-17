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
`define ALU_LTS  7'b0000000
`define ALU_LTU  7'b0000001
`define ALU_GES  7'b0001010
`define ALU_GEU  7'b0001011
`define ALU_EQ   7'b0001100
`define ALU_NE   7'b0001101

//------------------------------------------------------------------------------
// alu_coverage : plan "Coverage" sheet items that can be built from alu_item
//
//   Existing: addsub_cg, slt_cg, bitwise_cg, shift_cg, branch_cg,
//             div_cg, rem_cg, div_eq_operand_cg, div_pattern_cg,
//             div_truncation_cg, rem_divisor_2_cg.
//
//     div_latency_cg : V-18 (DIV/REM half).  Cross operator with divisor
//                      class and with observed latency class.
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

  function bit [31:0] dividend();
    return div_operands_swapped ? item.operand_b : item.operand_a;
  endfunction

  function bit [31:0] divisor();
    return div_operands_swapped ? item.operand_a : item.operand_b;
  endfunction

  function int branch_rel();
    bit [31:0] a = item.operand_a;
    bit [31:0] b = item.operand_b;
    if (a == b)         return 0;
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

  function automatic bit [32:0] mag33(bit [31:0] x, bit is_signed);
    return (is_signed && x[31]) ? ({1'b0, ~x} + 33'd1) : {1'b0, x};
  endfunction

  // CHK:V-18  Divisor LO-class (leading-one position of rs2).  Matches the
  //  C-10 formula's classification, so the coverage view aligns with the
  //  check's classification (0=zero, 1=one, 2..3=pow2 ranges, 4=LO=31).
  function int classify_divisor_lo(bit [31:0] v);
    for (int i = 31; i >= 0; i--) begin
      if (v[i]) begin
        if (i == 0)  return 1;   // v == 1
        if (i <= 15) return 2;   // 2..2^15
        if (i <= 30) return 3;   // 2^16..2^30
        return 4;                // single bit at 31 (or 0xFFFF_FFFF)
      end
    end
    return 0;                    // v == 0
  endfunction

  // CHK:V-18  Latency class in cycles: 1-5, 6-15, 16-30, 31+.
  function int classify_latency(int unsigned lat);
    if (lat <= 5)   return 0;
    if (lat <= 15)  return 1;
    if (lat <= 30)  return 2;
    return 3;
  endfunction

  //============================================================================
  // Existing covergroups (unchanged)
  //============================================================================
  covergroup addsub_cg;
    option.per_instance = 1;
    cp_op: coverpoint item.operator { bins add = {`ALU_ADD}; bins sub = {`ALU_SUB}; }
    cp_sign_a: coverpoint is_neg(item.operand_a) { bins pos = {0}; bins neg = {1}; }
    cp_sign_b: coverpoint is_neg(item.operand_b) { bins pos = {0}; bins neg = {1}; }
    cp_overflow: coverpoint ((item.operator == `ALU_ADD) ? add_overflowed() : sub_overflowed()) {
      bins no_overflow = {0};
      bins overflow    = {1};
    }
    addi_overflow_cov: cross cp_op, cp_sign_a, cp_sign_b, cp_overflow {
      ignore_bins add_diff_sign_ovf =
        (binsof(cp_op.add) && binsof(cp_sign_a.pos) && binsof(cp_sign_b.neg) && binsof(cp_overflow.overflow)) ||
        (binsof(cp_op.add) && binsof(cp_sign_a.neg) && binsof(cp_sign_b.pos) && binsof(cp_overflow.overflow));
      ignore_bins sub_same_sign_ovf =
        (binsof(cp_op.sub) && binsof(cp_sign_a.pos) && binsof(cp_sign_b.pos) && binsof(cp_overflow.overflow)) ||
        (binsof(cp_op.sub) && binsof(cp_sign_a.neg) && binsof(cp_sign_b.neg) && binsof(cp_overflow.overflow));
    }
  endgroup

  covergroup slt_cg;
    option.per_instance = 1;
    cp_op: coverpoint item.operator { bins slt = {`ALU_SLTS}; bins sltu = {`ALU_SLTU}; }
    cp_sign_a: coverpoint is_neg(item.operand_a) { bins pos = {0}; bins neg = {1}; }
    cp_sign_b: coverpoint is_neg(item.operand_b) { bins pos = {0}; bins neg = {1}; }
    cp_result: coverpoint item.result[0] { bins zero = {0}; bins one = {1}; }
    slti_cov: cross cp_sign_a, cp_sign_b, cp_result iff (item.operator == `ALU_SLTS) {
      ignore_bins neg_pos_never_0 = binsof(cp_sign_a.neg) && binsof(cp_sign_b.pos) && binsof(cp_result.zero);
      ignore_bins pos_neg_never_1 = binsof(cp_sign_a.pos) && binsof(cp_sign_b.neg) && binsof(cp_result.one);
    }
    sltiu_cov: cross cp_sign_a, cp_sign_b, cp_result iff (item.operator == `ALU_SLTU) {
      ignore_bins neg_pos_never_1 = binsof(cp_sign_a.neg) && binsof(cp_sign_b.pos) && binsof(cp_result.one);
      ignore_bins pos_neg_never_0 = binsof(cp_sign_a.pos) && binsof(cp_sign_b.neg) && binsof(cp_result.zero);
    }
    cp_seqz_imm: coverpoint item.operand_b iff (item.operator == `ALU_SLTU) { bins imm_one = {32'h1}; }
    cp_seqz_rs1: coverpoint (item.operand_a == 32'h0) iff (item.operator == `ALU_SLTU) {
      bins rs1_zero    = {1};
      bins rs1_nonzero = {0};
    }
    sltiu_seqz_cov: cross cp_seqz_imm, cp_seqz_rs1;
  endgroup

  covergroup bitwise_cg;
    option.per_instance = 1;
    cp_op: coverpoint item.operator {
      bins and_ = {`ALU_AND};
      bins or_  = {`ALU_OR};
      bins xor_ = {`ALU_XOR};
    }
    cp_pat_a: coverpoint pattern_of(item.operand_a) {
      bins zero = {0}; bins all_ones = {1}; bins walking_1 = {2};
      bins walking_0 = {3}; ignore_bins other = {4};
    }
    cp_pat_b: coverpoint pattern_of(item.operand_b) {
      bins zero = {0}; bins all_ones = {1}; bins walking_1 = {2};
      bins walking_0 = {3}; ignore_bins other = {4};
    }
    bitwise_imm_cov: cross cp_op, cp_pat_a, cp_pat_b;
  endgroup

  covergroup shift_cg;
    option.per_instance = 1;
    cp_op: coverpoint item.operator {
      bins sll = {`ALU_SLL}; bins srl = {`ALU_SRL}; bins sra = {`ALU_SRA};
    }
    cp_shamt: coverpoint shamt() {
      bins s0 = {0}; bins s1 = {1}; bins s15 = {15}; bins s31 = {31};
      bins other = default;
    }
    cp_rs1_msb: coverpoint item.operand_a[31] { bins zero = {0}; bins one = {1}; }
    slli_cov: coverpoint shamt() iff (item.operator == `ALU_SLL) {
      bins s0 = {0}; bins s1 = {1}; bins s15 = {15}; bins s31 = {31};
    }
    srli_cov: cross cp_shamt, cp_rs1_msb iff (item.operator == `ALU_SRL);
    srai_cov: cross cp_shamt, cp_rs1_msb iff (item.operator == `ALU_SRA);
  endgroup

  covergroup branch_cg;
    option.per_instance = 1;
    cp_op: coverpoint item.operator {
      bins beq = {`ALU_EQ}; bins bne = {`ALU_NE};
      bins blt = {`ALU_LTS}; bins bge = {`ALU_GES};
      bins bltu = {`ALU_LTU}; bins bgeu = {`ALU_GEU};
    }
    cp_taken: coverpoint branch_taken() { bins not_taken = {0}; bins taken = {1}; }
    cp_rel: coverpoint branch_rel() {
      bins equal = {0}; bins lt = {1}; bins gt = {2}; bins msb_differ = {3};
    }
    branch_cov: cross cp_op, cp_taken, cp_rel {
      ignore_bins beq_impossible =
          (binsof(cp_op.beq) && binsof(cp_taken.taken)     && !binsof(cp_rel.equal)) ||
          (binsof(cp_op.beq) && binsof(cp_taken.not_taken) &&  binsof(cp_rel.equal));
      ignore_bins bne_impossible =
          (binsof(cp_op.bne) && binsof(cp_taken.taken)     &&  binsof(cp_rel.equal)) ||
          (binsof(cp_op.bne) && binsof(cp_taken.not_taken) && !binsof(cp_rel.equal));
      ignore_bins lt_impossible =
          ((binsof(cp_op.blt) || binsof(cp_op.bltu)) && binsof(cp_taken.taken) &&
              (binsof(cp_rel.equal) || binsof(cp_rel.gt))) ||
          ((binsof(cp_op.blt) || binsof(cp_op.bltu)) && binsof(cp_taken.not_taken) &&
              binsof(cp_rel.lt));
      ignore_bins ge_impossible =
          ((binsof(cp_op.bge) || binsof(cp_op.bgeu)) && binsof(cp_taken.taken) &&
              binsof(cp_rel.lt)) ||
          ((binsof(cp_op.bge) || binsof(cp_op.bgeu)) && binsof(cp_taken.not_taken) &&
              (binsof(cp_rel.equal) || binsof(cp_rel.gt)));
    }
  endgroup

  covergroup div_cg;
    option.per_instance = 1;
    cp_op: coverpoint item.operator { bins div = {`ALU_DIV}; bins divu = {`ALU_DIVU}; }
    cp_sign_rs1: coverpoint is_neg(dividend()) { bins pos = {0}; bins neg = {1}; }
    cp_sign_rs2: coverpoint is_neg(divisor())  { bins pos = {0}; bins neg = {1}; }
    cp_res_sign: coverpoint item.result[31] { bins pos = {0}; bins neg = {1}; }
    div_sign_cross_cov: cross cp_op, cp_sign_rs1, cp_sign_rs2, cp_res_sign {
      ignore_bins divu_cross = binsof(cp_op) intersect {`ALU_DIVU};
    }
    divu_msb_cross_cov: cross cp_sign_rs1, cp_sign_rs2 iff (item.operator == `ALU_DIVU);
    cp_boundary_rs1: coverpoint dividend() {
      bins zero = {32'h0000_0000}; bins pos_one = {32'h0000_0001};
      bins neg_one = {32'hFFFF_FFFF}; bins max_pos = {32'h7FFF_FFFF};
      bins min_neg = {32'h8000_0000};
    }
    cp_boundary_rs2: coverpoint divisor() {
      bins zero = {32'h0000_0000}; bins pos_one = {32'h0000_0001};
      bins neg_one = {32'hFFFF_FFFF}; bins max_pos = {32'h7FFF_FFFF};
      bins min_neg = {32'h8000_0000};
    }
    div_boundary_val_cov: cross cp_op, cp_boundary_rs1, cp_boundary_rs2;
    cp_div_zero: coverpoint (divisor() == 32'h0) { bins zero = {1}; }
    div_zero_cov: cross cp_op, cp_div_zero;
    div_overflow_cov: coverpoint item.operator
        iff (item.operator == `ALU_DIV &&
             dividend() == 32'h8000_0000 &&
             divisor()  == 32'hFFFF_FFFF) { bins int_min_div_minus1 = {`ALU_DIV}; }
  endgroup

  covergroup rem_cg;
    option.per_instance = 1;
    cp_op: coverpoint item.operator { bins rem = {`ALU_REM}; bins remu = {`ALU_REMU}; }
    cp_sign_rs1: coverpoint is_neg(dividend()) { bins pos = {0}; bins neg = {1}; }
    cp_sign_rs2: coverpoint is_neg(divisor())  { bins pos = {0}; bins neg = {1}; }
    cp_res_sign: coverpoint item.result[31] { bins pos = {0}; bins neg = {1}; }
    rem_sign_cross_cov: cross cp_op, cp_sign_rs1, cp_sign_rs2, cp_res_sign {
      ignore_bins remu_cross = binsof(cp_op) intersect {`ALU_REMU};
      ignore_bins pos_dividend_neg_result =
          binsof(cp_sign_rs1.pos) && binsof(cp_res_sign.neg);
    }
    remu_msb_cross_cov: cross cp_sign_rs1, cp_sign_rs2 iff (item.operator == `ALU_REMU);
    cp_boundary_rs1: coverpoint dividend() {
      bins zero = {32'h0000_0000}; bins pos_one = {32'h0000_0001};
      bins neg_one = {32'hFFFF_FFFF}; bins max_pos = {32'h7FFF_FFFF};
      bins min_neg = {32'h8000_0000};
    }
    cp_boundary_rs2: coverpoint divisor() {
      bins zero = {32'h0000_0000}; bins pos_one = {32'h0000_0001};
      bins neg_one = {32'hFFFF_FFFF}; bins max_pos = {32'h7FFF_FFFF};
      bins min_neg = {32'h8000_0000};
    }
    rem_boundary_val_cov: cross cp_op, cp_boundary_rs1, cp_boundary_rs2;
    cp_div_zero: coverpoint (divisor() == 32'h0) { bins zero = {1}; }
    rem_div_zero_cov: cross cp_op, cp_div_zero;
    rem_overflow_cov: coverpoint item.operator
        iff (item.operator == `ALU_REM &&
             dividend() == 32'h8000_0000 &&
             divisor()  == 32'hFFFF_FFFF) { bins int_min_rem_minus1 = {`ALU_REM}; }
  endgroup

  covergroup div_eq_operand_cg;
    option.per_instance = 1;
    cp_op: coverpoint item.operator {
      bins div  = {`ALU_DIV};
      bins divu = {`ALU_DIVU};
      bins rem  = {`ALU_REM};
      bins remu = {`ALU_REMU};
    }
    cp_equal: coverpoint (dividend() == divisor()) { bins equal = {1}; }
    div_eq_cov: cross cp_op, cp_equal;
  endgroup

  covergroup div_pattern_cg;
    option.per_instance = 1;
    cp_op: coverpoint item.operator {
      bins div  = {`ALU_DIV};
      bins divu = {`ALU_DIVU};
      bins rem  = {`ALU_REM};
      bins remu = {`ALU_REMU};
    }
    cp_pat_a: coverpoint dividend() {
      bins alt_5 = {32'h5555_5555};
      bins alt_A = {32'hAAAA_AAAA};
      bins all_1 = {32'hFFFF_FFFF};
      bins other = default;
    }
    cp_pat_b: coverpoint divisor() {
      bins alt_5 = {32'h5555_5555};
      bins alt_A = {32'hAAAA_AAAA};
      bins all_1 = {32'hFFFF_FFFF};
      bins other = default;
    }
    div_pattern_cov: cross cp_op, cp_pat_a, cp_pat_b;
  endgroup

  covergroup div_truncation_cg;
    option.per_instance = 1;
    cp_op: coverpoint item.operator {
      bins div  = {`ALU_DIV};
      bins divu = {`ALU_DIVU};
    }
    cp_trunc: coverpoint (mag33(divisor(), item.operator[0]) >
                          mag33(dividend(), item.operator[0])) {
      bins rs2_gt_rs1 = {1};
    }
    cp_res: coverpoint item.result { bins zero = {32'h0}; bins nonzero = default; }
    div_truncation_cov: cross cp_op, cp_trunc, cp_res;
  endgroup

  covergroup rem_divisor_2_cg;
    option.per_instance = 1;
    cp_op: coverpoint item.operator {
      bins rem  = {`ALU_REM};
      bins remu = {`ALU_REMU};
    }
    cp_div: coverpoint divisor() {
      bins two     = {32'h0000_0002};
      bins minus_2 = {32'hFFFF_FFFE};
    }
    rem_div2_cov: cross cp_op, cp_div {
      ignore_bins remu_no_signed = binsof(cp_op.remu) && binsof(cp_div.minus_2);
    }
  endgroup

  //============================================================================
  // CHK:V-18  DIV / REM latency coverage.
  //  Cross operator with divisor LO-class and with observed latency class.
  //  Complements the C-10 warning-only check: even when the check declines
  //  to fire (LO=31), the coverage records that the observation occurred.
  //============================================================================
  covergroup div_latency_cg;
    option.per_instance = 1;

    cp_op: coverpoint item.operator {
      bins div  = {`ALU_DIV};
      bins divu = {`ALU_DIVU};
      bins rem  = {`ALU_REM};
      bins remu = {`ALU_REMU};
    }

    cp_div_lo: coverpoint classify_divisor_lo(divisor()) {
      bins div_zero = {0};
      bins lo_0     = {1};
      bins lo_1_15  = {2};
      bins lo_16_30 = {3};
      bins lo_31    = {4};
    }

    cp_lat: coverpoint classify_latency(item.latency) {
      bins lat_1_5     = {0};
      bins lat_6_15    = {1};
      bins lat_16_30   = {2};
      bins lat_31_plus = {3};
    }

    div_div_cov: cross cp_op, cp_div_lo;
    div_lat_cov: cross cp_op, cp_lat;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    addsub_cg         = new();
    slt_cg            = new();
    bitwise_cg        = new();
    shift_cg          = new();
    branch_cg         = new();
    div_cg            = new();
    rem_cg            = new();
    div_eq_operand_cg = new();
    div_pattern_cg    = new();
    div_truncation_cg = new();
    rem_divisor_2_cg  = new();
    div_latency_cg    = new();
  endfunction

  function void write(alu_item t);
    item = t;
    case (item.operator)
      `ALU_ADD, `ALU_SUB:               addsub_cg.sample();
      `ALU_SLTS, `ALU_SLTU:             slt_cg.sample();
      `ALU_AND, `ALU_OR, `ALU_XOR:      bitwise_cg.sample();
      `ALU_SLL, `ALU_SRL, `ALU_SRA:     shift_cg.sample();
      `ALU_EQ, `ALU_NE, `ALU_LTS,
      `ALU_GES, `ALU_LTU, `ALU_GEU:     branch_cg.sample();
      `ALU_DIV, `ALU_DIVU: begin
        div_cg.sample();
        div_eq_operand_cg.sample();
        div_pattern_cg.sample();
        div_truncation_cg.sample();
        div_latency_cg.sample();
      end
      `ALU_REM, `ALU_REMU: begin
        rem_cg.sample();
        div_eq_operand_cg.sample();
        div_pattern_cg.sample();
        rem_divisor_2_cg.sample();
        div_latency_cg.sample();
      end
      default: ;
    endcase
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("ALU_COV", $sformatf(
      "coverage %%: addsub=%0.1f slt=%0.1f bitwise=%0.1f shift=%0.1f branch=%0.1f div=%0.1f rem=%0.1f div_eq=%0.1f div_pat=%0.1f div_tr=%0.1f rem_2=%0.1f div_lat=%0.1f",
      addsub_cg.get_inst_coverage(), slt_cg.get_inst_coverage(),
      bitwise_cg.get_inst_coverage(), shift_cg.get_inst_coverage(),
      branch_cg.get_inst_coverage(), div_cg.get_inst_coverage(),
      rem_cg.get_inst_coverage(), div_eq_operand_cg.get_inst_coverage(),
      div_pattern_cg.get_inst_coverage(), div_truncation_cg.get_inst_coverage(),
      rem_divisor_2_cg.get_inst_coverage(), div_latency_cg.get_inst_coverage()),
      UVM_LOW)
  endfunction
endclass

`endif