// Directed regfile/RAW hazard closure and hazard sweeps.
class rv32im_dir_hazard_seq extends rv32im_instr_seq;
  `uvm_object_utils(rv32im_dir_hazard_seq);

  function new(string name = "rv32im_dir_hazard_seq");
    super.new(name);
  endfunction

  // ======================================================================
  //  Directed phase: regfile / RAW-hazard closure
  //  (CHK:V-01 producer x distance; CHK:V-02 hazard matrix)
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

    // Long-delay write-then-read on x1..x4 (raw_hazard_cg long_delay bin).
    for (int r = 1; r <= 4; r++) begin
      rreg = r[4:0];
      emit_addi(rreg, 5'd0, 12'(12'h100 + r));
      repeat (10) emit_addi(5'd12, 5'd0, 12'h000);
      emit_r_alu(5'd13, 5'd0, rreg, ADD_SUB, 0);
    end

    // R-type producer -> ALU consumers at distance 0 and 1
    // (hazard_matrix_cg alu_r producer x distance bins).
    emit_r_alu(5'd8, 5'd16, 5'd17, ADD_SUB, 0);
    emit_r_alu(5'd9, 5'd8,  5'd16, AND, 0);
    emit_r_alu(5'd8, 5'd16, 5'd17, XOR, 0);
    emit_addi (5'd10, 5'd0, 12'h001);
    emit_r_alu(5'd9, 5'd8,  5'd16, OR, 0);

    // One-cycle and short-delay coverage on x1..x30.
    for (int r = 1; r < 31; r++) begin
      rreg = r[4:0];
      emit_addi(rreg, 5'd0, 12'h007);
      emit_r_alu(5'd31, 5'd0, rreg, ADD_SUB, 0);
    end
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
  //  CHK:S-10 + V-10 + V-12  Per-instruction register walk.
  //  Clobbers x1..x31; call last in the Batch-3 block.
  // ======================================================================
  task phase_stim_reg_walk();
    bit [4:0] rreg;
    mul_div_ops_t mul_ops [4];

    mul_ops[0] = MUL;
    mul_ops[1] = MULH;
    mul_ops[2] = MULHSU;
    mul_ops[3] = MULHU;

    for (int op = 0; op < 4; op++) begin
      for (int r = 0; r < 32; r++) begin
        rreg = r[4:0];
        emit_r_muldiv(rreg, 5'd16, 5'd17, mul_ops[op]);
      end
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
  //  CHK:V-01  Full register x distance sweep for the raw-hazard covergroup.
  //  For each x1..x30, write-then-read at four filler distances to fill
  //  same_cycle, one_cycle, short_delay and long_delay.
  //  Clobbers x1..x30; call last in the hazard block.
  // ======================================================================
  task phase_hazard_full_sweep();
    bit [4:0]    rreg;
    int unsigned dists [4];

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
  //  CHK:V-01 + V-02  Systematic producer x consumer x distance sweep.
  //
  //  Fires every reachable hazard-matrix combination:
  //    producers: alu_imm, alu_r, mul, divrem, load
  //    consumers: alu_imm, alu_r, mul, divrem, load, store, branch
  //    distances: 0, 1, 2, 3+  (0, 1, 2, 8 filler instructions)
  //  Clobbers x1..x31; call last in the hazard block.
  // ======================================================================
  task phase_hazard_matrix_complete();
    int unsigned dist_list [4];

    dist_list[0] = 0;
    dist_list[1] = 1;
    dist_list[2] = 2;
    dist_list[3] = 8;

    restore_mem_base();

    // Producer: ALU-immediate.
    foreach (dist_list[d]) begin
      emit_addi(5'd8, 5'd0, 12'h010);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_addi(5'd9, 5'd8, 12'h001);

      emit_addi(5'd8, 5'd0, 12'h010);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_r_alu(5'd9, 5'd8, 5'd16, ADD_SUB, 0);

      emit_addi(5'd8, 5'd0, 12'h010);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_r_muldiv(5'd9, 5'd8, 5'd17, MUL);

      emit_addi(5'd8, 5'd0, 12'h010);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_r_muldiv(5'd9, 5'd8, 5'd17, DIV);

      emit_li32(5'd1, 32'h0000_1000);
      emit_addi(5'd8, 5'd0, 12'h000);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_load(5'd9, 5'd8, 12'h000, LW);

      emit_addi(5'd8, 5'd0, 12'h010);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_store(5'd8, 5'd1, 12'h000, 3'b010);

      emit_addi(5'd8, 5'd0, 12'h010);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_branch(5'd8, 5'd16, 13'd8, BEQ);
    end

    // Producer: ALU-register.
    foreach (dist_list[d]) begin
      emit_r_alu(5'd8, 5'd16, 5'd17, ADD_SUB, 0);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_addi(5'd9, 5'd8, 12'h001);

      emit_r_alu(5'd8, 5'd16, 5'd17, XOR, 0);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_r_alu(5'd9, 5'd8, 5'd16, AND, 0);

      emit_r_alu(5'd8, 5'd16, 5'd17, OR, 0);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_r_muldiv(5'd9, 5'd8, 5'd17, MUL);

      emit_r_alu(5'd8, 5'd16, 5'd17, ADD_SUB, 0);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_r_muldiv(5'd9, 5'd8, 5'd17, DIV);

      emit_r_alu(5'd8, 5'd16, 5'd17, AND, 0);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_load(5'd9, 5'd8, 12'h000, LW);

      emit_r_alu(5'd8, 5'd16, 5'd17, OR, 0);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_store(5'd8, 5'd1, 12'h000, 3'b010);

      emit_r_alu(5'd8, 5'd16, 5'd17, ADD_SUB, 0);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_branch(5'd8, 5'd16, 13'd8, BEQ);
    end

    // Producer: MUL.
    foreach (dist_list[d]) begin
      emit_r_muldiv(5'd8, 5'd16, 5'd17, MUL);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_addi(5'd9, 5'd8, 12'h001);

      emit_r_muldiv(5'd8, 5'd16, 5'd17, MUL);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_r_alu(5'd9, 5'd8, 5'd16, ADD_SUB, 0);

      emit_r_muldiv(5'd8, 5'd16, 5'd17, MUL);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_r_muldiv(5'd9, 5'd8, 5'd17, MUL);

      emit_r_muldiv(5'd8, 5'd16, 5'd17, MUL);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_r_muldiv(5'd9, 5'd8, 5'd17, DIV);

      emit_r_muldiv(5'd8, 5'd16, 5'd17, MUL);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_load(5'd9, 5'd8, 12'h000, LW);

      emit_r_muldiv(5'd8, 5'd16, 5'd17, MUL);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_store(5'd8, 5'd1, 12'h000, 3'b010);

      emit_r_muldiv(5'd8, 5'd16, 5'd17, MUL);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_branch(5'd8, 5'd16, 13'd8, BEQ);
    end

    // Producer: DIV/REM.
    foreach (dist_list[d]) begin
      emit_r_muldiv(5'd8, 5'd16, 5'd17, DIV);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_addi(5'd9, 5'd8, 12'h001);

      emit_r_muldiv(5'd8, 5'd16, 5'd17, DIV);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_r_alu(5'd9, 5'd8, 5'd16, ADD_SUB, 0);

      emit_r_muldiv(5'd8, 5'd16, 5'd17, DIV);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_r_muldiv(5'd9, 5'd8, 5'd17, MUL);

      emit_r_muldiv(5'd8, 5'd16, 5'd17, DIV);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_r_muldiv(5'd9, 5'd8, 5'd17, REM);

      emit_r_muldiv(5'd8, 5'd16, 5'd17, DIV);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_load(5'd9, 5'd8, 12'h000, LW);

      emit_r_muldiv(5'd8, 5'd16, 5'd17, DIV);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_store(5'd8, 5'd1, 12'h000, 3'b010);

      emit_r_muldiv(5'd8, 5'd16, 5'd17, DIV);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_branch(5'd8, 5'd16, 13'd8, BEQ);
    end

    // Producer: LOAD.
    foreach (dist_list[d]) begin
      emit_load(5'd8, 5'd1, 12'h000, LW);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_addi(5'd9, 5'd8, 12'h001);

      emit_load(5'd8, 5'd1, 12'h000, LW);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_r_alu(5'd9, 5'd8, 5'd16, ADD_SUB, 0);

      emit_load(5'd8, 5'd1, 12'h000, LW);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_r_muldiv(5'd9, 5'd8, 5'd17, MUL);

      emit_load(5'd8, 5'd1, 12'h000, LW);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_r_muldiv(5'd9, 5'd8, 5'd17, DIV);

      emit_load(5'd8, 5'd1, 12'h000, LW);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_load(5'd9, 5'd8, 12'h000, LW);

      emit_load(5'd8, 5'd1, 12'h000, LW);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_store(5'd8, 5'd1, 12'h000, 3'b010);

      emit_load(5'd8, 5'd1, 12'h000, LW);
      repeat (dist_list[d]) emit_addi(5'd15, 5'd0, 12'h0AA);
      emit_branch(5'd8, 5'd16, 13'd8, BEQ);
    end

    // Targeted cells for the one_cycle and short_delay distances on
    // registers x13 and x30.
    emit_addi(5'd13, 5'd0, 12'h055);
    emit_r_alu(5'd9, 5'd0, 5'd13, ADD_SUB, 0);

    emit_addi(5'd13, 5'd0, 12'h055);
    emit_addi(5'd15, 5'd0, 12'h0AA);
    emit_addi(5'd15, 5'd0, 12'h0AA);
    emit_r_alu(5'd9, 5'd0, 5'd13, ADD_SUB, 0);

    emit_addi(5'd30, 5'd0, 12'h055);
    emit_r_alu(5'd9, 5'd0, 5'd30, ADD_SUB, 0);

    emit_addi(5'd30, 5'd0, 12'h055);
    emit_addi(5'd15, 5'd0, 12'h0AA);
    emit_addi(5'd15, 5'd0, 12'h0AA);
    emit_r_alu(5'd9, 5'd0, 5'd30, ADD_SUB, 0);
  endtask

  virtual task body();
    `uvm_info(get_name(), "phase_regfile_hazard_directed", UVM_LOW);
    phase_regfile_hazard_directed();
    if (run_stim_batch3) begin
      phase_stim_forwarding();
      phase_stim_waw();
      phase_stim_reg_walk();
      phase_stim_load_use();
      phase_stim_store_load_dep();
      phase_hazard_full_sweep();
      phase_hazard_matrix_complete();
    end
  endtask
endclass  // rv32im_dir_hazard_seq
