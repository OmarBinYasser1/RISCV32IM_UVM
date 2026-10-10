class alu_item extends uvm_sequence_item;
  `uvm_object_utils(alu_item) 

 
  rand bit [6:0]  operator;   
  rand bit [31:0] operand_a;  
  rand bit [31:0] operand_b;  
  rand bit [31:0] operand_c;  
       bit [31:0] result;     
       bit comparison_result;     
       bit pc_ex; // Used only in Jump/Branch Instructions

  function new(string name = "alu_item");
    super.new(name); 
  endfunction

 
  function string convertTostring();
    return $sformatf("op=%0h a=%0h b=%0h res=%0h", operator, operand_a, operand_b, result);
  endfunction
  
endclass
