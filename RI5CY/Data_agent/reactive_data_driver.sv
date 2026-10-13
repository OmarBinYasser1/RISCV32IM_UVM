

class reactive_data_driver extends uvm_driver #(data_transaction);
  `uvm_component_utils(reactive_data_driver)

  virtual obi_data_if.driver_mp vif;

  bit dbg = 1;  // 0 silences DRV messages
  bit [31:0] mem[bit [31:2]];  // word-addressed data memory

  // Values captured at the handshake edge
  bit [31:0] c_addr, c_wdata, c_rdata;
  bit c_we;
  bit [3:0] c_be;

  int unsigned n_grant = 0;
  int unsigned n_rsp = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

  endfunction

  function void dbg_msg(string s);
    if (dbg) `uvm_info("DRV", s, UVM_NONE)
  endfunction

  // ---------------------------------------------------------------
  // Main loop: one request at a time
  // ---------------------------------------------------------------
  task run_phase(uvm_phase phase);
    data_transaction resp_item;

    drive_idle();

    forever begin
      wait_for_request();  // req is high, reset is released

      seq_item_port.get_next_item(resp_item);
      dbg_msg($sformatf(
              "t=%0t ITEM gnt_delay=%0d rvalid_delay=%0d addr=%08h we=%0b be=%b",
              $time,
              resp_item.gnt_delay,
              resp_item.rvalid_delay,
              resp_item.data_addr_o,
              resp_item.data_we_o,
              resp_item.data_be_o
              ));

      do_grant(resp_item);
      do_response(resp_item);

      seq_item_port.item_done();
    end
  endtask

  // ---------------------------------------------------------------
  // Stage 1: wait for a request
  // ---------------------------------------------------------------
  task wait_for_request();
    forever begin
      @(vif.cb_driver);
      if (vif.cb_driver.rst_n === 1'b1 && vif.cb_driver.data_req_o === 1'b1) return;
    end
  endtask

  // ---------------------------------------------------------------
  // Stage 2: grant after gnt_delay, capture the bus at the handshake
  // ---------------------------------------------------------------
  task do_grant(data_transaction item);
    // Wait gnt_delay cycles. req must stay high while we wait.
    repeat (item.gnt_delay) begin
      @(vif.cb_driver);
      if (vif.cb_driver.data_req_o !== 1'b1) `uvm_error("DRV", "req dropped during gnt_delay")
    end

    // Drive gnt now. The DUT samples it on the next edge (the handshake).
    vif.cb_driver.data_gnt_i <= 1'b1;
    @(vif.cb_driver);

    // Handshake edge: capture the request the DUT is granting
    c_addr  = vif.cb_driver.data_addr_o;
    c_we    = vif.cb_driver.data_we_o;
    c_be    = vif.cb_driver.data_be_o;
    c_wdata = vif.cb_driver.data_wdata_o;
    vif.cb_driver.data_gnt_i <= 1'b0;  // one-cycle pulse
    n_grant++;

    if (vif.cb_driver.data_req_o !== 1'b1) `uvm_error("DRV", "req low at the handshake edge")

    if (c_addr !== item.data_addr_o || c_we !== item.data_we_o)
      `uvm_error("DRV", $sformatf(
                 "bus vs item: bus addr=%08h we=%0b, item addr=%08h we=%0b",
                 c_addr,
                 c_we,
                 item.data_addr_o,
                 item.data_we_o
                 ))

    dbg_msg($sformatf(
            "t=%0t GRANT #%0d addr=%08h we=%0b be=%b wdata=%08h",
            $time,
            n_grant,
            c_addr,
            c_we,
            c_be,
            c_wdata
            ));
  endtask

  // ---------------------------------------------------------------
  // Stage 3: respond after rvalid_delay, access memory once
  // ---------------------------------------------------------------
  task do_response(data_transaction item);
    // rvalid_delay = 0 drives rvalid on the handshake edge,
    // so it is visible for the cycle right after the grant.
    repeat (item.rvalid_delay) @(vif.cb_driver);

    if (c_we) begin
      write_word(c_addr, c_wdata, c_be);
      c_rdata = '0;
    end else begin
      c_rdata = read_word(c_addr);
    end

    vif.cb_driver.data_rdata_i  <= c_rdata;
    vif.cb_driver.data_rvalid_i <= 1'b1;
    n_rsp++;

    dbg_msg($sformatf(
            "t=%0t RSP #%0d %s addr=%08h rdata=%08h",
            $time,
            n_rsp,
            c_we ? "STORE" : "LOAD ",
            c_addr,
            c_rdata
            ));

    @(vif.cb_driver);  // one-cycle pulse
    vif.cb_driver.data_rvalid_i <= 1'b0;
    vif.cb_driver.data_rdata_i  <= '0;
  endtask

  // ---------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------
  task drive_idle();
    vif.cb_driver.data_gnt_i    <= 1'b0;
    vif.cb_driver.data_rvalid_i <= 1'b0;
    vif.cb_driver.data_rdata_i  <= '0;
  endtask

  function automatic bit [31:0] read_word(bit [31:0] a);
    bit [31:2] w;
    w = a[31:2];
    return mem.exists(w) ? mem[w] : 32'h0;
  endfunction

  function automatic void write_word(bit [31:0] a, bit [31:0] d, bit [3:0] be);
    bit [31:2] w;
    bit [31:0] cur;
    w   = a[31:2];
    cur = mem.exists(w) ? mem[w] : 32'h0;
    for (int i = 0; i < 4; i++) if (be[i]) cur[i*8+:8] = d[i*8+:8];
    mem[w] = cur;
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("DRV", $sformatf("SUMMARY: grants=%0d responses=%0d", n_grant, n_rsp), UVM_NONE)
  endfunction

endclass
