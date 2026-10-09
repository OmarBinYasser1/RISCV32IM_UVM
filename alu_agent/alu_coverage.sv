
`define ALU_ADD  7'b0011000
`define ALU_SUB  7'b0011001
`define ALU_XOR  7'b0101111
`define ALU_OR   7'b0101110
`define ALU_AND  7'b0010101
`define ALU_SRA  7'b0100100
`define ALU_SRL  7'b0100101
`define ALU_SLL  7'b0100111
`define ALU_SLTS 7'b0000010
`define ALU_SLTU 7'b0000011
`define ALU_DIVU 7'b0110000
`define ALU_DIV  7'b0110001
`define ALU_REMU 7'b0110010
`define ALU_REM  7'b0110011

class alu_coverage extends uvm_subscriber #(alu_item);
  `uvm_component_utils(alu_coverage)

  alu_item item;   

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

 
  function bit is_neg(bit [31:0] v);
    return v[31];
  endfunction

  
  function int pattern_of(bit [31:0] v);
    if (v == 32'h0)                     return 0;
    if (v == 32'hFFFF_FFFF)             return 1;
    if ((v & (v - 1)) == 0)             return 2;
    if (((~v) & ((~v) - 1)) == 0)       return 3;
    return 4;
  endfunction

  
  function bit add_overflowed();
    return (item.operand_a[31] == item.operand_b[31]) &&
           (item.result[31]    != item.operand_a[31]);
  endfunction

  function bit sub_overflowed();
    return (item.operand_a[31] != item.operand_b[31]) &&
           (item.result[31]    != item.operand_a[31]);
  endfunction

 
  function bit [4:0] shamt();
    return item.operand_b[4:0];
  endfunction

  
  covergroup addsub_cg;
    option.per_instance = 1;

    cp_op: coverpoint item.operator {
      bins add = {`ALU_ADD};
      bins sub = {`ALU_SUB};
    }
    cp_sign_a: coverpoint is_neg(item.operand_a) { bins pos = {0}; bins neg = {1}; }
    cp_sign_b: coverpoint is_neg(item.operand_b) { bins pos = {0}; bins neg = {1}; }

    cp_overflow: coverpoint ((item.operator == `ALU_ADD) ? add_overflowed() : sub_overflowed()) {
      bins no_overflow = {0};
      bins overflow    = {1};
    }

    addi_overflow_cov: cross cp_op, cp_sign_a, cp_sign_b, cp_overflow;
  endgroup

 
  covergroup slt_cg;
    option.per_instance = 1;

    cp_op: coverpoint item.operator {
      bins slt  = {`ALU_SLTS};
      bins sltu = {`ALU_SLTU};
    }
    cp_sign_a: coverpoint is_neg(item.operand_a) { bins pos = {0}; bins neg = {1}; }
    cp_sign_b: coverpoint is_neg(item.operand_b) { bins pos = {0}; bins neg = {1}; }
    cp_result: coverpoint item.result[0]         { bins zero = {0}; bins one = {1}; }

    slti_cov:  cross cp_sign_a, cp_sign_b, cp_result iff (item.operator == `ALU_SLTS);
    sltiu_cov: cross cp_sign_a, cp_sign_b, cp_result iff (item.operator == `ALU_SLTU);

    
    sltiu_seqz_cov: coverpoint item.operand_b iff (item.operator == `ALU_SLTU) {
      bins seqz_imm_one = {32'h1};
    }
  endgroup

  covergroup bitwise_cg;
    option.per_instance = 1;

    cp_op: coverpoint item.operator {
      bins and_ = {`ALU_AND};
      bins or_  = {`ALU_OR};
      bins xor_ = {`ALU_XOR};
    }
    cp_pat_a: coverpoint pattern_of(item.operand_a) {
      bins zero      = {0};
      bins all_ones  = {1};
      bins walking_1 = {2};
      bins walking_0 = {3};
      ignore_bins other = {4};
    }
    cp_pat_b: coverpoint pattern_of(item.operand_b) {
      bins zero      = {0};
      bins all_ones  = {1};
      bins walking_1 = {2};
      bins walking_0 = {3};
      ignore_bins other = {4};
    }

    bitwise_imm_cov: cross cp_op, cp_pat_a, cp_pat_b;
  endgroup

  covergroup shift_cg;
    option.per_instance = 1;

    cp_op: coverpoint item.operator {
      bins sll = {`ALU_SLL};
      bins srl = {`ALU_SRL};
      bins sra = {`ALU_SRA};
    }
    cp_shamt: coverpoint shamt() {
      bins s0  = {0};
      bins s1  = {1};
      bins s15 = {15};
      bins s31 = {31};
      bins other = default;
    }
    cp_rs1_msb: coverpoint item.operand_a[31] { bins zero = {0}; bins one = {1}; }

    
    slli_cov: coverpoint shamt() iff (item.operator == `ALU_SLL) {
      bins s0  = {0};
      bins s1  = {1};
      bins s15 = {15};
      bins s31 = {31};
    }
    srli_cov: cross cp_shamt, cp_rs1_msb iff (item.operator == `ALU_SRL);
    srai_cov: cross cp_shamt, cp_rs1_msb iff (item.operator == `ALU_SRA);
  endgroup


  covergroup div_cg;
    option.per_instance = 1;

    cp_op: coverpoint item.operator {
      bins div  = {`ALU_DIV};
      bins divu = {`ALU_DIVU};
    }
    cp_sign_a: coverpoint is_neg(item.operand_a) { bins pos = {0}; bins neg = {1}; }
    cp_sign_b: coverpoint is_neg(item.operand_b) { bins pos = {0}; bins neg = {1}; }

    cp_res_sign: coverpoint item.result[31] { bins pos = {0}; bins neg = {1}; }

    
    div_sign_cross_cov: cross cp_op, cp_sign_a, cp_sign_b, cp_res_sign {
      ignore_bins divu_cross = binsof(cp_op) intersect {`ALU_DIVU};
    }

  
    divu_msb_cross_cov: cross cp_sign_a, cp_sign_b iff (item.operator == `ALU_DIVU);

    
    cp_boundary_a: coverpoint item.operand_a {
      bins zero    = {32'h0000_0000};
      bins pos_one = {32'h0000_0001};
      bins neg_one = {32'hFFFF_FFFF};
      bins max_pos = {32'h7FFF_FFFF};
      bins min_neg = {32'h8000_0000};
    }
    cp_boundary_b: coverpoint item.operand_b {
      bins zero    = {32'h0000_0000};
      bins pos_one = {32'h0000_0001};
      bins neg_one = {32'hFFFF_FFFF};
      bins max_pos = {32'h7FFF_FFFF};
      bins min_neg = {32'h8000_0000};
    }
    div_boundary_val_cov: cross cp_op, cp_boundary_a, cp_boundary_b;

    
    cp_div_zero: coverpoint (item.operand_b == 32'h0) { bins zero = {1}; }
    div_zero_cov: cross cp_op, cp_div_zero;

   
    div_overflow_cov: coverpoint item.operator
        iff (item.operator == `ALU_DIV &&
             item.operand_a == 32'h8000_0000 &&
             item.operand_b == 32'hFFFF_FFFF) {
      bins int_min_div_minus1 = {`ALU_DIV};
    }

   
  endgroup

 
  covergroup rem_cg;
    option.per_instance = 1;

    cp_op: coverpoint item.operator {
      bins rem  = {`ALU_REM};
      bins remu = {`ALU_REMU};
    }
    cp_sign_a: coverpoint is_neg(item.operand_a) { bins pos = {0}; bins neg = {1}; }
    cp_sign_b: coverpoint is_neg(item.operand_b) { bins pos = {0}; bins neg = {1}; }

    cp_res_sign: coverpoint item.result[31] { bins pos = {0}; bins neg = {1}; }

    
    rem_sign_cross_cov: cross cp_op, cp_sign_a, cp_sign_b, cp_res_sign {
      ignore_bins remu_cross = binsof(cp_op) intersect {`ALU_REMU};
    }

   
    remu_msb_cross_cov: cross cp_sign_a, cp_sign_b iff (item.operator == `ALU_REMU);

    
    cp_boundary_a: coverpoint item.operand_a {
      bins zero    = {32'h0000_0000};
      bins pos_one = {32'h0000_0001};
      bins neg_one = {32'hFFFF_FFFF};
      bins max_pos = {32'h7FFF_FFFF};
      bins min_neg = {32'h8000_0000};
    }
    cp_boundary_b: coverpoint item.operand_b {
      bins zero    = {32'h0000_0000};
      bins pos_one = {32'h0000_0001};
      bins neg_one = {32'hFFFF_FFFF};
      bins max_pos = {32'h7FFF_FFFF};
      bins min_neg = {32'h8000_0000};
    }
    rem_boundary_val_cov: cross cp_op, cp_boundary_a, cp_boundary_b;

  
    cp_div_zero: coverpoint (item.operand_b == 32'h0) {
      bins zero = {1};
    }
    rem_div_zero_cov: cross cp_op, cp_div_zero;

    
    rem_overflow_cov: coverpoint item.operator
        iff (item.operator == `ALU_REM &&
             item.operand_a == 32'h8000_0000 &&
             item.operand_b == 32'hFFFF_FFFF) {
      bins int_min_rem_minus1 = {`ALU_REM};
    }

  endgroup


  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    addsub_cg  = new();
    slt_cg     = new();
    bitwise_cg = new();
    shift_cg   = new();
    div_cg     = new();
    rem_cg     = new();
  endfunction

  
  function void write(alu_item t);
    item = t;
    case (item.operator)
      `ALU_ADD, `ALU_SUB:               addsub_cg.sample();
      `ALU_SLTS, `ALU_SLTU:             slt_cg.sample();
      `ALU_AND, `ALU_OR, `ALU_XOR:      bitwise_cg.sample();
      `ALU_SLL, `ALU_SRL, `ALU_SRA:     shift_cg.sample();
      `ALU_DIV, `ALU_DIVU:              div_cg.sample();
      `ALU_REM, `ALU_REMU:              rem_cg.sample();
      default: ; // other ALU opcodes are out of scope (COREV_PULP = 0)
    endcase
  endfunction
endclass
