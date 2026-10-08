class rv32im_env extends uvm_env;
  `uvm_component_utils(rv32im_env);

  rv32im_instr_agent   instr_agent;
  reactive_data_agent  data_agent;
  debug_interupt_agent debug_int_agent;
  alu_agent            alu_agt;
  mul_agent            mul_agt;
  regfile_agent        rf_agt;
  riscv_scoreboard     sb;

  rv32im_virtual_seqr  sys_vseqr;


  function new(string name = "rv32im_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    instr_agent     = rv32im_instr_agent::type_id::create("instr_agent", this);
    data_agent      = reactive_data_agent::type_id::create("data_agent", this);
    debug_int_agent = debug_interupt_agent::type_id::create("debug_int_agent", this);
    alu_agt         = alu_agent::type_id::create("alu_agt", this);
    mul_agt         = mul_agent::type_id::create("mul_agt", this);
    rf_agt          = regfile_agent::type_id::create("rf_agt", this);
    sb              = riscv_scoreboard::type_id::create("sb", this);
    sys_vseqr       = rv32im_virtual_seqr::type_id::create("sys_vseqr", this);
  endfunction


  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    sys_vseqr.instr_seqr = instr_agent.instr_seqr;
    sys_vseqr.data_seqr = data_agent.sequencer;
    sys_vseqr.debug_int_seqr = debug_int_agent.sequencer;


    instr_agent.instr_mon_ap.connect(sb.instr_ae);
    data_agent.transaction_ap.connect(sb.data_ae);
    // TODO (Optional) : Add analysis exports at the edge of those agents to abstract them
    alu_agt.mon.analysis_port.connect(sb.alu_ae);
    mul_agt.mon.analysis_port.connect(sb.mul_ae);
    rf_agt.mon.analysis_port.connect(sb.rf_ae);

  endfunction

endclass  // rv32im_env
