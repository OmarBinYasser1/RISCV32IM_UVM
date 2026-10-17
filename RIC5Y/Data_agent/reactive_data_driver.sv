class reactive_data_driver extends uvm_driver #(data_transaction);
  `uvm_component_utils(reactive_data_driver)

  virtual obi_data_if.driver_mp vif;

  localparam int MAX_OUT = 2;

  typedef struct {
    bit [31:0]   addr;
    bit          we;
    bit [3:0]    be;
    bit [31:0]   wdata;
    int unsigned due;    // cycle when the response may be driven
  } resp_t;

  typedef enum {
    IDLE,
    WAIT_GNT,
    GNT_SENT
  } state_t;

  bit [31:0] mem[bit [31:2]];
  bit preload_enable = 1;

  data_transaction items[$];  // requests from the sequence, in order
  resp_t pending[$];  // accepted, response not sent yet
  data_transaction cur;
  state_t state = IDLE;
  int unsigned gnt_cnt = 0;
  int unsigned cycle = 0;
  int unsigned n_grant = 0, n_resp = 0;
  bit accepted_now;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'(uvm_config_db#(bit)::get(this, "", "preload_enable", preload_enable));
  endfunction

  task run_phase(uvm_phase phase);
    drive_idle();
    if (preload_enable) preload_mem();
    fork
      fetch_items();
      bus_loop();
    join
  endtask

  // Take each item from the sequence and release the sequence right away.
  task fetch_items();
    data_transaction t;
    forever begin
      seq_item_port.get_next_item(t);
      items.push_back(t);
      seq_item_port.item_done();
    end
  endtask

  task bus_loop();
    forever begin
      @(vif.cb_driver);
      cycle++;
      drive_idle();

      if (vif.cb_driver.rst_n !== 1'b1) begin
        reset_state();
        continue;
      end

      accepted_now = 0;
      if (state == GNT_SENT) take_accept();
      send_response();
      if (!accepted_now) try_grant();
    end
  endtask

  task take_accept();
    resp_t r;
    accepted_now = 1;

    if (vif.cb_driver.data_req_o !== 1'b1) `uvm_error("data_drv", "req low on the accept edge")

    if (vif.cb_driver.data_addr_o !== cur.data_addr_o ||
        vif.cb_driver.data_we_o   !== cur.data_we_o) begin
      `uvm_error("data_drv", $sformatf("bus addr=%08h we=%0b does not match item addr=%08h we=%0b",
                                       vif.cb_driver.data_addr_o, vif.cb_driver.data_we_o,
                                       cur.data_addr_o, cur.data_we_o))
    end

    r.addr  = vif.cb_driver.data_addr_o;
    r.we    = vif.cb_driver.data_we_o;
    r.be    = vif.cb_driver.data_be_o;
    r.wdata = vif.cb_driver.data_wdata_o;
    r.due   = cycle + cur.rvalid_delay;
    pending.push_back(r);

    n_grant++;
    `uvm_info("data_drv", $sformatf("accept #%0d addr=%08h we=%0b outstanding=%0d", n_grant,
                                    r.addr, r.we, pending.size()), UVM_HIGH)

    cur   = null;
    state = IDLE;
  endtask

  // Responses go out in order. With two pending, the head goes out now.
  task send_response();
    resp_t r;
    if (pending.size() == 0) return;
    if (pending.size() < MAX_OUT && pending[0].due > cycle) return;

    r = pending.pop_front();
    if (r.we) begin
      write_word(r.addr, r.wdata, r.be);
      vif.cb_driver.data_rdata_i <= '0;
    end else begin
      vif.cb_driver.data_rdata_i <= read_word(r.addr);
    end
    vif.cb_driver.data_rvalid_i <= 1'b1;
    n_resp++;
  endtask

  task try_grant();
    if (state == IDLE) begin
      if (vif.cb_driver.data_req_o === 1'b1 && items.size() > 0 && pending.size() < MAX_OUT) begin
        cur     = items.pop_front();
        gnt_cnt = cur.gnt_delay;
        state   = WAIT_GNT;
      end
    end

    if (state == WAIT_GNT) begin
      if (vif.cb_driver.data_req_o !== 1'b1) begin
        `uvm_error("data_drv", "req dropped before it was granted")
        cur   = null;
        state = IDLE;
      end else if (gnt_cnt == 0) begin
        vif.cb_driver.data_gnt_i <= 1'b1;
        state = GNT_SENT;
      end else begin
        gnt_cnt--;
      end
    end
  endtask


  task reset_state();
    items.delete();
    pending.delete();
    cur          = null;
    state        = IDLE;
    gnt_cnt      = 0;
    accepted_now = 0;
  endtask

  task drive_idle();
    vif.cb_driver.data_gnt_i    <= 1'b0;
    vif.cb_driver.data_rvalid_i <= 1'b0;
    vif.cb_driver.data_rdata_i  <= '0;
  endtask

  function void preload_mem();
    for (int i = 0; i < 256; i++) begin
      bit [31:0] a;
      a            = 32'h1000_0000 + i * 4;
      mem[a[31:2]] = a;
    end
  endfunction


  function automatic bit [31:0] read_word(bit [31:0] data_addr);
    bit [31:2] word_addr;
    word_addr = data_addr[31:2];
    return mem.exists(word_addr) ? mem[word_addr] : 32'h0;
  endfunction

  function automatic void write_word(bit [31:0] data_addr, bit [31:0] data_wdata,
                                     bit [3:0] data_be);
    bit [31:2] word_addr;
    bit [31:0] old_word;
    word_addr = data_addr[31:2];
    old_word  = mem.exists(word_addr) ? mem[word_addr] : 32'h0;
    for (int i = 0; i < 4; i++) if (data_be[i]) old_word[i*8+:8] = data_wdata[i*8+:8];
    mem[word_addr] = old_word;
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("DATA_DRV", $sformatf("grants=%0d responses=%0d", n_grant, n_resp), UVM_LOW)
  endfunction

endclass
