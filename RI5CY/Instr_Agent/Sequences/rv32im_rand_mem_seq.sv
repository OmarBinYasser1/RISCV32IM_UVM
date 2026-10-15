// Random base load, STORE and LOAD (Phases 4-6).
class rv32im_rand_mem_seq extends rv32im_instr_seq;
  `uvm_object_utils(rv32im_rand_mem_seq);

  function new(string name = "rv32im_rand_mem_seq");
    super.new(name);
  endfunction

  virtual task body();
    int n_tests;
    n_tests = (TESTS > 0) ? TESTS : 10;

    // -- Phase 4: Pre-load x1 = 0x1000 and x2 = 0x123 --------------------
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

    // -- Phase 5: STORE instructions ------------------------------------
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

    // -- Phase 6: LOAD instructions -------------------------------------
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

  endtask
endclass  // rv32im_rand_mem_seq
