class rv32im_instr_seq_item extends uvm_object;
    `uvm_object_utils(rv32im_instr_seq_item);

    typedef enum bit[6:0] { 
        // Define types whose instructions share the same opcode
        OP_R = 7'h33 , OP_IMM = 7'h13 , OP_BRANCH = 7'h63 , OP_STORE = 7'h23 ,
        // Special I-type Instructions sharing a different opcode
        OP_LOAD = 7'h03 ,
        // Specific instructions 
        OP_JAL = 7'h6f , OP_JALR = 7'h67 , OP_LUI = 7'h37 , OP_AUIPC = 7'h17
    } opcode_t; // This type defines the possible opcodes for the RV32IM

    // Define the enum of the opcode    
    rand opcode_t opcode;
    bit [6:0]  funct7; // Valid Vlaues are : 0 , 1 , 32
    bit [2:0]  funct3;
    rand bit [4:0]  rd , rs1 , rs2;
    rand bit [4:0]  shamt;
    rand bit [11:0] i_imm12; // I/S-type Immediate
    rand bit [19:0] u_imm20; // U-type Immediate
    rand bit [20:0] jal_imm21; // jal immediate
    rand bit [12:0] b_imm13; // B-type Immediate 


    // instruction to be passed to the core
    bit [31:0] instruction;

    rand enum bit[2:0] { 
        ADD  , SUB , SLL , SLT , 
        SLTU , XOR , SRL , 
        SRA  , OR  , AND 
    } R_rv32i_ops;

    rand enum bit[2:0] { 
       MUL , MULH , MULHSU , MULHU ,
       DIV , DIVU , REM    , REMU
    } R_rv32m_ops;

    rand enum bit[2:0] { 
        ADDI , SLTI , SLTIU ,
        XORI , ORI , ANDI , 
        SLLI , SRLI , SRAI
     } I_ops;

    rand enum bit[2:0] { 
        BEQ ,  BNE , 
        BLT ,  BGE ,
        BLTU , BGEU     
    } B_ops;
    
    rand enum bit[2:0] { SB , SH , SW } S_ops;
 
    rand enum bit[2:0] { LB , LH , LW , LBU , LHU } Load_ops;

    rand enum bit {ALU , MUL_DIV} ALU_MUL_sel; 


    // Constraints

    constraint c_general {
        // Initially Constraint to have only R Type Instructions
        soft opcode == OP_R;
        
        // Initially Constraint to have the destination register to be x0
        rd dist {[32'd1 : 32'd31] :/98 , 0:/2}; 
    
        // B-type Immediate value should be multiple of 2
        b_imm13 % 2 == 0;

        //  J-immediate encodes a signed offset in multiples of 2 bytes
        jal_imm21 %2 == 0;


    }

    
    constraint c_R_Type {

        solve opcode before ALU_MUL_sel;
        solve ALU_MUL_sel before R_rv32i_ops;
        solve ALU_MUL_sel before R_rv32m_ops;
        
        if(opcode == OP_R) {

            soft ALU_MUL_sel dist {ALU := 60 , MUL_DIV:= 40};
            
            if(ALU_MUL_sel == ALU) {
                // todo : Only If we need weighted dist
                R_rv32i_ops inside {[ADD , SUB , SLL , SLT , SLTU , XOR , SRL , SRA , OR , AND]}; 
            } else {
                // todo : Only If we need weighted dist
                R_rv32m_ops inside {[MUL, MULH , MULHSU , MULHU , DIV , DIVU , REM , REMU]};
            } 
        
            // No constraint on the source operands
        
        }
    }

    constraint c_I_type {

        solve opcode before I_ops;

        if(opcode == OP_IMM) {
            // todo : Only If we need weighted dist
            I_ops inside {[ADDI , SLTI , SLTIU , XORI , ORI , ANDI , SLLI , SRLI , SRAI]};

            // No constraint on the shift amount `shamt`

            // No constraint on the imm12

            // No constraint on the source operands

         
        } 
    }

    constraint c_Load_ops {

        solve opcode before Load_ops;

        if(opcode == OP_LOAD) {
            // todo : Only If we need weighted dist
            Load_ops inside {[LB , LH , LW , LBU , LHU]};

            // No constraint on the imm12



        }

    }

    constraint c_Store_ops {

        solve opcode before S_ops;

        if(opcode == OP_STORE) {
            // todo : Only If we need weighted dist
            S_ops inside {[SB , SH , SW]};
        
            // No constraint on the imm12
        
        }

    }

    constraint c_B_ops {

        solve opcode before B_ops;

        if(opcode == OP_BRANCH) {
            // todo : Only If we need weighted dist
            B_ops inside {[BEQ,BNE,BLT,BGE,BLTU,BGEU]};
        
            // No constraint on the imm12
        
        }
        
    }

    // todo : J/U have no constraints except for the rd which may be a general constraint 

    // constraint c_J_ops {
    //     if(opcode == OP_JAL)

    //     else if(opcode == OP_JALR)
    // } 
    
    // constraint c_U_ops {
    //     if(opcode == OP_LUI) 

    //     else if (opcode == OP_AUIPC)
    // }
    

    function new (string name = "rv32im_instr_seq_item");
        super.new(name);
    endfunction

    function void post_randomize ();
        bit [6:0] opcode_x; // A version of the opcode represented in bits not enum
        
        opcode_x = bit[6:0]'(opcode); 
        
        case (opcode)
            OP_R : begin

                if(ALU_MUL_sel == ALU) begin
                    funct3 = bit[2:0]'(R_rv32i_ops);
                    funct7 = (R_rv32i_ops == SUB || R_rv32i_ops == SRA) ? 7'd32 : 7'd0;
                end
                else begin
                    funct3 = bit[2:0]'(R_rv32m_ops);
                    funct7 = 7'd1;    
                end

                instruction = {funct7,rs2,rs1,funct3,rd,opcode_x};
            
            end

            OP_IMM : begin

                funct3 = bit[2:0]'(I_ops);
            
                if (I_ops == SRAI || I_ops == SLLI || I_ops == SRLI) begin
                    funct7 = (I_ops == SRAI)? 7'd32 : 7'd0;
                    instruction = {funct7,shamt,rs1,funct3,rd,opcode_x};
                end
                else instruction = {i_imm12,rs1,funct3,rd,opcode_x};
            
            end

            OP_LOAD : begin
                funct3 = bit[2:0]'(Load_ops);
                instruction = {i_imm12,rs1,funct3,rd,opcode_x};
            end

            OP_STORE : begin
                funct3 = bit[2:0]'(S_ops);
                instruction = {i_imm12[11:5],rs2,rs1,funct3,imm12[4:0],opcode_x};
            end

            OP_BRANCH : begin
                funct3 = bit[2:0]'(B_ops);
                instruction = {b_imm13[12],b_imm13[10:5],rs2,rs1,funct3,b_imm13[4:1],b_imm13[11],opcode_x};
            end

            OP_JALR : begin
                funct3 = 3'h0;
                instruction = {i_imm12[11:0],rs1,funct3,rd,opcode_x};
            end

            OP_JAL : begin
                instruction = {jal_imm21[20],jal_imm21[10:1],jal_imm21[11],jal_imm21[19:12],rd,opcode_x};
            end

            default : begin // LUI / AUIPC
                instruction = {u_imm20,rd,opcode_x};
            end

        endcase
            
        
    endfunction



endclass // rv32im_instr_seq_item