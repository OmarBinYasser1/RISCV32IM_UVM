`ifndef OBI_COVERAGE_SV
`define OBI_COVERAGE_SV

//------------------------------------------------------------------------------
// obi_coverage : CHK:V-17  OBI observation coverage.
//
// Subscribes to the reactive data monitor's transaction_ap (completed
// transactions) and covers:
//   - load vs store
//   - byte-enable pattern
//   - address alignment
//   - grant delay (cycles from publish to grant)
//   - rvalid delay (cycles from grant to response)
//   - outstanding count at grant
//
// The monitor populates cycle_at_publish / cycle_at_grant / cycle_at_rvalid
// and outstanding_at_grant on the data_transaction at the corresponding
// edges.
//------------------------------------------------------------------------------
class obi_coverage extends uvm_subscriber #(data_transaction);
  `uvm_component_utils(obi_coverage)

  data_transaction item;

  //----------------------------------------------------------------------------
  // OBI bus observation covergroup
  //----------------------------------------------------------------------------
  covergroup obi_cg;
    option.per_instance = 1;

    cp_we: coverpoint item.data_we_o {
      bins load  = {1'b0};
      bins store = {1'b1};
    }

    // Byte-enable pattern.  Full-scale patterns plus boundary-crossing ones.
    cp_be: coverpoint item.data_be_o {
      bins be_0001 = {4'b0001};
      bins be_0010 = {4'b0010};
      bins be_0100 = {4'b0100};
      bins be_1000 = {4'b1000};
      bins be_0011 = {4'b0011};
      bins be_1100 = {4'b1100};
      bins be_1111 = {4'b1111};
      bins be_0110 = {4'b0110};
      bins be_0111 = {4'b0111};
      bins be_1110 = {4'b1110};
    }

    cp_addr_align: coverpoint item.data_addr_o[1:0] {
      bins word_aligned = {2'b00};
      bins off_1        = {2'b01};
      bins off_2        = {2'b10};
      bins off_3        = {2'b11};
    }

    // Grant delay = cycles from request publish to grant.  0 = zero-wait grant.
    cp_gnt_delay: coverpoint (item.cycle_at_grant - item.cycle_at_publish) {
      bins zero_wait = {0};
      bins one       = {1};
      bins two_three = {[2:3]};
      bins four_plus = {[4:$]};
    }

    // Rvalid delay = cycles from grant to response completion.
    cp_rvalid_delay: coverpoint (item.cycle_at_rvalid - item.cycle_at_grant) {
      bins one        = {1};
      bins two_four   = {[2:4]};
      bins five_12    = {[5:12]};
      bins thirteen_p = {[13:$]};
    }

    // Outstanding count at grant edge (0 = idle, 1, 2 = max per plan).
    cp_outstanding: coverpoint item.outstanding_at_grant {
      bins zero = {0};
      bins one  = {1};
      bins two  = {2};
    }

    we_be_cov:     cross cp_we, cp_be;
    we_align_cov:  cross cp_we, cp_addr_align;
    we_gnt_cov:    cross cp_we, cp_gnt_delay;
    we_rvalid_cov: cross cp_we, cp_rvalid_delay;
    we_out_cov:    cross cp_we, cp_outstanding;
  endgroup

  //----------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    obi_cg = new();
  endfunction

  function void write(data_transaction t);
    item = t;
    if (item.data_req_o) obi_cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("OBI_COV", $sformatf("coverage %%: obi=%0.1f",
              obi_cg.get_inst_coverage()), UVM_LOW)
  endfunction
endclass

`endif