class regfile_item extends uvm_sequence_item;
  `uvm_object_utils(regfile_item)

  typedef enum {WRITE, READ, PC_TRACE} rf_kind_e;

  rand rf_kind_e kind;
       string    port;
  rand bit    [5:0]   addr;
       bit    [31:0]  data;

       // ---- PC_TRACE fields ------------------------------------------------
       logic  [31:0]  pc_id;  // PC at ID 
       logic  [31:0]  instr; // instruction at ID (Pieplined version of the instruction at the ID stage)
       // --------------------------------------------------------------------

  function new(string name = "regfile_item");
    super.new(name);
  endfunction

  function string convertTostring();
    if (kind == PC_TRACE)
      return $sformatf("PC_TRACE pc=0x%08h instr=0x%08h", pc_id, instr);
    return $sformatf("%s port=%s addr=x%0d data=%0h",
                     kind.name(), port, addr, data);
  endfunction
endclass