// TODO : create a virtual sequence for variety of instructions
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
            // TODO : Randomize for the R-type 
            finish_item(instr_item);
        end
    
    endtask

    
    


endclass // rv32im_instr_seq_item


