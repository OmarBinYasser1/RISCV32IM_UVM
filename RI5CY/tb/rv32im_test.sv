// =============================================================================
// RISCV32IM UVM Verification Test Suite
// Includes specialized and randomized test classes for CV32E40P core.
// =============================================================================

class rv32im_base_test extends uvm_test;
  `uvm_component_utils(rv32im_base_test);

  rv32im_env env;
  rv32im_virtual_seq sys_vseq;
  rv32im_instr_config instr_config;

  function new(string name = "rv32im_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    env = rv32im_env::type_id::create("env", this);
    sys_vseq = rv32im_virtual_seq::type_id::create("sys_vseq");
    instr_config = rv32im_instr_config::type_id::create("instr_config");

    assert (uvm_config_db#(int)::get(this, "", "TESTS", instr_config.TESTS))
    else `uvm_fatal(get_name(), "INSTR BASE TEST - Can't get the number of tests");

    assert (uvm_config_db#(virtual rv32im_instr_if)::get(
        this, "", "INSTR_IF", instr_config.instr_vif
    ))
    else `uvm_fatal(get_name(), "INSTR BASE TEST - Can't get the Instruction Interface");

    // Optional knobs (all default = base regression unchanged).
    void'(uvm_config_db#(bit)::get(this, "", "relax_rd_rs",      instr_config.relax_rd_rs));
    void'(uvm_config_db#(bit)::get(this, "", "run_stim_batch3",  instr_config.run_stim_batch3));
    void'(uvm_config_db#(int)::get(this, "", "stream_min_len",   instr_config.stream_min_len));
    void'(uvm_config_db#(int)::get(this, "", "stream_max_len",   instr_config.stream_max_len));
    void'(uvm_config_db#(bit [5:0])::get(this, "", "stream_opcode_mask", instr_config.stream_opcode_mask));

    uvm_config_db#(rv32im_instr_config)::set(this, "*", "INSTR_CONFIG", instr_config);

    // Derived tests pick their sequences here.
    add_sequences();
  endfunction

  // Default (base_test) = full regression, same order as the old single sequence.
  virtual function void add_sequences();
    add_seq(rv32im_reset_init_seq::type_id::create("reset_init_seq"));
    add_seq(rv32im_rand_alu_seq::type_id::create("rand_alu_seq"));
    add_seq(rv32im_rand_mem_seq::type_id::create("rand_mem_seq"));
    add_seq(rv32im_rand_ctrl_seq::type_id::create("rand_ctrl_seq"));
    add_seq(rv32im_dir_alu_seq::type_id::create("dir_alu_seq"));
    add_seq(rv32im_dir_ctrl_seq::type_id::create("dir_ctrl_seq"));
    add_seq(rv32im_dir_muldiv_seq::type_id::create("dir_muldiv_seq"));
    add_seq(rv32im_dir_hazard_seq::type_id::create("dir_hazard_seq"));
    add_seq(rv32im_dir_mem_seq::type_id::create("dir_mem_seq"));
    add_seq(rv32im_dir_corner_seq::type_id::create("dir_corner_seq"));
    add_seq(rv32im_stream_seq::type_id::create("stream_seq"));
  endfunction

  // Queue a sequence and push the command-line knobs (via instr_config) into it.
  function void add_seq(rv32im_instr_seq s);
    s.TESTS              = instr_config.TESTS;
    s.relax_rd_rs        = instr_config.relax_rd_rs;
    s.run_stim_batch3    = instr_config.run_stim_batch3;
    s.stream_min_len     = instr_config.stream_min_len;
    s.stream_max_len     = instr_config.stream_max_len;
    s.stream_opcode_mask = instr_config.stream_opcode_mask;
    sys_vseq.instr_seq_q.push_back(s);
  endfunction

  function void start_of_simulation_phase(uvm_phase phase);
    super.start_of_simulation_phase(phase);
    `uvm_info(get_name(), $sformatf("\n=======================================================\n  STARTING TEST: %s\n=======================================================", get_type_name()), UVM_LOW);
  endfunction

  task run_phase(uvm_phase phase);
    super.run_phase(phase);
    phase.raise_objection(this);
    `uvm_info(get_name(), "Started the System Virtual Sequence", UVM_HIGH);

    sys_vseq.start(env.sys_vseqr);

    `uvm_info(get_name(), "Finished the System Virtual Sequence", UVM_HIGH);
    phase.drop_objection(this);
  endtask

  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();
    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info(get_name(), $sformatf("\n=======================================================\n  TEST PASSED: %s (0 Errors, 0 Fatals)\n=======================================================", get_type_name()), UVM_LOW);
    end else begin
      `uvm_error(get_name(), $sformatf("\n=======================================================\n  TEST FAILED: %s (%0d Errors, %0d Fatals)\n=======================================================", get_type_name(), svr.get_severity_count(UVM_ERROR), svr.get_severity_count(UVM_FATAL)));
    end
  endfunction
endclass // rv32im_base_test
