// Random R-type ALU, R-type MUL/DIV and I-type (Phases 1-3).
class rv32im_rand_alu_seq extends rv32im_instr_seq;
  `uvm_object_utils(rv32im_rand_alu_seq);

  function new(string name = "rv32im_rand_alu_seq");
    super.new(name);
  endfunction

  virtual task body();
    int n_tests;
    n_tests = (TESTS > 0) ? TESTS : 10;

    // -- Phase 1: R-type ALU arithmetic/logic instructions --------------
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

    // -- Phase 2: R-type MUL/DIV instructions ---------------------------
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

    // -- Phase 3: I-type Immediate arithmetic/logic instructions --------
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

  endtask
endclass  // rv32im_rand_alu_seq
