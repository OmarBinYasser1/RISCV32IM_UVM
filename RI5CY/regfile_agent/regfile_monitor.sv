class regfile_monitor extends uvm_monitor;
  `uvm_component_utils(regfile_monitor)

  virtual regfile_if vif;
  uvm_analysis_port #(regfile_item) analysis_port;
  
  // Local cycle counter in the monitor
  int unsigned cycle_count = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_port = new("analysis_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  // -------------------------------------------------------------------------
  // Single deterministic loop: for each clock edge, emit all items in a fixed
  // order so that the scoreboard sees WRITEs before READs when they occur in
  // the same cycle.
  // This is done mainly to fix the corner case of having reading and writing from the same register at the same time
  // Recording the write first is always correct but reading will be delayed one cycle as the read will get the old value in the register not the new one 
  // -------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    regfile_item item;
    forever begin
      @(vif.cb_mon);
      
      if (!vif.cb_mon.rst_n) begin
        cycle_count = 0;
        continue;
      end

      // Increment cycle count on each valid clock edge outside of reset
      cycle_count++;

      // 1) Port A write (lower priority for the RF)
      if (vif.cb_mon.we_a_i) begin
        item = regfile_item::type_id::create("item");
        item.cycle = cycle_count; // <-- Assign current cycle count here
        item.pc_id = vif.cb_mon.pc_id;
        item.kind  = regfile_item::WRITE;
        item.port  = "a";
        item.addr  = vif.cb_mon.waddr_a_i;
        item.data  = vif.cb_mon.wdata_a_i;
        `uvm_info("REGFILE_MON", $sformatf("WRITE Port A: %s", item.convertTostring()), UVM_MEDIUM)
        analysis_port.write(item);
      end

      // 2) Port B write (higher priority for the RF)
      if (vif.cb_mon.we_b_i) begin
        item = regfile_item::type_id::create("item");
        item.cycle = cycle_count; // <-- Assign current cycle count here
        item.pc_id = vif.cb_mon.pc_id;
        item.kind  = regfile_item::WRITE;
        item.port  = "b";
        item.addr  = vif.cb_mon.waddr_b_i;
        item.data  = vif.cb_mon.wdata_b_i;
        `uvm_info("REGFILE_MON", $sformatf("WRITE Port B: %s", item.convertTostring()), UVM_MEDIUM)
        analysis_port.write(item);
      end

      // 3) Port A read
      if (vif.cb_mon.rega_used_dec) begin
        item = regfile_item::type_id::create("item");
        item.cycle = cycle_count; // <-- Assign current cycle count here
        item.pc_id = vif.cb_mon.pc_id;
        item.kind  = regfile_item::READ;
        item.port  = "a";
        item.addr  = vif.cb_mon.raddr_a_i;
        item.data  = vif.cb_mon.rdata_a_o;
        analysis_port.write(item);
      end

      // 4) Port B read
      if (vif.cb_mon.regb_used_dec) begin
        item = regfile_item::type_id::create("item");
        item.cycle = cycle_count; // <-- Assign current cycle count here
        item.pc_id = vif.cb_mon.pc_id;
        item.kind  = regfile_item::READ;
        item.port  = "b";
        item.addr  = vif.cb_mon.raddr_b_i;
        item.data  = vif.cb_mon.rdata_b_o;
        analysis_port.write(item);
      end

      // 5) Port C read
      if (vif.cb_mon.regc_used_dec) begin
        item = regfile_item::type_id::create("item");
        item.cycle = cycle_count; // <-- Assign current cycle count here
        item.pc_id = vif.cb_mon.pc_id;
        item.kind  = regfile_item::READ;
        item.port  = "c";
        item.addr  = vif.cb_mon.raddr_c_i;
        item.data  = vif.cb_mon.rdata_c_o;
        analysis_port.write(item);
      end

      // 6) PC-trace (last, same edge)
      if (vif.cb_mon.pc_trace_enable) begin
        item = regfile_item::type_id::create("pc_trace_item");
        item.cycle = cycle_count; // <-- Assign current cycle count here
        item.kind  = regfile_item::PC_TRACE;
        item.pc_id = vif.cb_mon.pc_id;
        item.instr = vif.cb_mon.instr_rdata_id;
        analysis_port.write(item);
      end
    end
  endtask

endclass
