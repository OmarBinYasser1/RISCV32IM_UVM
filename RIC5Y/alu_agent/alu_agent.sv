
class alu_agent extends uvm_agent;
  `uvm_component_utils(alu_agent)

  alu_monitor mon;
  virtual alu_if vif;
  uvm_analysis_port #(alu_item) analysis_port;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = alu_monitor::type_id::create("mon", this);
    analysis_port = new("analysis_port", this);

    if (!uvm_config_db#(virtual alu_if)::get(this, "", "ALU_IF", vif))
      `uvm_fatal("ALU_MON", "alu_if not found");
  endfunction

  function void connect_phase (uvm_phase phase);
    super.connect_phase(phase);
    mon.vif = vif;
    mon.analysis_port.connect(analysis_port);
  endfunction
  
endclass
