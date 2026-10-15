class regfile_monitor extends uvm_monitor;

  `uvm_component_utils(regfile_monitor)

  virtual regfile_if vif;
  uvm_analysis_port #(regfile_item) analysis_port;

  int unsigned cycle_count = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_port = new("analysis_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);

    regfile_item item;

    forever begin
      @(vif.cb_mon);

      // Reset
      if (!vif.cb_mon.rst_n) begin
        cycle_count = 0;

        item = regfile_item::type_id::create("reset_item");
        item.cycle = 0;
        item.is_reset = 1;

        analysis_port.write(item);
        continue;
      end

      cycle_count++;

      // Port A write
      if (vif.cb_mon.we_a_i) begin
        item = regfile_item::type_id::create("write_a_item");
        item.cycle = cycle_count;
        item.is_reset = 0;
        item.pc_id = vif.cb_mon.pc_id;
        item.kind = regfile_item::WRITE;
        item.port = "a";
        item.addr = vif.cb_mon.waddr_a_i;
        item.data = vif.cb_mon.wdata_a_i;

        `uvm_info("REGFILE_MON", $sformatf("WRITE A: %s", item.convertTostring()), UVM_MEDIUM)

        analysis_port.write(item);
      end

      // Port B write
      if (vif.cb_mon.we_b_i) begin
        item = regfile_item::type_id::create("write_b_item");
        item.cycle = cycle_count;
        item.is_reset = 0;
        item.pc_id = vif.cb_mon.pc_id;
        item.kind = regfile_item::WRITE;
        item.port = "b";
        item.addr = vif.cb_mon.waddr_b_i;
        item.data = vif.cb_mon.wdata_b_i;

        `uvm_info("REGFILE_MON", $sformatf("WRITE B: %s", item.convertTostring()), UVM_MEDIUM)

        analysis_port.write(item);
      end

      // Port A read
      if (vif.cb_mon.rega_used_dec) begin
        item = regfile_item::type_id::create("read_a_item");
        item.cycle = cycle_count;
        item.is_reset = 0;
        item.pc_id = vif.cb_mon.pc_id;
        item.kind = regfile_item::READ;
        item.port = "a";
        item.addr = vif.cb_mon.raddr_a_i;
        item.data = vif.cb_mon.rdata_a_o;

        analysis_port.write(item);
      end

      // Port B read
      if (vif.cb_mon.regb_used_dec) begin
        item = regfile_item::type_id::create("read_b_item");
        item.cycle = cycle_count;
        item.is_reset = 0;
        item.pc_id = vif.cb_mon.pc_id;
        item.kind = regfile_item::READ;
        item.port = "b";
        item.addr = vif.cb_mon.raddr_b_i;
        item.data = vif.cb_mon.rdata_b_o;

        analysis_port.write(item);
      end

      // Port C read
      if (vif.cb_mon.regc_used_dec) begin
        item = regfile_item::type_id::create("read_c_item");
        item.cycle = cycle_count;
        item.is_reset = 0;
        item.pc_id = vif.cb_mon.pc_id;
        item.kind = regfile_item::READ;
        item.port = "c";
        item.addr = vif.cb_mon.raddr_c_i;
        item.data = vif.cb_mon.rdata_c_o;

        analysis_port.write(item);
      end

      // PC trace
      if (vif.cb_mon.pc_trace_enable) begin
        item = regfile_item::type_id::create("pc_trace_item");
        item.cycle = cycle_count;
        item.is_reset = 0;
        item.kind = regfile_item::PC_TRACE;
        item.pc_id = vif.cb_mon.pc_id;
        item.instr = vif.cb_mon.instr_rdata_id;
        // CHK:C-03  Forwarded operands, same values the DUT uses in EX.
        item.op_a_fw = vif.cb_mon.pc_trace_operand_a;
        item.op_b_fw = vif.cb_mon.pc_trace_operand_b;

        analysis_port.write(item);
      end

    end
  endtask

endclass