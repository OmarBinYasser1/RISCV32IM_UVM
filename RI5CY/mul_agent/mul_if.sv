
interface mul_if (
    input logic        clk,
    input logic        rst_n,
    input logic        enable_i,
    input logic [2:0]  operator_i,
    input logic [1:0]  short_signed_i,   //  MULH=11 MULHSU=01 MULHU=00
    input logic [31:0] op_a_i,
    input logic [31:0] op_b_i,
    input logic [31:0] op_c_i,
    input logic [31:0] result_o,
    input logic        ready_o,
    input logic        ex_ready_i
  );

  clocking cb_mon @(posedge clk);
      default input #1;
      input rst_n;
      input enable_i;
      input operator_i;
      input short_signed_i;              
      input op_a_i;
      input op_b_i;
      input op_c_i;
      input result_o;
      input ready_o;
      input ex_ready_i;
  endclocking

endinterface
