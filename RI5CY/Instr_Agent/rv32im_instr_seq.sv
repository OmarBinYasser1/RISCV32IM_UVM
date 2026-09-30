// TODO : create a virtual sequence for variety of instructions
typedef uvm_sequencer#(rv32im_instr_seq_item) rv32im_instr_seqr;

class rv32im_instr_seq extends uvm_sequence#(rv32im_instr_seq_item);
    `uvm_object_utils(rv32im_instr_seq_item);

    int TESTS;

    rv32im_instr_seq_item instr_item;
    

    function new (string name = "rv32im_instr_seq_item");
        super.new(name);
    endfunction

    task body();
        repeat(TESTS) begin
            instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
            start_item(instr_item);
            assert(instr_item.randomize with {opcode == OP_R ; ALU_MUL_sel == ALU ; R_rv32i_ops == ADD}) 
                else `uvm_fatal(get_name(), "INSTR SEQ - Can't randomize for the Instruction");
            finish_item(instr_item);
        end
    endtask

endclass // rv32im_instr_seq_item


