class rv32im_instr_monitor extends uvm_monitor;
    `uvm_component_utils(rv32im_instr_monitor);

    
    virtual rv32im_instr_if.mp_mon instr_vif;

    uvm_analysis_port#(rv32im_instr_seq_item) instr_mon_ap;
    rv32im_instr_seq_item instr_item;


    function new (string name = "rv32im_instr_monitor" , uvm_component parent = null);
        super.new(name , parent);
    endfunction

    function void build_phase (uvm_phase phase);
        super.build_phase(phase);  
        instr_mon_ap = new("instr_mon_ap",this);
    endfunction

    task run_phase (uvm_phase phase);
        super.run_phase(phase);
        forever begin
            instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
            i_monitor(instr_item);
            i_decoder(instr_item);
            instr_mon_ap.write(instr_item);
        end
    endtask

    task i_monitor (ref rv32im_instr_seq_item instr_item); // Instruction Monitor
        @(instr_vif.cb_mon iff (instr_vif.cb_mon.instr_rvalid_i == 1));
        instr_item.instruction = instr_vif.cb_mon.instr_rdata_i;
    endtask

    
    /*
    task i_decoder (ref rv32im_instr_seq_item instr_item); // Instruction Decoder : Pass the Instruction Useful Data to the Scoreboard
        
    endtask
    */




endclass // rv32im_instr_monitor