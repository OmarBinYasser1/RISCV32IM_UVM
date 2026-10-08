
class regfile_item extends uvm_sequence_item;
  `uvm_object_utils(regfile_item)

  typedef enum {WRITE, READ} rf_kind_e;

  rand rf_kind_e kind;      
       string    port;      
  rand bit [5:0] addr;      
       bit [31:0] data;    

  function new(string name = "regfile_item");
    super.new(name);
  endfunction

  function string convertTostring();
    return $sformatf("%s port=%s addr=x%0d data=%0h",
                      kind.name(), port, addr, data);
  endfunction
  
endclass
