`ifndef MUL_ITEM_SV
`define MUL_ITEM_SV

class mul_item extends uvm_sequence_item;
  `uvm_object_utils(mul_item)

  // RV32M: MUL = 3'b000 (MUL_MAC32, operand_c==0); MULH/MULHSU/MULHU = 3'b110 (MUL_H)
  rand bit [2:0]  operator  ;
  rand bit [31:0] operand_a ;
  rand bit [31:0] operand_b ;
  rand bit [31:0] operand_c ;

  // NEW: sign interpretation of the operands, observed on mul_if.short_signed_i
  //   bit0 -> operand_a is signed, bit1 -> operand_b is signed
  //   MULH = 2'b11, MULHSU = 2'b01, MULHU = 2'b00   (only meaningful for MUL_H)
  // Observed by the monitor like 'result'. Make it 'rand' only if your driver
  // actually drives short_signed_i from this item.
       bit [1:0]  signed_mode;

       bit [31:0] result;

  // Debug info only (timing is checked by mul_timing_sva.sv): cycles the multiplier needed, counted from the first cycle enable_i is
  // high for this operation up to (and including) the first cycle ready_o is high.
  // MUL -> 1, MULH/MULHSU/MULHU -> 5
       int        latency;

  function new(string name = "mul_item");
    super.new(name);
  endfunction

  // Standard UVM hook (the original 'convertTostring' name is not a UVM
  // override, so it never took part in print()/sprint()).
  virtual function string convert2string();
    return $sformatf("op=%0b sm=%0b a=%0h b=%0h c=%0h res=%0h lat=%0d",
                     operator, signed_mode, operand_a, operand_b, operand_c, result, latency);
  endfunction

  // Kept so existing callers do not break
  function string convertTostring();
    return convert2string();
  endfunction

endclass

`endif
