`ifndef MUL_TIMING_SVA_SV
`define MUL_TIMING_SVA_SV

//------------------------------------------------------------------------------
// mul_timing_sva
// Plan GEN_1 : MUL                    -> result ready in 1 cycle
// Plan GEN_2 : MULH / MULHSU / MULHU  -> result ready in 5 cycles
//
// Cycle 1 = first cycle enable_i is high for the operation.
//------------------------------------------------------------------------------

import uvm_pkg::*;
`include "uvm_macros.svh"

module mul_timing_sva (
  input logic       clk,
  input logic       rst_n,
  input logic       enable_i,
  input logic       ready_o,
  input logic       ex_ready_i,
  input logic [2:0] operator_i
);

  localparam logic [2:0] MUL_MAC32 = 3'b000;   // RV32M MUL
  localparam logic [2:0] MUL_H     = 3'b110;   // MULH / MULHSU / MULHU

  // busy = an operation is already in flight (so enable_i is not a new start)
  logic busy;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)                       busy <= 1'b0;
    else if (!enable_i)               busy <= 1'b0;   // idle or flushed
    else if (ready_o && ex_ready_i)   busy <= 1'b0;   // operation completed
    else                              busy <= 1'b1;
  end

  wire start = enable_i && !busy;

  // GEN_1: MUL result is ready in the very first cycle
  a_mul_1cycle: assert property (
    @(posedge clk) disable iff (!rst_n || !enable_i)
    (start && operator_i == MUL_MAC32) |-> ready_o
  ) else `uvm_fatal("MUL_SVA","MUL: ready_o not asserted in the first cycle")
;

  // GEN_2: MULH/MULHSU/MULHU not ready for 4 cycles, ready in the 5th
  a_mulh_5cycles: assert property (
    @(posedge clk) disable iff (!rst_n || !enable_i)
    (start && operator_i == MUL_H) |-> (!ready_o)[*4] ##1 ready_o
  ) else `uvm_fatal("MUL_SVA","MULH/MULHSU/MULHU: ready_o not asserted exactly in the 5th cycle");


endmodule

`endif