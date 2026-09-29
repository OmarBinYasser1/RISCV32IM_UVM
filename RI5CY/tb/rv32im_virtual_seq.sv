class rv32im_virtual_seq extends uvm_sequence#(uvm_sequence_item);
    `uvm_object_utils(rv32im_virtual_seq);

// Define the sequences that live in the virtual sequence

    // 1- Instruction (TODO Virtual) Sequence 
    rv32im_instr_seq instr_seq;

    // TODO : Define the Data & Debug_Interrupt sequences in virtual sequence 

// Define the local sequencer handles to be connected from the top

    // 1- Instruction Sequencer
    rv32im_instr_seqr instr_seqr;

    // TODO : Define Data & Debug_Interrupt Sequencer in virtual Sequencer

// Define the virual sequencer to connect its sub-sequencers to the local sequencers

    rv32im_virtual_seqr sys_vseqr;

    // Declare the virtual sequencer as p_sequencer not m_sequencer
    `uvm_declare_p_sequencer(rv32im_virtual_seqr);

    function new (string name = "rv32im_virtual_seq");
        super.new(name);
    endfunction

    virtual task body();
    // Connect the local sequencers to the virtual sequencer's sub-sequencers
        instr_seqr = sys_vseq.instr_seqr;
        
        // TODO : Connect the data & debug_interrupt sequencers to the virtual sequencer's sub-sequencer

    // Build the sub-sequences 

        instr_seq = rv32im_instr_seq::type_id::create("instr_seq");

        // TODO : Build the data & debug_interrupt sub-sequences

    // Run the sequences on the local sequencers
        fork
            instr_seq.start(instr_seq);    
            // TODO : Run the data and debug_interupt sequences on the local sequencers
        join
        
    endtask
    
endclass // rv32im_virtual_seq