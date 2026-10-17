class regfile_item extends uvm_sequence_item;
  `uvm_object_utils(regfile_item)

  typedef enum {
    WRITE,
    READ,
    PC_TRACE
  } rf_kind_e;

  rand rf_kind_e kind;
  string port;
  rand bit [5:0] addr;
  bit [31:0] data;
  int unsigned cycle;
  bit is_reset;

  // ---- PC_TRACE fields ------------------------------------------------
  logic [31:0] pc_id;  // PC at ID
  logic [31:0] instr;  // instruction at ID
  // ---- CHK:C-03  Forwarded operands sampled at ID ---------------------
  // These are id_stage_i.operand_a_fw_id / operand_b_fw_id, i.e. the exact
  // values the DUT's branch comparator in EX consumes.  Raw RF reads
  // (rdata_a_o / rdata_b_o) are the pre-forwarding values and would give
  // false failures whenever a distance-0/1 RAW hazard is present.
  logic [31:0] op_a_fw;
  logic [31:0] op_b_fw;
  // --------------------------------------------------------------------

  function new(string name = "regfile_item");
    super.new(name);
  endfunction

  function string convertTostring();
    if (is_reset) return "RESET";
    if (kind == PC_TRACE)
      return $sformatf("PC_TRACE pc=0x%08h instr=0x%08h opa=%08h opb=%08h",
                       pc_id, instr, op_a_fw, op_b_fw);
    return $sformatf(
        "%s port=%s addr=x%0d data=%0h cycle=%0d", kind.name(), port, addr, data, cycle
    );
  endfunction

endclass