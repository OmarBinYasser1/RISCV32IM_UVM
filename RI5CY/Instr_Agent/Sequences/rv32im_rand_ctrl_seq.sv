// Random BRANCH, JAL and JALR (Phases 7-9).
class rv32im_rand_ctrl_seq extends rv32im_instr_seq;
  `uvm_object_utils(rv32im_rand_ctrl_seq);

  function new(string name = "rv32im_rand_ctrl_seq");
    super.new(name);
  endfunction

  virtual task body();
    int n_tests;
    n_tests = (TESTS > 0) ? TESTS : 10;

    // -- Phase 7: BRANCH instructions (random) --------------------------
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

    // -- Phase 8: JAL instructions (random) -----------------------------
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

    // -- Phase 9: JALR instructions (using x1 = AUIPC 0) ----------------
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

  endtask
endclass  // rv32im_rand_ctrl_seq
