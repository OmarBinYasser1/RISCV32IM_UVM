// Instruction Enums
typedef enum bit [6:0] {
  // Define types whose instructions share the same opcode
  OP_R = 7'h33,
  OP_IMM = 7'h13,
  OP_BRANCH = 7'h63,
  OP_STORE = 7'h23,
  // Special I-type Instructions sharing a different opcode
  OP_LOAD = 7'h03,
  // Specific instructions 
  OP_JAL = 7'h6f,
  OP_JALR = 7'h67,
  OP_LUI = 7'h37,
  OP_AUIPC = 7'h17
} opcode_t;  // This type defines the possible opcodes for the RV32IM

typedef enum bit [2:0] {
  ADD_SUB,
  SLL,
  SLT,
  SLTU,
  XOR,
  SRL_SRA,
  OR,
  AND
} alu_ops_t;

typedef enum bit [2:0] {
  MUL,
  MULH,
  MULHSU,
  MULHU,
  DIV,
  DIVU,
  REM,
  REMU
} mul_div_ops_t;

typedef enum bit [2:0] {
  ADDI = 'd0,
  SLTI = 'd2,
  SLTIU = 'd3,
  XORI = 'd4,
  ORI = 'd6,
  ANDI = 'd7,
  SLLI = 'd1,
  SRLI_SRAI = 'd5
} I_ops_t;

typedef enum bit [2:0] {
  BEQ  = 'd0,
  BNE  = 'd1,
  BLT  = 'd4,
  BGE  = 'd5,
  BLTU = 'd6,
  BGEU = 'd7
} B_ops_t;

typedef enum bit [2:0] {
  SB,
  SH,
  SW
} S_ops_t;

typedef enum bit [2:0] {
  LB  = 'd0,
  LH  = 'd1,
  LW  = 'd2,
  LBU = 'd4,
  LHU = 'd5
} Load_ops_t;

typedef enum bit {
  ALU,
  MUL_DIV
} ALU_MUL_sel_t;

class rv32im_instr_seq_item extends uvm_sequence_item;
  `uvm_object_utils(rv32im_instr_seq_item);


  // Define the enum of the opcode   
  rand bit rst_n;
  // rand opcode_t opcode;
  rand opcode_t opcode;
  rand bit [6:0] funct7;  // Valid Vlaues are : 0 , 1 , 32
  bit [2:0] funct3;
  rand bit [4:0] rd, rs1, rs2;
  rand bit [4:0] shamt;
  rand bit [11:0] i_imm12;  // I/S-type Immediate
  rand bit [19:0] u_imm20;  // U-type Immediate
  rand bit [20:0] jal_imm21;  // jal immediate 
  rand bit [12:0] b_imm13;  // B-type Immediate

  bit [31:0] instruction;

  rand alu_ops_t R_rv32i_ops;
  rand mul_div_ops_t R_rv32m_ops;
  rand I_ops_t I_ops;
  rand B_ops_t B_ops;
  rand S_ops_t S_ops;
  rand Load_ops_t Load_ops;
  rand ALU_MUL_sel_t ALU_MUL_sel;

  //  Relax the rd/rs partition in c_general.  Non-rand so a
  // sequence can set it before randomize() without fighting the solver.
  // Default 0 = old strict behaviour (rd in [8:15], rs in {0, x16..x31}).
  // When 1, rd may equal rs (same-register / RAW corner is reachable).
  bit relax_rd_rs = 0;

  bit [31:0] pc;  // Program counter received as `req_o` from the core
  bit [31:0] pc_if;  // Program counter inside the IF stage



  // Constraints

  constraint c_general {

    // Initial Constraint on reset
    soft rst_n dist {
      1 := 90,
      0 := 10
    };

    // Initially Constraint to have only R Type Instructions
    soft opcode == OP_R;

    // ---------------------------------------------------------------
    // Operand-pool policy (see rv32im_instr_seq.preload_operand_pool):
    //   x16..x31 hold the preloaded "interesting" constants.
    //   x8 ..x15 are the scratch destination registers.
    //
    // Every instruction that writes a destination must be steered to
    // the scratch range so the pool is never clobbered, INCLUDING the
    // control-flow and U-type instructions (their `rd` was previously
    // unconstrained and therefore destroyed the pool before the
    // directed phases ran).
    //
    // All three constraints are `soft`, so the directed phases can
    // still override them with hard `rd/rs1/rs2` assignments.
    //
    // CHK:I-03  Gate these on !relax_rd_rs so a test can drop the
    // partition (rd may equal rs, RAW becomes possible).
    // ---------------------------------------------------------------
    if (!relax_rd_rs) {
      if (opcode inside {OP_R, OP_IMM, OP_LOAD, OP_LUI, OP_AUIPC, OP_JAL, OP_JALR})
      soft rd inside {[8 : 15]};

      if (opcode inside {OP_R, OP_IMM}) soft rs1 inside {0, [16 : 31]};

      if (opcode inside {OP_R, OP_STORE}) soft rs2 inside {0, [16 : 31]};
    }

    // Valid values for funct7 for R/I types are 0, 1, 32
    funct7 inside {0, 1, 32};

    // ---------------------------------------------------------------
    // RV32IM only: every instruction is a 32-bit instruction, so every
    // instruction address must be 4-byte aligned.  Branch/JAL offsets
    // must therefore be multiples of 4.
    // we force 4-byte alignment, the compressed path is never taken.
    // ---------------------------------------------------------------
    b_imm13 % 4 == 0;
    jal_imm21 % 4 == 0;
  }


  constraint c_R_Type {

    solve opcode before ALU_MUL_sel;
    solve ALU_MUL_sel before R_rv32i_ops;
    solve ALU_MUL_sel before R_rv32m_ops;
    solve R_rv32i_ops before funct7;
    solve R_rv32m_ops before funct7;

    if (opcode == OP_R) {

      soft ALU_MUL_sel dist {
        ALU := 60,
        MUL_DIV := 40
      };

      if (ALU_MUL_sel == ALU) {
        R_rv32i_ops inside {ADD_SUB, SLL, SLT, SLTU, XOR, SRL_SRA, OR, AND};

        if (R_rv32i_ops == ADD_SUB) {
          funct7 dist {
            'd0  := 50,
            'd32 := 50
          };
        } else
        if (R_rv32i_ops == SRL_SRA) {
          funct7 dist {
            'd0  := 50,
            'd32 := 50
          };
        } else {
          funct7 == 'd0;
        }
      } else {
        R_rv32m_ops inside {MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU};
        funct7 == 'd1;
      }
    }
  }

  constraint c_I_type {

    solve opcode before I_ops;
    solve I_ops before funct7;

    if (opcode == OP_IMM) {
      I_ops inside {ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI_SRAI};

      if (I_ops == SRLI_SRAI)
      funct7 dist {
        'd0  := 50,
        'd32 := 50
      };
      else
      funct7 == 0;
    }
  }

  constraint c_Load_ops {
    solve opcode before Load_ops;
    if (opcode == OP_LOAD) {Load_ops inside {LB, LH, LW, LBU, LHU};}
  }

  constraint c_Store_ops {
    solve opcode before S_ops;
    if (opcode == OP_STORE) {S_ops inside {SB, SH, SW};}
  }

  constraint c_B_ops {
    solve opcode before B_ops;
    if (opcode == OP_BRANCH) {B_ops inside {BEQ, BNE, BLT, BGE, BLTU, BGEU};}
  }


  function new(string name = "rv32im_instr_seq_item");
    super.new(name);
  endfunction

  function void post_randomize();
    bit [6:0] opcode_x;

    opcode_x = opcode;

    case (opcode)
      OP_R: begin

        if (ALU_MUL_sel == ALU) begin
          funct3 = R_rv32i_ops;
        end else begin
          funct3 = R_rv32m_ops;
        end

        instruction = {funct7, rs2, rs1, funct3, rd, opcode_x};

      end

      OP_IMM: begin

        funct3 = I_ops;

        if (I_ops == SRLI_SRAI || I_ops == SLLI) begin
          instruction = {funct7, shamt, rs1, funct3, rd, opcode_x};
        end else instruction = {i_imm12, rs1, funct3, rd, opcode_x};

      end

      OP_LOAD: begin
        funct3 = Load_ops;
        instruction = {i_imm12, rs1, funct3, rd, opcode_x};
      end

      OP_STORE: begin
        funct3 = S_ops;
        instruction = {i_imm12[11:5], rs2, rs1, funct3, i_imm12[4:0], opcode_x};
      end

      OP_BRANCH: begin
        funct3 = B_ops;
        instruction = {
          b_imm13[12], b_imm13[10:5], rs2, rs1, funct3, b_imm13[4:1], b_imm13[11], opcode_x
        };
      end

      OP_JALR: begin
        funct3 = 3'h0;
        instruction = {i_imm12[11:0], rs1, funct3, rd, opcode_x};
      end

      OP_JAL: begin
        instruction = {
          jal_imm21[20], jal_imm21[10:1], jal_imm21[11], jal_imm21[19:12], rd, opcode_x
        };
      end

      default: begin  // LUI / AUIPC
        instruction = {u_imm20, rd, opcode_x};
      end
    endcase
  endfunction  // post_randomize

  virtual function string convert2string();
    string s;

    s = super.convert2string();

    case (opcode)
      OP_R: begin
        if (ALU_MUL_sel == ALU) begin
          alu_ops_t alu_op;
          alu_op = alu_ops_t'(funct3);
          case (alu_op)
            ADD_SUB: s = (funct7 == 'd0) ? "ADD" : "SUB";
            SRL_SRA: s = (funct7 == 'd0) ? "SRL" : "SRA";
            default: s = alu_op.name();
          endcase
          s = {s, $sformatf(" X%0d , X%0d , X%0d", rd, rs1, rs2)};
        end else begin
          mul_div_ops_t mul_op;
          mul_op = mul_div_ops_t'(funct3);
          s = $sformatf(" %s X%0d , X%0d , X%0d", mul_op.name(), rd, rs1, rs2);
        end
      end

      OP_IMM: begin
        I_ops_t alu_imm_op;
        alu_imm_op = I_ops_t'(funct3);
        case (alu_imm_op)
          SRLI_SRAI: s = (funct7 == 'd0) ? "SRLI" : "SRAI";
          default:   s = alu_imm_op.name();
        endcase

        if (alu_imm_op == SRLI_SRAI || alu_imm_op == SLLI)
          s = {s, $sformatf(" X%0d , X%0d , %0d", rd, rs1, shamt)};
        else s = {s, $sformatf(" X%0d , X%0d , %0d", rd, rs1, i_imm12)};
      end

      OP_LOAD: begin
        Load_ops_t load_op;
        load_op = Load_ops_t'(funct3);
        s = $sformatf(" %s X%0d , %0d (X%0d)", load_op.name(), rd, i_imm12, rs1);
      end

      OP_STORE: begin
        S_ops_t store_op;
        store_op = S_ops_t'(funct3);
        s = $sformatf(" %s X%0d , %0d (X%0d)", store_op.name(), rs2, i_imm12, rs1);
      end

      OP_BRANCH: begin
        B_ops_t branch_op;
        branch_op = B_ops_t'(funct3);
        s = $sformatf(" %s X%0d , X%0d , %0d", branch_op.name(), rs1, rs2, b_imm13);
      end

      OP_JAL: begin
        s = $sformatf(" %s X%0d , %0d", opcode.name(), rd, jal_imm21);
      end

      OP_JALR: begin
        s = $sformatf(" %s X%0d , %0d", opcode.name(), rd, i_imm12);
      end

      OP_AUIPC, OP_LUI: begin
        s = $sformatf(" %s X%0d , %0d", opcode.name(), rd, u_imm20);
      end
    endcase

    return s;
  endfunction  // convert2string


endclass  // rv32im_instr_seq_item
