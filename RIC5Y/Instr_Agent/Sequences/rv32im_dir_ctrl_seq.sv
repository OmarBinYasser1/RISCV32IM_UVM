// Directed control-flow variety and flush stimulus.
class rv32im_dir_ctrl_seq extends rv32im_instr_seq;
  `uvm_object_utils(rv32im_dir_ctrl_seq);

  function new(string name = "rv32im_dir_ctrl_seq");
    super.new(name);
  endfunction

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
  //  CHK:S-14 / S-27  Branch flush with multi-cycle op in flight.
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

    // Back-to-back control-flow pair burst.
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

  virtual task body();
    `uvm_info(get_name(), "phase_ctrl_flow_directed", UVM_LOW);
    phase_ctrl_flow_directed();
    if (run_stim_batch3) begin
      phase_stim_flush();
    end
  endtask
endclass  // rv32im_dir_ctrl_seq
