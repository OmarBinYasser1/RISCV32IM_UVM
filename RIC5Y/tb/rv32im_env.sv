class rv32im_env extends uvm_env;
  `uvm_component_utils(rv32im_env);

  // agents
  rv32im_instr_agent      instr_agent;
  reactive_data_agent     data_agent;
  debug_interupt_agent    debug_int_agent;
  alu_agent               alu_agt;
  mul_agent               mul_agt;
  regfile_agent           rf_agt;

  // scoreboards
  riscv_alu_scoreboard    alu_sb;
  riscv_rf_scoreboard     rf_sb;
  riscv_system_scoreboard sb;

  // coverage
  alu_coverage            alu_cov;
  ctrl_flow_coverage      ctrl_cov;
  mul_coverage            mul_cov;
  regfile_coverage        rf_cov;
  obi_coverage            obi_cov;

  rv32im_virtual_seqr     sys_vseqr;


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

    alu_sb          = riscv_alu_scoreboard::type_id::create("alu_sb", this);
    rf_sb           = riscv_rf_scoreboard::type_id::create("rf_sb", this);
    sb              = riscv_system_scoreboard::type_id::create("sb", this);

    alu_cov         = alu_coverage::type_id::create("alu_cov", this);
    ctrl_cov        = ctrl_flow_coverage::type_id::create("ctrl_cov", this);
    mul_cov         = mul_coverage::type_id::create("mul_cov", this);
    rf_cov          = regfile_coverage::type_id::create("rf_cov", this);
    obi_cov         = obi_coverage::type_id::create("obi_cov", this);


    sys_vseqr       = rv32im_virtual_seqr::type_id::create("sys_vseqr", this);
  endfunction


  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    sys_vseqr.instr_seqr = instr_agent.instr_seqr;
    sys_vseqr.data_seqr = data_agent.sequencer;
    sys_vseqr.debug_int_seqr = debug_int_agent.sequencer;

    // Connect to system scoreboard (PC flow, link values, LSU/data bus, instruction mix)
    instr_agent.instr_mon_ap.connect(sb.instr_ae);
    data_agent.transaction_ap.connect(sb.data_ae);
    rf_agt.analysis_port.connect(sb.rf_ae);

    // Connect to dedicated block scoreboards
    alu_agt.analysis_port.connect(alu_sb.alu_ae);
    mul_agt.analysis_port.connect(alu_sb.mul_ae);
    rf_agt.analysis_port.connect(rf_sb.rf_ae);

    // Connect analysis ports to coverage components
    instr_agent.instr_mon_ap.connect(ctrl_cov.analysis_export);
    alu_agt.analysis_port.connect(alu_cov.analysis_export);
    mul_agt.analysis_port.connect(mul_cov.analysis_export);
    rf_agt.analysis_port.connect(rf_cov.analysis_export);
    data_agent.transaction_ap.connect(obi_cov.analysis_export);
  endfunction

endclass  // rv32im_env