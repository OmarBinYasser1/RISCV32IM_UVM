// Directed ALU corners and ALU/immediate/shift stimulus.
class rv32im_dir_alu_seq extends rv32im_instr_seq;
  `uvm_object_utils(rv32im_dir_alu_seq);

  function new(string name = "rv32im_dir_alu_seq");
    super.new(name);
  endfunction

  // ======================================================================
  //  Directed phase: ALU corners   (CHK:S-04 partial)
  // ======================================================================
  task phase_alu_directed();
    bit [4:0] pats [6];
    bit [4:0] shamt_list [4];
    bit [4:0] src_list   [3];

    preload_operand_pool();

    pats[0] = 5'd16;
    pats[1] = 5'd18;
    pats[2] = 5'd20;
    pats[3] = 5'd23;
    pats[4] = 5'd19;
    pats[5] = 5'd25;

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
  //  CHK:S-04  ALU immediate boundaries.
  // ======================================================================
  task phase_stim_alu_imm_boundary();
    bit [2:0] iops [6];
    bit [11:0] imm_bit;
    preload_operand_pool();

    emit_addi(5'd8, 5'd19, 12'h001);
    emit_addi(5'd8, 5'd20, 12'hFFF);
    emit_addi(5'd8, 5'd18, 12'h001);

    emit_addi(5'd8, 5'd0, 12'h800);
    emit_addi(5'd8, 5'd0, 12'h7FF);

    emit_slti(5'd8, 5'd16, 12'h000);
    emit_slti(5'd8, 5'd17, 12'h000);
    emit_slti(5'd8, 5'd18, 12'h000);
    emit_slti(5'd8, 5'd19, 12'h000);
    emit_slti(5'd8, 5'd20, 12'h000);

    emit_slti (5'd8, 5'd20, 12'h000);
    emit_i_op(3'b011, 5'd9, 5'd20, 12'h000);

    emit_xori(5'd8, 5'd16, 12'hFFF);
    emit_xori(5'd8, 5'd18, 12'hFFF);

    iops[0] = 3'b000;
    iops[1] = 3'b010;
    iops[2] = 3'b011;
    iops[3] = 3'b100;
    iops[4] = 3'b110;
    iops[5] = 3'b111;
    for (int k = 0; k < 6; k++) begin
      emit_i_op(iops[k], 5'd8, 5'd16, 12'h800);
      emit_i_op(iops[k], 5'd8, 5'd16, 12'h7FF);
      emit_i_op(iops[k], 5'd8, 5'd16, 12'h000);
      emit_i_op(iops[k], 5'd8, 5'd16, 12'h001);
      emit_i_op(iops[k], 5'd8, 5'd16, 12'hFFF);
      for (int b = 0; b < 12; b++) begin
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
  //  CHK:S-29  R-type ALU directed corners.
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
  //  CHK:S-26  LUI / AUIPC / JAL / JALR corner stimulus.
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

    emit_lui  (5'd1, 20'hFFFFF);
    emit_lui  (5'd0, 20'h00000);
    emit_lui  (5'd0, 20'h00001);
    emit_auipc(5'd0, 20'hFFFFF);
    emit_auipc(5'd1, 20'h00001);
    emit_auipc(5'd0, 20'h00000);
  endtask

  virtual task body();
    `uvm_info(get_name(), "phase_alu_directed", UVM_LOW);
    phase_alu_directed();
    if (run_stim_batch3) begin
      phase_stim_alu_imm_boundary();
      phase_stim_slt_pairwise();
      phase_stim_reg_shifts();
      phase_stim_rtype_alu();
      phase_stim_upper_imm();
    end
  endtask
endclass  // rv32im_dir_alu_seq
