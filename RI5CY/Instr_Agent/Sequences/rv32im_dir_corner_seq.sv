// Illegal, same-register and x0 corners (gated by run_stim_batch3).
class rv32im_dir_corner_seq extends rv32im_instr_seq;
  `uvm_object_utils(rv32im_dir_corner_seq);

  function new(string name = "rv32im_dir_corner_seq");
    super.new(name);
  endfunction

  // ======================================================================
  //  CHK:S-01  Illegal-encoding stimulus.
  // ======================================================================
  task phase_stim_illegal();
    preload_operand_pool();

    // SLLI with imm[11:5] != 0 (reserved)
    emit_raw({7'b0100000, 5'd0, 5'd16, 3'b001, 5'd8, 7'h13});
    emit_addi(5'd8, 5'd0, 12'h001);

    // SRLI with imm[11:5] neither 0 nor 0x20
    emit_raw({7'b0110000, 5'd0, 5'd16, 3'b101, 5'd8, 7'h13});
    emit_addi(5'd8, 5'd0, 12'h002);

    // LOAD funct3=3'b011
    emit_raw({12'h000, 5'd0, 3'b011, 5'd8, 7'h03});
    emit_addi(5'd8, 5'd0, 12'h003);

    // LOAD funct3=3'b110
    emit_raw({12'h000, 5'd0, 3'b110, 5'd8, 7'h03});
    emit_addi(5'd8, 5'd0, 12'h004);

    // LOAD funct3=3'b111
    emit_raw({12'h000, 5'd0, 3'b111, 5'd8, 7'h03});
    emit_addi(5'd8, 5'd0, 12'h005);

    // STORE funct3=3'b011
    emit_raw({7'b0000000, 5'd16, 5'd0, 3'b011, 5'd0, 7'h23});
    emit_addi(5'd8, 5'd0, 12'h006);

    // STORE funct3=3'b100
    emit_raw({7'b0000000, 5'd16, 5'd0, 3'b100, 5'd0, 7'h23});
    emit_addi(5'd8, 5'd0, 12'h007);

    // STORE funct3=3'b101
    emit_raw({7'b0000000, 5'd16, 5'd0, 3'b101, 5'd0, 7'h23});
    emit_addi(5'd8, 5'd0, 12'h008);

    // STORE funct3=3'b110
    emit_raw({7'b0000000, 5'd16, 5'd0, 3'b110, 5'd0, 7'h23});
    emit_addi(5'd8, 5'd0, 12'h009);

    // STORE funct3=3'b111
    emit_raw({7'b0000000, 5'd16, 5'd0, 3'b111, 5'd0, 7'h23});
    emit_addi(5'd8, 5'd0, 12'h00A);

    // BRANCH funct3=3'b010
    emit_raw({7'b0000000, 5'd0, 5'd0, 3'b010, 5'd0, 7'h63});
    emit_addi(5'd8, 5'd0, 12'h00B);

    // BRANCH funct3=3'b011
    emit_raw({7'b0000000, 5'd0, 5'd0, 3'b011, 5'd0, 7'h63});
    emit_addi(5'd8, 5'd0, 12'h00C);

    // JALR funct3=3'b001
    emit_raw({12'h000, 5'd0, 3'b001, 5'd0, 7'h67});
    emit_addi(5'd8, 5'd0, 12'h00D);

    // Unused opcode 0x7F (custom-3, never decoded by RV32IM)
    emit_raw(32'h0000007F);
    // Unused opcode 0x0B for redundancy
    emit_raw(32'h0000000B);
    emit_addi(5'd8, 5'd0, 12'h00E);

    // OP funct7=2, funct3=110 (not a defined encoding)
    emit_raw({7'b0000010, 5'd17, 5'd16, 3'b110, 5'd8, 7'h33});
    emit_addi(5'd8, 5'd0, 12'h00F);
  endtask

  // ======================================================================
  //  CHK:S-02  rd == rs1 / rd == rs2 for ALU / MUL / DIV / REM.
  // ======================================================================
  task phase_stim_same_reg();
    preload_operand_pool();

    emit_addi(5'd8, 5'd8, 12'h010);
    emit_r_alu(5'd9, 5'd9, 5'd17, ADD_SUB, 0);
    emit_r_alu(5'd10, 5'd16, 5'd10, ADD_SUB, 0);
    emit_r_alu(5'd11, 5'd11, 5'd11, AND, 0);

    emit_r_muldiv(5'd8, 5'd8, 5'd17, MUL);
    emit_r_muldiv(5'd9, 5'd16, 5'd9, MUL);

    emit_r_muldiv(5'd8, 5'd8, 5'd17, DIV);
    emit_r_muldiv(5'd9, 5'd16, 5'd9, DIV);
    emit_r_muldiv(5'd10, 5'd10, 5'd17, REM);
    emit_r_muldiv(5'd11, 5'd16, 5'd11, REM);

    emit_shift_imm(5'd8, 5'd8, 5'd3, SLLI, 1'b0);
    emit_shift_imm(5'd8, 5'd8, 5'd3, SRLI_SRAI, 1'b0);
    emit_shift_imm(5'd8, 5'd8, 5'd3, SRLI_SRAI, 1'b1);

    // rd == rs1 == rs2 for R-type ops.
    emit_r_muldiv(5'd8, 5'd8, 5'd8, MUL);
    emit_r_muldiv(5'd8, 5'd8, 5'd8, DIV);
    emit_r_muldiv(5'd8, 5'd8, 5'd8, REM);

    // LOAD has no rs2 field; the low 5 bits of the immediate alias the
    // rs2 position, so imm=0x008 with rd=rs1=8 fires the cross.
    emit_load(5'd8, 5'd8, 12'h008, LW);
  endtask

  // ======================================================================
  //  CHK:S-03  x0 behaviour.
  // ======================================================================
  task phase_stim_x0();
    preload_operand_pool();

    emit_addi(5'd0, 5'd0, 12'd5);
    emit_r_alu(5'd8, 5'd0, 5'd17, ADD_SUB, 0);
    emit_r_alu(5'd8, 5'd16, 5'd0, ADD_SUB, 0);
    emit_addi(5'd8, 5'd0, 12'd1);

    emit_r_muldiv(5'd0, 5'd16, 5'd17, MUL);
    emit_r_muldiv(5'd0, 5'd16, 5'd17, MULH);
    emit_r_muldiv(5'd0, 5'd16, 5'd17, DIV);
    emit_r_muldiv(5'd0, 5'd16, 5'd17, REM);
    emit_load(5'd0, 5'd1, 12'h000, LW);
    emit_jal(5'd0, 21'd8);
    emit_jalr(5'd0, 5'd1, 12'h000);
    emit_lui(5'd0, 20'hFFFFF);
    emit_i_op(3'b000, 5'd0, 5'd16, 12'h123);

    // rd = 0 with rs1 = 0 or rs2 = 0 for ALU / MUL / DIV.
    emit_r_alu   (5'd0, 5'd16, 5'd0,  ADD_SUB, 0);
    emit_r_muldiv(5'd0, 5'd16, 5'd0,  MUL);
    emit_r_muldiv(5'd0, 5'd16, 5'd0,  DIV);
    emit_r_alu   (5'd8, 5'd0,  5'd0,  ADD_SUB, 0);
    emit_r_muldiv(5'd8, 5'd0,  5'd0,  MUL);
    emit_r_muldiv(5'd8, 5'd0,  5'd0,  DIV);

    // rd = 0, rs1 = 0 with a nonzero immediate
    emit_load(5'd0, 5'd0, 12'h004, LW);
    emit_r_alu(5'd0, 5'd0, 5'd17, ADD_SUB, 0);
    emit_r_muldiv(5'd0, 5'd0, 5'd17, MUL);
    emit_r_muldiv(5'd0, 5'd0, 5'd17, DIV);
    emit_load(5'd0, 5'd16, 12'h004, LW);
    emit_r_alu(5'd0, 5'd16, 5'd17, ADD_SUB, 0);
  endtask

  virtual task body();
    if (run_stim_batch3) begin
      phase_stim_illegal();
      phase_stim_same_reg();
      phase_stim_x0();
    end
  endtask
endclass  // rv32im_dir_corner_seq
