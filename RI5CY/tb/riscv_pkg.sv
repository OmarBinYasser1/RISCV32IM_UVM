`ifndef RISCV_PKG_SV
`define RISCV_PKG_SV

package riscv_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Sequence (Transactions) Items  / Configuration Objects
  `include "../Instr_Agent/rv32im_instr_seq_item.sv"
  `include "../Instr_Agent/rv32im_instr_config.sv"
  `include "../Data_agent/data_transaction.sv"
  `include "../Debug_interupt_agent/debug_interupt_transaction.sv"

  // Sequencer(s)
  `include "../Instr_Agent/rv32im_instr_seqr.sv"
  `include "../Data_agent/reactive_data_sequencer.sv"
  `include "../Debug_interupt_agent/debug_interupt_sequencer.sv"
  `include "./rv32im_virtual_seqr.sv"

  // Sequences
  `include "../Instr_Agent/rv32im_instr_seq.sv"
  `include "../Debug_interupt_agent/debug_interupt_seq.sv"
  `include "../Data_agent/reactive_data_seq.sv"
  `include "./rv32im_virtual_seq.sv"

  // Sequence Items
  `include "../alu_agent/alu_item.sv"
  `include "../mul_agent/mul_item.sv"
  `include "../regfile_agent/regfile_item.sv"

  // Drivers
  `include "../Instr_Agent/rv32im_instr_driver.sv"
  `include "../Data_agent/reactive_data_driver.sv"
  `include "../Debug_interupt_agent/debug_interupt_driver.sv"

  // Monitors
  `include "../Instr_Agent/rv32im_instr_monitor.sv"
  `include "../alu_agent/alu_monitor.sv"
  `include "../mul_agent/mul_monitor.sv"
  `include "../regfile_agent/regfile_monitor.sv"
  `include "../Data_agent/reactive_data_monitor.sv"
  `include "../Debug_interupt_agent/debug_interupt_monitor.sv"

  // Agents
  `include "../Instr_Agent/rv32im_instr_agent.sv"
  `include "../Data_agent/reactive_data_agent.sv"
  `include "../Debug_interupt_agent/debug_interupt_agent.sv"

  `include "../alu_agent/alu_agent.sv"
  `include "../mul_agent/mul_agent.sv"
  `include "../regfile_agent/regfile_agent.sv"

  // Scoreboard(s)
  `include "../alu_scoreboard/riscv_alu_scoreboard.sv"
  `include "../regfile_scoreboard/riscv_rf_scoreboard.sv"
  `include "../system_scoreboard/riscv_system_scoreboard.sv"

  // Coverage
  `include "../Coverage/alu_coverage.sv"
  `include "../Coverage/ctrl_flow_coverage.sv"
  `include "../Coverage/mul_coverage.sv"
  `include "../Coverage/regfile_coverage.sv"
  `include "../Coverage/obi_coverage.sv"

  // Env / Test
  `include "./rv32im_env.sv"
  `include "./rv32im_test.sv"

endpackage

`endif