class regfile_monitor extends uvm_monitor;
  `uvm_component_utils(regfile_monitor)

  virtual regfile_if vif;
  uvm_analysis_port #(regfile_item) analysis_port;

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
      if (!vif.cb_mon.rst_n) continue;

      if (vif.cb_mon.we_a_i) begin 
        item = regfile_item::type_id::create("item");
        item.pc_id = vif.cb_mon.pc_id;
        item.kind = regfile_item::WRITE;
        item.port = "a";
        item.addr = vif.cb_mon.waddr_a_i;
        item.data = vif.cb_mon.wdata_a_i;
        `uvm_info("REGFILE_MON", $sformatf("WRITE Port A: %s", item.convertTostring()), UVM_MEDIUM)
        analysis_port.write(item);
      end

      if (vif.cb_mon.we_b_i) begin
        item = regfile_item::type_id::create("item");
        item.pc_id = vif.cb_mon.pc_id;
        item.kind = regfile_item::WRITE;
        item.port = "b";
        item.addr = vif.cb_mon.waddr_b_i;
        item.data = vif.cb_mon.wdata_b_i;
        `uvm_info("REGFILE_MON", $sformatf("WRITE Port B: %s", item.convertTostring()), UVM_MEDIUM)
        analysis_port.write(item);
      end

      if(vif.cb_mon.rega_used_dec) begin
        item = regfile_item::type_id::create("item");
        item.pc_id = vif.cb_mon.pc_id;
        item.kind = regfile_item::READ;
        item.port = "a";
        item.addr = vif.cb_mon.raddr_a_i;
        item.data = vif.cb_mon.rdata_a_o;
        analysis_port.write(item);
      end

      if(vif.cb_mon.regb_used_dec) begin
        item = regfile_item::type_id::create("item");
        item.pc_id = vif.cb_mon.pc_id;
        item.kind = regfile_item::READ;
        item.port = "b";
        item.addr = vif.cb_mon.raddr_b_i;
        item.data = vif.cb_mon.rdata_b_o;
        analysis_port.write(item); 
      end

      if (vif.cb_mon.regc_used_dec) begin
          item = regfile_item::type_id::create("item");
          item.pc_id = vif.cb_mon.pc_id;
          item.kind = regfile_item::READ;
          item.port = "c";
          item.addr = vif.cb_mon.raddr_c_i;
          item.data = vif.cb_mon.rdata_c_o;
          analysis_port.write(item);        
      end
    end
  endtask
endclass
