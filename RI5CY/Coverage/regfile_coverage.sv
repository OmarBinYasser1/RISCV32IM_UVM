class regfile_coverage extends uvm_subscriber #(regfile_item);

  `uvm_component_utils(regfile_coverage)

  regfile_item item;

  // Register write history
  bit written[64];
  int unsigned write_cycle[64];

  bit x0_write_seen;
  int unsigned raw_distance;

  // General register access coverage
  covergroup regfile_cg;
    option.per_instance = 1;

    cp_addr: coverpoint item.addr {
      bins gpr[32] = {[0:31]};
      bins fpr[32] = {[32:63]};
    }

    cp_kind: coverpoint item.kind {
      bins write_b = {regfile_item::WRITE};
      bins read_b  = {regfile_item::READ};
    }

    cp_port: coverpoint item.port {
      bins port_a = {"a"};
      bins port_b = {"b"};
      bins port_c = {"c"};
    }

    cp_x0_write: coverpoint x0_write_seen {
      bins write_attempted = {1};
    }

    cross cp_kind, cp_addr, cp_port;
  endgroup

  // RAW hazard coverage
  covergroup raw_hazard_cg;
    option.per_instance = 1;

    cp_raw_addr: coverpoint item.addr {
      bins gpr[31] = {[1:31]};
      bins fpr[32] = {[32:63]};
    }

    cp_raw_distance: coverpoint raw_distance {
      bins same_cycle  = {0};
      bins one_cycle   = {1};
      bins short_delay = {[2:5]};
      bins long_delay  = {[6:$]};
    }

    cross cp_raw_addr, cp_raw_distance;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);

    regfile_cg = new();
    raw_hazard_cg = new();

    clear_write_history();
  endfunction

  function void clear_write_history();

    foreach (written[i]) begin
      written[i] = 0;
      write_cycle[i] = 0;
    end

    x0_write_seen = 0;

  endfunction

  function void write(regfile_item t);

    item = t;

    // Reset
    if (item.is_reset) begin
      clear_write_history();
      return;
    end

    // Ignore PC trace
    if (item.kind == regfile_item::PC_TRACE)
      return;

    // Track writes
    if (item.kind == regfile_item::WRITE) begin

      if (item.addr == 0) begin
        x0_write_seen = 1;
      end
      else begin
        written[item.addr] = 1;
        write_cycle[item.addr] = item.cycle;
      end

    end

    // Sample general coverage
    regfile_cg.sample();

    // Calculate RAW distance on first read after a write
    if (item.kind == regfile_item::READ &&
        item.addr != 0 &&
        written[item.addr]) begin

      raw_distance = item.cycle - write_cycle[item.addr];

      raw_hazard_cg.sample();

      // Reset after the first read following the write
      written[item.addr] = 0;

    end

  endfunction

endclass
