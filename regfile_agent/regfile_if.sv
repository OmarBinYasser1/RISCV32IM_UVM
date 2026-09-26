

interface regfile_if (input logic clk, input logic rst_n);

 
  logic [5:0]  raddr_a_i;
  logic [31:0] rdata_a_o;

  logic [5:0]  raddr_b_i;
  logic [31:0] rdata_b_o;

  logic [5:0]  raddr_c_i;
  logic [31:0] rdata_c_o;

  
  logic [5:0]  waddr_a_i;
  logic [31:0] wdata_a_i;
  logic        we_a_i;


  logic [5:0]  waddr_b_i;
  logic [31:0] wdata_b_i;
  logic        we_b_i;

endinterface
