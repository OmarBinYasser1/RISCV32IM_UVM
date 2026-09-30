
interface alu_if (input logic clk, input logic rst_n);

  logic        enable_i;
  logic [6:0]  operator_i;      
  logic [31:0] operand_a_i;     
  logic [31:0] operand_b_i;     
  logic [31:0] operand_c_i;
  logic [31:0] result_o;  
  logic        comparison_result_o;      
  logic        ready_o;         
  logic        ex_ready_i;      
  
endinterface
