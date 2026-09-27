class rv32im_instr_seq_item extends uvm_object;
    `uvm_object_utils(rv32im_instr_seq_item);

    // Instruction Fields
    bit [31:0] instruction;
    
    rand bit [5:0] opcode;
    rand bit [6:0] funct7;
    rand bit [2:0] funct3;
    rand bit [4:0] rd , rs1 , rs2;
    rand bit [11:0] imm12;
    rand bit [19:0] imm20;

    function new (string name = "rv32im_instr_seq_item");
        super.new(name);
    endfunction





endclass // rv32im_instr_seq_item