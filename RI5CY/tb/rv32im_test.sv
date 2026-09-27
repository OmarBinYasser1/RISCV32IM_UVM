class rv32im_base_test extends uvm_test;
    `uvm_component_utils(rv32im_test);

    rv32im_env env;
    rv32im_instr_seq instr_seq;
    rv32im_instr_config instr_config;    

    function new (string name  = "rv32im_test" , uvm_component parent = null);
        super.new(name,parent);
    endfunction


    function void build_phase (uvm_phase phase);
        super.build_phase(phase);
        
        env = rv32im_env::type_id::create("env",this);
        instr_seq = rv32im_instr_seq::type_id::create("instr_seq");
        instr_config = rv32im_instr_config::type_id::create("instr_config");

        assert(uvm_config_db#(int)::get(this,"","TESTS", instr_config.TESTS))
            else `uvm_fatal(get_name(), "INSTR BASE TEST - Can't get the number of tests");

        assert(uvm_config_db#(virtual instr_if)::get(this,"",INSTR_IF,instr_config.instr_vif))
            else `uvm_fatal(get_name(), "INSTR BASE TEST - Can't get the Instruction Interface");

        
        uvm_config_db#(rv32im_instr_config)::set(this,*,"INSTR_CONFIG",instr_config);
    endfunction


    function void connect_phase (uvm_phase phase);
        super.build_phase(phase);
        // TODO : This is an intial set , need to configure the ratios of the instructions in our program 
        instr_seq.TESTS = instr_config.TESTS; 
    endfunction

    task run_phase (uvm_phase phase);
        super.run_phase(phase);
        phase.raise_objection(this);
        `uvm_info(get_name(), "Started the Instruction Sequence", UVM_HIGH);
        instr_seq.start(env.instr_agent.instr_seqr);
        `uvm_info(get_name(), "Finished the Instruction Sequence", UVM_HIGH);
        phase.drop_objection(this);
    endtask

    


endclass