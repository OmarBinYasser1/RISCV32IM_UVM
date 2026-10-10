// TODO : create a virtual sequence for variety of instructions
class rv32im_instr_seq extends uvm_sequence#(rv32im_instr_seq_item);
    `uvm_object_utils(rv32im_instr_seq);

    int TESTS;

    rv32im_instr_seq_item instr_item;
    rv32im_instr_seq_item reset_item;
    
    function new (string name = "rv32im_instr_seq");
        super.new(name);
    endfunction

    task body();
        // Initial System Reset for 5 cycles
        `uvm_info(get_name(), "Asserting System Reset (rst_n = 0)...", UVM_LOW);
        repeat(5) begin
            reset_item = rv32im_instr_seq_item::type_id::create("reset_item");
            start_item(reset_item);
            assert(reset_item.randomize with {rst_n == 0;} )
                else `uvm_fatal(get_name,"Can't initially reset the core");
            finish_item(reset_item);
        end

        `uvm_info(get_name(), "Releasing System Reset (rst_n = 1)...", UVM_LOW);

        repeat(TESTS) begin
            instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
            start_item(instr_item);
            assert(instr_item.randomize with {
                rst_n == 1;
                // opcode inside {OP_R,OP_IMM};
                // opcode inside {OP_R,OP_BRANCH};
                opcode == OP_BRANCH;
                // funct7 == 'd0;
                // R_rv32i_ops == SLT;
                // ALU_MUL_sel == MUL_DIV;
                ALU_MUL_sel == ALU;
                // R_rv32m_ops inside {MUL , MULHSU , MULHU , MULH};
            })
                else `uvm_fatal(get_name(), "INSTR SEQ - Can't randomize for the Instruction");
            finish_item(instr_item);
        end
    endtask
endclass // rv32im_instr_seq_item


