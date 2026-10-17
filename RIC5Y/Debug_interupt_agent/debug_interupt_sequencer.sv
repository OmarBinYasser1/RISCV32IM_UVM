class debug_interupt_sequencer extends uvm_sequencer #(debug_interupt_transaction);
  `uvm_component_utils(debug_interupt_sequencer)

  function new(string name = "debug_interupt_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass
