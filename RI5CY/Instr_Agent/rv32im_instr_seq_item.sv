// Instruction Enums
    typedef enum bit[6:0] { 
            // Define types whose instructions share the same opcode
            OP_R = 7'h33 , OP_IMM = 7'h13 , OP_BRANCH = 7'h63 , OP_STORE = 7'h23 ,
            // Special I-type Instructions sharing a different opcode
            OP_LOAD = 7'h03 ,
            // Specific instructions 
            OP_JAL = 7'h6f , OP_JALR = 7'h67 , OP_LUI = 7'h37 , OP_AUIPC = 7'h17
    } opcode_t; // This type defines the possible opcodes for the RV32IM

   typedef enum bit[2:0] { 
        ADD_SUB , SLL , SLT , 
        SLTU , XOR , 
        SRL_SRA , OR  , AND 
    } alu_ops_t;

    typedef enum bit[2:0] { 
       MUL , MULH , MULHSU , MULHU ,
       DIV , DIVU , REM    , REMU
    } mul_div_ops_t;

    typedef enum bit [2:0]{ 
        ADDI = 'd0 , SLTI ='d2 , SLTIU = 'd3 ,
        XORI = 'd4 , ORI = 'd6 , ANDI = 'd7 , 
        SLLI = 'd1 , SRLI_SRAI = 'd5
     } I_ops_t;

    typedef enum bit[2:0] { 
        BEQ = 'd0 ,  BNE = 'd1 , 
        BLT = 'd4 ,  BGE = 'd5 ,
        BLTU = 'd6 , BGEU = 'd7
    } B_ops_t;

    typedef enum bit[2:0] { SB , SH , SW } S_ops_t;
    
    typedef enum bit[2:0] { LB = 'd0 , LH = 'd1 , LW = 'd2 , LBU = 'd4 , LHU = 'd5 } Load_ops_t;

    typedef enum bit {ALU , MUL_DIV} ALU_MUL_sel_t;

class rv32im_instr_seq_item extends uvm_sequence_item;
    `uvm_object_utils(rv32im_instr_seq_item);


    // Define the enum of the opcode   
    rand bit rst_n; 
    rand opcode_t opcode;
    rand bit [6:0]  funct7; // Valid Vlaues are : 0 , 1 , 32
    bit [2:0]  funct3;
    rand bit [4:0]  rd , rs1 , rs2;
    rand bit [4:0]  shamt;
    rand bit [11:0] i_imm12; // I/S-type Immediate
    rand bit [19:0] u_imm20; // U-type Immediate
    rand bit [20:0] jal_imm21; // jal immediate 
    rand bit [12:0] b_imm13; // B-type Immediate

    // bit [31:0] imm

    // instruction to be passed to the core
    bit [31:0] instruction;

    rand alu_ops_t R_rv32i_ops;

    rand mul_div_ops_t R_rv32m_ops;

    rand I_ops_t I_ops;

    rand B_ops_t B_ops;

    rand S_ops_t S_ops;
 
    rand Load_ops_t Load_ops;

    rand ALU_MUL_sel_t  ALU_MUL_sel; 

    bit [31:0] pc; // Program counter received as `req_o` from the core
    
    
    
    // Constraints

    constraint c_general {

        // Initial Constraint on reset
        soft rst_n dist {1:=90 , 0:=10};

        // Initially Constraint to have only R Type Instructions
        soft opcode == OP_R;
        
        // Initially Constraint to have the destination register to be x0
        rd dist {[32'd1 : 32'd31] :/98 , 0:/2}; 
    
        // In xase of R,I types , the valid values for the funct7 filed are 0,1,32
        funct3 inside {0,1,32};
        
        // B-type Immediate value should be multiple of 2
        b_imm13 % 2 == 0;

        //  J-immediate encodes a signed offset in multiples of 2 bytes
        jal_imm21 %2 == 0;


    }

    
    constraint c_R_Type {

        solve opcode before ALU_MUL_sel;
        solve ALU_MUL_sel before R_rv32i_ops;
        solve ALU_MUL_sel before R_rv32m_ops;
        solve R_rv32i_ops before funct7;
        solve R_rv32m_ops before funct7;

        if(opcode == OP_R) {

            soft ALU_MUL_sel dist {ALU := 60 , MUL_DIV:= 40};
            
            if(ALU_MUL_sel == ALU) {
                // todo : Only If we need weighted dist
                R_rv32i_ops inside {ADD_SUB , SLL , SLT , SLTU , XOR , SRL_SRA , OR , AND}; 
                
                if(R_rv32i_ops == ADD_SUB){
                    funct7 dist {'d0 := 50, 'd32 := 50}; // ADD and SUB are of the same probability
                } else if (R_rv32i_ops == SRL_SRA) {
                    funct7 dist {'d0 := 50, 'd32 := 50}; // SRL and SRA are of the same probability
                } else {
                    funct7 == 'd0;
                }
            } else {
                // todo : Only If we need weighted dist
                R_rv32m_ops inside {MUL, MULH , MULHSU , MULHU , DIV , DIVU , REM , REMU};
            
                funct7 == 'd1;
            
            } 
            
            
            // No constraint on the source operands
        
        }
    }

    constraint c_I_type {

        solve opcode before I_ops;
        solve I_ops before funct7;

        if(opcode == OP_IMM) {
            // todo : Only If we need weighted dist
            I_ops inside {ADDI , SLTI , SLTIU , XORI , ORI , ANDI , SLLI , SRLI_SRAI};

            if (I_ops == SRLI_SRAI)
                    funct7 dist {'d0 := 50, 'd32 := 50}; // SRLI and SRAI are of the same probability
            else funct7 == 0; // Whether SLLI or any other operation that don't use funct7

            // No constraint on the shift amount `shamt`

            // No constraint on the imm12

            // No constraint on the source operands

         
        } 
    }

    constraint c_Load_ops {

        solve opcode before Load_ops;

        if(opcode == OP_LOAD) {
            // todo : Only If we need weighted dist
            Load_ops inside {LB , LH , LW , LBU , LHU};

            // No constraint on the imm12



        }

    }

    constraint c_Store_ops {

        solve opcode before S_ops;

        if(opcode == OP_STORE) {
            // todo : Only If we need weighted dist
            S_ops inside {SB , SH , SW};
        
            // No constraint on the imm12
        
        }

    }

    constraint c_B_ops {

        solve opcode before B_ops;

        if(opcode == OP_BRANCH) {
            // todo : Only If we need weighted dist
            B_ops inside {BEQ,BNE,BLT,BGE,BLTU,BGEU};
        
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
        
        opcode_x = opcode; 
        
        case (opcode)
            OP_R : begin

                if(ALU_MUL_sel == ALU) begin
                    funct3 = R_rv32i_ops;
                end
                else begin
                    funct3 = R_rv32m_ops;
                end

                instruction = {funct7,rs2,rs1,funct3,rd,opcode_x};
            
            end

            OP_IMM : begin

                funct3 = I_ops;
            
                if (I_ops == SRLI_SRAI || I_ops == SLLI) begin
                    // funct7 = (I_ops == SRAI)? 7'd32 : 7'd0;
                    instruction = {funct7,shamt,rs1,funct3,rd,opcode_x};
                end
                else instruction = {i_imm12,rs1,funct3,rd,opcode_x};
            
            end

            OP_LOAD : begin
                funct3 = Load_ops;
                instruction = {i_imm12,rs1,funct3,rd,opcode_x};
            end

            OP_STORE : begin
                funct3 = S_ops;
                instruction = {i_imm12[11:5],rs2,rs1,funct3,i_imm12[4:0],opcode_x};
            end

            OP_BRANCH : begin
                funct3 = B_ops;
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
    endfunction // post_randomize

    virtual function string convert2string();
        string s;

        s = super.convert2string();

        // if(opcode == OP_R)    
        //     if(funct7 == 7'd1)
        //         s= $sformatf(" %s X%0d , X%0d , X%0d", alu_ops_t'(funct3) , rd , rs1 , rs2 );
        //     else
        //         s= $sformatf(" %s X%0d , X%0d , X%0d", mul_div_ops_t'(funct3) , rd , rs1 , rs2 );
        
        case (opcode)
            OP_R : begin
                if(ALU_MUL_sel == ALU) begin
                    alu_ops_t alu_op;
                    alu_op = alu_ops_t'(funct3);
                    case (alu_op)
                        ADD_SUB : s = (funct7 == 'd0)? "ADD" : "SUB";
                        SRL_SRA : s = (funct7 == 'd0)? "SRL" : "SRA";
                        default : s = alu_op.name();              
                    endcase
                    s= {s,$sformatf(" X%0d , X%0d , X%0d", rd , rs1 , rs2 )};
                end
                else
                    s= $sformatf(" %s X%0d , X%0d , X%0d", mul_div_ops_t'(funct3) , rd , rs1 , rs2 );                
            end

            OP_IMM : begin
                I_ops_t alu_imm_op;
                alu_imm_op = I_ops_t'(funct3);
                case (alu_imm_op)
                    SRLI_SRAI : s = (funct7 == 'd0)? "SRLI" : "SRAI";
                    default : s = alu_imm_op.name();
                endcase
                // I_ops_t operation = funct3;
                // if(I_ops !== SLLI || I_ops !== SRLI || I_ops !== SRAI) 
                s= {s , $sformatf(" X%0d , X%0d , %0d", mul_div_ops_t'(funct3) , rd , rs1 , i_imm12 )};                
            end

            OP_LOAD : begin
                s = $sformatf(" %s X%0d , %0d (X%0d)", Load_ops_t'(funct3), rd , i_imm12 , rs1);
            end

            OP_STORE : begin
                s = $sformatf(" %s X%0d , %0d (X%0d)", S_ops_t'(funct3), rs2 , i_imm12 , rs1);
            end

            OP_BRANCH : begin
                s = $sformatf(" %s X%0d , X%0d , %0d", B_ops_t'(funct3), rs1 , rs2 , b_imm13);
            end

            OP_JALR , OP_JAL : begin
                s = $sformatf(" %s X%0d , %0d", opcode , rd , jal_imm21 );
            end

            OP_AUIPC , OP_LUI : begin
                s = $sformatf(" %s X%0d , %0d", opcode , rd , u_imm20 );
            end
        endcase

        return s;
    endfunction // convert2string


endclass // rv32im_instr_seq_item