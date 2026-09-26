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
    if (!uvm_config_db#(virtual regfile_if)::get(this, "", "regfile_vif", vif))
      `uvm_fatal("REGFILE_MON", "regfile_if not found")
  endfunction

  task run_phase(uvm_phase phase);
    regfile_item item;

    forever begin
      @(posedge vif.clk);
      if (!vif.rst_n) continue;

      if (vif.we_a_i && (vif.waddr_a_i != 0)) begin
        item = regfile_item::type_id::create("item");
        item.kind = regfile_item::WRITE;
        item.port = "a";
        item.addr = vif.waddr_a_i;
        item.data = vif.wdata_a_i;
        `uvm_info("REGFILE_MON", $sformatf("WRITE Port A: %s", item.convertTostring()), UVM_MEDIUM)
        analysis_port.write(item);
      end

      if (vif.we_b_i && (vif.waddr_b_i != 0)) begin
        item = regfile_item::type_id::create("item");
        item.kind = regfile_item::WRITE;
        item.port = "b";
        item.addr = vif.waddr_b_i;
        item.data = vif.wdata_b_i;
        `uvm_info("REGFILE_MON", $sformatf("WRITE Port B: %s", item.convertTostring()), UVM_MEDIUM)
        analysis_port.write(item);
      end

      if (vif.raddr_a_i != 0) begin
        item = regfile_item::type_id::create("item");
        item.kind = regfile_item::READ;
        item.port = "a";
        item.addr = vif.raddr_a_i;
        item.data = vif.rdata_a_o;
        analysis_port.write(item);
      end

      if (vif.raddr_b_i != 0) begin
        item = regfile_item::type_id::create("item");
        item.kind = regfile_item::READ;
        item.port = "b";
        item.addr = vif.raddr_b_i;
        item.data = vif.rdata_b_o;
        analysis_port.write(item);
      end

      if (vif.raddr_c_i != 0) begin
        item = regfile_item::type_id::create("item");
        item.kind = regfile_item::READ;
        item.port = "c";
        item.addr = vif.raddr_c_i;
        item.data = vif.rdata_c_o;
        analysis_port.write(item);
      end
    end
  endtask
endclass
