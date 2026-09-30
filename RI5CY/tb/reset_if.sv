interface reset_if (
    //clk and reset
    input logic clk

);

  // inputs
  logic rst_n;


  clocking cb_driver @(posedge clk);
    default input #1step output #1step;

    input rst_n, clk;
  endclocking

  clocking cb_monitor @(posedge clk);
    default input #1step;
    input rst_n, clk;
  endclocking

  //modport for the driver
  modport driver_mp(clocking cb_driver);
  //modport for the monitor
  modport monitor_mp(clocking cb_monitor);
endinterface
