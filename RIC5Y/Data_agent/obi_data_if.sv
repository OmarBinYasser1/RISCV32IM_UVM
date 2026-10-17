interface obi_data_if (
    input logic clk,
    input logic rst_n
);

  // Driven by the testbench
  logic        data_gnt_i = 1'b0;
  logic        data_rvalid_i = 1'b0;
  logic [31:0] data_rdata_i = '0;

  // Driven by the DUT
  logic        data_req_o;
  logic        data_we_o;
  logic [ 3:0] data_be_o;
  logic [31:0] data_addr_o;
  logic [31:0] data_wdata_o;

  clocking cb_driver @(posedge clk);
    default input #1step output #0;
    input rst_n, data_req_o, data_we_o, data_be_o, data_addr_o, data_wdata_o;
    output data_gnt_i, data_rvalid_i, data_rdata_i;
  endclocking

  clocking cb_monitor @(posedge clk);
    default input #1step;
    input rst_n, data_req_o, data_gnt_i, data_rvalid_i,
          data_we_o, data_be_o, data_addr_o, data_wdata_o, data_rdata_i;
  endclocking

  modport driver_mp(clocking cb_driver);
  modport monitor_mp(clocking cb_monitor);

endinterface
