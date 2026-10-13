interface regfile_if (
    input   logic        clk,
    input   logic        rst_n,
    input   logic        rega_used_dec,
    input   logic        regb_used_dec,
    input   logic        regc_used_dec,
    input   logic [5:0]  raddr_a_i,
    input   logic [31:0] rdata_a_o,
    input   logic [5:0]  raddr_b_i,
    input   logic [31:0] rdata_b_o,
    input   logic [5:0]  raddr_c_i,
    input   logic [31:0] rdata_c_o,
    input   logic [5:0]  waddr_a_i,
    input   logic [31:0] wdata_a_i,
    input   logic        we_a_i,
    input   logic [5:0]  waddr_b_i,
    input   logic [31:0] wdata_b_i,
    input   logic        we_b_i,
    // ---- PC-trace ports --------------------------------------------------
    input   logic [31:0] pc_id, // PC in the ID stage used to be as an identifier to the instruction in the pipeline 
    input   logic        pc_trace_enable, // asserted for valid, non-flushed ID instruction
    input   logic [31:0] instr_rdata_id   // instruction at ID (Pieplined version of the instruction at the ID stage)
    // ----------------------------------------------------------------------
);

  clocking cb_mon @(posedge clk);
      default input #1;
      input rst_n;
      input rega_used_dec;
      input regb_used_dec;
      input regc_used_dec;
      input raddr_a_i;
      input rdata_a_o;
      input raddr_b_i;
      input rdata_b_o;
      input raddr_c_i;
      input rdata_c_o;
      input waddr_a_i;
      input wdata_a_i;
      input we_a_i;
      input waddr_b_i;
      input wdata_b_i;
      input we_b_i;
      input pc_id;
      input pc_trace_enable;
      input instr_rdata_id;
  endclocking

endinterface