class debug_interupt_driver extends uvm_driver #(debug_interupt_transaction);
  `uvm_component_utils(debug_interupt_driver)

  virtual debug_interupt_if vif;

  function new(string name = "debug_interupt_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual debug_interupt_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("DRV_NO_VIF", "Virtual interface debug_interupt_if not found in uvm_config_db")
    end
  endfunction

  task run_phase(uvm_phase phase);
    debug_interupt_transaction tr;
    //initializing the signals to the DUT
    vif.irq_i <= 1'b0;
    vif.debug_req_i <= 1'b0;
    vif.fetch_enable_i <= 1'b0;
    forever begin
      seq_item_port.get_next_item(tr);

      @(posedge vif.clk);
      // Drive the signals to the DUT using the transaction fields
      vif.irq_i <= tr.irq_i;
      vif.debug_req_i <= tr.debug_req_i;
      vif.fetch_enable_i <= tr.fetch_enable_i;


      // Indicate that the transaction is done
      seq_item_port.item_done();
    end
  endtask
endclass

