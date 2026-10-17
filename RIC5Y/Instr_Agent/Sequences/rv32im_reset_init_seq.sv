// Reset + operand-pool preload (must run first in every test).
class rv32im_reset_init_seq extends rv32im_instr_seq;
  `uvm_object_utils(rv32im_reset_init_seq);

  function new(string name = "rv32im_reset_init_seq");
    super.new(name);
  endfunction

  virtual task body();
    // -- Phase 0: Initial System Reset for 5 cycles ----------------------
    `uvm_info(get_name(), "Asserting System Reset (rst_n = 0)...", UVM_LOW);
    repeat (5) drive_reset();
    `uvm_info(get_name(), "Releasing System Reset (rst_n = 1)...", UVM_LOW);

    // -- Phase 0.5: Preload operand pool x16..x31 ------------------------
    `uvm_info(get_name(), "Phase 0.5: Preloading operand pool x16..x31...", UVM_LOW);
    preload_operand_pool();
    `uvm_info(get_name(), "Phase 0.5: Operand pool loaded.", UVM_LOW);

  endtask
endclass  // rv32im_reset_init_seq
