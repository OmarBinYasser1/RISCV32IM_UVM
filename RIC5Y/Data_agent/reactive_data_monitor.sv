class reactive_data_monitor extends uvm_monitor;
  `uvm_component_utils(reactive_data_monitor)

  virtual obi_data_if.monitor_mp        vif;

  uvm_analysis_port #(data_transaction) request_ap;  // -> reactive sequence
  uvm_analysis_port #(data_transaction) transaction_ap;  // -> scoreboard + OBI coverage

  localparam int MAX_OUT = 2;  //outstanding max

  bit waiting_gnt = 0;  // published, not yet granted
  data_transaction pub_tr;  // the request that was published
  data_transaction accepted_q[$];  // granted, waiting for rvalid (oldest first)

  int unsigned n_pub = 0, n_acc = 0, n_cmp = 0;
  int unsigned cycle_count = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);

    request_ap     = new("request_ap", this);
    transaction_ap = new("transaction_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    bit rst, req, gnt, rvalid;
    data_transaction tr;

    forever begin
      @(vif.cb_monitor);
      cycle_count++;

      rst    = (vif.cb_monitor.rst_n === 1'b1);
      req    = (vif.cb_monitor.data_req_o === 1'b1);
      gnt    = (vif.cb_monitor.data_gnt_i === 1'b1);
      rvalid = (vif.cb_monitor.data_rvalid_i === 1'b1);

      if (!rst) begin
        if (waiting_gnt || accepted_q.size() > 0) accepted_q.delete();
        waiting_gnt = 0;
        continue;
      end

      // Response: completes the oldest granted request.
      if (rvalid) begin
        if (accepted_q.size() == 0) begin
          `uvm_error("data_mon", "rvalid with no granted request")
        end else begin
          tr = accepted_q.pop_front();
          tr.cycle_at_rvalid = cycle_count;
          if (!tr.data_we_o) tr.data_rdata_i = vif.cb_monitor.data_rdata_i;
          n_cmp++;

          transaction_ap.write(tr);
        end
      end

      if (req && !waiting_gnt) begin
        pub_tr                  = sample_bus();
        pub_tr.cycle_at_publish = cycle_count;
        waiting_gnt             = 1;
        n_pub++;

        request_ap.write(pub_tr);
      end

      // Handshake 
      if (req && gnt) begin
        tr = sample_bus();
        if (tr.data_addr_o !== pub_tr.data_addr_o || tr.data_we_o !== pub_tr.data_we_o)
          `uvm_error("data_mon", $sformatf(
                     "request changed before grant: published addr=%08h we=%0b, granted addr=%08h we=%0b",
                     pub_tr.data_addr_o,
                     pub_tr.data_we_o,
                     tr.data_addr_o,
                     tr.data_we_o
                     ))
        tr.cycle_at_grant   = cycle_count;
        tr.cycle_at_publish = pub_tr.cycle_at_publish;
        waiting_gnt         = 0;
        accepted_q.push_back(tr);
        tr.outstanding_at_grant = accepted_q.size();
        n_acc++;

        if (accepted_q.size() > MAX_OUT)
          `uvm_error("data_mon", $sformatf("%0d outstanding, max_outstanding = 2", accepted_q.size()
                     ))
      end
    end
  endtask
  function automatic data_transaction sample_bus();
    data_transaction t;
    t = data_transaction::type_id::create("t");
    t.data_req_o  = vif.cb_monitor.data_req_o;
    t.data_addr_o  = vif.cb_monitor.data_addr_o;
    t.data_we_o    = vif.cb_monitor.data_we_o;
    t.data_be_o    = vif.cb_monitor.data_be_o;
    t.data_wdata_o = vif.cb_monitor.data_wdata_o;
    return t;
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (waiting_gnt) `uvm_error("data_mon", "a request was published but never granted")
    if (accepted_q.size() > 0)
      `uvm_error("data_mon", $sformatf("%0d granted requests never got rvalid", accepted_q.size()))
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("data_mon", $sformatf(
              "SUMMARY: published=%0d accepted=%0d completed=%0d", n_pub, n_acc, n_cmp), UVM_NONE)
  endfunction

endclass
