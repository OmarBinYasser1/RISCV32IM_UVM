`ifndef RISCV_PKG_SV
`define RISCV_PKG_SV

package riscv_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "../alu_agent/alu_item.sv"
  `include "../mul_agent/mul_item.sv"
  `include "../regfile_agent/regfile_item.sv"

  `include "../alu_agent/alu_monitor.sv"
  `include "../mul_agent/mul_monitor.sv"
  `include "../regfile_agent/regfile_monitor.sv"

  `include "../alu_agent/alu_agent.sv"
  `include "../mul_agent/mul_agent.sv"
  `include "../regfile_agent/regfile_agent.sv"

  `include "riscv_scoreboard.sv"
  `include "riscv_env.sv"
  `include "riscv_base_test.sv"

endpackage

`endif
