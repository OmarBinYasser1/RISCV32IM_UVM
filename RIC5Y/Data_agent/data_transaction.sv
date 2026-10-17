class data_transaction extends uvm_sequence_item;
  `uvm_object_utils(data_transaction)

  // response signals
  bit                      data_rvalid_i;
  bit                      data_gnt_i;
  bit               [31:0] data_rdata_i;

  //request signals
  rand bit                 data_req_o;
  rand bit                 data_we_o;
  rand bit          [ 3:0] data_be_o;
  rand bit          [31:0] data_addr_o;
  rand bit          [31:0] data_wdata_o;
  // Delay Control Attributes for Slow Memory Simulation
  rand int unsigned        gnt_delay;  // Cycles to wait before driving gnt_i = 1
  rand int unsigned        rvalid_delay;  // Cycles to wait before driving rvalid_i = 1


  int unsigned             cycle_at_publish;  // monitor cycle when req was published
  int unsigned             cycle_at_grant;  // monitor cycle when gnt fired
  int unsigned             cycle_at_rvalid;  // monitor cycle when rvalid fired
  int unsigned             outstanding_at_grant;  // accepted_q size at the grant edge

  constraint c_delays {
    gnt_delay dist {
      0 := 70,
      [1 : 3] := 30
    };
    rvalid_delay dist {
      0 := 50,
      [1 : 4] := 40,
      [5 : 12] := 10
    };
  }




  // Constructor
  function new(string name = "data_transaction");
    super.new(name);
  endfunction

  // Convert transaction to string for printing
  virtual function string my_convert2string();
    return $sformatf(
        "data_rvalid_i: %0b, data_gnt_i: %0b, data_rdata_i: %0h, data_req_o: %0b, data_we_o: %0b, data_be_o: %0h, data_addr_o: %0h, data_wdata_o: %0h",
        data_rvalid_i,
        data_gnt_i,
        data_rdata_i,
        data_req_o,
        data_we_o,
        data_be_o,
        data_addr_o,
        data_wdata_o
    );
  endfunction
endclass
