// Base instruction sequence: knobs + reset + primitive emitters + operand preload.
// Concrete scenarios live in ../Instr_Agent/seqs/*.sv and extend this class.
class rv32im_instr_seq extends uvm_sequence #(rv32im_instr_seq_item);
  `uvm_object_utils(rv32im_instr_seq);

  int TESTS;

  // CHK:I-03  Relax the rd/rs partition used by random stimulus.
  bit relax_rd_rs = 0;

  // CHK:S-01..S-29  Gate for the directed stimulus phases.
  bit run_stim_batch3 = 0;

  // CHK:I-09  Stream knobs used by rv32im_stream_seq (propagated from rv32im_instr_config).
  int unsigned stream_min_len     = 3;
  int unsigned stream_max_len     = 5;
  bit [5:0]    stream_opcode_mask = 6'b11_1111;

  rv32im_instr_seq_item instr_item;
  rv32im_instr_seq_item reset_item;

  function new(string name = "rv32im_instr_seq");
    super.new(name);
  endfunction

  // -- Helper task to drive reset ------------------------------------------
  task drive_reset();
    reset_item = rv32im_instr_seq_item::type_id::create("reset_item");
    start_item(reset_item);
    if (!reset_item.randomize() with {rst_n == 0;})
      `uvm_fatal(get_name(), "Can't initially reset the core");
    finish_item(reset_item);
  endtask

  // ======================================================================
  //  Primitive emitters
  // ======================================================================

  task emit_lui(bit [4:0] arg_rd, bit [19:0] arg_imm20);
    rv32im_instr_seq_item it;
    it = rv32im_instr_seq_item::type_id::create("lui_item");
    it.relax_rd_rs = this.relax_rd_rs;
    start_item(it);
    if (!it.randomize() with {
          rst_n   == 1;
          opcode  == OP_LUI;
          rd      == arg_rd;
          u_imm20 == arg_imm20;
        })
      `uvm_fatal(get_name(), "emit_lui randomize failed");
    finish_item(it);
  endtask

  // CHK:S-26  AUIPC helper.
  task emit_auipc(bit [4:0] arg_rd, bit [19:0] arg_imm20);
    rv32im_instr_seq_item it;
    it = rv32im_instr_seq_item::type_id::create("auipc_item");
    it.relax_rd_rs = this.relax_rd_rs;
    start_item(it);
    if (!it.randomize() with {
          rst_n   == 1;
          opcode  == OP_AUIPC;
          rd      == arg_rd;
          u_imm20 == arg_imm20;
        })
      `uvm_fatal(get_name(), "emit_auipc randomize failed");
    finish_item(it);
  endtask

  task emit_addi(bit [4:0] arg_rd, bit [4:0] arg_rs1, bit [11:0] arg_imm12);
    rv32im_instr_seq_item it;
    it = rv32im_instr_seq_item::type_id::create("addi_item");
    it.relax_rd_rs = this.relax_rd_rs;
    start_item(it);
    if (!it.randomize() with {
          rst_n   == 1;
          opcode  == OP_IMM;
          I_ops   == ADDI;
          rd      == arg_rd;
          rs1     == arg_rs1;
          i_imm12 == arg_imm12;
        })
      `uvm_fatal(get_name(), "emit_addi randomize failed");
    finish_item(it);
  endtask

  task emit_load(bit [4:0] arg_rd, bit [4:0] arg_rs1, bit [11:0] arg_imm12,
                 Load_ops_t arg_op);
    rv32im_instr_seq_item it;
    it = rv32im_instr_seq_item::type_id::create("load_item");
    it.relax_rd_rs = this.relax_rd_rs;
    start_item(it);
    if (!it.randomize() with {
          rst_n   == 1;
          opcode  == OP_LOAD;
          Load_ops == arg_op;
          rd      == arg_rd;
          rs1     == arg_rs1;
          i_imm12 == arg_imm12;
        })
      `uvm_fatal(get_name(), "emit_load randomize failed");
    finish_item(it);
  endtask

  task emit_li32(bit [4:0] arg_rd, bit [31:0] value);
    bit [19:0] hi20_base;
    bit [11:0] lo12_raw;
    bit [19:0] hi20_corr;
    bit [11:0] lo12_eff;

    lo12_raw  = value[11:0];
    hi20_base = value[31:12];

    if (lo12_raw[11]) hi20_corr = hi20_base + 20'd1;
    else              hi20_corr = hi20_base;

    lo12_eff = value[11:0] - (hi20_corr << 12);

    emit_lui(arg_rd, hi20_corr);
    if (lo12_eff != 12'd0) emit_addi(arg_rd, arg_rd, lo12_eff);
  endtask

  task emit_r_alu(bit [4:0] rd_arg, bit [4:0] rs1_arg, bit [4:0] rs2_arg,
                  alu_ops_t op, bit funct7_high);
    rv32im_instr_seq_item it;
    it = rv32im_instr_seq_item::type_id::create("r_alu");
    it.relax_rd_rs = this.relax_rd_rs;
    start_item(it);
    if (!it.randomize() with {
          rst_n       == 1;
          opcode      == OP_R;
          ALU_MUL_sel == ALU;
          rd          == rd_arg;
          rs1         == rs1_arg;
          rs2         == rs2_arg;
          R_rv32i_ops == op;
          funct7      == (funct7_high ? 7'd32 : 7'd0);
        })
      `uvm_fatal(get_name(), "emit_r_alu randomize failed");
    finish_item(it);
  endtask

  task emit_r_muldiv(bit [4:0] rd_arg, bit [4:0] rs1_arg, bit [4:0] rs2_arg,
                     mul_div_ops_t op);
    rv32im_instr_seq_item it;
    it = rv32im_instr_seq_item::type_id::create("r_muldiv");
    it.relax_rd_rs = this.relax_rd_rs;
    start_item(it);
    if (!it.randomize() with {
          rst_n       == 1;
          opcode      == OP_R;
          ALU_MUL_sel == MUL_DIV;
          rd          == rd_arg;
          rs1         == rs1_arg;
          rs2         == rs2_arg;
          R_rv32m_ops == op;
        })
      `uvm_fatal(get_name(), "emit_r_muldiv randomize failed");
    finish_item(it);
  endtask

  task emit_shift_imm(bit [4:0] rd_arg, bit [4:0] rs1_arg, bit [4:0] shamt_arg,
                      I_ops_t op, bit is_sra);
    rv32im_instr_seq_item it;
    it = rv32im_instr_seq_item::type_id::create("shift_imm");
    it.relax_rd_rs = this.relax_rd_rs;
    start_item(it);
    if (!it.randomize() with {
          rst_n == 1;
          opcode == OP_IMM;
          rd     == rd_arg;
          rs1    == rs1_arg;
          shamt  == shamt_arg;
          I_ops  == op;
          if (op == SRLI_SRAI) funct7 == (is_sra ? 7'd32 : 7'd0);
          else                 funct7 == 7'd0;
        })
      `uvm_fatal(get_name(), "emit_shift_imm randomize failed");
    finish_item(it);
  endtask

  task emit_sltiu_1(bit [4:0] rd_arg, bit [4:0] rs1_arg);
    rv32im_instr_seq_item it;
    it = rv32im_instr_seq_item::type_id::create("sltiu_1");
    it.relax_rd_rs = this.relax_rd_rs;
    start_item(it);
    if (!it.randomize() with {
          rst_n   == 1;
          opcode  == OP_IMM;
          I_ops   == SLTIU;
          rd      == rd_arg;
          rs1     == rs1_arg;
          i_imm12 == 12'd1;
        })
      `uvm_fatal(get_name(), "emit_sltiu_1 randomize failed");
    finish_item(it);
  endtask

  task emit_branch(bit [4:0] rs1_arg, bit [4:0] rs2_arg, bit [12:0] imm_arg,
                   B_ops_t op);
    rv32im_instr_seq_item it;
    it = rv32im_instr_seq_item::type_id::create("branch");
    it.relax_rd_rs = this.relax_rd_rs;
    start_item(it);
    if (!it.randomize() with {
          rst_n   == 1;
          opcode  == OP_BRANCH;
          rs1     == rs1_arg;
          rs2     == rs2_arg;
          b_imm13 == imm_arg;
          B_ops   == op;
        })
      `uvm_fatal(get_name(), "emit_branch randomize failed");
    finish_item(it);
  endtask

  task emit_jal(bit [4:0] rd_arg, bit [20:0] imm_arg);
    rv32im_instr_seq_item it;
    it = rv32im_instr_seq_item::type_id::create("jal");
    it.relax_rd_rs = this.relax_rd_rs;
    start_item(it);
    if (!it.randomize() with {
          rst_n      == 1;
          opcode     == OP_JAL;
          rd         == rd_arg;
          jal_imm21  == imm_arg;
        })
      `uvm_fatal(get_name(), "emit_jal randomize failed");
    finish_item(it);
  endtask

  task emit_jalr(bit [4:0] rd_arg, bit [4:0] rs1_arg, bit [11:0] imm_arg);
    rv32im_instr_seq_item it;
    it = rv32im_instr_seq_item::type_id::create("jalr");
    it.relax_rd_rs = this.relax_rd_rs;
    start_item(it);
    if (!it.randomize() with {
          rst_n   == 1;
          opcode  == OP_JALR;
          rd      == rd_arg;
          rs1     == rs1_arg;
          i_imm12 == imm_arg;
        })
      `uvm_fatal(get_name(), "emit_jalr randomize failed");
    finish_item(it);
  endtask

  // ======================================================================
  //  CHK:S-01  Raw 32-bit word, no decoding / randomisation.
  // ======================================================================
  task emit_raw(bit [31:0] word);
    rv32im_instr_seq_item it;
    it = rv32im_instr_seq_item::type_id::create("raw_item");
    it.relax_rd_rs = this.relax_rd_rs;
    start_item(it);
    if (!it.randomize() with { rst_n == 1; })
      `uvm_fatal(get_name(), "emit_raw randomize failed");
    it.instruction = word;
    finish_item(it);
  endtask

  // ======================================================================
  //  CHK:I-02  Generic I-type (OP_IMM) with explicit funct3 / imm.
  // ======================================================================
  task emit_i_op(bit [2:0] arg_funct3, bit [4:0] arg_rd, bit [4:0] arg_rs1,
                 bit [11:0] arg_imm12);
    rv32im_instr_seq_item it;
    it = rv32im_instr_seq_item::type_id::create("i_op");
    it.relax_rd_rs = this.relax_rd_rs;
    start_item(it);
    if (!it.randomize() with {
          rst_n    == 1;
          opcode   == OP_IMM;
          rd       == arg_rd;
          rs1      == arg_rs1;
          i_imm12  == arg_imm12;
          I_ops    == I_ops_t'(arg_funct3);
        })
      `uvm_fatal(get_name(), "emit_i_op randomize failed");
    finish_item(it);
  endtask

  task emit_slti(bit [4:0] arg_rd, bit [4:0] arg_rs1, bit [11:0] arg_imm12);
    emit_i_op(3'b010, arg_rd, arg_rs1, arg_imm12);
  endtask

  task emit_xori(bit [4:0] arg_rd, bit [4:0] arg_rs1, bit [11:0] arg_imm12);
    emit_i_op(3'b100, arg_rd, arg_rs1, arg_imm12);
  endtask

  // ======================================================================
  //  CHK:I-02  Store with explicit funct3 (SB=0, SH=1, SW=2).
  // ======================================================================
  task emit_store(bit [4:0] arg_rs2, bit [4:0] arg_rs1, bit [11:0] arg_imm12,
                  bit [2:0] arg_funct3);
    rv32im_instr_seq_item it;
    it = rv32im_instr_seq_item::type_id::create("store_op");
    it.relax_rd_rs = this.relax_rd_rs;
    start_item(it);
    if (!it.randomize() with {
          rst_n   == 1;
          opcode  == OP_STORE;
          rs2     == arg_rs2;
          rs1     == arg_rs1;
          i_imm12 == arg_imm12;
          S_ops   == S_ops_t'(arg_funct3);
        })
      `uvm_fatal(get_name(), "emit_store randomize failed");
    finish_item(it);
  endtask

  // ======================================================================
  //  CHK:S-07  Load a register with the constant 32.
  // ======================================================================
  task emit_lw_reg32();
    emit_addi(5'd31, 5'd0, 12'd32);
  endtask

  // ======================================================================
  //  CHK:S-22..S-25  Restore x1 = 0x1000 (memory base).
  // ======================================================================
  task restore_mem_base();
    emit_lui(5'd1, 20'h00001);
  endtask

  // ======================================================================
  //  Operand-pool preload
  // ======================================================================
  task preload_operand_pool();
    emit_addi(5'd16, 5'd0,  12'h000);        // 0x00000000
    emit_addi(5'd17, 5'd0,  12'h001);        // 0x00000001
    emit_addi(5'd18, 5'd0,  12'hFFF);        // 0xFFFFFFFF
    emit_lui (5'd19, 20'h80000);
    emit_addi(5'd19, 5'd19, 12'hFFF);        // 0x7FFFFFFF
    emit_lui (5'd20, 20'h80000);             // 0x80000000
    emit_lui (5'd21, 20'h55555);
    emit_addi(5'd21, 5'd21, 12'h555);        // 0x55555555
    emit_lui (5'd22, 20'hAAAAB);
    emit_addi(5'd22, 5'd22, 12'hAAA);        // 0xAAAAAAAA
    emit_lui (5'd23, 20'h40000);             // 0x40000000
    emit_addi(5'd24, 5'd0,  12'h002);        // 0x00000002
    emit_addi(5'd25, 5'd0,  12'hFFE);        // 0xFFFFFFFE
    emit_lui (5'd26, 20'h00010);             // 0x00010000
    emit_lui (5'd27, 20'h00010);
    emit_addi(5'd27, 5'd27, 12'hFFF);        // 0x0000FFFF
    emit_lui (5'd28, 20'h12345);
    emit_addi(5'd28, 5'd28, 12'h678);        // 0x12345678
    emit_lui (5'd29, 20'h80000);
    emit_addi(5'd29, 5'd29, 12'h001);        // 0x80000001
    emit_lui (5'd30, 20'h80000);
    emit_addi(5'd30, 5'd30, 12'hFFE);        // 0x7FFFFFFE
    emit_addi(5'd31, 5'd0,  12'h010);        // 0x00000010
  endtask

  // Derived sequences override body().
  virtual task body();
  endtask
endclass  // rv32im_instr_seq
