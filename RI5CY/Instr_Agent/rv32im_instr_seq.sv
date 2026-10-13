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

  task body();
    int n_tests;
    n_tests = (TESTS > 0) ? TESTS : 10;

    // ── Phase 0: Initial System Reset for 5 cycles ──────────────────────
    `uvm_info(get_name(), "Asserting System Reset (rst_n = 0)...", UVM_LOW);
    repeat (5) drive_reset();
    `uvm_info(get_name(), "Releasing System Reset (rst_n = 1)...", UVM_LOW);

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

    // ── Phase 4: Pre-load base address in x1 (x1 = 0x1000) for LOAD/STORE
    `uvm_info(get_name(), "Phase 4: Pre-loading x1 = 0x1000 for memory accesses...", UVM_LOW);
    instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
    start_item(instr_item);
    if (!instr_item.randomize() with {
          rst_n == 1;
          opcode == OP_LUI;
          rd == 5'd1;
          u_imm20 == 20'h00001;  // x1 = 0x0000_1000
        })
      `uvm_fatal(get_name(), "Phase 4: Randomization failed for LUI base address");
    finish_item(instr_item);

    // Pre-load data in x2 = 0x123
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

    // ── Phase 5: STORE instructions (writing to addresses based on x1) ──
    `uvm_info(get_name(), $sformatf("Phase 5: STORE instructions (%0d instructions)...", n_tests),
              UVM_LOW);
    repeat (n_tests) begin
      instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
      start_item(instr_item);
      if (!instr_item.randomize() with {
            rst_n == 1;
            opcode == OP_STORE;
            rs1 == 5'd1;  // base address in x1 = 0x1000
            i_imm12 inside {0, 4, 8, 12, 16, 20, 24, 28, 32};
            // i_imm12 == 12;
          })
        `uvm_fatal(get_name(), "Phase 5: Randomization failed for STORE");
      finish_item(instr_item);
    end

    // ── Phase 6: LOAD instructions (reading from addresses based on x1) ──
    `uvm_info(get_name(), $sformatf("Phase 6: LOAD instructions (%0d instructions)...", n_tests),
              UVM_LOW);
    repeat (n_tests) begin
      instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
      start_item(instr_item);
      if (!instr_item.randomize() with {
            rst_n == 1;
            opcode == OP_LOAD;
            rs1 == 5'd1;  // base address in x1 = 0x1000
            i_imm12 inside {0, 4, 8, 12, 16, 20, 24, 28, 32};
            // i_imm12 == 12;
          })
        `uvm_fatal(get_name(), "Phase 6: Randomization failed for LOAD");
      finish_item(instr_item);
    end
    /*
        // ── Phase 7: BRANCH instructions (forward offsets only) ─────────────
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

        // ── Phase 8: JAL instructions (forward offsets only) ────────────────
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

        // ── Phase 9: JALR instructions (pre-load base PC via AUIPC) ─────────
        `uvm_info(get_name(), "Phase 9: Pre-loading PC via AUIPC for JALR...", UVM_LOW);
        instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
        start_item(instr_item);
        if (!instr_item.randomize() with {
            rst_n == 1;
            opcode == OP_AUIPC;
            rd == 5'd1;
            u_imm20 == 20'd0; // x1 = current PC
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
        end*/

  endtask
endclass  // rv32im_instr_seq
