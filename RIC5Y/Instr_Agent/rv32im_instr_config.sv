class rv32im_instr_config extends uvm_object;
    `uvm_object_utils(rv32im_instr_config);

    int TESTS; // Number of tests to be run defined by the number of instructions (Program Length)
    virtual rv32im_instr_if instr_vif;

    // CHK:I-03  Relax the rd/rs partition used by random stimulus.
    // 0 (default) = old strict partition (rd in [8:15], rs in {0, x16..x31}).
    // 1 = rd may equal a source register (RAW / same-register corners reachable).
    bit relax_rd_rs = 0;

    // CHK:I-09  Stream knobs used by rv32im_instr_seq.phase_mixed_stream().
    int unsigned stream_min_len     = 3;
    int unsigned stream_max_len     = 5;
    bit [5:0]    stream_opcode_mask = 6'b11_1111;

    // CHK:S-01..S-29  Batch-3 stimulus gate.  0 (default) = base regression
    // unchanged; 1 = run the new directed phases after Phase 14.
    bit run_stim_batch3 = 0;

    function new (string name = "rv32im_instr_config");
        super.new(name);
    endfunction


endclass // rv32im_config