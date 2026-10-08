class rv32im_instr_seqr extends uvm_sequencer#(rv32im_instr_seq_item);
    `uvm_component_utils(rv32im_instr_seqr);

    function new (string name = "rv32im_instr_seqr" , uvm_component parent = null);
        super.new(name , parent);
    endfunction
endclass //rv32im_instr_seqr