
class mul_agent extends uvm_agent;
  `uvm_component_utils(mul_agent)

  mul_monitor mon;

  virtual mul_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = mul_monitor::type_id::create("mon", this);

    if (!uvm_config_db#(virtual mul_if)::get(this, "", "MUL_IF", vif))
      `uvm_fatal("MUL_MON", "mul_if not found")
  
  endfunction
  
  function void connect_phase (uvm_phase phase);
    super.connect_phase(phase);
    mon.vif = vif;
  endfunction

endclass
