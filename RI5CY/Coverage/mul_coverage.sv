`ifndef MUL_COVERAGE_SV
`define MUL_COVERAGE_SV

//------------------------------------------------------------------------------
// mul_coverage : plan "Coverage" sheet items for MUL / MULH / MULHSU / MULHU
//
//   Existing: mul_cg, toggle_cg, pair_cg, mul_latency_cg, mul_pattern_cg.
//
//     mul_regwalk_cg : V-10  rd walk x0..x31 per instruction
//     mul_x0_cg      : V-12  rd == x0 per instruction
//------------------------------------------------------------------------------
class mul_coverage extends uvm_subscriber #(mul_item);
  `uvm_component_utils(mul_coverage)

  localparam logic [2:0] MUL_MAC32 = 3'b000;
  localparam logic [2:0] MUL_H     = 3'b110;

  localparam int K_MUL = 0, K_MULH = 1, K_MULHSU = 2, K_MULHU = 3, K_OTHER = 4;

  mul_item item;

  bit          prev_valid = 0;
  bit [31:0]   prev_result;

  bit          hi_valid = 0;
  bit [31:0]   hi_a, hi_b;
  bit [1:0]    hi_sm;
  int          pair_kind;

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

  function bit [63:0] prod64(bit [31:0] a, bit [31:0] b, bit [1:0] sm);
    bit signed [32:0] ea = $signed({sm[0] & a[31], a});
    bit signed [32:0] eb = $signed({sm[1] & b[31], b});
    bit signed [65:0] p  = ea * eb;
    return p[63:0];
  endfunction

  function int zero_which();
    return (item.operand_a == 32'h0 ? 1 : 0) | (item.operand_b == 32'h0 ? 2 : 0);
  endfunction

  function int one_which();
    return (item.operand_a == 32'h1 ? 1 : 0) | (item.operand_b == 32'h1 ? 2 : 0);
  endfunction

  function bit mul_overflows_32();
    bit [63:0] p = prod64(item.operand_a, item.operand_b, 2'b11);
    return (p[63:32] != {32{p[31]}});
  endfunction

  function int hi_class();
    if (item.result == 32'h0)         return 0;
    if (item.result == 32'hFFFF_FFFF) return 1;
    return 2;
  endfunction

  function bit both_nonzero();
    return (item.operand_a != 32'h0) && (item.operand_b != 32'h0);
  endfunction

  //----------------------------------------------------------------------------
  covergroup mul_cg;
    option.per_instance = 1;

    cp_instr: coverpoint mul_instr() {
      bins mul    = {K_MUL};
      bins mulh   = {K_MULH};
      bins mulhsu = {K_MULHSU};
      bins mulhu  = {K_MULHU};
    }
    cp_zero: coverpoint zero_which() {
      bins rs1_zero = {1}; bins rs2_zero = {2}; bins both_zero = {3};
    }
    mul_by_zero_cov: cross cp_instr, cp_zero;
    cp_one: coverpoint one_which() {
      bins rs1_one = {1}; bins rs2_one = {2}; bins both_one = {3};
    }
    mul_by_one_cov: cross cp_instr, cp_one;
    cp_a_sign: coverpoint item.operand_a[31] { bins pos = {0}; bins neg = {1}; }
    cp_b_sign: coverpoint item.operand_b[31] { bins pos = {0}; bins neg = {1}; }
    mul_sign_cov: cross cp_instr, cp_a_sign, cp_b_sign;
    mul_overflow_cov: coverpoint mul_overflows_32() iff (mul_instr() == K_MUL) {
      bins fits     = {0};
      bins overflow = {1};
    }
    min_neg_x_m1_cov: coverpoint (item.operand_a == 32'h8000_0000 && item.operand_b == 32'hFFFF_FFFF)
        iff (mul_instr() == K_MUL) { bins directed = {1}; }
    cp_hi: coverpoint hi_class() iff (mul_instr() != K_MUL && both_nonzero()) {
      bins zero = {0}; bins all_ones = {1}; bins other = {2};
    }
    hi_zero_cov: cross cp_instr, cp_hi {
      ignore_bins mul_has_no_high_word = binsof(cp_instr.mul);
      ignore_bins mulhu_never_all_ones = binsof(cp_instr.mulhu) && binsof(cp_hi.all_ones);
    }
  endgroup

  covergroup toggle_cg with function sample(int unsigned bit_idx, bit rising);
    option.per_instance = 1;
    cp_bit: coverpoint bit_idx { bins b[] = {[0:31]}; }
    cp_dir: coverpoint rising  { bins rise = {1}; bins fall = {0}; }
    toggle_cov: cross cp_bit, cp_dir;
  endgroup

  covergroup pair_cg;
    option.per_instance = 1;
    pair_cov: coverpoint pair_kind {
      bins mulh_then_mul  = {1};
      bins mulhu_then_mul = {2};
    }
  endgroup

  covergroup mul_latency_cg;
    option.per_instance = 1;
    cp_instr: coverpoint mul_instr() {
      bins mul    = {K_MUL};
      bins mulh   = {K_MULH};
      bins mulhsu = {K_MULHSU};
      bins mulhu  = {K_MULHU};
    }
    cp_latency: coverpoint item.latency {
      bins one_cycle  = {1};
      bins five_cycle = {5};
      bins other      = default;
    }
    mul_lat_cov: cross cp_instr, cp_latency {
      ignore_bins mul_5cyc    = binsof(cp_instr.mul)    && binsof(cp_latency.five_cycle);
      ignore_bins mulh_1cyc   = binsof(cp_instr.mulh)   && binsof(cp_latency.one_cycle);
      ignore_bins mulhsu_1cyc = binsof(cp_instr.mulhsu) && binsof(cp_latency.one_cycle);
      ignore_bins mulhu_1cyc  = binsof(cp_instr.mulhu)  && binsof(cp_latency.one_cycle);
    }
  endgroup

  covergroup mul_pattern_cg;
    option.per_instance = 1;
    cp_instr: coverpoint mul_instr() {
      bins mul    = {K_MUL};
      bins mulh   = {K_MULH};
      bins mulhsu = {K_MULHSU};
      bins mulhu  = {K_MULHU};
    }
    cp_pat_a: coverpoint item.operand_a {
      bins a5 = {32'hA5A5_A5A5};
      bins f0 = {32'h0F0F_0F0F};
      bins inv_a5 = {32'h5A5A_5A5A};
      bins inv_f0 = {32'hF0F0_F0F0};
      bins other  = default;
    }
    cp_pat_b: coverpoint item.operand_b {
      bins a5 = {32'hA5A5_A5A5};
      bins f0 = {32'h0F0F_0F0F};
      bins inv_a5 = {32'h5A5A_5A5A};
      bins inv_f0 = {32'hF0F0_F0F0};
      bins other  = default;
    }
    mul_pattern_cov: cross cp_instr, cp_pat_a, cp_pat_b;
  endgroup

  //============================================================================
  // CHK:V-10  Register-file walking for MUL: rd swept across the register
  //  file, per instruction.
  //============================================================================
  covergroup mul_regwalk_cg;
    option.per_instance = 1;

    cp_instr: coverpoint mul_instr() {
      bins mul    = {K_MUL};
      bins mulh   = {K_MULH};
      bins mulhsu = {K_MULHSU};
      bins mulhu  = {K_MULHU};
    }

    cp_rd: coverpoint item.rd {
      bins x0      = {5'd0};
      bins x1_x7   = {[5'd1:5'd7]};
      bins x8_x15  = {[5'd8:5'd15]};
      bins x16_x23 = {[5'd16:5'd23]};
      bins x24_x31 = {[5'd24:5'd31]};
    }

    mul_regwalk_cov: cross cp_instr, cp_rd;
  endgroup

  //============================================================================
  // CHK:V-12  MUL-to-x0 silent-ignore: bin on rd == x0 per instruction.
  //  The DUT-side write suppression is checked by C-01's x0_immutable_write_p;
  //  this group makes the coverage attribution explicit per MUL opcode.
  //============================================================================
  covergroup mul_x0_cg;
    option.per_instance = 1;

    cp_instr: coverpoint mul_instr() {
      bins mul    = {K_MUL};
      bins mulh   = {K_MULH};
      bins mulhsu = {K_MULHSU};
      bins mulhu  = {K_MULHU};
    }

    cp_rd_is_x0: coverpoint (item.rd == 5'd0) {
      bins rd_x0 = {1'b1};
    }

    mul_x0_cov: cross cp_instr, cp_rd_is_x0;
  endgroup

  //============================================================================
  function new(string name, uvm_component parent);
    super.new(name, parent);
    mul_cg          = new();
    toggle_cg       = new();
    pair_cg         = new();
    mul_latency_cg  = new();
    mul_pattern_cg  = new();
    mul_regwalk_cg  = new();
    mul_x0_cg       = new();
  endfunction

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
    if (mul_instr() == K_OTHER) return;

    mul_cg.sample();
    sample_toggle();
    track_pair();
    mul_latency_cg.sample();
    mul_pattern_cg.sample();
    mul_regwalk_cg.sample();
    mul_x0_cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("MUL_COV", $sformatf(
      "coverage %%: mul=%0.1f toggle=%0.1f pair=%0.1f lat=%0.1f pat=%0.1f regwalk=%0.1f x0=%0.1f",
      mul_cg.get_inst_coverage(), toggle_cg.get_inst_coverage(),
      pair_cg.get_inst_coverage(), mul_latency_cg.get_inst_coverage(),
      mul_pattern_cg.get_inst_coverage(), mul_regwalk_cg.get_inst_coverage(),
      mul_x0_cg.get_inst_coverage()), UVM_LOW)
  endfunction
endclass

`endif