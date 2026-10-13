class reactive_data_agent extends uvm_agent;

  `uvm_component_utils(reactive_data_agent)

  // Virtual interface handle
  virtual obi_data_if vif;

  reactive_data_monitor monitor;
  reactive_data_sequencer sequencer;
  reactive_data_driver driver;


  uvm_analysis_port #(data_transaction) transaction_ap;  //full transaction
  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual obi_data_if)::get(this, "", "DATA_IF", vif)) begin

      `uvm_fatal(get_name(), "NOVIF - Virtual interface not set");

    end
    driver = reactive_data_driver::type_id::create("driver", this);
    monitor = reactive_data_monitor::type_id::create("monitor", this);
    sequencer = reactive_data_sequencer::type_id::create("sequencer", this);

    transaction_ap = new("transaction_ap", this);

  endfunction

  // Connect phase
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    monitor.request_ap.connect(
        sequencer.req_export); // Connect the monitor request transaction to the sequencer fifo thorugh the sequencer export port
    driver.seq_item_port.connect(
        sequencer.seq_item_export);  // Connect the sequencer to the driver

    // Connect the virtual interface retreived at the agent to the driver/monitor
    driver.vif  = vif;
    monitor.vif = vif;

    // Connect the monitor transaction_ap to the agent transaction_ap for scoreboard and coverage
    monitor.transaction_ap.connect(transaction_ap);
  endfunction
endclass
