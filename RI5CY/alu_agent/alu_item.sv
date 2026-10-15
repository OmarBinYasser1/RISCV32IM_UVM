class alu_item extends uvm_sequence_item;
  `uvm_object_utils(alu_item) 

 
  rand bit [6:0]  operator;   
  rand bit [31:0] operand_a;  
  rand bit [31:0] operand_b;  
  rand bit [31:0] operand_c;  
       bit [31:0] result;     
       bit comparison_result;     
       bit pc_ex; // Used only in Jump/Branch Instructions

  // CHK:C-10  Number of clock cycles from the first cycle enable_i was high
  // for this operation to the cycle (ready_o && ex_ready_i) completed it.
  // Non-DIV ops: 1.  MUL-ish ops on the ALU are N/A (see mul_item.latency).
  // DIV/DIVU/REM/REMU: ~35 - LO(rs2) per the plan.
       int        latency;

  function new(string name = "alu_item");
    super.new(name); 
  endfunction

 
  function string convertTostring();
    return $sformatf("op=%0h a=%0h b=%0h res=%0h lat=%0d",
                     operator, operand_a, operand_b, result, latency);
  endfunction
  
endclass