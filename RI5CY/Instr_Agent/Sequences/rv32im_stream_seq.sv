// Mixed random instruction stream (gated by run_stim_batch3).
class rv32im_stream_seq extends rv32im_instr_seq;
  `uvm_object_utils(rv32im_stream_seq);

  function new(string name = "rv32im_stream_seq");
    super.new(name);
  endfunction

  // ======================================================================
  //  CHK:S-28  Mixed-opcode back-to-back stream.
  //  opcode_mask bit order: {BRANCH,STORE,LOAD,MUL_DIV,R_ALU,IMM}.
  // ======================================================================
  task phase_mixed_stream(int unsigned min_len, int unsigned max_len,
                          bit [5:0] mask);
    int unsigned pick;
    bit [2:0]    s_f3;

    if (min_len == 0) min_len = 1;
    if (max_len < min_len) max_len = min_len;

    for (int i = 0; i < int'(max_len); i++) begin
      if (i >= int'(min_len)) begin
        if ($urandom_range(0, 1) == 0) break;
      end

      pick = $urandom_range(0, 5);
      while (!mask[pick]) pick = $urandom_range(0, 5);

      case (pick)
        0: emit_i_op(3'b000, 5'd8, 5'd16, 12'($urandom_range(0, 4095)));
        1: emit_r_alu(5'd8, 5'd16, 5'd17, ADD_SUB, $urandom_range(0, 1));
        2: emit_r_muldiv(5'd8, 5'd16, 5'd17,
                         mul_div_ops_t'($urandom_range(0, 7)));
        3: emit_load(5'd8, 5'd1, 12'($urandom_range(0, 32)),
                     Load_ops_t'($urandom_range(0, 5)));
        4: begin
             s_f3 = 3'($urandom_range(0, 2));
             emit_store(5'd8, 5'd1, 12'($urandom_range(0, 32)), s_f3);
           end
        5: emit_branch(5'd16, 5'd17, 13'd8,
                       B_ops_t'($urandom_range(0, 1)));
      endcase
    end
  endtask

  virtual task body();
    if (run_stim_batch3) begin
      phase_mixed_stream(stream_min_len, stream_max_len, stream_opcode_mask);
    end
  endtask
endclass  // rv32im_stream_seq
