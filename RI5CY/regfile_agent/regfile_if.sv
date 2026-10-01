interface regfile_if (
    input   logic        clk, 
    input   logic        rst_n,
    // TODO : Add `id_valid_o` signal
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
    input   logic        we_b_i
  );

  clocking cb_mon @(posedge clk);
      default input #1;
      input     rst_n;
      // TODO : Add `id_valid_o` signal
      input     raddr_a_i;
      input     rdata_a_o;
      input     raddr_b_i;
      input     rdata_b_o;
      input     raddr_c_i;
      input     rdata_c_o;
      input     waddr_a_i;
      input     wdata_a_i;
      input     we_a_i;
      input     waddr_b_i;
      input     wdata_b_i;
      input     we_b_i;
  endclocking


endinterface
