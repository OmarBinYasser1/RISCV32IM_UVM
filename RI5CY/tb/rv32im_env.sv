class rv32im_env extends uvm_env;
    `uvm_component_utils(rv32im_env);

    rv32im_instr_agent instr_agent;

    // TODO : Define the ALU/MUL , Regfile passive agents

    // TODO : Define the system scoreboard

    rv32im_virtual_seqr sys_vseqr;


    function new (string name = "rv32im_env" , uvm_component parent = null);
        super.new(name , parent);
    endfunction

    function void build_phase (uvm_phase phase);
        super.build_phase(phase);
        instr_agent = rv32im_instr_agent::type_id::create("instr_agent",this);
        sys_vseqr = rv32im_virtual_seqr::type_id::create("sys_vseqr",this);
    endfunction


    function void connect_phase (uvm_phase phase);
        super.connect_phase(phase);
        sys_vseqr.instr_seqr = instr_agent.instr_seqr;
    endfunction  

endclass // rv32im_env