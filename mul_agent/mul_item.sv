
class mul_item extends uvm_sequence_item;
  `uvm_object_utils(mul_item)

  rand bit [2:0]  operator;   
  rand bit [31:0] operand_a;  
  rand bit [31:0] operand_b;  
       bit [31:0] result;     

  function new(string name = "mul_item");
    super.new(name);
  endfunction

  function string convertTostring();
    return $sformatf("op=%0h a=%0h b=%0h res=%0h",
                      operator, operand_a, operand_b, result);
  endfunction

endclass
