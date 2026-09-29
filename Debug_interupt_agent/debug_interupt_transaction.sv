class debug_interupt_transaction extends uvm_sequence_item;
  `uvm_object_utils(debug_interupt_transaction)

  // Transaction fields

  logic [31:0] irq_i;  // CLINT interrupts + CLINT extension interrupts
  logic        irq_ack_o;
  logic [ 4:0] irq_id_o;

  // Debug Interface
  logic        debug_req_i;
  logic        debug_havereset_o;
  logic        debug_running_o;
  logic        debug_halted_o;

  // CPU Control Signals
  logic        fetch_enable_i;
  logic        core_sleep_o;

  // Constructor
  function new(string name = "debug_interupt_transaction");
    super.new(name);
  endfunction
  task convert2string();
    $display(
        "irq_i: %0h, irq_ack_o: %0b, irq_id_o: %0h, debug_req_i: %0b, debug_havereset_o: %0b, debug_running_o: %0b, debug_halted_o: %0b, fetch_enable_i: %0b, core_sleep_o: %0b",
        irq_i, irq_ack_o, irq_id_o, debug_req_i, debug_havereset_o, debug_running_o,
        debug_halted_o, fetch_enable_i, core_sleep_o);
  endtask
endclass
