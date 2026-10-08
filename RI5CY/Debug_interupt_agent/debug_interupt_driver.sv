class debug_interupt_driver extends uvm_driver #(debug_interupt_transaction);
  `uvm_component_utils(debug_interupt_driver)

  virtual debug_interupt_if.driver_mp vif;

  function new(string name = "debug_interupt_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    debug_interupt_transaction tr;
    //initializing the signals to the DUT
    vif.cb_driver.irq_i <= 1'b0;
    vif.cb_driver.scan_cg_en_i <= 1'b0;
    vif.cb_driver.debug_req_i <= 1'b0;
    vif.cb_driver.fetch_enable_i <= 1'b0;
    forever begin
      seq_item_port.get_next_item(tr);

      @(posedge vif.cb_driver);
      // Drive the signals to the DUT using the transaction fields
      vif.cb_driver.irq_i <= tr.irq_i;
      vif.cb_driver.debug_req_i <= tr.debug_req_i;
      vif.cb_driver.fetch_enable_i <= tr.fetch_enable_i;


      // Indicate that the transaction is done
      seq_item_port.item_done();
    end
  endtask
endclass

