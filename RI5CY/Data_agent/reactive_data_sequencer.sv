class reactive_data_sequencer extends uvm_sequencer #(data_transaction);

  `uvm_component_utils(reactive_data_sequencer)

  uvm_analysis_export #(data_transaction)   req_export; //The request_export connects to the monitor’s request_aport, routing requests into the FIFO.
  uvm_tlm_analysis_fifo #(data_transaction) req_fifo_x;  //The request_fifo stores incoming requests from monitor, allowing sequences to block via get() until a request is available.


  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
    req_fifo_x   = new("req_fifo_x", this);
    req_export = new("req_export", this);
  endfunction

  // connect phase
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    req_export.connect(req_fifo_x.analysis_export);
  endfunction
endclass
