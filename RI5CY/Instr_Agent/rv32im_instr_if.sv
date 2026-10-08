interface rv32im_instr_if (
    input bit clk
);

    // System Reset
    bit rst_n;
    // OBI Istruction Interface Signals
    bit             instr_gnt_i;
    bit             instr_rvalid_i;
    bit     [31:0]  instr_rdata_i;
    logic           instr_req_o;
    logic   [31:0]  instr_addr_o;
   
    clocking cb_drv @(posedge clk);
        default input #1 output #0;
        input instr_req_o;
        input instr_addr_o;
        output instr_gnt_i;
        output instr_rvalid_i;
        output instr_rdata_i;
        output rst_n;
    endclocking

    clocking cb_mon @(posedge clk);
        default input #1;
        input rst_n;
        input instr_req_o;
        input instr_addr_o;
        input instr_gnt_i;
        input instr_rvalid_i;
        input instr_rdata_i; 
    endclocking
    
    modport mp_drv (clocking cb_drv);

    modport mp_mon (clocking cb_mon);

endinterface