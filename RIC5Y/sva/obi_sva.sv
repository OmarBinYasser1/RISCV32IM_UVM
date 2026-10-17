`ifndef OBI_SVA_SV
`define OBI_SVA_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
// -----------------------------------------------------------------------------
// obi_instr_sva : instruction bus
// -----------------------------------------------------------------------------
module obi_instr_sva #(
    parameter int MAX_OUT = 2
) (
    input logic        clk,
    input logic        rst_n,
    input logic        instr_req_o,
    input logic [31:0] instr_addr_o,
    input logic        instr_gnt_i,
    input logic        instr_rvalid_i,
    input logic [31:0] instr_rdata_i
);

  // --------------------------------------------------------------------------
  // OBI_11
  // --------------------------------------------------------------------------
  a_req_gnt_low_in_reset :
  assert property (@(posedge clk) !rst_n |-> (!instr_req_o && !instr_gnt_i))
  else `uvm_fatal("OBI_SVA", "[OBI_11/I] req or gnt high during reset");

  // --------------------------------------------------------------------------
  // OBI_12
  // --------------------------------------------------------------------------
  a_no_x_after_reset :
  assert property (@(posedge clk) disable iff (!rst_n) (!$isunknown(
      instr_req_o
  ) && !$isunknown(
      instr_addr_o
  )))
  else `uvm_fatal("OBI_SVA", "[OBI_12/I] X on req or addr after reset");

  // --------------------------------------------------------------------------
  // OBI_1 + OBI_15
  // --------------------------------------------------------------------------
  a_addr_stable_in_gnt_delay :
  assert property (
    @(posedge clk) disable iff (!rst_n)
    (instr_req_o && !instr_gnt_i) |=> (instr_req_o && $stable(
      instr_addr_o
  )))
  else `uvm_fatal("OBI_SVA", "[OBI_1/I] addr changed while waiting for gnt");

  // --------------------------------------------------------------------------
  // OBI_2
  // --------------------------------------------------------------------------
  a_req_held_until_gnt :
  assert property (
    @(posedge clk) disable iff (!rst_n)
    (instr_req_o && !instr_gnt_i) |=> instr_req_o
  )
  else `uvm_fatal("OBI_SVA", "[OBI_2/I] req withdrawn before gnt");

  a_gnt_implies_req :
  assert property (@(posedge clk) disable iff (!rst_n) instr_gnt_i |-> instr_req_o)
  else `uvm_fatal("OBI_SVA", "[OBI_3/I] gnt asserted without req");
  // --------------------------------------------------------------------------
  // OBI_4 + OBI_5 + OBI_6 + OBI_7 + OBI_9
  // --------------------------------------------------------------------------
  int unsigned instr_outstanding = 0;
  bit          instr_accept_seen = 0;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      instr_outstanding <= 0;
      instr_accept_seen <= 0;
    end else begin
      case ({
        instr_req_o && instr_gnt_i, instr_rvalid_i
      })
        2'b10:   instr_outstanding <= instr_outstanding + 1;
        2'b01:   instr_outstanding <= (instr_outstanding > 0) ? instr_outstanding - 1 : 0;
        default: ;  // 2'b00 and 2'b11 (same-cycle accept and complete) leave the count unchanged
      endcase
      if (instr_req_o && instr_gnt_i) instr_accept_seen <= 1'b1;
    end
  end

  // OBI_7  rvalid never precedes its own grant.
  a_rvalid_needs_outstanding :
  assert property (
    @(posedge clk) disable iff (!rst_n)
    instr_rvalid_i |-> (instr_accept_seen || (instr_req_o && instr_gnt_i))
  )
  else `uvm_fatal("OBI_SVA", "[OBI_7/I] rvalid without a preceding or concurrent accept");

  // OBI_9
  a_max_outstanding_2 :
  assert property (@(posedge clk) disable iff (!rst_n) (instr_outstanding <= 2))
  else `uvm_fatal("OBI_SVA", "[OBI_9/I] more than 2 outstanding transactions");

  // OBI_18
  a_no_outstanding_after_reset :
  assert property (@(posedge clk) $rose(rst_n) |-> (instr_outstanding == 0))
  else `uvm_fatal("OBI_SVA", "[OBI_18/I] outstanding request survived reset");

endmodule

// -----------------------------------------------------------------------------
// Data bus
// -----------------------------------------------------------------------------
module obi_data_sva #(
    parameter int MAX_OUT = 2
) (
    input logic        clk,
    input logic        rst_n,
    input logic        req,
    input logic        gnt,
    input logic        rvalid,
    input logic        we,
    input logic [31:0] addr,
    input logic [31:0] wdata,
    input logic [ 3:0] be
);

  wire acc = (req === 1'b1) && (gnt === 1'b1);
  wire rv = (rvalid === 1'b1);

  int  outs = 0;
  always @(posedge clk) begin
    if (!rst_n) outs <= 0;
    else outs <= outs + int'(acc) - int'(rv);
  end

  // OBI_1 : address phase held while waiting for grant
  OBI_1_addr_phase_stable :
  assert property (@(posedge clk) disable iff (!rst_n) (req && !gnt) |=> (req && $stable(
      addr
  ) && $stable(
      we
  ) && $stable(
      be
  ) && $stable(
      wdata
  )))
  else `uvm_fatal("OBI_SVA", "[OBI_1/D] address-phase fields changed while waiting for grant");

  // OBI_2 : req held until granted
  OBI_2_req_held_until_gnt :
  assert property (@(posedge clk) disable iff (!rst_n) (req && !gnt) |=> req)
  else `uvm_fatal("OBI_SVA", "[OBI_2/D] req withdrawn before grant");

  // OBI_3 : gnt only while req is high
  OBI_3_gnt_needs_req :
  assert property (@(posedge clk) disable iff (!rst_n) gnt |-> req)
  else `uvm_fatal("OBI_SVA", "[OBI_3/D] gnt asserted without req");

  // OBI_6 : every response retires an accepted request
  OBI_6_rvalid_has_outstanding :
  assert property (@(posedge clk) disable iff (!rst_n) rv |-> (outs > 0))
  else `uvm_fatal("OBI_SVA", "[OBI_6/D] rvalid with no outstanding request");

  // OBI_7 : rvalid never on the same edge as the accept it would answer
  OBI_7_no_rvalid_on_grant_edge :
  assert property (@(posedge clk) disable iff (!rst_n) (acc && rv) |-> (outs > 0))
  else `uvm_fatal("OBI_SVA", "[OBI_7/D] rvalid on the grant edge of its own request");

  // OBI_9 : no more than MAX_OUT outstanding after any edge
  OBI_9_max_outstanding :
  assert property (@(posedge clk) disable iff (!rst_n) (outs + int'(acc) - int'(rv)) <= MAX_OUT)
  else `uvm_fatal("OBI_SVA", "[OBI_9/D] more than MAX_OUT outstanding transactions");

  // OBI_11 : req and gnt low during reset (checked from the first reset cycle after it is seen)
  OBI_11_req_gnt_low_in_reset :
  assert property (@(posedge clk) !rst_n |=> (!req && !gnt))
  else `uvm_fatal("OBI_SVA", "[OBI_11/D] req or gnt high during reset");

  // OBI_12 : no X once out of reset
  OBI_12_no_x :
  assert property (@(posedge clk) rst_n |-> !$isunknown({req, gnt, rvalid}))
  else `uvm_fatal("OBI_SVA", "[OBI_12/D] X on req/gnt/rvalid while out of reset");

  OBI_12_no_x_on_request :
  assert property (@(posedge clk) disable iff (!rst_n) req |-> !$isunknown({addr, we, be}))
  else `uvm_fatal("OBI_SVA", "[OBI_12/D] X on addr/we/be while req is high");


  OBI_13_single_lane_at_offset :
  assert property (@(posedge clk) disable iff (!rst_n) (req && $onehot(
      be
  )) |-> (be == (4'b0001 << addr[1:0])))
  else `uvm_fatal("OBI_SVA", "[OBI_13/D] single enabled lane does not match address offset");

  OBI_13_halfword_aligned :
  assert property (
    @(posedge clk) disable iff (!rst_n)
      (req && (be == 4'b0011 || be == 4'b1100)) |->
        (addr[0] == 1'b0) &&
        ((be == 4'b0011) ? (addr[1] == 1'b0) : (addr[1] == 1'b1)))
  else `uvm_fatal("OBI_SVA", "[OBI_13/D] halfword byte enable not aligned");

  OBI_13_word_aligned :
  assert property (
    @(posedge clk) disable iff (!rst_n)
      (req && be == 4'b1111) |-> (addr[1:0] == 2'b00))
  else `uvm_fatal("OBI_SVA", "[OBI_13/D] word byte enable with unaligned address");

  OBI_13_store_has_lane :
  assert property (@(posedge clk) disable iff (!rst_n) (req && we) |-> (be != 4'b0000))
  else `uvm_fatal("OBI_SVA", "[OBI_13/D] store with no byte lanes enabled");

  // OBI_18 : nothing outstanding and no response in the first cycle after reset
  OBI_18_clean_after_reset :
  assert property (@(posedge clk) $rose(rst_n) |-> (!rv && outs == 0))
  else `uvm_fatal("OBI_SVA", "[OBI_18/D] outstanding state or rvalid survived reset");

  // ---------------------------------------------------------------------------
  // Cover points for the plan scenarios
  // ---------------------------------------------------------------------------
  // OBI_5 : registered grant, one cycle after req is first seen
  COV_OBI_5_registered_grant :
  cover property (@(posedge clk) disable iff (!rst_n) $rose(req) ##1 (req && gnt));

  // OBI_9 : depth reached and a stall at full depth
  COV_OBI_9_depth_reached :
  cover property (@(posedge clk) disable iff (!rst_n) outs == MAX_OUT);

  COV_OBI_9_stall_at_full :
  cover property (@(posedge clk) disable iff (!rst_n) (outs == MAX_OUT) && req && !gnt);

  // Back-to-back requests and a response overlapping a new accept
  COV_back_to_back :
  cover property (@(posedge clk) disable iff (!rst_n) acc ##1 req);

  COV_rvalid_with_accept :
  cover property (@(posedge clk) disable iff (!rst_n) acc && rv);

  COV_store_word :
  cover property (@(posedge clk) disable iff (!rst_n) req && we && be == 4'b1111);

  COV_store_half :
  cover property (
    @(posedge clk) disable iff (!rst_n)
      req && we && (be == 4'b0011 || be == 4'b1100));

  COV_store_byte :
  cover property (@(posedge clk) disable iff (!rst_n) req && we && $onehot(be));

endmodule


`endif
