class debug_interupt_agent extends uvm_agent;
  `uvm_component_utils(debug_interupt_agent)

  // Agent components
  debug_interupt_sequencer sequencer;
  debug_interupt_driver    driver;
  debug_interupt_monitor   monitor;

  // Transaction analysis port for scoreboard and coverage
  uvm_analysis_port #(debug_interupt_transaction) transaction_ap;

  function new(string name = "debug_interupt_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create the sequencer, driver, and monitor
    sequencer = debug_interupt_sequencer::type_id::create("sequencer", this);
    driver    = debug_interupt_driver::type_id::create("driver", this);
    monitor   = debug_interupt_monitor::type_id::create("monitor", this);

    // Connect the monitor transaction_ap to the agent transaction_ap for scoreboard and coverage
    monitor.transaction_ap.connect(transaction_ap);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect the sequencer to the driver
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
