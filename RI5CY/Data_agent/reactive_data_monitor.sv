class reactive_data_monitor extends uvm_monitor;
  `uvm_component_utils(reactive_data_monitor)

  virtual obi_data_if.monitor_mp        vif;

  uvm_analysis_port #(data_transaction) request_ap;  // -> reactive sequence
  uvm_analysis_port #(data_transaction) transaction_ap;  // -> scoreboard + OBI coverage

  localparam int MAX_OUT = 2;  // used for the outstanding check; this milestone never exceeds 1

  bit dbg = 1;  // 0 silences MON messages

  bit waiting_gnt = 0;  // published, not yet granted
  data_transaction pub_tr;  // the request that was published
  data_transaction accepted_q[$];  // granted, waiting for rvalid (oldest first)

  int unsigned n_pub = 0, n_acc = 0, n_cmp = 0;

  // CHK:V-17  Free-running cycle counter for the OBI timing coverage.
  int unsigned cycle_count = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    request_ap     = new("request_ap", this);
    transaction_ap = new("transaction_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

  endfunction

  function void dbg_msg(string s);
    if (dbg) `uvm_info("MON", s, UVM_NONE)
  endfunction

  // A fresh object from the current bus sample
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

  // ---------------------------------------------------------------
  // One wait per clock. Checks run in a fixed order each cycle.
  // ---------------------------------------------------------------
  task run_phase(uvm_phase phase);
    bit rst, req, gnt, rvalid;
    data_transaction tr;

    forever begin
      @(vif.cb_monitor);
      cycle_count++;   // CHK:V-17

      rst    = (vif.cb_monitor.rst_n === 1'b1);
      req    = (vif.cb_monitor.data_req_o === 1'b1);
      gnt    = (vif.cb_monitor.data_gnt_i === 1'b1);
      rvalid = (vif.cb_monitor.data_rvalid_i === 1'b1);

      if (!rst) begin
        if (waiting_gnt || accepted_q.size() > 0)
          dbg_msg($sformatf(
                  "t=%0t reset: dropping %0d granted, waiting=%0b",
                  $time,
                  accepted_q.size(),
                  waiting_gnt
                  ));
        accepted_q.delete();
        waiting_gnt = 0;
        continue;
      end

      // 1. Response: completes the oldest granted request.
      if (rvalid) begin
        if (accepted_q.size() == 0) begin
          `uvm_error("MON", "rvalid with no granted request")
        end else begin
          tr = accepted_q.pop_front();
          tr.cycle_at_rvalid = cycle_count;   // CHK:V-17
          if (!tr.data_we_o) tr.data_rdata_i = vif.cb_monitor.data_rdata_i;
          n_cmp++;
          dbg_msg($sformatf(
                  "t=%0t COMPLETE req_o =%0b we=%0b addr=%08h rdata=%08h",
                  $time,
                  tr.data_req_o,
                  tr.data_we_o,
                  tr.data_addr_o,
                  tr.data_rdata_i
                  ));
          transaction_ap.write(tr);
        end
      end

      // 2. Request: publish once, on the first edge req is high and nothing is waiting
      if (req && !waiting_gnt) begin
        pub_tr      = sample_bus();
        pub_tr.cycle_at_publish = cycle_count;   // CHK:V-17
        waiting_gnt = 1;
        n_pub++;
        dbg_msg($sformatf(
                "t=%0t PUBLISH req_0=%0b we=%0b addr=%08h wdata=%08h be=%b",
                $time,
                pub_tr.data_req_o,
                pub_tr.data_we_o,
                pub_tr.data_addr_o,
                pub_tr.data_wdata_o,
                pub_tr.data_be_o
                ));
        request_ap.write(pub_tr);
      end

      // 3. Handshake: the waiting request is granted
      if (req && gnt) begin
        tr = sample_bus();
        if (tr.data_addr_o !== pub_tr.data_addr_o || tr.data_we_o !== pub_tr.data_we_o)
          `uvm_error("MON", $sformatf(
                     "request changed before grant: published addr=%08h we=%0b, granted addr=%08h we=%0b",
                     pub_tr.data_addr_o,
                     pub_tr.data_we_o,
                     tr.data_addr_o,
                     tr.data_we_o
                     ))
        tr.cycle_at_grant     = cycle_count;    // CHK:V-17
        tr.cycle_at_publish   = pub_tr.cycle_at_publish;
        waiting_gnt = 0;
        accepted_q.push_back(tr);
        tr.outstanding_at_grant = accepted_q.size();  // CHK:V-17
        n_acc++;
        dbg_msg($sformatf(
                "t=%0t ACCEPT we=%0b addr=%08h outstanding=%0d",
                $time,
                tr.data_we_o,
                tr.data_addr_o,
                accepted_q.size()
                ));
        if (accepted_q.size() > MAX_OUT)
          `uvm_error("MON", $sformatf("%0d outstanding, limit is %0d", accepted_q.size(), MAX_OUT))
      end
    end
  endtask

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (waiting_gnt) `uvm_error("MON", "a request was published but never granted")
    if (accepted_q.size() > 0)
      `uvm_error("MON", $sformatf("%0d granted requests never got rvalid", accepted_q.size()))
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("MON", $sformatf(
              "SUMMARY: published=%0d accepted=%0d completed=%0d", n_pub, n_acc, n_cmp), UVM_NONE)
  endfunction

endclass