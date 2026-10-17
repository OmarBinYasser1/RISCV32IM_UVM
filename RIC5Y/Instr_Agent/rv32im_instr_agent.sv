class rv32im_instr_agent extends uvm_agent;
    `uvm_component_utils(rv32im_instr_agent);

    rv32im_instr_driver instr_driver;
    rv32im_instr_monitor instr_monitor;
    rv32im_instr_seqr instr_seqr;
    // Define analysis port at the agent boundary to facilitate the integration
    uvm_analysis_port#(rv32im_instr_seq_item) instr_mon_ap; 

    rv32im_instr_config instr_config;


    function new (string name = "rv32im_instr_agent" , uvm_component parent = null);
        super.new(name , parent);
    endfunction

    function void build_phase (uvm_phase phase);
        super.build_phase(phase);
        instr_driver = rv32im_instr_driver::type_id::create("instr_driver",this);
        instr_monitor = rv32im_instr_monitor::type_id::create("instr_monitor",this);
        // instr_seqr = uvm_sequencer#(rv32im_instr_seq_item)::type_id::create("instr_seqr",this);
        instr_seqr = rv32im_instr_seqr::type_id::create("instr_seqr",this);
        instr_mon_ap = new("instr_mon_ap",this);
        
        // Retreive the instruction Agent Configuration
        assert(uvm_config_db#(rv32im_instr_config)::get(this, "", "INSTR_CONFIG" , instr_config))
            else `uvm_fatal(get_name(),"INSR AGENT - Can't get the Intruction Configuration");                    
    endfunction


    function void connect_phase (uvm_phase phase);
        super.connect_phase(phase);

        // Driver Connections
        instr_driver.seq_item_port.connect(instr_seqr.seq_item_export);
        instr_driver.instr_vif = instr_config.instr_vif;


        // Monitor Connections
        instr_monitor.instr_vif = instr_config.instr_vif;
        instr_monitor.instr_mon_ap.connect(instr_mon_ap);


    endfunction


    

endclass // rv32im_instr_agent