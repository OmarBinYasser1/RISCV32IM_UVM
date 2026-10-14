`ifndef CTRL_FLOW_COVERAGE_SV
`define CTRL_FLOW_COVERAGE_SV

//------------------------------------------------------------------------------
// ctrl_flow_coverage : INSTRUCTION-LEVEL coverage of JAL, JALR and branches
//
// Division of work with alu_coverage.sv
//   alu_coverage       : what the ALU PINS see = operand VALUES and results
//                        (branch compare condition x taken/not-taken x relation,
//                        add/sub/slt/shift/logic/div/rem value scenarios)
//   ctrl_flow_coverage : what the INSTRUCTION encodes = which jump/branch, which
//                        registers, offset size and direction, static target
//                        alignment (pc + imm)
//
// NOTE - RV32IM only
//   All jumps/branches must be 4-byte aligned.  Two consequences:
//     * The "halfword_only" alignment bins (in cp_align) become unreachable.
//       They are declared as ignore_bins so coverage can still reach 100%.
//     * The "max_forward" offset bins must use the largest 4-aligned value
//       (0x0000_0FFC / 0x000F_FFFC) instead of the previous 2-mod-4 values.
//------------------------------------------------------------------------------
class ctrl_flow_coverage extends uvm_subscriber #(rv32im_instr_seq_item);
  `uvm_component_utils(ctrl_flow_coverage)

  rv32im_instr_seq_item item;

  //----------------------------------------------------------------------------
  // helpers : sign extension (the item keeps raw 12/13/21-bit immediates)
  //----------------------------------------------------------------------------
  function bit [31:0] imm_i();   return {{20{item.i_imm12[11]}},  item.i_imm12};   endfunction
  function bit [31:0] imm_jal(); return {{11{item.jal_imm21[20]}}, item.jal_imm21}; endfunction
  function bit [31:0] imm_b();   return {{19{item.b_imm13[12]}},  item.b_imm13};   endfunction

  function bit jal_backward(); return item.jal_imm21[20]; endfunction
  function bit br_backward();  return item.b_imm13[12];  endfunction

  function bit [31:0] jal_target();    return item.pc + imm_jal(); endfunction
  function bit [31:0] branch_target(); return item.pc + imm_b();   endfunction

  // 1 when the target is only halfword aligned (bit 1 set; bit 0 is always 0)
  function bit halfword_only(bit [31:0] target);
    return target[1];
  endfunction

  // 0 x0, 1 x1 (ra), 2 other
  function int reg_class(bit [4:0] r);
    if (r == 5'd0) return 0;
    if (r == 5'd1) return 1;
    return 2;
  endfunction

  // branch source registers: 0 distinct, 1 same register, 2 one of them is x0
  function int br_reg_rel();
    if (item.rs1 == 5'd0 || item.rs2 == 5'd0) return 2;
    if (item.rs1 == item.rs2)                 return 1;
    return 0;
  endfunction

  function bit is_cf();
    return item.opcode inside {OP_JAL, OP_JALR, OP_BRANCH};
  endfunction

  //----------------------------------------------------------------------------
  // JAL
  //----------------------------------------------------------------------------
  covergroup jal_cg;
    option.per_instance = 1;

    cp_rd: coverpoint reg_class(item.rd) {
      bins rd_x0    = {0};   // plain jump
      bins rd_x1    = {1};   // call
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
      // FIXED: previous value 32'h000F_FFFE was 2-mod-4 and thus unreachable
      // in an RV32IM-only test.  Use the largest 4-aligned forward offset.
      bins max_forward  = {32'h000F_FFFC};
    }
    // RV32IM only: every target is 4-byte aligned, so halfword_only is
    // structurally unreachable -> ignore it so coverage can reach 100%.
    cp_align: coverpoint halfword_only(jal_target()) {
      bins word_aligned  = {0};
      ignore_bins halfword_only = {1};
    }
    jal_rd_dir_cov: cross cp_rd, cp_dir;
    jal_align_cov:  cross cp_align, cp_rd;
  endgroup

  //----------------------------------------------------------------------------
  // JALR (funct3 is always 0)
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
    // call (rd=x1), return (rd=x0, rs1=x1), indirect jump (rd=x0, rs1=other) ...
    jalr_rd_rs1_cov: cross cp_rd, cp_rs1;
    jalr_rd_imm_cov: cross cp_rd, cp_imm;
  endgroup

  //----------------------------------------------------------------------------
  // Conditional branches : which instruction, which direction, which target
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
      bins min_backward = {32'hFFFF_F000};              // -4096
      bins backward     = {[32'hFFFF_F004 : 32'hFFFF_FFFC]};
      bins zero         = {32'h0};
      bins forward      = {[32'h0000_0004 : 32'h0000_0FF8]};
      // FIXED: previous value 32'h0000_0FFE was 2-mod-4 and unreachable.
      bins max_forward  = {32'h0000_0FFC};              // +4092
    }
    // static target alignment (the target the branch WOULD jump to)
    cp_align: coverpoint halfword_only(branch_target()) {
      bins word_aligned  = {0};
      ignore_bins halfword_only = {1};
    }
    cp_regs: coverpoint br_reg_rel() {
      bins distinct = {0};
      bins same_reg = {1};   // BEQ x5,x5 always taken, BNE x5,x5 never
      bins uses_x0  = {2};   // compare against zero
    }
    branch_op_dir_cov:   cross cp_op, cp_dir;
    branch_op_align_cov: cross cp_op, cp_align;
    branch_op_regs_cov:  cross cp_op, cp_regs;
  endgroup

  //----------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    jal_cg          = new();
    jalr_cg         = new();
    branch_instr_cg = new();
  endfunction

  function void write(rv32im_instr_seq_item t);
    item = t;
    case (item.opcode)
      OP_JAL:    jal_cg.sample();
      OP_JALR:   jalr_cg.sample();
      OP_BRANCH: branch_instr_cg.sample();
      default: ;
    endcase
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("CF_COV", $sformatf("coverage %%: jal=%0.1f jalr=%0.1f branch_instr=%0.1f",
      jal_cg.get_inst_coverage(), jalr_cg.get_inst_coverage(),
      branch_instr_cg.get_inst_coverage()), UVM_LOW)
  endfunction
endclass

`endif