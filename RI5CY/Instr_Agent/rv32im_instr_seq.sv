// Multi-phase instruction sequence covering all RV32IM operations
class rv32im_instr_seq extends uvm_sequence #(rv32im_instr_seq_item);
  `uvm_object_utils(rv32im_instr_seq);

  int TESTS;

  rv32im_instr_seq_item instr_item;
  rv32im_instr_seq_item reset_item;

  function new(string name = "rv32im_instr_seq");
    super.new(name);
  endfunction

  // ── Helper task to drive reset ──────────────────────────────────────────
  task drive_reset();
    reset_item = rv32im_instr_seq_item::type_id::create("reset_item");
    start_item(reset_item);
    if (!reset_item.randomize() with {rst_n == 0;})
      `uvm_fatal(get_name(), "Can't initially reset the core");
    finish_item(reset_item);
  endtask

  // ══════════════════════════════════════════════════════════════════════
  //  Primitive emitters
  // ══════════════════════════════════════════════════════════════════════

  task emit_lui(bit [4:0] arg_rd, bit [19:0] arg_imm20);
    rv32im_instr_seq_item it;
    it = rv32im_instr_seq_item::type_id::create("lui_item");
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

  task emit_addi(bit [4:0] arg_rd, bit [4:0] arg_rs1, bit [11:0] arg_imm12);
    rv32im_instr_seq_item it;
    it = rv32im_instr_seq_item::type_id::create("addi_item");
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

  // ══════════════════════════════════════════════════════════════════════
  //  Operand-pool preload
  //     x16 = 0x00000000    x23 = 0x40000000
  //     x17 = 0x00000001    x24 = 0x00000002
  //     x18 = 0xFFFFFFFF    x25 = 0xFFFFFFFE
  //     x19 = 0x7FFFFFFF    x26 = 0x00010000
  //     x20 = 0x80000000    x27 = 0x0000FFFF
  //     x21 = 0x55555555    x28 = 0x12345678
  //     x22 = 0xAAAAAAAA    x29 = 0x80000001
  //                         x30 = 0x7FFFFFFE
  //                         x31 = 0x00000010
  // ══════════════════════════════════════════════════════════════════════
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

  // ══════════════════════════════════════════════════════════════════════
  //  Directed phase: ALU corners
  // ══════════════════════════════════════════════════════════════════════
  task phase_alu_directed();
    bit [4:0] pats [6];
    bit [4:0] shamt_list [4];
    bit [4:0] src_list   [3];

    // Refresh pool in case a previous phase disturbed it
    preload_operand_pool();

    pats[0] = 5'd16;   // zero
    pats[1] = 5'd18;   // all_ones
    pats[2] = 5'd20;   // walking_1
    pats[3] = 5'd23;   // walking_1
    pats[4] = 5'd19;   // walking_0
    pats[5] = 5'd25;   // walking_0

    // ── ADD/SUB overflow and different-sign combinations ───────────────
    emit_r_alu(5'd8, 5'd19, 5'd19, ADD_SUB, 0);  // MAX + MAX = -2   (pos,pos,overflow)
    emit_r_alu(5'd8, 5'd20, 5'd20, ADD_SUB, 0);  // MIN + MIN = 0    (neg,neg,overflow)
    emit_r_alu(5'd8, 5'd18, 5'd18, ADD_SUB, 0);  // -1 + -1  = -2   (neg,neg,no_ovf)
    emit_r_alu(5'd8, 5'd25, 5'd25, ADD_SUB, 0);  // -2 + -2  = -4   (neg,neg,no_ovf)
    emit_r_alu(5'd8, 5'd20, 5'd25, ADD_SUB, 0);  // MIN + -2         (neg,neg,no_ovf)
    emit_r_alu(5'd8, 5'd19, 5'd24, ADD_SUB, 0);  // MAX + 2          (pos,pos,overflow)
    emit_r_alu(5'd8, 5'd19, 5'd20, ADD_SUB, 1);  // MAX - MIN        (pos,neg,overflow)
    emit_r_alu(5'd8, 5'd19, 5'd18, ADD_SUB, 1);  // MAX - (-1)       (pos,neg,overflow)
    emit_r_alu(5'd8, 5'd20, 5'd24, ADD_SUB, 1);  // MIN - 2          (neg,pos,overflow)
    emit_r_alu(5'd8, 5'd20, 5'd25, ADD_SUB, 1);  // MIN - (-2)       (neg,neg,no_ovf)
    emit_r_alu(5'd8, 5'd19, 5'd24, ADD_SUB, 1);  // MAX - 2          (pos,pos,no_ovf)
    emit_r_alu(5'd8, 5'd19, 5'd20, ADD_SUB, 0);  // MAX + MIN        (pos,neg,no_ovf)
    emit_r_alu(5'd8, 5'd18, 5'd19, ADD_SUB, 1);  // -1 - MAX         (neg,pos,no_ovf)
    emit_r_alu(5'd8, 5'd25, 5'd19, ADD_SUB, 1);  // -2 - MAX         (neg,pos,no_ovf)
    emit_r_alu(5'd8, 5'd18, 5'd18, ADD_SUB, 1);  // -1 - (-1) = 0    (neg,neg,no_ovf)
    emit_r_alu(5'd8, 5'd25, 5'd18, ADD_SUB, 1);  // -2 - (-1) = -1   (neg,neg,no_ovf)
    emit_r_alu(5'd8, 5'd24, 5'd19, ADD_SUB, 1);  // 2 - MAX          (pos,pos,no_ovf)
    emit_r_alu(5'd8, 5'd24, 5'd25, ADD_SUB, 1);  // 2 - (-2) = 4     (pos,neg,no_ovf)

    // ── Bitwise full pattern matrix (4 distinct classes per operand) ───
    for (int i = 0; i < 6; i++) begin
      for (int j = 0; j < 6; j++) begin
        emit_r_alu(5'd8, pats[i], pats[j], AND, 0);
        emit_r_alu(5'd8, pats[i], pats[j], OR,  0);
        emit_r_alu(5'd8, pats[i], pats[j], XOR, 0);
      end
    end

    // ── Shifts with shamt = 0, 1, 15, 31 ───────────────────────────────
    shamt_list[0] = 5'd0;
    shamt_list[1] = 5'd1;
    shamt_list[2] = 5'd15;
    shamt_list[3] = 5'd31;
    src_list[0]   = 5'd19;   // MAX  (MSB=0)
    src_list[1]   = 5'd20;   // MIN  (MSB=1)
    src_list[2]   = 5'd18;   // -1   (MSB=1)
    for (int i = 0; i < 4; i++) begin
      for (int j = 0; j < 3; j++) begin
        emit_shift_imm(5'd8, src_list[j], shamt_list[i], SLLI,     1'b0);
        emit_shift_imm(5'd8, src_list[j], shamt_list[i], SRLI_SRAI, 1'b0);
        emit_shift_imm(5'd8, src_list[j], shamt_list[i], SRLI_SRAI, 1'b1);
      end
    end

    // ── SLTIU x?, rs1, 1 (seqz idiom) ──────────────────────────────────
    emit_sltiu_1(5'd8,  5'd16);   // rs1 = 0
    emit_sltiu_1(5'd8,  5'd0);    // rs1 = x0
    emit_sltiu_1(5'd8,  5'd19);   // rs1 = MAX
    emit_sltiu_1(5'd8,  5'd20);   // rs1 = MIN
  endtask

  // ══════════════════════════════════════════════════════════════════════
  //  Directed phase: control flow
  //
  //  RV32IM only: every taken branch/jump must land on a 4-byte-aligned
  //  address, otherwise the core enters the compressed-instruction path.
  //  All immediate values below are therefore multiples of 4 (in the
  //  13-bit B or 21-bit J encoding).
  // ══════════════════════════════════════════════════════════════════════
  task phase_ctrl_flow_directed();
    B_ops_t br_ops [6];

    // Refresh pool in case a previous phase disturbed it
    preload_operand_pool();

    br_ops[0] = BEQ;  br_ops[1] = BNE;  br_ops[2] = BLT;
    br_ops[3] = BGE;  br_ops[4] = BLTU; br_ops[5] = BGEU;

    // ── Branch directed per op ─────────────────────────────────────────
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
      emit_branch(5'd19, 5'd24, 13'h1FFC, br_ops[i]);   // -4
      emit_branch(5'd19, 5'd24, 13'h1FFC, br_ops[i]);   // -4
      emit_branch(5'd24, 5'd19, 13'h1004, br_ops[i]);   // -4092
      emit_branch(5'd19, 5'd24, 13'd8,  br_ops[i]);
      emit_branch(5'd19, 5'd24, 13'd12, br_ops[i]);
    end

    // ── Edge-offset branches ───────────────────────────────────────────
    // BEQ with x0 != x24 is never taken, so the huge offsets below do
    // NOT cause far jumps — they only exercise the imm-encoding bins.
    emit_branch(5'd0, 5'd24, 13'h1000, BEQ);  // min_backward (0xFFFF_F000)
    emit_branch(5'd0, 5'd24, 13'h0000, BEQ);  // zero         (0x0000_0000)
    emit_branch(5'd0, 5'd24, 13'h0FFC, BEQ);  // max_forward  (0x0000_0FFC)

    // ── JAL directed: rd classes × offset classes ──────────────────────
    begin
      bit [4:0] jal_rd [4];
      bit [20:0] jal_imm [8];
      jal_rd[0] = 5'd0;   jal_rd[1] = 5'd1;
      jal_rd[2] = 5'd8;   jal_rd[3] = 5'd9;

      // All values are multiples of 4 (see comment above).
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

    // ── JALR directed: rd × rs1 × imm ──────────────────────────────────
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

  // ══════════════════════════════════════════════════════════════════════
  //  Directed phase: DIV / REM boundary matrix
  // ══════════════════════════════════════════════════════════════════════
  task phase_divrem_directed();
    bit [4:0] regs [5];

    // Refresh pool
    preload_operand_pool();

    regs[0] = 5'd16;  // 0
    regs[1] = 5'd17;  // 1
    regs[2] = 5'd18;  // -1
    regs[3] = 5'd19;  // MAX
    regs[4] = 5'd20;  // MIN

    for (int i = 0; i < 5; i++) begin
      for (int j = 0; j < 5; j++) begin
        emit_r_muldiv(5'd8, regs[i], regs[j], DIV);
        emit_r_muldiv(5'd8, regs[i], regs[j], DIVU);
        emit_r_muldiv(5'd8, regs[i], regs[j], REM);
        emit_r_muldiv(5'd8, regs[i], regs[j], REMU);
      end
    end

    // Specific extras
    emit_r_muldiv(5'd8, 5'd20, 5'd18, DIV);   // MIN / -1
    emit_r_muldiv(5'd8, 5'd20, 5'd18, REM);   // MIN % -1
    emit_r_muldiv(5'd8, 5'd19, 5'd24, DIV);   // MAX / 2
    emit_r_muldiv(5'd8, 5'd19, 5'd24, REM);   // MAX % 2
    emit_r_muldiv(5'd8, 5'd22, 5'd21, DIVU);
    emit_r_muldiv(5'd8, 5'd22, 5'd21, REMU);
    emit_r_muldiv(5'd8, 5'd16, 5'd16, REMU);
  endtask

  // ══════════════════════════════════════════════════════════════════════
  //  Directed phase: MUL corners and MULH+MUL pair
  // ══════════════════════════════════════════════════════════════════════
  task phase_mul_directed();

    // Refresh pool
    preload_operand_pool();

    // ── both_zero / rs1_zero / rs2_zero ───────────────────────────────
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

    // ── by one ─────────────────────────────────────────────────────────
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

    // ── overflow / MIN × -1 ───────────────────────────────────────────
    emit_r_muldiv(5'd8, 5'd20, 5'd18, MUL);    // MIN * -1
    emit_r_muldiv(5'd8, 5'd19, 5'd19, MUL);    // MAX * MAX
    emit_r_muldiv(5'd8, 5'd20, 5'd20, MUL);    // MIN * MIN
    emit_r_muldiv(5'd8, 5'd23, 5'd24, MUL);    // 0x40000000 * 2

    // ── MULHU pos × neg and hi_zero ───────────────────────────────────
    emit_r_muldiv(5'd8, 5'd24, 5'd18, MULHU);
    emit_r_muldiv(5'd8, 5'd18, 5'd24, MULHU);
    emit_r_muldiv(5'd8, 5'd24, 5'd24, MULHU);
    emit_r_muldiv(5'd8, 5'd24, 5'd31, MULHU);
    emit_r_muldiv(5'd8, 5'd31, 5'd31, MULHU);
    emit_r_muldiv(5'd8, 5'd17, 5'd17, MULHU);

    // ── MULHSU with negative rs1 ───────────────────────────────────────
    emit_r_muldiv(5'd8, 5'd18, 5'd24, MULHSU);
    emit_r_muldiv(5'd8, 5'd18, 5'd20, MULHSU);

    // ── MULH pair: MULH then MUL with same operands ───────────────────
    emit_r_muldiv(5'd8, 5'd19, 5'd20, MULH);
    emit_r_muldiv(5'd8, 5'd19, 5'd20, MUL);

    emit_r_muldiv(5'd8, 5'd18, 5'd20, MULH);
    emit_r_muldiv(5'd8, 5'd18, 5'd20, MUL);

    emit_r_muldiv(5'd8, 5'd19, 5'd24, MULH);
    emit_r_muldiv(5'd8, 5'd19, 5'd24, MUL);

    // ── MULHU pair: MULHU then MUL with same operands ─────────────────
    emit_r_muldiv(5'd8, 5'd19, 5'd24, MULHU);
    emit_r_muldiv(5'd8, 5'd19, 5'd24, MUL);

    emit_r_muldiv(5'd8, 5'd18, 5'd24, MULHU);
    emit_r_muldiv(5'd8, 5'd18, 5'd24, MUL);
  endtask

  // ══════════════════════════════════════════════════════════════════════
  //  Directed phase: close remaining regfile / RAW-hazard coverage bins
  //
  //  Targets (RV32IM only, FPU=0):
  //    regfile_cg
  //      * write_b, gpr[0..7],  port_b   -- ALU write to x0..x7
  //      * write_b, gpr[0..7],  port_a   -- load write to x0..x7
  //      * write_b, gpr[16..31],port_a   -- load write to x16..x31
  //      * read_b,  gpr[2],     port_b   -- x2 as rs2
  //      * read_b,  gpr[11],    port_b   -- x11 as rs2
  //      * read_b,  gpr[7],     port_a   -- x7 as rs1 (closes <*,gpr[7],*>)
  //    raw_hazard_cg
  //      * cp_raw_addr.gpr[2..6]         -- write-then-read x2..x6
  //      * cp_raw_distance.short_delay   -- 2..5 cycle gap between write and read
  // ══════════════════════════════════════════════════════════════════════
  task phase_regfile_hazard_directed();

    // ── 1. ALU writes to x0..x7 (port_b) ──────────────────────────────
    emit_addi(5'd0, 5'd0, 12'h000);   // x0 (still 0, exercises write_b, gpr[0], port_b)
    emit_addi(5'd1, 5'd0, 12'h001);   // x1
    emit_addi(5'd2, 5'd0, 12'h002);   // x2
    emit_addi(5'd3, 5'd0, 12'h003);   // x3
    emit_addi(5'd4, 5'd0, 12'h004);   // x4
    emit_addi(5'd5, 5'd0, 12'h005);   // x5
    emit_addi(5'd6, 5'd0, 12'h006);   // x6
    emit_addi(5'd7, 5'd0, 12'h007);   // x7

    // ── 2. Load writes to x0..x7 (port_a) ─────────────────────────────
    // Base address is x0 = 0, so no scratch register is clobbered.
    // Unmapped addresses return 0 (reactive driver).
    emit_load(5'd0, 5'd0, 12'h000, LW);   // x0 (write_b, gpr[0], port_a)
    emit_load(5'd1, 5'd0, 12'h004, LW);   // x1 (write_b, gpr[1], port_a)
    emit_load(5'd2, 5'd0, 12'h008, LW);   // x2 (write_b, gpr[2], port_a)
    emit_load(5'd3, 5'd0, 12'h00C, LW);   // x3
    emit_load(5'd4, 5'd0, 12'h010, LW);   // x4
    emit_load(5'd5, 5'd0, 12'h014, LW);   // x5
    emit_load(5'd6, 5'd0, 12'h018, LW);   // x6
    emit_load(5'd7, 5'd0, 12'h01C, LW);   // x7 (write_b, gpr[7], port_a)

    // ── 3. Load writes to x16..x31 (port_a) ───────────────────────────
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

    // ── 4. Reads that close specific read_port_* bins ────────────────
    emit_r_alu(5'd8, 5'd0,  5'd7,  ADD_SUB, 0);   // read x7  on port_b (rs2)
    emit_r_alu(5'd8, 5'd0,  5'd2,  ADD_SUB, 0);   // read x2  on port_b
    emit_r_alu(5'd8, 5'd0,  5'd11, ADD_SUB, 0);   // read x11 on port_b
    emit_r_alu(5'd8, 5'd7,  5'd0,  ADD_SUB, 0);   // read x7  on port_a (rs1)

    // ── 5. RAW hazards with controlled short delays ──────────────────
    // Pattern: write register, N filler instructions, then read it as rs2.

    // Delay ~2: write, 1 filler, read
    emit_addi(5'd20, 5'd0, 12'h001);              // write x20
    emit_addi(5'd21, 5'd0, 12'h002);              // 1 filler
    emit_r_alu(5'd22, 5'd0, 5'd20, ADD_SUB, 0);   // read x20 on port_b

    // Delay ~3:
    emit_addi(5'd23, 5'd0, 12'h003);              // write x23
    emit_addi(5'd24, 5'd0, 12'h004);              // filler
    emit_addi(5'd25, 5'd0, 12'h005);              // filler
    emit_r_alu(5'd26, 5'd0, 5'd23, ADD_SUB, 0);   // read x23 on port_b

    // Delay ~4:
    emit_addi(5'd27, 5'd0, 12'h006);              // write x27
    emit_addi(5'd28, 5'd0, 12'h007);              // filler
    emit_addi(5'd29, 5'd0, 12'h008);              // filler
    emit_addi(5'd30, 5'd0, 12'h009);              // filler
    emit_r_alu(5'd31, 5'd0, 5'd27, ADD_SUB, 0);   // read x27 on port_b

    // Delay ~5 for x2 (also closes cp_raw_addr.gpr[2], short_delay)
    emit_addi(5'd2, 5'd0, 12'h00A);               // write x2
    emit_addi(5'd3, 5'd0, 12'h00B);               // filler
    emit_addi(5'd4, 5'd0, 12'h00C);               // filler
    emit_addi(5'd5, 5'd0, 12'h00D);               // filler
    emit_addi(5'd6, 5'd0, 12'h00E);               // filler
    emit_r_alu(5'd7, 5'd0, 5'd2, ADD_SUB, 0);     // read x2 on port_b

    // x3, short_delay
    emit_addi(5'd3, 5'd0, 12'h011);
    emit_addi(5'd8, 5'd0, 12'h012);
    emit_r_alu(5'd9, 5'd0, 5'd3, ADD_SUB, 0);

    // x4, short_delay
    emit_addi(5'd4, 5'd0, 12'h013);
    emit_addi(5'd8, 5'd0, 12'h014);
    emit_addi(5'd9, 5'd0, 12'h015);
    emit_r_alu(5'd10, 5'd0, 5'd4, ADD_SUB, 0);

    // x5, short_delay
    emit_addi(5'd5, 5'd0, 12'h016);
    emit_addi(5'd8, 5'd0, 12'h017);
    emit_addi(5'd9, 5'd0, 12'h018);
    emit_addi(5'd10, 5'd0, 12'h019);
    emit_r_alu(5'd11, 5'd0, 5'd5, ADD_SUB, 0);

    // x6, short_delay
    emit_addi(5'd6, 5'd0, 12'h01A);
    emit_addi(5'd8, 5'd0, 12'h01B);
    emit_addi(5'd9, 5'd0, 12'h01C);
    emit_addi(5'd10, 5'd0, 12'h01D);
    emit_addi(5'd11, 5'd0, 12'h01E);
    emit_r_alu(5'd12, 5'd0, 5'd6, ADD_SUB, 0);
  endtask


  task body();
    int n_tests;
    n_tests = (TESTS > 0) ? TESTS : 10;

    // ── Phase 0: Initial System Reset for 5 cycles ──────────────────────
    `uvm_info(get_name(), "Asserting System Reset (rst_n = 0)...", UVM_LOW);
    repeat (5) drive_reset();
    `uvm_info(get_name(), "Releasing System Reset (rst_n = 1)...", UVM_LOW);

    // ── Phase 0.5: Preload operand pool x16..x31 ────────────────────────
    `uvm_info(get_name(), "Phase 0.5: Preloading operand pool x16..x31...", UVM_LOW);
    preload_operand_pool();
    `uvm_info(get_name(), "Phase 0.5: Operand pool loaded.", UVM_LOW);

    // ── Phase 1: R-type ALU arithmetic/logic instructions ──────────────
    `uvm_info(get_name(), $sformatf("Phase 1: R-type ALU (%0d instructions)...", n_tests), UVM_LOW);
    repeat (n_tests) begin
      instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
      start_item(instr_item);
      if (!instr_item.randomize() with {
            rst_n == 1;
            opcode == OP_R;
            ALU_MUL_sel == ALU;
          })
        `uvm_fatal(get_name(), "Phase 1: Randomization failed for R-type ALU");
      finish_item(instr_item);
    end

    // ── Phase 2: R-type MUL/DIV instructions ───────────────────────────
    `uvm_info(get_name(), $sformatf("Phase 2: R-type MUL/DIV (%0d instructions)...", n_tests),
              UVM_LOW);
    repeat (n_tests) begin
      instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
      start_item(instr_item);
      if (!instr_item.randomize() with {
            rst_n == 1;
            opcode == OP_R;
            ALU_MUL_sel == MUL_DIV;
          })
        `uvm_fatal(get_name(), "Phase 2: Randomization failed for R-type MUL/DIV");
      finish_item(instr_item);
    end

    // ── Phase 3: I-type Immediate arithmetic/logic instructions ────────
    `uvm_info(get_name(), $sformatf("Phase 3: I-type arithmetic (%0d instructions)...", n_tests),
              UVM_LOW);
    repeat (n_tests) begin
      instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
      start_item(instr_item);
      if (!instr_item.randomize() with {
            rst_n == 1;
            opcode == OP_IMM;
          })
        `uvm_fatal(get_name(), "Phase 3: Randomization failed for I-type");
      finish_item(instr_item);
    end

    // ── Phase 4: Pre-load x1 = 0x1000 and x2 = 0x123 ────────────────────
    `uvm_info(get_name(), "Phase 4: Pre-loading x1 = 0x1000 for memory accesses...", UVM_LOW);
    instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
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

    // ── Phase 5: STORE instructions ────────────────────────────────────
    `uvm_info(get_name(), $sformatf("Phase 5: STORE instructions (%0d instructions)...", n_tests),
              UVM_LOW);
    repeat (n_tests) begin
      instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
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

    // ── Phase 6: LOAD instructions ─────────────────────────────────────
    `uvm_info(get_name(), $sformatf("Phase 6: LOAD instructions (%0d instructions)...", n_tests),
              UVM_LOW);
    repeat (n_tests) begin
      instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
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

    // ── Phase 7: BRANCH instructions (random) ──────────────────────────
    `uvm_info(get_name(), $sformatf("Phase 7: BRANCH instructions (%0d instructions)...", n_tests), UVM_LOW);
    repeat(n_tests) begin
      instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
      start_item(instr_item);
      if (!instr_item.randomize() with {
          rst_n == 1;
          opcode == OP_BRANCH;
          b_imm13 inside {4, 8, 12, 16};
      })
          `uvm_fatal(get_name(), "Phase 7: Randomization failed for BRANCH");
      finish_item(instr_item);
    end

    // ── Phase 8: JAL instructions (random) ─────────────────────────────
    `uvm_info(get_name(), $sformatf("Phase 8: JAL instructions (%0d instructions)...", n_tests), UVM_LOW);
    repeat(n_tests) begin
      instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
      start_item(instr_item);
      if (!instr_item.randomize() with {
          rst_n == 1;
          opcode == OP_JAL;
          jal_imm21 inside {4, 8, 12, 16};
      })
          `uvm_fatal(get_name(), "Phase 8: Randomization failed for JAL");
      finish_item(instr_item);
    end

    // ── Phase 9: JALR instructions (using x1 = AUIPC 0) ────────────────
    `uvm_info(get_name(), "Phase 9: Pre-loading PC via AUIPC for JALR...", UVM_LOW);
    instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
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

    // ── Phase 10: Directed ALU corner cases ────────────────────────────
    `uvm_info(get_name(), "Phase 10: Directed ALU corners...", UVM_LOW);
    phase_alu_directed();

    // ── Phase 11: Directed control-flow variety ────────────────────────
    `uvm_info(get_name(), "Phase 11: Directed control-flow variety...", UVM_LOW);
    phase_ctrl_flow_directed();

    // ── Phase 12: Directed DIV/REM boundary matrix ─────────────────────
    `uvm_info(get_name(), "Phase 12: Directed DIV/REM boundary matrix...", UVM_LOW);
    phase_divrem_directed();

    // ── Phase 13: Directed MUL corners and MULH+MUL pair ───────────────
    `uvm_info(get_name(), "Phase 13: Directed MUL corners and pair...", UVM_LOW);
    phase_mul_directed();

    // ── Phase 14: Directed regfile / RAW-hazard coverage closure ───────
    `uvm_info(get_name(), "Phase 14: Directed regfile / RAW-hazard closure...", UVM_LOW);
    phase_regfile_hazard_directed();

  endtask
endclass  // rv32im_instr_seq