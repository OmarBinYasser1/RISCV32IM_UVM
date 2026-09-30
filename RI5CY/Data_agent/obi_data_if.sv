interface obi_data_if(
   //clk and reset
  input logic        clk,
  input logic        rst_n
);

  // inputs
  logic        data_rvalid_i;
  logic        data_gnt_i;
  logic [31:0] data_rdata_i;
  //outputs

  logic        data_req_o;
  logic        data_we_o;
  logic [ 3:0] data_be_o;
  logic [31:0] data_addr_o;
  logic [31:0] data_wdata_o;


  clocking cb_driver @(posedge clk);
    default input #1step output #1step;

    input rst_n,data_req_o, data_we_o, data_be_o, data_addr_o, data_wdata_o;
    output data_gnt_i, data_rvalid_i, data_rdata_i;
  endclocking

  clocking cb_monitor @(posedge clk);
    default input #1step;
    input rst_n,data_req_o,data_gnt_i,data_rvalid_i,data_we_o,data_be_o,data_addr_o,data_wdata_o,data_rdata_i;
  endclocking

  //modport for the driver
  modport driver_mp(clocking cb_driver);
  //modport for the monitor
  modport monitor_mp(clocking cb_monitor);

endinterface
