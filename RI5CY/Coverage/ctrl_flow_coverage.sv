`ifndef CTRL_FLOW_COVERAGE_SV
`define CTRL_FLOW_COVERAGE_SV

//------------------------------------------------------------------------------
// ctrl_flow_coverage : INSTRUCTION-LEVEL coverage of JAL, JALR, branches, and
//                      LOAD / STORE / R-type ALU / LUI / AUIPC.
//
//   N-01  removed the two `ignore_bins halfword_only` declarations (H-A5).
//   V-13  imm_bitwalk_cg   - 12 single-bit I-immediate bins + corners.
//   V-14  load_cg          - width x imm sign x imm zero/max.
//   V-15  store_cg         - width x imm sign x imm zero/max.
//   V-19  branch_back2back_cg - consecutive branch/JAL/JALR pair classes.
//   V-21  rtype_alu_cg + lui_auipc_cg.
//------------------------------------------------------------------------------
class ctrl_flow_coverage extends uvm_subscriber #(rv32im_instr_seq_item);
  `uvm_component_utils(ctrl_flow_coverage)

  rv32im_instr_seq_item item;

  //----------------------------------------------------------------------------
  // helpers
  //----------------------------------------------------------------------------
  function bit [31:0] imm_i();   return {{20{item.i_imm12[11]}},  item.i_imm12};   endfunction
  function bit [31:0] imm_jal(); return {{11{item.jal_imm21[20]}}, item.jal_imm21}; endfunction
  function bit [31:0] imm_b();   return {{19{item.b_imm13[12]}},  item.b_imm13};   endfunction

  function bit jal_backward(); return item.jal_imm21[20]; endfunction
  function bit br_backward();  return item.b_imm13[12];  endfunction

  function bit [31:0] jal_target();    return item.pc + imm_jal(); endfunction
  function bit [31:0] branch_target(); return item.pc + imm_b();   endfunction

  function bit halfword_only(bit [31:0] target);
    return target[1];
  endfunction

  function int reg_class(bit [4:0] r);
    if (r == 5'd0) return 0;
    if (r == 5'd1) return 1;
    return 2;
  endfunction

  function int br_reg_rel();
    if (item.rs1 == 5'd0 || item.rs2 == 5'd0) return 2;
    if (item.rs1 == item.rs2)                 return 1;
    return 0;
  endfunction

  function bit is_cf();
    return item.opcode inside {OP_JAL, OP_JALR, OP_BRANCH};
  endfunction

  // CHK:V-19  Classify a branch/JAL/JALR item into "taken" by decode only
  // (taken-ness for branches is not visible at instruction level; we use the
  //  static target/fall-through choice to build the back-to-back bin).
  function int cf_class();
    case (item.opcode)
      OP_JAL:    return 1;
      OP_JALR:   return 2;
      OP_BRANCH: return 3;
      default:   return 0;
    endcase
  endfunction

  //----------------------------------------------------------------------------
  // JAL
  //----------------------------------------------------------------------------
  covergroup jal_cg;
    option.per_instance = 1;

    cp_rd: coverpoint reg_class(item.rd) {
      bins rd_x0    = {0};
      bins rd_x1    = {1};
      bins rd_other = {2};
    }
    cp_dir: coverpoint jal_backward() {
      bins forward  = {0};
      bins backward = {1};
    }
    cp_offset: coverpoint imm_jal() {
      bins min_backward = {32'hFFF0_0000};
      bins backward     = {[32'hFFF0_0004 : 32'hFFFF_FFFC]};
      bins zero         = {32'h0};
      bins forward      = {[32'h0000_0004 : 32'h000F_FFF8]};
      bins max_forward  = {32'h000F_FFFC};
    }
    // N-01 (H-A5): the two "ignore_bins halfword_only" declarations were
    // removed.  word_aligned remains the only explicitly declared bin.
    cp_align: coverpoint halfword_only(jal_target()) {
      bins word_aligned  = {0};
    }
    jal_rd_dir_cov: cross cp_rd, cp_dir;
    jal_align_cov:  cross cp_align, cp_rd;
  endgroup

  //----------------------------------------------------------------------------
  // JALR
  //----------------------------------------------------------------------------
  covergroup jalr_cg;
    option.per_instance = 1;

    cp_rd:  coverpoint reg_class(item.rd)  { bins rd_x0 = {0}; bins rd_x1 = {1}; bins rd_other = {2}; }
    cp_rs1: coverpoint reg_class(item.rs1) { bins rs1_x0 = {0}; bins rs1_x1 = {1}; bins rs1_other = {2}; }
    cp_imm: coverpoint imm_i() {
      bins zero     = {32'h0};
      bins positive = {[32'h1 : 32'h7FF]};
      bins negative = {[32'hFFFF_F800 : 32'hFFFF_FFFF]};
    }
    jalr_rd_rs1_cov: cross cp_rd, cp_rs1;
    jalr_rd_imm_cov: cross cp_rd, cp_imm;
  endgroup

  //----------------------------------------------------------------------------
  // Conditional branches : instruction-level
  //----------------------------------------------------------------------------
  covergroup branch_instr_cg;
    option.per_instance = 1;

    cp_op: coverpoint item.funct3 iff (item.funct3 != 3'b010 && item.funct3 != 3'b011) {
      bins beq  = {3'b000};
      bins bne  = {3'b001};
      bins blt  = {3'b100};
      bins bge  = {3'b101};
      bins bltu = {3'b110};
      bins bgeu = {3'b111};
    }
    cp_dir: coverpoint br_backward() {
      bins forward  = {0};
      bins backward = {1};
    }
    cp_offset: coverpoint imm_b() {
      bins min_backward = {32'hFFFF_F000};
      bins backward     = {[32'hFFFF_F004 : 32'hFFFF_FFFC]};
      bins zero         = {32'h0};
      bins forward      = {[32'h0000_0004 : 32'h0000_0FF8]};
      bins max_forward  = {32'h0000_0FFC};
    }
    // N-01 (H-A5): ignore_bins halfword_only removed.
    cp_align: coverpoint halfword_only(branch_target()) {
      bins word_aligned  = {0};
    }
    cp_regs: coverpoint br_reg_rel() {
      bins distinct = {0};
      bins same_reg = {1};
      bins uses_x0  = {2};
    }
    branch_op_dir_cov:   cross cp_op, cp_dir;
    branch_op_align_cov: cross cp_op, cp_align;
    branch_op_regs_cov:  cross cp_op, cp_regs;
  endgroup

  //----------------------------------------------------------------------------
  // CHK:V-13  I-type immediate bit-walk and corners, per I-type opcode.
  //----------------------------------------------------------------------------
  covergroup imm_bitwalk_cg;
    option.per_instance = 1;

    cp_op: coverpoint item.I_ops iff (item.opcode == OP_IMM) {
      bins addi  = {ADDI};
      bins slti  = {SLTI};
      bins sltiu = {SLTIU};
      bins xori  = {XORI};
      bins ori   = {ORI};
      bins andi  = {ANDI};
    }
    cp_imm_corner: coverpoint item.i_imm12 iff (item.opcode == OP_IMM) {
      bins most_neg = {12'h800};
      bins most_pos = {12'h7FF};
      bins zero     = {12'h000};
      bins one      = {12'h001};
      bins minus_1  = {12'hFFF};
      bins onehot   = {12'h001, 12'h002, 12'h004, 12'h008,
                       12'h010, 12'h020, 12'h040, 12'h080,
                       12'h100, 12'h200, 12'h400, 12'h800};
    }
    
    cp_imm_bit: coverpoint item.i_imm12 iff (item.opcode == OP_IMM) {
      bins b[12] = {12'h001, 12'h002, 12'h004, 12'h008,
                    12'h010, 12'h020, 12'h040, 12'h080,
                    12'h100, 12'h200, 12'h400, 12'h800};
    }

    imm_cov: cross cp_op, cp_imm_corner;
  endgroup

  //----------------------------------------------------------------------------
  // CHK:V-14  Load instruction coverage.
  //   Alignment cannot be sampled here (needs rs1 runtime value); the
  //   effective-address class is captured via the immediate sign / magnitude.
  //----------------------------------------------------------------------------
  covergroup load_cg;
    option.per_instance = 1;

    cp_op: coverpoint item.Load_ops {
      bins lb  = {LB};
      bins lh  = {LH};
      bins lw  = {LW};
      bins lbu = {LBU};
      bins lhu = {LHU};
    }

    // cp_imm_sign (bit-select on a function call) removed.  Sign is
    // captured by the pos/neg classification inside cp_imm_class.
    cp_imm_class: coverpoint imm_i() {
      bins zero      = {32'h0};
      bins pos_small = {[32'h0000_0001 : 32'h0000_001F]};
      bins pos_large = {[32'h0000_0020 : 32'h0000_07FF]};
      bins min_neg   = {32'hFFFF_F800};
      bins neg_other = {[32'hFFFF_F801 : 32'hFFFF_FFFF]};
    }

    load_op_imm_cov: cross cp_op, cp_imm_class;
  endgroup

  //----------------------------------------------------------------------------
  // CHK:V-15  Store instruction coverage.
  //----------------------------------------------------------------------------
  covergroup store_cg;
    option.per_instance = 1;

    cp_op: coverpoint item.S_ops {
      bins sb = {SB};
      bins sh = {SH};
      bins sw = {SW};
    }

    cp_imm_class: coverpoint imm_i() {
      bins zero      = {32'h0};
      bins pos_small = {[32'h0000_0001 : 32'h0000_001F]};
      bins pos_large = {[32'h0000_0020 : 32'h0000_07FF]};
      bins min_neg   = {32'hFFFF_F800};
      bins neg_other = {[32'hFFFF_F801 : 32'hFFFF_FFFF]};
    }

    store_op_imm_cov: cross cp_op, cp_imm_class;
  endgroup

  //----------------------------------------------------------------------------
  // CHK:V-19  Back-to-back control-flow pair classes.
  //   Consecutive {first, second} where each is JAL / JALR / BRANCH.
  //----------------------------------------------------------------------------
  int unsigned prev_cf_class;
  bit          cf_first_valid;

  covergroup branch_back2back_cg;
    option.per_instance = 1;

    cp_prev: coverpoint prev_cf_class {
      bins jal    = {1};
      bins jalr   = {2};
      bins branch = {3};
    }
    cp_curr: coverpoint cf_class() {
      bins jal    = {1};
      bins jalr   = {2};
      bins branch = {3};
    }
    pair_cov: cross cp_prev, cp_curr;
  endgroup

  //----------------------------------------------------------------------------
  // CHK:V-21  R-type ALU coverage: op x sign combination.
  //----------------------------------------------------------------------------
  covergroup rtype_alu_cg;
    option.per_instance = 1;

    cp_op: coverpoint item.R_rv32i_ops
        iff (item.opcode == OP_R && item.ALU_MUL_sel == ALU) {
      bins add_sub = {ADD_SUB};
      bins sll     = {SLL};
      bins slt     = {SLT};
      bins sltu    = {SLTU};
      bins xor_    = {XOR};
      bins srl_sra = {SRL_SRA};
      bins or_     = {OR};
      bins and_    = {AND};
    }
    cp_op_mod: coverpoint item.funct7
        iff (item.opcode == OP_R && item.ALU_MUL_sel == ALU) {
      bins f0  = {7'd0};
      bins f32 = {7'd32};
    }
    rtype_op_mod_cov: cross cp_op, cp_op_mod;
  endgroup

  //----------------------------------------------------------------------------
  // CHK:V-21  LUI / AUIPC immediate class.
  //----------------------------------------------------------------------------
  covergroup lui_auipc_cg;
    option.per_instance = 1;

    cp_op: coverpoint item.opcode iff (item.opcode inside {OP_LUI, OP_AUIPC}) {
      bins lui_  = {OP_LUI};
      bins auipc = {OP_AUIPC};
    }
    cp_imm: coverpoint item.u_imm20 iff (item.opcode inside {OP_LUI, OP_AUIPC}) {
      bins zero   = {20'h00000};
      bins max    = {20'hFFFFF};
      bins one    = {20'h00001};
      bins other  = default;
    }
    cp_rd: coverpoint reg_class(item.rd) iff (item.opcode inside {OP_LUI, OP_AUIPC}) {
      bins rd_x0    = {0};
      bins rd_x1    = {1};
      bins rd_other = {2};
    }
    lui_auipc_cov: cross cp_op, cp_imm, cp_rd;
  endgroup

  //----------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    jal_cg              = new();
    jalr_cg             = new();
    branch_instr_cg     = new();
    imm_bitwalk_cg      = new();
    load_cg             = new();
    store_cg            = new();
    branch_back2back_cg = new();
    rtype_alu_cg        = new();
    lui_auipc_cg        = new();

    prev_cf_class   = 0;
    cf_first_valid  = 0;
  endfunction

  function void write(rv32im_instr_seq_item t);
    item = t;

    // CHK:V-19  Track back-to-back control-flow pairs.
    if (is_cf()) begin
      if (cf_first_valid) begin
        branch_back2back_cg.sample();
      end
      prev_cf_class  = cf_class();
      cf_first_valid = 1;
    end else begin
      cf_first_valid = 0;
      prev_cf_class  = 0;
    end

    // Existing control-flow coverage
    case (item.opcode)
      OP_JAL:    jal_cg.sample();
      OP_JALR:   jalr_cg.sample();
      OP_BRANCH: branch_instr_cg.sample();
      OP_IMM:    imm_bitwalk_cg.sample();
      OP_LOAD:   load_cg.sample();
      OP_STORE:  store_cg.sample();
      OP_R: begin
        if (item.ALU_MUL_sel == ALU) rtype_alu_cg.sample();
      end
      OP_LUI, OP_AUIPC: lui_auipc_cg.sample();
      default: ;
    endcase
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("CF_COV", $sformatf(
      "coverage %%: jal=%0.1f jalr=%0.1f branch=%0.1f imm_bw=%0.1f load=%0.1f store=%0.1f cf_b2b=%0.1f rtype=%0.1f lui_auipc=%0.1f",
      jal_cg.get_inst_coverage(), jalr_cg.get_inst_coverage(),
      branch_instr_cg.get_inst_coverage(), imm_bitwalk_cg.get_inst_coverage(),
      load_cg.get_inst_coverage(), store_cg.get_inst_coverage(),
      branch_back2back_cg.get_inst_coverage(), rtype_alu_cg.get_inst_coverage(),
      lui_auipc_cg.get_inst_coverage()), UVM_LOW)
  endfunction
endclass

`endif