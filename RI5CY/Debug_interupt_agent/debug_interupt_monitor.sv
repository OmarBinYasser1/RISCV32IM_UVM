class debug_interface_monitor extends uvm_monitor;

  `uvm_component_utils(debug_interface_monitor)

  virtual debug_interupt_if.monitor_mp vif;

  uvm_analysis_port #(debug_interupt_transaction) transaction_ap;

  function new(string name = "debug_interface_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    debug_interupt_transaction tr;
    forever begin
      @(posedge vif.clk);
      if (vif.rst_n) begin
        if (vif.debug_req_o) begin
          tr = debug_interupt_transaction::type_id::create("tr");
          tr.irq_i = vif.irq_i;
          tr.irq_ack_o = vif.irq_ack_o;
          tr.irq_id_o = vif.irq_id_o;
          tr.debug_req_i = vif.debug_req_i;
          tr.debug_havereset_o = vif.debug_havereset_o;
          tr.debug_running_o = vif.debug_running_o;
          tr.debug_halted_o = vif.debug_halted_o;
          tr.fetch_enable_i = vif.fetch_enable_i;
          tr.core_sleep_o = vif.core_sleep_o;

          tr.transaction_ap.write(tr);
        end
      end
    end
  endtask
endclass
