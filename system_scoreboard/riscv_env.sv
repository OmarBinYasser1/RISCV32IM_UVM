`ifndef RISCV_ENV_SV
`define RISCV_ENV_SV

class riscv_env extends uvm_env;
  `uvm_component_utils(riscv_env)

  alu_agent      alu_agt;
  mul_agent      mul_agt;
  regfile_agent  rf_agt;
  riscv_scoreboard sb;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    alu_agt = alu_agent::type_id::create("alu_agt", this);
    mul_agt = mul_agent::type_id::create("mul_agt", this);
    rf_agt  = regfile_agent::type_id::create("rf_agt",  this);
    sb      = riscv_scoreboard::type_id::create("sb",   this);
  endfunction

  function void connect_phase(uvm_phase phase);
    alu_agt.mon.analysis_port.connect(sb.alu_ae);
    mul_agt.mon.analysis_port.connect(sb.mul_ae);
    rf_agt.mon.analysis_port.connect(sb.rf_ae);
  endfunction

endclass

`endif
