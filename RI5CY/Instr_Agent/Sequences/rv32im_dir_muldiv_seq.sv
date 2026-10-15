// Directed DIV/REM and MUL corners, MUL/DIV hazard stimulus.
class rv32im_dir_muldiv_seq extends rv32im_instr_seq;
  `uvm_object_utils(rv32im_dir_muldiv_seq);

  function new(string name = "rv32im_dir_muldiv_seq");
    super.new(name);
  endfunction

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
  //  CHK:S-09 + S-11  MUL chains and operand patterns.
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

    // Full 4x4 pattern matrix for all four MUL ops.
    pats[0] = 5'd10;
    pats[1] = 5'd11;
    pats[2] = 5'd12;
    pats[3] = 5'd13;
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

    // DIVU / REMU with divisor 0x12345678 (LO=28) for the mid-range
    // latency class.
    emit_r_muldiv(5'd8, 5'd19, 5'd28, DIVU);
    emit_r_muldiv(5'd8, 5'd20, 5'd28, DIVU);
    emit_r_muldiv(5'd8, 5'd16, 5'd28, DIVU);
    emit_r_muldiv(5'd8, 5'd19, 5'd28, REMU);
    emit_r_muldiv(5'd8, 5'd20, 5'd28, REMU);
    emit_r_muldiv(5'd8, 5'd16, 5'd28, REMU);
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
  //  CHK:S-19 / S-20 / S-21  DIV/REM pattern, equal-operand, truncation,
  //                          operand-class corners.
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

    // Full 3x3 alternating pattern matrix for all four ops.
    pats[0] = 5'd21;
    pats[1] = 5'd22;
    pats[2] = 5'd18;
    for (int i = 0; i < 3; i++)
      for (int j = 0; j < 3; j++) begin
        emit_r_muldiv(5'd8, pats[i], pats[j], DIV);
        emit_r_muldiv(5'd8, pats[i], pats[j], DIVU);
        emit_r_muldiv(5'd8, pats[i], pats[j], REM);
        emit_r_muldiv(5'd8, pats[i], pats[j], REMU);
      end
  endtask

  virtual task body();
    `uvm_info(get_name(), "phase_divrem_directed", UVM_LOW);
    phase_divrem_directed();
    `uvm_info(get_name(), "phase_mul_directed", UVM_LOW);
    phase_mul_directed();
    if (run_stim_batch3) begin
      phase_stim_mul_chain();
      phase_stim_mul_store();
      phase_stim_div_hazards();
      phase_stim_rem_decode();
      phase_stim_div_patterns();
    end
  endtask
endclass  // rv32im_dir_muldiv_seq
