interface debug_interupt_if(
  input logic        clk,
  input logic        rst_n
);

  logic [31:0] irq_i;  // CLINT interrupts + CLINT extension interrupts
  logic        irq_ack_o;
  logic [ 4:0] irq_id_o;

  // 
  logic scan_cg_en_i;

  // Debug Interface
  logic        debug_req_i;
  logic        debug_havereset_o;
  logic        debug_running_o;
  logic        debug_halted_o;

  // CPU Control Signals
  logic        fetch_enable_i;
  logic        core_sleep_o;

  clocking cb_driver @(posedge clk);
    default input #1step output #0;
    input irq_ack_o, irq_id_o, debug_havereset_o, debug_running_o, debug_halted_o, core_sleep_o;
    output irq_i,debug_req_i, fetch_enable_i , scan_cg_en_i;
  endclocking
  
  clocking cb_monitor @(posedge clk);
    default input #1step;
    input rst_n,irq_i, irq_ack_o, irq_id_o, debug_req_i, debug_havereset_o, debug_running_o, debug_halted_o, fetch_enable_i, core_sleep_o , scan_cg_en_i;
  endclocking

  modport driver_mp(clocking cb_driver);
  modport monitor_mp(clocking cb_monitor);
endinterface
