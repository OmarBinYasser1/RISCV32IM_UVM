class regfile_coverage extends uvm_subscriber #(regfile_item);

  `uvm_component_utils(regfile_coverage)

  regfile_item item;

  // Register write history
  bit written[64];
  int unsigned write_cycle[64];

  bit x0_write_seen;
  int unsigned raw_distance;

  // General register access coverage
  //
  // NOTE - RV32IM only
  //   This testbench instantiates cv32e40p_top with FPU = 0 and ZFINX = 0,
  //   so the register file has only 32 integer registers.  Address bit 5
  //   (which selects the FP register file) is never driven high, so the
  //   FPR address range [32:63] is unreachable.
  //   The FPR bins are declared as ignore_bins so the coverage denominator
  //   reflects only the bins that this configuration is expected to hit.
  covergroup regfile_cg;
    option.per_instance = 1;

    cp_addr: coverpoint item.addr {
      bins gpr[32] = {[0:31]};
      // RV32IM only: no FPU in this testbench, address bit 5 is never set.
      ignore_bins fpr = {[32:63]};
    }

    cp_kind: coverpoint item.kind {
      bins write_b = {regfile_item::WRITE};
      bins read_b  = {regfile_item::READ};
    }

    cp_port: coverpoint
      ((item.port == "a") ? 0 :
       (item.port == "b") ? 1 :
       (item.port == "c") ? 2 : 3) {

      bins port_a = {0};
      bins port_b = {1};
      bins port_c = {2};

      ignore_bins invalid_port = {3};
    }

    cp_x0_write: coverpoint x0_write_seen {
      bins write_attempted = {1};
    }

    // Cross with two structural ignores:
    //   * Port C is read-only, so no write can ever appear on it.
    //   * In RV32IM, port C is only ever read at address 0 (REGC_ZERO,
    //     used by MULH / MULHSU / MULHU).  Any other address on port C
    //     is unreachable.
    cross cp_kind, cp_addr, cp_port {
      ignore_bins write_on_port_c =
          binsof(cp_kind.write_b) && binsof(cp_port.port_c);

      ignore_bins read_port_c_nonzero =
          binsof(cp_kind.read_b) && binsof(cp_port.port_c) &&
          binsof(cp_addr) intersect {[1:31]};
    }
  endgroup

  // RAW hazard coverage
  //
  // NOTE - RV32IM only
  //   Same as regfile_cg.cp_addr: the FPR range [32:63] is unreachable.
  covergroup raw_hazard_cg;
    option.per_instance = 1;

    cp_raw_addr: coverpoint item.addr {
      bins gpr[31] = {[1:31]};
      // RV32IM only
      ignore_bins fpr = {[32:63]};
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

    regfile_cg    = new();
    raw_hazard_cg = new();

    clear_write_history();
  endfunction

  function void clear_write_history();

    foreach (written[i]) begin
      written[i]     = 0;
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
        written[item.addr]     = 1;
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