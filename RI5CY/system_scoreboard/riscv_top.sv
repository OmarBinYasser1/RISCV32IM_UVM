module riscv_top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import riscv_pkg::*;

  logic clk, rst_n;

  initial clk = 0;
  always #5 clk = ~clk;

  alu_if     alu_vif    (.clk(clk), .rst_n(rst_n));
  mul_if     mul_vif    (.clk(clk), .rst_n(rst_n));
  regfile_if rf_vif     (.clk(clk), .rst_n(rst_n));

  // DUT would be instantiated here
  
  initial begin
    uvm_config_db#(virtual alu_if)::set(null,     "uvm_test_top.*", "alu_vif",     alu_vif);
    uvm_config_db#(virtual mul_if)::set(null,     "uvm_test_top.*", "mul_vif",     mul_vif);
    uvm_config_db#(virtual regfile_if)::set(null, "uvm_test_top.*", "regfile_vif", rf_vif);

    rst_n = 0;
    #20;
    rst_n = 1;
    run_test("riscv_base_test");
  end
endmodule
