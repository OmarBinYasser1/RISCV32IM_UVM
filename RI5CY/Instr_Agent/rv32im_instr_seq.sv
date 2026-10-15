// Multi-phase instruction sequence covering all RV32IM operations
class rv32im_instr_seq extends uvm_sequence #(rv32im_instr_seq_item);
  `uvm_object_utils(rv32im_instr_seq);

  int TESTS;

  // CHK:I-03  Mirrors rv32im_instr_config.relax_rd_rs.
  bit relax_rd_rs = 0;

  // CHK:S-01..S-29  Batch-3 stimulus gate.  See rv32im_instr_config.
  bit run_stim_batch3 = 0;

  rv32im_instr_seq_item instr_item;
  rv32im_instr_seq_item reset_item;

  function new(string name = "rv32im_instr_seq");
    super.new(name);
  endfunction

  // == Helper task to drive reset ==========================================
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
  //  CHK:I-01  Raw 32-bit word, no decoding / randomisation.
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
  //  CHK:I-02  Load a register with 32 (for S-07 register-shift corner).
  // ======================================================================
  task emit_lw_reg32();
    emit_addi(5'd31, 5'd0, 12'd32);
  endtask

  // ======================================================================
  //  CHK:S-22..S-25  Restore x1 = 0x1000 (memory base for random test).
  // ======================================================================
  task restore_mem_base();
    emit_lui(5'd1, 20'h00001);   // x1 = 0x1000
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

  // ======================================================================
  //  Directed phase: ALU corners
  // ======================================================================
  task phase_alu_directed();
    bit [4:0] pats [6];
    bit [4:0] shamt_list [4];
    bit [4:0] src_list   [3];

    preload_operand_pool();

    pats[0] = 5'd16;   // zero
    pats[1] = 5'd18;   // all_ones
    pats[2] = 5'd20;   // walking_1
    pats[3] = 5'd23;   // walking_1
    pats[4] = 5'd19;   // walking_0
    pats[5] = 5'd25;   // walking_0

    emit_r_alu(5'd8, 5'd19, 5'd19, ADD_SUB, 0);
    emit_r_alu(5'd8, 5'd20, 5'd20, ADD_SUB, 0);
    emit_r_alu(5'd8, 5'd18, 5'd18, ADD_SUB, 0);
    emit_r_alu(5'd8, 5'd25, 5'd25, ADD_SUB, 0);
    emit_r_alu(5'd8, 5'd20, 5'd25, ADD_SUB, 0);
    emit_r_alu(5'd8, 5'd19, 5'd24, ADD_SUB, 0);
    emit_r_alu(5'd8, 5'd19, 5'd20, ADD_SUB, 1);
    emit_r_alu(5'd8, 5'd19, 5'd18, ADD_SUB, 1);
    emit_r_alu(5'd8, 5'd20, 5'd24, ADD_SUB, 1);
    emit_r_alu(5'd8, 5'd20, 5'd25, ADD_SUB, 1);
    emit_r_alu(5'd8, 5'd19, 5'd24, ADD_SUB, 1);
    emit_r_alu(5'd8, 5'd19, 5'd20, ADD_SUB, 0);
    emit_r_alu(5'd8, 5'd18, 5'd19, ADD_SUB, 1);
    emit_r_alu(5'd8, 5'd25, 5'd19, ADD_SUB, 1);
    emit_r_alu(5'd8, 5'd18, 5'd18, ADD_SUB, 1);
    emit_r_alu(5'd8, 5'd25, 5'd18, ADD_SUB, 1);
    emit_r_alu(5'd8, 5'd24, 5'd19, ADD_SUB, 1);
    emit_r_alu(5'd8, 5'd24, 5'd25, ADD_SUB, 1);

    for (int i = 0; i < 6; i++) begin
      for (int j = 0; j < 6; j++) begin
        emit_r_alu(5'd8, pats[i], pats[j], AND, 0);
        emit_r_alu(5'd8, pats[i], pats[j], OR,  0);
        emit_r_alu(5'd8, pats[i], pats[j], XOR, 0);
      end
    end

    shamt_list[0] = 5'd0;
    shamt_list[1] = 5'd1;
    shamt_list[2] = 5'd15;
    shamt_list[3] = 5'd31;
    src_list[0]   = 5'd19;
    src_list[1]   = 5'd20;
    src_list[2]   = 5'd18;
    for (int i = 0; i < 4; i++) begin
      for (int j = 0; j < 3; j++) begin
        emit_shift_imm(5'd8, src_list[j], shamt_list[i], SLLI,     1'b0);
        emit_shift_imm(5'd8, src_list[j], shamt_list[i], SRLI_SRAI, 1'b0);
        emit_shift_imm(5'd8, src_list[j], shamt_list[i], SRLI_SRAI, 1'b1);
      end
    end

    emit_sltiu_1(5'd8,  5'd16);
    emit_sltiu_1(5'd8,  5'd0);
    emit_sltiu_1(5'd8,  5'd19);
    emit_sltiu_1(5'd8,  5'd20);
  endtask

  // ======================================================================
  //  Directed phase: control flow
  // ======================================================================
  task phase_ctrl_flow_directed();
    B_ops_t br_ops [6];

    preload_operand_pool();

    br_ops[0] = BEQ;  br_ops[1] = BNE;  br_ops[2] = BLT;
    br_ops[3] = BGE;  br_ops[4] = BLTU; br_ops[5] = BGEU;

    for (int i = 0; i < 6; i++) begin
      emit_branch(5'd16, 5'd16, 13'd4, br_ops[i]);
      emit_branch(5'd19, 5'd19, 13'd4, br_ops[i]);
      emit_branch(5'd20, 5'd20, 13'd4, br_ops[i]);
      emit_branch(5'd0,  5'd19, 13'd4, br_ops[i]);
      emit_branch(5'd19, 5'd0,  13'd4, br_ops[i]);
      emit_branch(5'd0,  5'd0,  13'd4, br_ops[i]);
      emit_branch(5'd19, 5'd24, 13'd4, br_ops[i]);
      emit_branch(5'd24, 5'd19, 13'd4, br_ops[i]);
      emit_branch(5'd18, 5'd20, 13'd4, br_ops[i]);
      emit_branch(5'd20, 5'd18, 13'd4, br_ops[i]);
      emit_branch(5'd19, 5'd20, 13'd4, br_ops[i]);
      emit_branch(5'd20, 5'd19, 13'd4, br_ops[i]);
      emit_branch(5'd19, 5'd24, 13'h1FFC, br_ops[i]);
      emit_branch(5'd19, 5'd24, 13'h1FFC, br_ops[i]);
      emit_branch(5'd24, 5'd19, 13'h1004, br_ops[i]);
      emit_branch(5'd19, 5'd24, 13'd8,  br_ops[i]);
      emit_branch(5'd19, 5'd24, 13'd12, br_ops[i]);
    end

    emit_branch(5'd0, 5'd24, 13'h1000, BEQ);
    emit_branch(5'd0, 5'd24, 13'h0000, BEQ);
    emit_branch(5'd0, 5'd24, 13'h0FFC, BEQ);

    begin
      bit [4:0] jal_rd [4];
      bit [20:0] jal_imm [8];
      jal_rd[0] = 5'd0;   jal_rd[1] = 5'd1;
      jal_rd[2] = 5'd8;   jal_rd[3] = 5'd9;

      jal_imm[0] = 21'h000004;
      jal_imm[1] = 21'h000004;
      jal_imm[2] = 21'h000008;
      jal_imm[3] = 21'h000FFC;
      jal_imm[4] = 21'h0FFFFC;
      jal_imm[5] = 21'h1FFFFC;
      jal_imm[6] = 21'h100000;
      jal_imm[7] = 21'h000000;

      for (int i = 0; i < 4; i++)
        for (int j = 0; j < 8; j++)
          emit_jal(jal_rd[i], jal_imm[j]);
    end

    emit_li32(5'd1, 32'h0000_0200);

    begin
      bit [4:0]  jr_rd  [3]; bit [4:0]  jr_rs1 [3];
      bit [11:0] jr_imm [3];
      jr_rd[0]  = 5'd0; jr_rd[1]  = 5'd1; jr_rd[2]  = 5'd8;
      jr_rs1[0] = 5'd0; jr_rs1[1] = 5'd1; jr_rs1[2] = 5'd28;
      jr_imm[0] = 12'h000; jr_imm[1] = 12'h004; jr_imm[2] = 12'hFFC;

      for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++)
          for (int k = 0; k < 3; k++)
            emit_jalr(jr_rd[i], jr_rs1[j], jr_imm[k]);
    end
  endtask

  // ======================================================================
  //  Directed phase: DIV / REM boundary matrix
  // ======================================================================
  task phase_divrem_directed();
    bit [4:0] regs [5];

    preload_operand_pool();

    regs[0] = 5'd16;
    regs[1] = 5'd17;
    regs[2] = 5'd18;
    regs[3] = 5'd19;
    regs[4] = 5'd20;

    for (int i = 0; i < 5; i++) begin
      for (int j = 0; j < 5; j++) begin
        emit_r_muldiv(5'd8, regs[i], regs[j], DIV);
        emit_r_muldiv(5'd8, regs[i], regs[j], DIVU);
        emit_r_muldiv(5'd8, regs[i], regs[j], REM);
        emit_r_muldiv(5'd8, regs[i], regs[j], REMU);
      end
    end

    emit_r_muldiv(5'd8, 5'd20, 5'd18, DIV);
    emit_r_muldiv(5'd8, 5'd20, 5'd18, REM);
    emit_r_muldiv(5'd8, 5'd19, 5'd24, DIV);
    emit_r_muldiv(5'd8, 5'd19, 5'd24, REM);
    emit_r_muldiv(5'd8, 5'd22, 5'd21, DIVU);
    emit_r_muldiv(5'd8, 5'd22, 5'd21, REMU);
    emit_r_muldiv(5'd8, 5'd16, 5'd16, REMU);
  endtask

  // ======================================================================
  //  Directed phase: MUL corners and MULH+MUL pair
  // ======================================================================
  task phase_mul_directed();
    preload_operand_pool();

    emit_r_muldiv(5'd8, 5'd16, 5'd16, MUL);
    emit_r_muldiv(5'd8, 5'd16, 5'd16, MULH);
    emit_r_muldiv(5'd8, 5'd16, 5'd16, MULHSU);
    emit_r_muldiv(5'd8, 5'd16, 5'd16, MULHU);
    emit_r_muldiv(5'd8, 5'd16, 5'd19, MUL);
    emit_r_muldiv(5'd8, 5'd16, 5'd19, MULH);
    emit_r_muldiv(5'd8, 5'd16, 5'd19, MULHSU);
    emit_r_muldiv(5'd8, 5'd16, 5'd19, MULHU);
    emit_r_muldiv(5'd8, 5'd19, 5'd16, MUL);
    emit_r_muldiv(5'd8, 5'd19, 5'd16, MULH);
    emit_r_muldiv(5'd8, 5'd19, 5'd16, MULHSU);
    emit_r_muldiv(5'd8, 5'd19, 5'd16, MULHU);

    emit_r_muldiv(5'd8, 5'd17, 5'd17, MUL);
    emit_r_muldiv(5'd8, 5'd17, 5'd17, MULH);
    emit_r_muldiv(5'd8, 5'd17, 5'd17, MULHSU);
    emit_r_muldiv(5'd8, 5'd17, 5'd17, MULHU);
    emit_r_muldiv(5'd8, 5'd17, 5'd19, MUL);
    emit_r_muldiv(5'd8, 5'd17, 5'd19, MULH);
    emit_r_muldiv(5'd8, 5'd17, 5'd19, MULHSU);
    emit_r_muldiv(5'd8, 5'd17, 5'd19, MULHU);
    emit_r_muldiv(5'd8, 5'd19, 5'd17, MUL);
    emit_r_muldiv(5'd8, 5'd19, 5'd17, MULH);
    emit_r_muldiv(5'd8, 5'd19, 5'd17, MULHSU);
    emit_r_muldiv(5'd8, 5'd19, 5'd17, MULHU);

    emit_r_muldiv(5'd8, 5'd20, 5'd18, MUL);
    emit_r_muldiv(5'd8, 5'd19, 5'd19, MUL);
    emit_r_muldiv(5'd8, 5'd20, 5'd20, MUL);
    emit_r_muldiv(5'd8, 5'd23, 5'd24, MUL);

    emit_r_muldiv(5'd8, 5'd24, 5'd18, MULHU);
    emit_r_muldiv(5'd8, 5'd18, 5'd24, MULHU);
    emit_r_muldiv(5'd8, 5'd24, 5'd24, MULHU);
    emit_r_muldiv(5'd8, 5'd24, 5'd31, MULHU);
    emit_r_muldiv(5'd8, 5'd31, 5'd31, MULHU);
    emit_r_muldiv(5'd8, 5'd17, 5'd17, MULHU);

    emit_r_muldiv(5'd8, 5'd18, 5'd24, MULHSU);
    emit_r_muldiv(5'd8, 5'd18, 5'd20, MULHSU);

    emit_r_muldiv(5'd8, 5'd19, 5'd20, MULH);
    emit_r_muldiv(5'd8, 5'd19, 5'd20, MUL);

    emit_r_muldiv(5'd8, 5'd18, 5'd20, MULH);
    emit_r_muldiv(5'd8, 5'd18, 5'd20, MUL);

    emit_r_muldiv(5'd8, 5'd19, 5'd24, MULH);
    emit_r_muldiv(5'd8, 5'd19, 5'd24, MUL);

    emit_r_muldiv(5'd8, 5'd19, 5'd24, MULHU);
    emit_r_muldiv(5'd8, 5'd19, 5'd24, MUL);

    emit_r_muldiv(5'd8, 5'd18, 5'd24, MULHU);
    emit_r_muldiv(5'd8, 5'd18, 5'd24, MUL);
  endtask

  // ======================================================================
  //  Directed phase: regfile / RAW-hazard closure
  // ======================================================================
  task phase_regfile_hazard_directed();
    bit [4:0] rreg;

    emit_addi(5'd0, 5'd0, 12'h000);
    emit_addi(5'd1, 5'd0, 12'h001);
    emit_addi(5'd2, 5'd0, 12'h002);
    emit_addi(5'd3, 5'd0, 12'h003);
    emit_addi(5'd4, 5'd0, 12'h004);
    emit_addi(5'd5, 5'd0, 12'h005);
    emit_addi(5'd6, 5'd0, 12'h006);
    emit_addi(5'd7, 5'd0, 12'h007);

    emit_load(5'd0, 5'd0, 12'h000, LW);
    emit_load(5'd1, 5'd0, 12'h004, LW);
    emit_load(5'd2, 5'd0, 12'h008, LW);
    emit_load(5'd3, 5'd0, 12'h00C, LW);
    emit_load(5'd4, 5'd0, 12'h010, LW);
    emit_load(5'd5, 5'd0, 12'h014, LW);
    emit_load(5'd6, 5'd0, 12'h018, LW);
    emit_load(5'd7, 5'd0, 12'h01C, LW);

    emit_load(5'd16, 5'd0, 12'h020, LW);
    emit_load(5'd17, 5'd0, 12'h024, LW);
    emit_load(5'd18, 5'd0, 12'h028, LW);
    emit_load(5'd19, 5'd0, 12'h02C, LW);
    emit_load(5'd20, 5'd0, 12'h030, LW);
    emit_load(5'd21, 5'd0, 12'h034, LW);
    emit_load(5'd22, 5'd0, 12'h038, LW);
    emit_load(5'd23, 5'd0, 12'h03C, LW);
    emit_load(5'd24, 5'd0, 12'h040, LW);
    emit_load(5'd25, 5'd0, 12'h044, LW);
    emit_load(5'd26, 5'd0, 12'h048, LW);
    emit_load(5'd27, 5'd0, 12'h04C, LW);
    emit_load(5'd28, 5'd0, 12'h050, LW);
    emit_load(5'd29, 5'd0, 12'h054, LW);
    emit_load(5'd30, 5'd0, 12'h058, LW);
    emit_load(5'd31, 5'd0, 12'h05C, LW);

    emit_r_alu(5'd8, 5'd0,  5'd7,  ADD_SUB, 0);
    emit_r_alu(5'd8, 5'd0,  5'd2,  ADD_SUB, 0);
    emit_r_alu(5'd8, 5'd0,  5'd11, ADD_SUB, 0);
    emit_r_alu(5'd8, 5'd7,  5'd0,  ADD_SUB, 0);

    emit_addi(5'd20, 5'd0, 12'h001);
    emit_addi(5'd21, 5'd0, 12'h002);
    emit_r_alu(5'd22, 5'd0, 5'd20, ADD_SUB, 0);

    emit_addi(5'd23, 5'd0, 12'h003);
    emit_addi(5'd24, 5'd0, 12'h004);
    emit_addi(5'd25, 5'd0, 12'h005);
    emit_r_alu(5'd26, 5'd0, 5'd23, ADD_SUB, 0);

    emit_addi(5'd27, 5'd0, 12'h006);
    emit_addi(5'd28, 5'd0, 12'h007);
    emit_addi(5'd29, 5'd0, 12'h008);
    emit_addi(5'd30, 5'd0, 12'h009);
    emit_r_alu(5'd31, 5'd0, 5'd27, ADD_SUB, 0);

    emit_addi(5'd2, 5'd0, 12'h00A);
    emit_addi(5'd3, 5'd0, 12'h00B);
    emit_addi(5'd4, 5'd0, 12'h00C);
    emit_addi(5'd5, 5'd0, 12'h00D);
    emit_addi(5'd6, 5'd0, 12'h00E);
    emit_r_alu(5'd7, 5'd0, 5'd2, ADD_SUB, 0);

    emit_addi(5'd3, 5'd0, 12'h011);
    emit_addi(5'd8, 5'd0, 12'h012);
    emit_r_alu(5'd9, 5'd0, 5'd3, ADD_SUB, 0);

    emit_addi(5'd4, 5'd0, 12'h013);
    emit_addi(5'd8, 5'd0, 12'h014);
    emit_addi(5'd9, 5'd0, 12'h015);
    emit_r_alu(5'd10, 5'd0, 5'd4, ADD_SUB, 0);

    emit_addi(5'd5, 5'd0, 12'h016);
    emit_addi(5'd8, 5'd0, 12'h017);
    emit_addi(5'd9, 5'd0, 12'h018);
    emit_addi(5'd10, 5'd0, 12'h019);
    emit_r_alu(5'd11, 5'd0, 5'd5, ADD_SUB, 0);

    emit_addi(5'd6, 5'd0, 12'h01A);
    emit_addi(5'd8, 5'd0, 12'h01B);
    emit_addi(5'd9, 5'd0, 12'h01C);
    emit_addi(5'd10, 5'd0, 12'h01D);
    emit_addi(5'd11, 5'd0, 12'h01E);
    emit_r_alu(5'd12, 5'd0, 5'd6, ADD_SUB, 0);

    // ---------- CHK:B7  Long-delay and R-type producer ----------
    // Long-delay write-then-read: write, 10 filler, read.
    // Note: loop variable is a correctly-typed 5-bit register.
    for (int r = 1; r <= 4; r++) begin
      rreg = r[4:0];
      emit_addi(rreg, 5'd0, 12'(12'h100 + r));
      repeat (10) emit_addi(5'd12, 5'd0, 12'h000);
      emit_r_alu(5'd13, 5'd0, rreg, ADD_SUB, 0);
    end

    // R-type ALU producer -> various consumers, at distance 0 and 1.
    emit_r_alu(5'd8, 5'd16, 5'd17, ADD_SUB, 0);
    emit_r_alu(5'd9, 5'd8,  5'd16, AND, 0);      // distance 0
    emit_r_alu(5'd8, 5'd16, 5'd17, XOR, 0);
    emit_addi (5'd10, 5'd0, 12'h001);            // filler
    emit_r_alu(5'd9, 5'd8,  5'd16, OR, 0);       // distance 1

    // Broad one-cycle and short-delay coverage on x1..x30.
    for (int r = 1; r < 31; r++) begin
      rreg = r[4:0];
      emit_addi(rreg, 5'd0, 12'h007);            // write x_r
      emit_r_alu(5'd31, 5'd0, rreg, ADD_SUB, 0); // read x_r on port B, distance ~1
    end
  endtask

  // ======================================================================
  //  CHK:S-01  Illegal-encoding stimulus.
  // ======================================================================
  task phase_stim_illegal();
    preload_operand_pool();

    // 1. SLLI with imm[11:5] != 0 (reserved)
    emit_raw({7'b0100000, 5'd0, 5'd16, 3'b001, 5'd8, 7'h13});
    emit_addi(5'd8, 5'd0, 12'h001);

    // 2. SRLI with imm[11:5] neither 0 nor 0x20
    emit_raw({7'b0110000, 5'd0, 5'd16, 3'b101, 5'd8, 7'h13});
    emit_addi(5'd8, 5'd0, 12'h002);

    // 3. LOAD funct3=3'b011
    emit_raw({12'h000, 5'd0, 3'b011, 5'd8, 7'h03});
    emit_addi(5'd8, 5'd0, 12'h003);

    // 4. LOAD funct3=3'b110
    emit_raw({12'h000, 5'd0, 3'b110, 5'd8, 7'h03});
    emit_addi(5'd8, 5'd0, 12'h004);

    // 5. LOAD funct3=3'b111
    emit_raw({12'h000, 5'd0, 3'b111, 5'd8, 7'h03});
    emit_addi(5'd8, 5'd0, 12'h005);

    // 6. STORE funct3=3'b011
    emit_raw({7'b0000000, 5'd16, 5'd0, 3'b011, 5'd0, 7'h23});
    emit_addi(5'd8, 5'd0, 12'h006);

    // 7. STORE funct3=3'b100
    emit_raw({7'b0000000, 5'd16, 5'd0, 3'b100, 5'd0, 7'h23});
    emit_addi(5'd8, 5'd0, 12'h007);

    // 8. STORE funct3=3'b101
    emit_raw({7'b0000000, 5'd16, 5'd0, 3'b101, 5'd0, 7'h23});
    emit_addi(5'd8, 5'd0, 12'h008);

    // 9. STORE funct3=3'b110
    emit_raw({7'b0000000, 5'd16, 5'd0, 3'b110, 5'd0, 7'h23});
    emit_addi(5'd8, 5'd0, 12'h009);

    // 10. STORE funct3=3'b111
    emit_raw({7'b0000000, 5'd16, 5'd0, 3'b111, 5'd0, 7'h23});
    emit_addi(5'd8, 5'd0, 12'h00A);

    // 11. BRANCH funct3=3'b010
    emit_raw({7'b0000000, 5'd0, 5'd0, 3'b010, 5'd0, 7'h63});
    emit_addi(5'd8, 5'd0, 12'h00B);

    // 12. BRANCH funct3=3'b011
    emit_raw({7'b0000000, 5'd0, 5'd0, 3'b011, 5'd0, 7'h63});
    emit_addi(5'd8, 5'd0, 12'h00C);

    // 13. JALR funct3=3'b001
    emit_raw({12'h000, 5'd0, 3'b001, 5'd0, 7'h67});
    emit_addi(5'd8, 5'd0, 12'h00D);

    // 14. Unused opcode 0x0B
    emit_raw(32'h0000000B);
    emit_addi(5'd8, 5'd0, 12'h00E);

    // 14. Unused opcode 0x7F (custom-3, never decoded by RV32IM)
    emit_raw(32'h0000007F);

    // 15. OP funct7=2, funct3=110
    emit_raw({7'b0000010, 5'd17, 5'd16, 3'b110, 5'd8, 7'h33});
    emit_addi(5'd8, 5'd0, 12'h00F);
  endtask

  // ======================================================================
  //  CHK:S-02 + B5  rd == rs1 / rd == rs2 for ALU / MUL / DIV / REM.
  // ======================================================================
  task phase_stim_same_reg();
    preload_operand_pool();

    emit_addi(5'd8, 5'd8, 12'h010);
    emit_r_alu(5'd9, 5'd9, 5'd17, ADD_SUB, 0);
    emit_r_alu(5'd10, 5'd16, 5'd10, ADD_SUB, 0);
    emit_r_alu(5'd11, 5'd11, 5'd11, AND, 0);

    emit_r_muldiv(5'd8, 5'd8, 5'd17, MUL);
    emit_r_muldiv(5'd9, 5'd16, 5'd9, MUL);

    emit_r_muldiv(5'd8, 5'd8, 5'd17, DIV);
    emit_r_muldiv(5'd9, 5'd16, 5'd9, DIV);
    emit_r_muldiv(5'd10, 5'd10, 5'd17, REM);
    emit_r_muldiv(5'd11, 5'd16, 5'd11, REM);

    emit_shift_imm(5'd8, 5'd8, 5'd3, SLLI, 1'b0);
    emit_shift_imm(5'd8, 5'd8, 5'd3, SRLI_SRAI, 1'b0);
    emit_shift_imm(5'd8, 5'd8, 5'd3, SRLI_SRAI, 1'b1);

    // ---------- CHK:B5  rd==rs1==rs2 ----------
    emit_r_muldiv(5'd8, 5'd8, 5'd8, MUL);
    emit_r_muldiv(5'd8, 5'd8, 5'd8, DIV);
    emit_r_muldiv(5'd8, 5'd8, 5'd8, REM);

    // LOAD has no rs2 field; the bin still fires because the imm field's
    // low bits alias the "rs2" position.  Use imm=0x008 with rd=rs1=8 so
    // the item's rs2 field also reads 8.
    emit_load(5'd8, 5'd8, 12'h008, LW);
  endtask

  // ======================================================================
  //  CHK:S-03  x0 behaviour.
  // ======================================================================
  task phase_stim_x0();
    preload_operand_pool();

    emit_addi(5'd0, 5'd0, 12'd5);
    emit_r_alu(5'd8, 5'd0, 5'd17, ADD_SUB, 0);
    emit_r_alu(5'd8, 5'd16, 5'd0, ADD_SUB, 0);
    emit_addi(5'd8, 5'd0, 12'd1);

    emit_r_muldiv(5'd0, 5'd16, 5'd17, MUL);
    emit_r_muldiv(5'd0, 5'd16, 5'd17, MULH);
    emit_r_muldiv(5'd0, 5'd16, 5'd17, DIV);
    emit_r_muldiv(5'd0, 5'd16, 5'd17, REM);
    emit_load(5'd0, 5'd1, 12'h000, LW);
    emit_jal(5'd0, 21'd8);
    emit_jalr(5'd0, 5'd1, 12'h000);
    emit_lui(5'd0, 20'hFFFFF);
    emit_i_op(3'b000, 5'd0, 5'd16, 12'h123);

        // ---------- CHK:x0_instr_cg residual ----------
    // <*,rd_rs2_x0>: rd=0, rs2=0 for R-type ops
    emit_r_alu   (5'd0, 5'd16, 5'd0,  ADD_SUB, 0);
    emit_r_muldiv(5'd0, 5'd16, 5'd0,  MUL);
    emit_r_muldiv(5'd0, 5'd16, 5'd0,  DIV);

    // <*,rs1_rs2_x0>: rd!=0, rs1=0, rs2=0
    emit_r_alu   (5'd8, 5'd0,  5'd0,  ADD_SUB, 0);
    emit_r_muldiv(5'd8, 5'd0,  5'd0,  MUL);
    emit_r_muldiv(5'd8, 5'd0,  5'd0,  DIV);

    // <load,rd_rs1_x0>  rd=0, rs1=0, imm[4:0]!=0
    emit_load(5'd0, 5'd0,  12'h004, LW);
    // <alu_r,rd_rs1_x0>  rd=0, rs1=0, rs2!=0
    emit_r_alu(5'd0, 5'd0,  5'd17,  ADD_SUB, 0);
    // <mul,rd_rs1_x0>  rd=0, rs1=0
    emit_r_muldiv(5'd0, 5'd0,  5'd17, MUL);
    // <divrem,rd_rs1_x0>  rd=0, rs1=0
    emit_r_muldiv(5'd0, 5'd0,  5'd17, DIV);

    // <load,rd_is_x0>  rd=0, rs1!=0, imm[4:0]!=0
    emit_load(5'd0, 5'd16, 12'h004, LW);
    // <alu_r,rd_is_x0>  rd=0, rs1!=0, rs2!=0
    emit_r_alu(5'd0, 5'd16, 5'd17,  ADD_SUB, 0);
  endtask

  // ======================================================================
  //  CHK:S-04 + B1  ALU immediate boundaries (full 6x5 + bit-walk).
  // ======================================================================
  task phase_stim_alu_imm_boundary();
    bit [2:0] iops [6];
    bit [11:0] imm_bit;
    preload_operand_pool();

    // ADDI overflow: 0x7FFFFFFF + 1, 0x80000000 + (-1), -1 + 1
    emit_addi(5'd8, 5'd19, 12'h001);
    emit_addi(5'd8, 5'd20, 12'hFFF);
    emit_addi(5'd8, 5'd18, 12'h001);

    // ADDI immediate extremes
    emit_addi(5'd8, 5'd0, 12'h800);
    emit_addi(5'd8, 5'd0, 12'h7FF);

    // SLTI over the pool
    emit_slti(5'd8, 5'd16, 12'h000);
    emit_slti(5'd8, 5'd17, 12'h000);
    emit_slti(5'd8, 5'd18, 12'h000);
    emit_slti(5'd8, 5'd19, 12'h000);
    emit_slti(5'd8, 5'd20, 12'h000);

    // SLTI vs SLTIU divergence on (0x80000000, imm=0)
    emit_slti (5'd8, 5'd20, 12'h000);
    emit_i_op(3'b011, 5'd9, 5'd20, 12'h000);

    // XORI imm -1 on 0 and 0xFFFFFFFF
    emit_xori(5'd8, 5'd16, 12'hFFF);
    emit_xori(5'd8, 5'd18, 12'hFFF);

    // ---------- CHK:B1  Full 6-op x 5-corner + 12-bit bit-walk ----------
    iops[0] = 3'b000;  // ADDI
    iops[1] = 3'b010;  // SLTI
    iops[2] = 3'b011;  // SLTIU
    iops[3] = 3'b100;  // XORI
    iops[4] = 3'b110;  // ORI
    iops[5] = 3'b111;  // ANDI
    for (int k = 0; k < 6; k++) begin
      emit_i_op(iops[k], 5'd8, 5'd16, 12'h800);  // most_neg
      emit_i_op(iops[k], 5'd8, 5'd16, 12'h7FF);  // most_pos
      emit_i_op(iops[k], 5'd8, 5'd16, 12'h000);  // zero
      emit_i_op(iops[k], 5'd8, 5'd16, 12'h001);  // one
      emit_i_op(iops[k], 5'd8, 5'd16, 12'hFFF);  // minus_1
      for (int b = 0; b < 12; b++) begin
        // Correct-width construction of the one-hot immediate.
        imm_bit    = 12'h0;
        imm_bit[b] = 1'b1;
        emit_i_op(iops[k], 5'd8, 5'd16, imm_bit);
      end
    end
  endtask

  // ======================================================================
  //  CHK:S-05  SLT / SLTU over all ordered pairs of the 4 extremes.
  // ======================================================================
  task phase_stim_slt_pairwise();
    bit [4:0] pool4 [4];
    preload_operand_pool();

    pool4[0] = 5'd20;
    pool4[1] = 5'd19;
    pool4[2] = 5'd18;
    pool4[3] = 5'd16;

    for (int i = 0; i < 4; i++) begin
      for (int j = 0; j < 4; j++) begin
        emit_r_alu(5'd8, pool4[i], pool4[j], SLT,  0);
        emit_r_alu(5'd9, pool4[i], pool4[j], SLTU, 0);
      end
    end
  endtask

  // ======================================================================
  //  CHK:S-07  Register-shift corners.
  // ======================================================================
  task phase_stim_reg_shifts();
    preload_operand_pool();

    emit_addi(5'd15, 5'd0, 12'd32);

    emit_r_alu(5'd8, 5'd19, 5'd15, SLL,     0);
    emit_r_alu(5'd8, 5'd19, 5'd15, SRL_SRA, 0);
    emit_r_alu(5'd8, 5'd19, 5'd15, SRL_SRA, 1);

    emit_r_alu(5'd8, 5'd19, 5'd18, SLL,     0);
    emit_r_alu(5'd8, 5'd19, 5'd18, SRL_SRA, 0);
    emit_r_alu(5'd8, 5'd19, 5'd18, SRL_SRA, 1);

    emit_r_alu(5'd8, 5'd20, 5'd15, SLL,     0);
    emit_r_alu(5'd8, 5'd20, 5'd15, SRL_SRA, 0);
    emit_r_alu(5'd8, 5'd20, 5'd15, SRL_SRA, 1);
  endtask

  // ======================================================================
  //  CHK:S-08  Forwarding distance 0 and 1.
  // ======================================================================
  task phase_stim_forwarding();
    preload_operand_pool();

    emit_addi(5'd8, 5'd0, 12'd42);
    emit_addi(5'd9, 5'd8, 12'd1);
    emit_addi(5'd10, 5'd0, 12'd0);
    emit_addi(5'd9, 5'd8, 12'd2);

    restore_mem_base();
    emit_load(5'd11, 5'd1, 12'h000, LW);
    emit_addi(5'd12, 5'd11, 12'd1);
    emit_addi(5'd13, 5'd0, 12'd0);
    emit_addi(5'd12, 5'd11, 12'd1);

    emit_r_muldiv(5'd8, 5'd16, 5'd17, MUL);
    emit_addi(5'd9, 5'd8, 12'd1);
    emit_addi(5'd10, 5'd0, 12'd0);
    emit_addi(5'd9, 5'd8, 12'd1);

    emit_r_muldiv(5'd8, 5'd16, 5'd17, DIV);
    emit_addi(5'd9, 5'd8, 12'd1);
    emit_addi(5'd10, 5'd0, 12'd0);
    emit_addi(5'd9, 5'd8, 12'd1);
  endtask

  // ======================================================================
  //  CHK:S-09 + S-11 + B4  MUL chains and patterns.
  // ======================================================================
  task phase_stim_mul_chain();
    bit [4:0] pats [4];
    preload_operand_pool();

    emit_r_muldiv(5'd8, 5'd16, 5'd17, MUL);
    emit_r_muldiv(5'd9, 5'd8, 5'd18, MUL);

    emit_r_muldiv(5'd8, 5'd16, 5'd17, MUL);
    emit_r_muldiv(5'd10, 5'd16, 5'd17, MUL);
    emit_r_muldiv(5'd9, 5'd8, 5'd18, MUL);

    emit_r_muldiv(5'd8, 5'd16, 5'd17, MUL);
    emit_r_muldiv(5'd10, 5'd16, 5'd17, MUL);
    emit_r_muldiv(5'd11, 5'd16, 5'd17, MUL);
    emit_r_muldiv(5'd9, 5'd8, 5'd18, MUL);

    emit_li32(5'd14, 32'hA5A5A5A5);
    emit_li32(5'd15, 32'h5A5A5A5A);
    emit_li32(5'd13, 32'h0F0F0F0F);
    emit_li32(5'd12, 32'hF0F0F0F0);

    emit_r_muldiv(5'd8, 5'd14, 5'd15, MUL);
    emit_r_muldiv(5'd8, 5'd13, 5'd12, MUL);
    emit_r_muldiv(5'd8, 5'd14, 5'd13, MUL);
    emit_r_muldiv(5'd8, 5'd15, 5'd12, MUL);
    emit_r_muldiv(5'd8, 5'd14, 5'd15, MULH);
    emit_r_muldiv(5'd8, 5'd13, 5'd12, MULH);
    emit_r_muldiv(5'd8, 5'd14, 5'd15, MULHU);
    emit_r_muldiv(5'd8, 5'd13, 5'd12, MULHU);
    emit_r_muldiv(5'd8, 5'd14, 5'd13, MULHSU);

    // ---------- CHK:B4  Full 4x4 pattern matrix for all 4 MUL ops ----------
    pats[0] = 5'd10;   // A5A5A5A5
    pats[1] = 5'd11;   // 5A5A5A5A
    pats[2] = 5'd12;   // 0F0F0F0F
    pats[3] = 5'd13;   // F0F0F0F0
    emit_li32(5'd10, 32'hA5A5A5A5);
    emit_li32(5'd11, 32'h5A5A5A5A);
    emit_li32(5'd12, 32'h0F0F0F0F);
    emit_li32(5'd13, 32'hF0F0F0F0);
    for (int i = 0; i < 4; i++)
      for (int j = 0; j < 4; j++) begin
        emit_r_muldiv(5'd8, pats[i], pats[j], MUL);
        emit_r_muldiv(5'd8, pats[i], pats[j], MULH);
        emit_r_muldiv(5'd8, pats[i], pats[j], MULHSU);
        emit_r_muldiv(5'd8, pats[i], pats[j], MULHU);
      end
  endtask

  // ======================================================================
  //  CHK:S-10  Per-instruction register walk.
  // ======================================================================
  task phase_stim_reg_walk();
    bit [4:0] rreg;
    for (int r = 1; r < 32; r++) begin
      rreg = r[4:0];
      emit_r_muldiv(rreg, 5'd16, 5'd17, MUL);
    end
    for (int r = 0; r < 32; r++) begin
      rreg = r[4:0];
      emit_r_muldiv(5'd8, rreg, 5'd17, REM);
      emit_r_muldiv(5'd8, 5'd16, rreg, REM);
      emit_r_muldiv(rreg, 5'd16, 5'd17, REM);
    end
  endtask

  // ======================================================================
  //  CHK:S-12  Load-use interlock.
  // ======================================================================
  task phase_stim_load_use();
    restore_mem_base();

    emit_load(5'd11, 5'd1, 12'h000, LW);
    emit_addi(5'd8, 5'd11, 12'd1);

    emit_load(5'd11, 5'd1, 12'h004, LW);
    emit_r_muldiv(5'd8, 5'd11, 5'd17, MUL);

    emit_load(5'd11, 5'd1, 12'h008, LW);
    emit_branch(5'd11, 5'd16, 13'd8, BEQ);

    emit_load(5'd11, 5'd1, 12'h00C, LW);
    emit_store(5'd11, 5'd1, 12'h010, 3'b010);

    emit_load(5'd11, 5'd1, 12'h014, LW);
    emit_r_muldiv(5'd8, 5'd11, 5'd17, DIV);
  endtask

  // ======================================================================
  //  CHK:S-13  MUL / DIV / REM result -> SW.
  // ======================================================================
  task phase_stim_mul_store();
    restore_mem_base();

    emit_r_muldiv(5'd8, 5'd16, 5'd17, MUL);
    emit_store(5'd8, 5'd1, 12'h000, 3'b010);

    emit_r_muldiv(5'd8, 5'd16, 5'd17, DIV);
    emit_store(5'd8, 5'd1, 12'h004, 3'b010);

    emit_r_muldiv(5'd8, 5'd16, 5'd17, REM);
    emit_store(5'd8, 5'd1, 12'h008, 3'b010);

    emit_r_muldiv(5'd8, 5'd16, 5'd17, MULH);
    emit_store(5'd8, 5'd1, 12'h00C, 3'b010);
  endtask

  // ======================================================================
  //  CHK:S-14 / S-27 + B8  Branch flush with multi-cycle op in flight.
  // ======================================================================
  task phase_stim_flush();
    B_ops_t br_ops [6];
    preload_operand_pool();

    br_ops[0] = BEQ;  br_ops[1] = BNE;  br_ops[2] = BLT;
    br_ops[3] = BGE;  br_ops[4] = BLTU; br_ops[5] = BGEU;

    emit_r_muldiv(5'd8, 5'd16, 5'd17, DIV);
    emit_branch(5'd16, 5'd16, 13'd8, BEQ);

    emit_r_muldiv(5'd8, 5'd16, 5'd17, REM);
    emit_branch(5'd16, 5'd16, 13'd8, BEQ);

    emit_r_muldiv(5'd8, 5'd16, 5'd17, MUL);
    emit_branch(5'd16, 5'd16, 13'd8, BEQ);

    for (int i = 0; i < 6; i++) begin
      emit_branch(5'd16, 5'd16, 13'd8,  br_ops[i]);
      emit_branch(5'd16, 5'd17, 13'd8,  br_ops[i]);
      emit_branch(5'd20, 5'd19, 13'd8,  br_ops[i]);
      emit_branch(5'd19, 5'd20, 13'd12, br_ops[i]);
      emit_branch(5'd0,  5'd16, 13'd8,  br_ops[i]);
    end

    emit_branch(5'd16, 5'd16, 13'd8, BEQ);
    emit_branch(5'd16, 5'd16, 13'd8, BEQ);

    // ---------- CHK:B8  CF pair burst at distance 1 ----------
    emit_li32(5'd1, 32'h0000_0200);
    emit_jal (5'd8, 21'd4);
    emit_jal (5'd8, 21'd4);
    emit_jal (5'd8, 21'd4);
    emit_jalr(5'd8, 5'd1, 12'h000);
    emit_jalr(5'd8, 5'd1, 12'h000);
    emit_jal (5'd8, 21'd4);
    emit_branch(5'd16, 5'd16, 13'd4, BEQ);
    emit_jal (5'd8, 21'd4);
    emit_branch(5'd16, 5'd16, 13'd4, BEQ);
    emit_jalr(5'd8, 5'd1, 12'h000);
    emit_branch(5'd16, 5'd16, 13'd4, BEQ);
    emit_jal (5'd8, 21'd4);
    emit_branch(5'd16, 5'd16, 13'd4, BEQ);
    emit_jalr(5'd8, 5'd1, 12'h000);
  endtask

  // ======================================================================
  //  CHK:S-15  Divider hazards matrix.
  // ======================================================================
  task phase_stim_div_hazards();
    mul_div_ops_t producers [3];
    preload_operand_pool();
    restore_mem_base();

    producers[0] = DIV;
    producers[1] = DIVU;
    producers[2] = REM;

    for (int p = 0; p < 3; p++) begin
      emit_r_muldiv(5'd8, 5'd16, 5'd17, producers[p]);
      emit_addi(5'd9, 5'd8, 12'd1);

      emit_r_muldiv(5'd8, 5'd16, 5'd17, producers[p]);
      emit_r_muldiv(5'd9, 5'd8, 5'd17, MUL);

      emit_r_muldiv(5'd8, 5'd16, 5'd17, producers[p]);
      emit_addi(5'd9, 5'd8, 12'd0);
      emit_load(5'd10, 5'd1, 12'h000, LW);

      emit_r_muldiv(5'd8, 5'd16, 5'd17, producers[p]);
      emit_store(5'd8, 5'd1, 12'h000, 3'b010);

      emit_r_muldiv(5'd8, 5'd16, 5'd17, producers[p]);
      emit_branch(5'd8, 5'd16, 13'd8, BEQ);

      emit_r_muldiv(5'd8, 5'd16, 5'd17, producers[p]);
      emit_r_muldiv(5'd9, 5'd8, 5'd17, DIV);
    end
  endtask

  // ======================================================================
  //  CHK:S-16  Write-after-write with long-latency producer.
  // ======================================================================
  task phase_stim_waw();
    preload_operand_pool();

    emit_r_muldiv(5'd10, 5'd16, 5'd17, DIV);
    emit_addi(5'd10, 5'd0, 12'd1);

    emit_r_muldiv(5'd10, 5'd16, 5'd17, REM);
    emit_lui(5'd10, 20'h12345);

    emit_r_muldiv(5'd10, 5'd16, 5'd17, MUL);
    emit_addi(5'd10, 5'd0, 12'd2);
  endtask

  // ======================================================================
  //  CHK:S-17  Store-dependency / load-after-store with multi-cycle op.
  // ======================================================================
  task phase_stim_store_load_dep();
    restore_mem_base();

    emit_r_muldiv(5'd8, 5'd16, 5'd17, MUL);
    emit_store(5'd8, 5'd1, 12'h020, 3'b010);
    emit_load(5'd9, 5'd1, 12'h020, LW);

    emit_r_muldiv(5'd8, 5'd16, 5'd17, DIV);
    emit_store(5'd8, 5'd1, 12'h024, 3'b010);
    emit_load(5'd9, 5'd1, 12'h024, LW);
  endtask

  // ======================================================================
  //  CHK:S-18  REM decode aliasing (raw words).
  // ======================================================================
  task phase_stim_rem_decode();
    preload_operand_pool();

    emit_raw({7'b0000010, 5'd17, 5'd16, 3'b110, 5'd8, 7'h33});
    emit_addi(5'd8, 5'd0, 12'd1);

    emit_raw({7'b0000011, 5'd17, 5'd16, 3'b111, 5'd8, 7'h33});
    emit_addi(5'd8, 5'd0, 12'd2);

    emit_raw({7'b0000000, 5'd17, 5'd16, 3'b110, 5'd8, 7'h33});
    emit_addi(5'd8, 5'd0, 12'd3);

    emit_raw({7'b0000000, 5'd17, 5'd16, 3'b111, 5'd8, 7'h33});
    emit_addi(5'd8, 5'd0, 12'd4);
  endtask

  // ======================================================================
  //  CHK:S-19 / S-20 / S-21 + B3  DIV/REM pattern, equal-operand,
  //                               truncation, operand-class corners.
  // ======================================================================
  task phase_stim_div_patterns();
    bit [4:0] pats [3];
    preload_operand_pool();

    emit_r_muldiv(5'd8, 5'd21, 5'd22, DIV);
    emit_r_muldiv(5'd8, 5'd22, 5'd21, DIV);
    emit_r_muldiv(5'd8, 5'd21, 5'd22, DIVU);
    emit_r_muldiv(5'd8, 5'd22, 5'd21, DIVU);
    emit_r_muldiv(5'd8, 5'd21, 5'd22, REM);
    emit_r_muldiv(5'd8, 5'd21, 5'd22, REMU);

    emit_li32(5'd12, 32'hDEADBEEF);
    emit_li32(5'd13, 32'hDEADBEEF);
    emit_r_muldiv(5'd8, 5'd12, 5'd13, DIV);
    emit_r_muldiv(5'd8, 5'd12, 5'd13, DIVU);
    emit_r_muldiv(5'd8, 5'd12, 5'd13, REM);
    emit_r_muldiv(5'd8, 5'd12, 5'd13, REMU);

    emit_li32(5'd12, 32'hFFFFFFFA);
    emit_li32(5'd13, 32'h0000000A);
    emit_r_muldiv(5'd8, 5'd12, 5'd13, DIV);
    emit_li32(5'd12, 32'h00000006);
    emit_r_muldiv(5'd8, 5'd12, 5'd13, DIVU);
    emit_li32(5'd12, 32'hFFFFFFFA);
    emit_r_muldiv(5'd8, 5'd12, 5'd13, REM);

    emit_li32(5'd12, 32'd7);
    emit_li32(5'd13, 32'd2);
    emit_li32(5'd14, 32'hFFFFFFFE);
    emit_r_muldiv(5'd8, 5'd12, 5'd13, DIV);
    emit_r_muldiv(5'd8, 5'd12, 5'd14, DIV);

    emit_li32(5'd12, 32'hFFFFFFF9);
    emit_r_muldiv(5'd8, 5'd12, 5'd14, REM);
    emit_r_muldiv(5'd8, 5'd12, 5'd13, REM);

    emit_li32(5'd12, 32'h00000007);
    emit_li32(5'd13, 32'hFFFFFFFE);
    emit_r_muldiv(5'd8, 5'd12, 5'd13, MULH);
    emit_r_muldiv(5'd8, 5'd12, 5'd13, MULHSU);

    // ---------- CHK:B3  Full 3x3 pattern matrix for all four ops ----------
    pats[0] = 5'd21;   // 0x5555_5555
    pats[1] = 5'd22;   // 0xAAAA_AAAA
    pats[2] = 5'd18;   // 0xFFFF_FFFF
    for (int i = 0; i < 3; i++)
      for (int j = 0; j < 3; j++) begin
        emit_r_muldiv(5'd8, pats[i], pats[j], DIV);
        emit_r_muldiv(5'd8, pats[i], pats[j], DIVU);
        emit_r_muldiv(5'd8, pats[i], pats[j], REM);
        emit_r_muldiv(5'd8, pats[i], pats[j], REMU);
      end
  endtask

  // ======================================================================
  //  CHK:S-22 + S-24 + B2  Loads/stores with real data.
  // ======================================================================
  task phase_stim_load_store_real();
    restore_mem_base();

    emit_li32(5'd12, 32'h00000080);
    emit_store(5'd12, 5'd1, 12'h040, 3'b000);
    emit_load(5'd8, 5'd1, 12'h040, LB);
    emit_load(5'd9, 5'd1, 12'h040, LBU);

    emit_li32(5'd12, 32'h0000007F);
    emit_store(5'd12, 5'd1, 12'h044, 3'b000);
    emit_load(5'd8, 5'd1, 12'h044, LB);
    emit_load(5'd9, 5'd1, 12'h044, LBU);

    emit_li32(5'd12, 32'h00008000);
    emit_store(5'd12, 5'd1, 12'h048, 3'b001);
    emit_load(5'd8, 5'd1, 12'h048, LH);
    emit_load(5'd9, 5'd1, 12'h048, LHU);

    emit_li32(5'd12, 32'h00007FFF);
    emit_store(5'd12, 5'd1, 12'h04C, 3'b001);
    emit_load(5'd8, 5'd1, 12'h04C, LH);
    emit_load(5'd9, 5'd1, 12'h04C, LHU);

    emit_li32(5'd12, 32'hDEADBEEF);
    emit_store(5'd12, 5'd1, 12'h050, 3'b000);
    emit_load(5'd8, 5'd1, 12'h050, LBU);

    emit_li32(5'd13, 32'h12345678);
    emit_store(5'd13, 5'd1, 12'h054, 3'b001);
    emit_load(5'd8, 5'd1, 12'h054, LHU);

    emit_store(5'd13, 5'd1, 12'h058, 3'b010);
    emit_load(5'd8, 5'd1, 12'h058, LW);

    emit_li32(5'd12, 32'h00000000);
    emit_store(5'd12, 5'd1, 12'h05C, 3'b010);
    emit_load(5'd8, 5'd1, 12'h05C, LW);

    emit_li32(5'd12, 32'hFFFFFFFF);
    emit_store(5'd12, 5'd1, 12'h060, 3'b010);
    emit_load(5'd8, 5'd1, 12'h060, LW);

    emit_li32(5'd12, 32'h80000000);
    emit_store(5'd12, 5'd1, 12'h064, 3'b010);
    emit_load(5'd8, 5'd1, 12'h064, LW);

    // ---------- CHK:B2  Byte/halfword loads and stores, negative offsets ----------
    emit_load(5'd8, 5'd1, 12'h800, LB);
    emit_load(5'd8, 5'd1, 12'hFFC, LB);
    emit_load(5'd8, 5'd1, 12'h800, LH);
    emit_load(5'd8, 5'd1, 12'hFFC, LH);
    emit_load(5'd8, 5'd1, 12'h800, LBU);
    emit_load(5'd8, 5'd1, 12'hFFC, LBU);
    emit_load(5'd8, 5'd1, 12'h800, LHU);
    emit_load(5'd8, 5'd1, 12'hFFC, LHU);

    emit_store(5'd16, 5'd1, 12'h800, 3'b000);
    emit_store(5'd16, 5'd1, 12'hFFC, 3'b000);
    emit_store(5'd16, 5'd1, 12'h800, 3'b001);
    emit_store(5'd16, 5'd1, 12'hFFC, 3'b001);

    // Close load_cg residual bins.
    emit_load(5'd8, 5'd1, 12'h000, LHU);   // <lhu,zero>
    emit_load(5'd8, 5'd1, 12'h000, LB);
    emit_load(5'd8, 5'd1, 12'h000, LH);
    emit_load(5'd8, 5'd1, 12'h000, LW);
    emit_load(5'd8, 5'd1, 12'h000, LBU);

    // store_cg -- <sw,min_neg>
    emit_store(5'd16, 5'd1, 12'h800, 3'b010);   // SW with imm = -2048

    // lui_auipc_cg -- <auipc,max,rd_x1>
    emit_auipc(5'd1, 20'hFFFFF);   // AUIPC imm = 0xFFFFF, rd = x1



  endtask

  // ======================================================================
  //  CHK:S-23  Load effective-address tag check.
  // ======================================================================
  task phase_stim_load_addr_tags();
    emit_li32(5'd1, 32'h1000_0000);

    emit_load(5'd8, 5'd1, 12'h000, LW);
    emit_load(5'd9, 5'd1, 12'h004, LW);
    emit_load(5'd10, 5'd1, 12'h008, LW);
    emit_load(5'd11, 5'd1, 12'h010, LW);
    emit_load(5'd12, 5'd1, 12'h100, LW);
    emit_load(5'd13, 5'd1, 12'h3FC, LW);

    restore_mem_base();
  endtask

  // ======================================================================
  //  CHK:S-25  Load/store address variety.
  // ======================================================================
  task phase_stim_addr_variety();
    restore_mem_base();

    emit_load(5'd8, 5'd1, 12'hFFC, LW);
    emit_store(5'd16, 5'd1, 12'hFFC, 3'b010);

    emit_load(5'd8, 5'd16, 12'h000, LW);
    emit_store(5'd16, 5'd20, 12'h008, 3'b010);

    emit_load(5'd8, 5'd1, 12'h7FF, LW);
    emit_load(5'd8, 5'd1, 12'h800, LW);

    emit_load(5'd1, 5'd1, 12'h004, LW);
    emit_store(5'd1, 5'd1, 12'h008, 3'b010);

    emit_li32(5'd15, 32'hFFFFFFFC);
    emit_load(5'd8, 5'd15, 12'h004, LW);

    emit_li32(5'd15, 32'h00000000);
    emit_load(5'd8, 5'd15, 12'hFFC, LW);
  endtask

  // ======================================================================
  //  CHK:S-26 + B6  LUI / AUIPC / JAL / JALR corner stimulus.
  // ======================================================================
  task phase_stim_upper_imm();
    preload_operand_pool();

    emit_lui(5'd8, 20'h00000);
    emit_lui(5'd8, 20'hFFFFF);
    emit_lui(5'd0, 20'hFFFFF);

    emit_auipc(5'd8,  20'h00000);
    emit_auipc(5'd8,  20'h00001);
    emit_auipc(5'd8,  20'hFFFFF);
    emit_auipc(5'd0,  20'h00001);

    emit_jal(5'd8, 21'h1FFFFC);
    emit_jal(5'd8, 21'h000FFC);
    emit_jal(5'd8, 21'h100000);
    emit_jal(5'd0, 21'h000008);

    emit_li32(5'd15, 32'h0000_1000);
    emit_jalr(5'd8, 5'd15, 12'h001);
    emit_li32(5'd15, 32'h0000_1001);
    emit_jalr(5'd8, 5'd15, 12'h000);
    emit_li32(5'd15, 32'h0000_1005);
    emit_jalr(5'd8, 5'd15, 12'h000);
    emit_li32(5'd15, 32'h0000_1000);
    emit_jalr(5'd8, 5'd15, 12'h005);

    // ---------- CHK:B6  LUI / AUIPC corner combinations ----------
    emit_lui  (5'd1, 20'hFFFFF);   // max, rd_x1
    emit_lui  (5'd0, 20'h00000);   // zero, rd_x0
    emit_lui  (5'd0, 20'h00001);   // one, rd_x0
    emit_auipc(5'd0, 20'hFFFFF);   // max, rd_x0
    emit_auipc(5'd1, 20'h00001);   // one, rd_x1
    emit_auipc(5'd0, 20'h00000);   // zero, rd_x0
  endtask

  // ======================================================================
  //  CHK:S-29  R-type ALU directed corners (extra).
  // ======================================================================
  task phase_stim_rtype_alu();
    preload_operand_pool();

    emit_r_alu(5'd8, 5'd20, 5'd17, ADD_SUB, 1);
    emit_r_alu(5'd8, 5'd19, 5'd18, ADD_SUB, 1);

    emit_r_alu(5'd8, 5'd20, 5'd19, SLT,  0);
    emit_r_alu(5'd9, 5'd20, 5'd19, SLTU, 0);
    emit_r_alu(5'd8, 5'd18, 5'd19, SLT,  0);
    emit_r_alu(5'd9, 5'd18, 5'd19, SLTU, 0);

    emit_r_alu(5'd8, 5'd19, 5'd24, SLL,     0);
    emit_r_alu(5'd8, 5'd19, 5'd24, SRL_SRA, 0);
    emit_r_alu(5'd8, 5'd19, 5'd24, SRL_SRA, 1);

    emit_r_alu(5'd8, 5'd21, 5'd22, AND, 0);
    emit_r_alu(5'd8, 5'd21, 5'd22, OR,  0);
    emit_r_alu(5'd8, 5'd21, 5'd22, XOR, 0);
  endtask

  // ======================================================================
  //  CHK:I-09  Mixed-opcode back-to-back stream.
  // ======================================================================
  task phase_mixed_stream(int unsigned min_len, int unsigned max_len,
                          bit [5:0] mask);
    int unsigned pick;
    bit [2:0]    s_f3;

    if (min_len == 0) min_len = 1;
    if (max_len < min_len) max_len = min_len;

    for (int i = 0; i < int'(max_len); i++) begin
      if (i >= int'(min_len)) begin
        if ($urandom_range(0, 1) == 0) break;
      end

      pick = $urandom_range(0, 5);
      while (!mask[pick]) pick = $urandom_range(0, 5);

      case (pick)
        0: emit_i_op(3'b000, 5'd8, 5'd16, 12'($urandom_range(0, 4095)));
        1: emit_r_alu(5'd8, 5'd16, 5'd17, ADD_SUB, $urandom_range(0, 1));
        2: emit_r_muldiv(5'd8, 5'd16, 5'd17,
                         mul_div_ops_t'($urandom_range(0, 7)));
        3: emit_load(5'd8, 5'd1, 12'($urandom_range(0, 32)),
                     Load_ops_t'($urandom_range(0, 5)));
        4: begin
             s_f3 = 3'($urandom_range(0, 2));
             emit_store(5'd8, 5'd1, 12'($urandom_range(0, 32)), s_f3);
           end
        5: emit_branch(5'd16, 5'd17, 13'd8,
                       B_ops_t'($urandom_range(0, 1)));
      endcase
    end
  endtask

    // ======================================================================
  //  CHK:raw_hazard_cg full sweep.
  //  For each x1..x30, write-then-read at 4 filler distances to cover
  //  same_cycle, one_cycle, short_delay, long_delay.
  //  Clobbers x1..x30.
  // ======================================================================
  task phase_hazard_full_sweep();
    bit [4:0]    rreg;
    int unsigned dists [4];
    // Same-cycle (3-instruction gap), 1-cycle (4-instruction gap),
    // short-delay (6), long-delay (12).
    dists[0] = 1;
    dists[1] = 2;
    dists[2] = 4;
    dists[3] = 12;

    for (int r = 1; r < 31; r++) begin
      rreg = r[4:0];
      for (int d = 0; d < 4; d++) begin
        emit_addi(rreg, 5'd0, 12'h0AB);
        repeat (dists[d]) emit_addi(5'd14, 5'd0, 12'h0CD);
        emit_r_alu(5'd15, 5'd0, rreg, ADD_SUB, 0);
      end
    end
  endtask

    // ======================================================================
  //  CHK:hazard_matrix_cg residual fill.
  // ======================================================================
  task phase_hazard_matrix_fill();
    bit [4:0] producer_class [4];
    bit       consumer_kind  [8];
    restore_mem_base();

    // ---- alu_r producer -> various consumers, at distances 0..1 ----
    emit_r_alu(5'd8, 5'd16, 5'd17, ADD_SUB, 0);
    emit_branch(5'd8, 5'd16, 13'd8, BEQ);                // <alu_r,branch,d0>

    emit_r_alu(5'd8, 5'd16, 5'd17, XOR, 0);
    emit_store(5'd8, 5'd1, 12'h000, 3'b010);             // <alu_r,store,d0>

    emit_r_alu(5'd8, 5'd1,  5'd17, ADD_SUB, 0);          // any value as addr
    emit_load(5'd9, 5'd8,  12'h000, LW);                 // <alu_r,load,d0>

    emit_r_alu(5'd8, 5'd16, 5'd17, OR, 0);
    emit_addi(5'd13, 5'd0, 12'h001);                     // filler
    emit_branch(5'd8, 5'd16, 13'd8, BEQ);                // <alu_r,branch,d1>

    // ---- alu_imm producer -> branch ----
    emit_addi(5'd8, 5'd0, 12'h010);
    emit_branch(5'd8, 5'd16, 13'd8, BEQ);                // <alu_imm,branch,d0>

    // ---- load producer -> alu_r ----
    emit_load(5'd8, 5'd1, 12'h000, LW);
    emit_r_alu(5'd9, 5'd8, 5'd16, ADD_SUB, 0);           // <load,alu_r,d0>

    // ---- divrem -> alu_r ----
    emit_r_muldiv(5'd8, 5'd16, 5'd17, DIV);
    emit_r_alu(5'd9, 5'd8, 5'd16, ADD_SUB, 0);           // <divrem,alu_r,d0>

    // ---- mul -> alu_r, mul -> branch ----
    emit_r_muldiv(5'd8, 5'd16, 5'd17, MUL);
    emit_r_alu(5'd9, 5'd8, 5'd16, ADD_SUB, 0);           // <mul,alu_r,d0>

    emit_r_muldiv(5'd8, 5'd16, 5'd17, MUL);
    emit_branch(5'd8, 5'd16, 13'd8, BEQ);                // <mul,branch,d0>

    // ---- <*,branch,d1> and <*,store,d1> for several producer classes ----
    // alu_imm producer -> branch at d1
    emit_addi(5'd8, 5'd0, 12'h010);
    emit_addi(5'd13, 5'd0, 12'h001);
    emit_branch(5'd8, 5'd16, 13'd8, BEQ);

    // load producer -> branch at d1
    emit_load(5'd8, 5'd1, 12'h000, LW);
    emit_addi(5'd13, 5'd0, 12'h001);
    emit_branch(5'd8, 5'd16, 13'd8, BEQ);

    // alu_imm producer -> store at d1
    emit_addi(5'd8, 5'd0, 12'h010);
    emit_addi(5'd13, 5'd0, 12'h001);
    emit_store(5'd8, 5'd1, 12'h000, 3'b010);

    // ---- <*,*,d2> matrix cells for the multi-cycle producers ----
    // divrem -> alu_r at d2
    emit_r_muldiv(5'd8, 5'd16, 5'd17, DIV);
    emit_addi(5'd13, 5'd0, 12'h001);
    emit_addi(5'd14, 5'd0, 12'h001);
    emit_r_alu(5'd9, 5'd8, 5'd16, ADD_SUB, 0);

    // mul -> divrem at d2
    emit_r_muldiv(5'd8, 5'd16, 5'd17, MUL);
    emit_addi(5'd13, 5'd0, 12'h001);
    emit_addi(5'd14, 5'd0, 12'h001);
    emit_r_muldiv(5'd9, 5'd8, 5'd17, DIV);

    // alu_r -> mul at d2
    emit_r_alu(5'd8, 5'd16, 5'd17, ADD_SUB, 0);
    emit_addi(5'd13, 5'd0, 12'h001);
    emit_addi(5'd14, 5'd0, 12'h001);
    emit_r_muldiv(5'd9, 5'd8, 5'd17, MUL);

    // alu_r -> divrem at d2
    emit_r_alu(5'd8, 5'd16, 5'd17, ADD_SUB, 0);
    emit_addi(5'd13, 5'd0, 12'h001);
    emit_addi(5'd14, 5'd0, 12'h001);
    emit_r_muldiv(5'd9, 5'd8, 5'd17, DIV);

    // alu_r -> alu_r at d2
    emit_r_alu(5'd8, 5'd16, 5'd17, ADD_SUB, 0);
    emit_addi(5'd13, 5'd0, 12'h001);
    emit_addi(5'd14, 5'd0, 12'h001);
    emit_r_alu(5'd9, 5'd8, 5'd16, AND, 0);

    // ---- long-distance (d3p) cells for multi-cycle producers ----
    // divrem -> load at d3p
    emit_r_muldiv(5'd8, 5'd16, 5'd17, DIV);
    repeat (10) emit_addi(5'd13, 5'd0, 12'h001);
    emit_load(5'd9, 5'd8, 12'h000, LW);

    // mul -> divrem at d3p
    emit_r_muldiv(5'd8, 5'd16, 5'd17, MUL);
    repeat (10) emit_addi(5'd13, 5'd0, 12'h001);
    emit_r_muldiv(5'd9, 5'd8, 5'd17, REM);

    // load -> mul at d3p
    emit_load(5'd8, 5'd1, 12'h000, LW);
    repeat (10) emit_addi(5'd13, 5'd0, 12'h001);
    emit_r_muldiv(5'd9, 5'd8, 5'd17, MUL);
  endtask


  // ======================================================================
  //  body()
  // ======================================================================
  task body();
    int n_tests;
    n_tests = (TESTS > 0) ? TESTS : 10;

    // == Phase 0: Initial System Reset for 5 cycles ======================
    `uvm_info(get_name(), "Asserting System Reset (rst_n = 0)...", UVM_LOW);
    repeat (5) drive_reset();
    `uvm_info(get_name(), "Releasing System Reset (rst_n = 1)...", UVM_LOW);

    // == Phase 0.5: Preload operand pool x16..x31 ========================
    `uvm_info(get_name(), "Phase 0.5: Preloading operand pool x16..x31...", UVM_LOW);
    preload_operand_pool();
    `uvm_info(get_name(), "Phase 0.5: Operand pool loaded.", UVM_LOW);

    // == Phase 1: R-type ALU arithmetic/logic instructions ==============
    `uvm_info(get_name(), $sformatf("Phase 1: R-type ALU (%0d instructions)...", n_tests), UVM_LOW);
    repeat (n_tests) begin
      instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
      instr_item.relax_rd_rs = this.relax_rd_rs;
      start_item(instr_item);
      if (!instr_item.randomize() with {
            rst_n == 1;
            opcode == OP_R;
            ALU_MUL_sel == ALU;
          })
        `uvm_fatal(get_name(), "Phase 1: Randomization failed for R-type ALU");
      finish_item(instr_item);
    end

    // == Phase 2: R-type MUL/DIV instructions ===========================
    `uvm_info(get_name(), $sformatf("Phase 2: R-type MUL/DIV (%0d instructions)...", n_tests),
              UVM_LOW);
    repeat (n_tests) begin
      instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
      instr_item.relax_rd_rs = this.relax_rd_rs;
      start_item(instr_item);
      if (!instr_item.randomize() with {
            rst_n == 1;
            opcode == OP_R;
            ALU_MUL_sel == MUL_DIV;
          })
        `uvm_fatal(get_name(), "Phase 2: Randomization failed for R-type MUL/DIV");
      finish_item(instr_item);
    end

    // == Phase 3: I-type Immediate arithmetic/logic instructions ========
    `uvm_info(get_name(), $sformatf("Phase 3: I-type arithmetic (%0d instructions)...", n_tests),
              UVM_LOW);
    repeat (n_tests) begin
      instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
      instr_item.relax_rd_rs = this.relax_rd_rs;
      start_item(instr_item);
      if (!instr_item.randomize() with {
            rst_n == 1;
            opcode == OP_IMM;
          })
        `uvm_fatal(get_name(), "Phase 3: Randomization failed for I-type");
      finish_item(instr_item);
    end

    // == Phase 4: Pre-load x1 = 0x1000 and x2 = 0x123 ====================
    `uvm_info(get_name(), "Phase 4: Pre-loading x1 = 0x1000 for memory accesses...", UVM_LOW);
    instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
    instr_item.relax_rd_rs = this.relax_rd_rs;
    start_item(instr_item);
    if (!instr_item.randomize() with {
          rst_n == 1;
          opcode == OP_LUI;
          rd == 5'd1;
          u_imm20 == 20'h00001;
        })
      `uvm_fatal(get_name(), "Phase 4: Randomization failed for LUI base address");
    finish_item(instr_item);

    instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
    instr_item.relax_rd_rs = this.relax_rd_rs;
    start_item(instr_item);
    if (!instr_item.randomize() with {
          rst_n == 1;
          opcode == OP_IMM;
          I_ops == ADDI;
          rd == 5'd2;
          rs1 == 5'd0;
          i_imm12 == 12'h123;
        })
      `uvm_fatal(get_name(), "Phase 4: Randomization failed for ADDI data");
    finish_item(instr_item);

    // == Phase 5: STORE instructions ====================================
    `uvm_info(get_name(), $sformatf("Phase 5: STORE instructions (%0d instructions)...", n_tests),
              UVM_LOW);
    repeat (n_tests) begin
      instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
      instr_item.relax_rd_rs = this.relax_rd_rs;
      start_item(instr_item);
      if (!instr_item.randomize() with {
            rst_n == 1;
            opcode == OP_STORE;
            rs1 == 5'd1;
            i_imm12 inside {0, 4, 8, 12, 16, 20, 24, 28, 32};
          })
        `uvm_fatal(get_name(), "Phase 5: Randomization failed for STORE");
      finish_item(instr_item);
    end

    // == Phase 6: LOAD instructions =====================================
    `uvm_info(get_name(), $sformatf("Phase 6: LOAD instructions (%0d instructions)...", n_tests),
              UVM_LOW);
    repeat (n_tests) begin
      instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
      instr_item.relax_rd_rs = this.relax_rd_rs;
      start_item(instr_item);
      if (!instr_item.randomize() with {
            rst_n == 1;
            opcode == OP_LOAD;
            rs1 == 5'd1;
            i_imm12 inside {0, 4, 8, 12, 16, 20, 24, 28, 32};
          })
        `uvm_fatal(get_name(), "Phase 6: Randomization failed for LOAD");
      finish_item(instr_item);
    end

    // == Phase 7: BRANCH instructions (random) ==========================
    `uvm_info(get_name(), $sformatf("Phase 7: BRANCH instructions (%0d instructions)...", n_tests), UVM_LOW);
    repeat(n_tests) begin
      instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
      instr_item.relax_rd_rs = this.relax_rd_rs;
      start_item(instr_item);
      if (!instr_item.randomize() with {
          rst_n == 1;
          opcode == OP_BRANCH;
          b_imm13 inside {4, 8, 12, 16};
      })
          `uvm_fatal(get_name(), "Phase 7: Randomization failed for BRANCH");
      finish_item(instr_item);
    end

    // == Phase 8: JAL instructions (random) =============================
    `uvm_info(get_name(), $sformatf("Phase 8: JAL instructions (%0d instructions)...", n_tests), UVM_LOW);
    repeat(n_tests) begin
      instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
      instr_item.relax_rd_rs = this.relax_rd_rs;
      start_item(instr_item);
      if (!instr_item.randomize() with {
          rst_n == 1;
          opcode == OP_JAL;
          jal_imm21 inside {4, 8, 12, 16};
      })
          `uvm_fatal(get_name(), "Phase 8: Randomization failed for JAL");
      finish_item(instr_item);
    end

    // == Phase 9: JALR instructions (using x1 = AUIPC 0) ================
    `uvm_info(get_name(), "Phase 9: Pre-loading PC via AUIPC for JALR...", UVM_LOW);
    instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
    instr_item.relax_rd_rs = this.relax_rd_rs;
    start_item(instr_item);
    if (!instr_item.randomize() with {
        rst_n == 1;
        opcode == OP_AUIPC;
        rd == 5'd1;
        u_imm20 == 20'd0;
    })
        `uvm_fatal(get_name(), "Phase 9: Randomization failed for AUIPC");
    finish_item(instr_item);

    `uvm_info(get_name(), $sformatf("Phase 9: JALR instructions (%0d instructions)...", n_tests), UVM_LOW);
    repeat(n_tests) begin
      instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
      instr_item.relax_rd_rs = this.relax_rd_rs;
      start_item(instr_item);
      if (!instr_item.randomize() with {
          rst_n == 1;
          opcode == OP_JALR;
          rs1 == 5'd1;
          i_imm12 inside {4, 8, 12, 16};
      })
          `uvm_fatal(get_name(), "Phase 9: Randomization failed for JALR");
      finish_item(instr_item);
    end

    // == Phase 10: Directed ALU corner cases ============================
    `uvm_info(get_name(), "Phase 10: Directed ALU corners...", UVM_LOW);
    phase_alu_directed();

    // == Phase 11: Directed control-flow variety ========================
    `uvm_info(get_name(), "Phase 11: Directed control-flow variety...", UVM_LOW);
    phase_ctrl_flow_directed();

    // == Phase 12: Directed DIV/REM boundary matrix =====================
    `uvm_info(get_name(), "Phase 12: Directed DIV/REM boundary matrix...", UVM_LOW);
    phase_divrem_directed();

    // == Phase 13: Directed MUL corners and MULH+MUL pair ===============
    `uvm_info(get_name(), "Phase 13: Directed MUL corners and pair...", UVM_LOW);
    phase_mul_directed();

    // == Phase 14: Directed regfile / RAW-hazard coverage closure =======
    `uvm_info(get_name(), "Phase 14: Directed regfile / RAW-hazard closure...", UVM_LOW);
    phase_regfile_hazard_directed();

    // == Batch 3 (CHK:S-01..S-29) — gated by run_stim_batch3 ============
    if (run_stim_batch3) begin
      `uvm_info(get_name(), "Batch 3 stim phases starting...", UVM_LOW);
      phase_stim_illegal();
      phase_stim_same_reg();
      phase_stim_x0();
      phase_stim_alu_imm_boundary();
      phase_stim_slt_pairwise();
      phase_stim_reg_shifts();
      phase_stim_forwarding();
      phase_stim_mul_chain();
      phase_stim_load_use();
      phase_stim_mul_store();
      phase_stim_div_hazards();
      phase_stim_waw();
      phase_stim_store_load_dep();
      phase_stim_rem_decode();
      phase_stim_div_patterns();
      phase_stim_load_store_real();
      phase_stim_load_addr_tags();
      phase_stim_addr_variety();
      phase_stim_upper_imm();
      phase_stim_rtype_alu();
      phase_stim_flush();
      phase_stim_reg_walk();
      phase_hazard_full_sweep();
      phase_hazard_matrix_fill();
      phase_mixed_stream(3, 5, 6'b11_1111);
      `uvm_info(get_name(), "Batch 3 stim phases complete.", UVM_LOW);
    end

  endtask
endclass  // rv32im_instr_seq