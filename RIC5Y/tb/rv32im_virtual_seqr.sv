class rv32im_virtual_seqr extends uvm_sequencer#(uvm_sequence_item);
    `uvm_component_utils(rv32im_virtual_seqr);

    // Define the sequencers of the top level interfaces (Instruction , Debug_Interrupt , Data)
    
    // 1- Instruction Sequencer
    rv32im_instr_seqr instr_seqr;
    // 2- Data Sequencer
    reactive_data_sequencer data_seqr;
    // 3- Debug_Interrupt Sequencer 
    debug_interupt_sequencer debug_int_seqr;

    function new (string name = "rv32im_virtual_seqr" , uvm_component parent = null);
        super.new(name , parent);
    endfunction

endclass // rv32im_virtual_seqr