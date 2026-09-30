class reactive_data_monitor extends uvm_monitor;

  `uvm_component_utils(reactive_data_monitor)

  // Virtual interface handle
  virtual obi_data_if.monitor_mp vif;

  uvm_analysis_port #(data_transaction) transaction_ap;  // full transaction
  uvm_analysis_port #(data_transaction) request_ap;  // partial request transaction

  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
    transaction_ap = new("transaction_ap", this);
    request_ap = new("request_ap", this);
  endfunction

  // Build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    // Queue to hold in-flight transactions for pipelined responses
    data_transaction pending_req_q[$];

    // Fork parallel threads to monitor Address Handshakes and Response Handshakes
    fork
      sample_address_phase(pending_req_q);
      sample_response_phase(pending_req_q);
    join
  endtask

  // ------------------------------------------------------------------
  // 1. Address Phase Thread (Detects Handshake: req_o == 1 && gnt_i == 1)
  // ------------------------------------------------------------------
  task sample_address_phase(ref data_transaction pending_q[$]);
    forever begin
      // @(posedge vif.clk);
      @(vif.cb_monitor)

      // if (vif.rst_n) begin
      if (vif.cb_monitor.rst_n) begin
        // OBI Protocol: Address phase completes when BOTH req and gnt are high
        if (vif.cb_monitor.data_req_o) begin
          data_transaction req_tr;
          req_tr = data_transaction::type_id::create("req_tr");

          // Capture Address Phase Signals
          req_tr.data_addr_o  = vif.cb_monitor.data_addr_o;
          req_tr.data_we_o    = vif.cb_monitor.data_we_o;
          req_tr.data_be_o    = vif.cb_monitor.data_be_o;
          req_tr.data_wdata_o = vif.cb_monitor.data_wdata_o;

          // Push to sequencer's FIFO so reactive sequence can calculate response
          request_ap.write(req_tr);

          // Push clone to queue to await rvalid/rdata matching
          pending_q.push_back(req_tr);
        end
      end else begin
        pending_q.delete();  // Clear pipeline on reset
      end
    end
  endtask

  // ------------------------------------------------------------------
  // 2. Response Phase Thread (Detects Handshake: rvalid_i == 1)
  // ------------------------------------------------------------------
  task sample_response_phase(ref data_transaction pending_q[$]);
    data_transaction completed_tr;

    forever begin
      // @(posedge vif.clk);
      @(posedge vif.cb_monitor);

      if (vif.cb_monitor.rst_n) begin
        // OBI Protocol: Response phase completes when rvalid_i is high
        if (vif.cb_monitor.data_rvalid_i) begin
          if (pending_q.size() > 0) begin
            // Match response to oldest in-flight request (FIFO order)
            completed_tr = pending_q.pop_front();

            // Capture read data if it was a READ operation
            if (!completed_tr.data_we_o) begin
              completed_tr.data_rdata_i = vif.cb_monitor.data_rdata_i;
            end

            // Broadcast fully completed transaction to Scoreboard and Coverage
            transaction_ap.write(completed_tr);
          end else begin
            `uvm_error("MON_PROTOCOL_ERROR",
                       "Received data_rvalid_i without an in-flight address request!")
          end
        end
      end
    end
  endtask

endclass
