class rv32im_instr_config extends uvm_object;
    `uvm_object_utils(rv32im_config);

    int TESTS; // Number of tests to be run defined by the number of instructions (Program Length)
    instr_if instr_vif;

    function new (string name = "rv32im_config");
        super.new(name);
    endfunction


endclass // rv32im_config