class mul_agent extends uvm_agent;
  `uvm_component_utils(mul_agent)

  mul_monitor mon;
  virtual mul_if vif;
  uvm_analysis_port #(mul_item) analysis_port;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = mul_monitor::type_id::create("mon", this);
    analysis_port = new("analysis_port", this);

    if (!uvm_config_db#(virtual mul_if)::get(this, "", "MUL_IF", vif))
      `uvm_fatal("MUL_AGT", "mul_if not found")
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    mon.vif = vif;
    mon.analysis_port.connect(analysis_port);
  endfunction
  
endclass
