
interface alu_if (
    input   logic        clk, 
    input   logic        rst_n,
    input   logic        enable_i,
    input   logic [6:0]  operator_i,     
    input   logic [31:0] operand_a_i,
    input   logic [31:0] operand_b_i,
    input   logic [31:0] operand_c_i,
    input   logic [31:0] result_o,
    input   logic        comparison_result_o,
    input   logic        ready_o,
    input   logic        ex_ready_i ,
    input   logic        pc_ex            // PC in ex stage used as tracking id in the pipeline but only takes value in case of jump/branch 
  );

  clocking cb_mon @(posedge clk);
      default input #1;
      input rst_n;
      input enable_i;
      input operator_i;
      input operand_a_i;
      input operand_b_i;
      input operand_c_i;
      input result_o;
      input comparison_result_o;
      input ready_o;
      input ex_ready_i;
      input pc_ex;
  endclocking

endinterface
