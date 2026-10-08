class debug_interupt_monitor extends uvm_monitor;

  `uvm_component_utils(debug_interupt_monitor)

  virtual debug_interupt_if.monitor_mp vif;

  uvm_analysis_port #(debug_interupt_transaction) transaction_ap;

  function new(string name = "debug_interupt_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    debug_interupt_transaction tr;
    forever begin
      @(posedge vif.cb_monitor);
      if (vif.cb_monitor.rst_n) begin
        if (vif.cb_monitor.debug_req_i) begin
          tr = debug_interupt_transaction::type_id::create("tr");
          tr.irq_i = vif.cb_monitor.irq_i;
          tr.irq_ack_o = vif.cb_monitor.irq_ack_o;
          tr.irq_id_o = vif.cb_monitor.irq_id_o;
          tr.debug_req_i = vif.cb_monitor.debug_req_i;
          tr.debug_havereset_o = vif.cb_monitor.debug_havereset_o;
          tr.debug_running_o = vif.cb_monitor.debug_running_o;
          tr.debug_halted_o = vif.cb_monitor.debug_halted_o;
          tr.fetch_enable_i = vif.cb_monitor.fetch_enable_i;
          tr.core_sleep_o = vif.cb_monitor.core_sleep_o;

          transaction_ap.write(tr);
        end
      end
    end
  endtask
endclass
