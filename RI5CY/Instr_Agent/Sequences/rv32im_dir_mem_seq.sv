// Directed load/store stimulus (gated by run_stim_batch3).
class rv32im_dir_mem_seq extends rv32im_instr_seq;
  `uvm_object_utils(rv32im_dir_mem_seq);

  function new(string name = "rv32im_dir_mem_seq");
    super.new(name);
  endfunction

  // ======================================================================
  //  CHK:S-22 + S-24 + V-17  Loads/stores with real data and OBI BE variety.
  // ======================================================================
  task phase_stim_load_store_real();
    restore_mem_base();

    emit_li32(5'd12, 32'h00000080);
    emit_store(5'd12, 5'd1, 12'h040, 3'b000);
    emit_load(5'd8, 5'd1, 12'h040, LB);
    emit_load(5'd9, 5'd1, 12'h040, LBU);

    emit_li32(5'd12, 32'h0000007F);
    emit_store(5'd12, 5'd1, 12'h044, 3'b000);
    emit_load(5'd8, 5'd1, 12'h044, LB);
    emit_load(5'd9, 5'd1, 12'h044, LBU);

    emit_li32(5'd12, 32'h00008000);
    emit_store(5'd12, 5'd1, 12'h048, 3'b001);
    emit_load(5'd8, 5'd1, 12'h048, LH);
    emit_load(5'd9, 5'd1, 12'h048, LHU);

    emit_li32(5'd12, 32'h00007FFF);
    emit_store(5'd12, 5'd1, 12'h04C, 3'b001);
    emit_load(5'd8, 5'd1, 12'h04C, LH);
    emit_load(5'd9, 5'd1, 12'h04C, LHU);

    emit_li32(5'd12, 32'hDEADBEEF);
    emit_store(5'd12, 5'd1, 12'h050, 3'b000);
    emit_load(5'd8, 5'd1, 12'h050, LBU);

    emit_li32(5'd13, 32'h12345678);
    emit_store(5'd13, 5'd1, 12'h054, 3'b001);
    emit_load(5'd8, 5'd1, 12'h054, LHU);

    emit_store(5'd13, 5'd1, 12'h058, 3'b010);
    emit_load(5'd8, 5'd1, 12'h058, LW);

    emit_li32(5'd12, 32'h00000000);
    emit_store(5'd12, 5'd1, 12'h05C, 3'b010);
    emit_load(5'd8, 5'd1, 12'h05C, LW);

    emit_li32(5'd12, 32'hFFFFFFFF);
    emit_store(5'd12, 5'd1, 12'h060, 3'b010);
    emit_load(5'd8, 5'd1, 12'h060, LW);

    emit_li32(5'd12, 32'h80000000);
    emit_store(5'd12, 5'd1, 12'h064, 3'b010);
    emit_load(5'd8, 5'd1, 12'h064, LW);

    // Loads with negative offsets.
    emit_load(5'd8, 5'd1, 12'h800, LB);
    emit_load(5'd8, 5'd1, 12'hFFC, LB);
    emit_load(5'd8, 5'd1, 12'h800, LH);
    emit_load(5'd8, 5'd1, 12'hFFC, LH);
    emit_load(5'd8, 5'd1, 12'h800, LBU);
    emit_load(5'd8, 5'd1, 12'hFFC, LBU);
    emit_load(5'd8, 5'd1, 12'h800, LHU);
    emit_load(5'd8, 5'd1, 12'hFFC, LHU);

    emit_store(5'd16, 5'd1, 12'h800, 3'b000);
    emit_store(5'd16, 5'd1, 12'hFFC, 3'b000);
    emit_store(5'd16, 5'd1, 12'h800, 3'b001);
    emit_store(5'd16, 5'd1, 12'hFFC, 3'b001);

    // Byte-aligned addresses spanning addr[1:0] = {0, 1, 2, 3} for
    // byte and halfword stores / loads.
    emit_li32(5'd12, 32'h5A5A_5A5A);
    emit_store(5'd12, 5'd1, 12'h080, 3'b000);
    emit_store(5'd12, 5'd1, 12'h081, 3'b000);
    emit_store(5'd12, 5'd1, 12'h082, 3'b000);
    emit_store(5'd12, 5'd1, 12'h083, 3'b000);

    emit_store(5'd12, 5'd1, 12'h084, 3'b001);
    emit_store(5'd12, 5'd1, 12'h086, 3'b001);

    emit_store(5'd12, 5'd1, 12'h085, 3'b001);
    emit_store(5'd12, 5'd1, 12'h087, 3'b001);

    emit_load(5'd8, 5'd1, 12'h080, LBU);
    emit_load(5'd8, 5'd1, 12'h081, LBU);
    emit_load(5'd8, 5'd1, 12'h082, LBU);
    emit_load(5'd8, 5'd1, 12'h083, LBU);

    emit_load(5'd8, 5'd1, 12'h084, LHU);
    emit_load(5'd8, 5'd1, 12'h086, LHU);
  endtask

  // ======================================================================
  //  CHK:S-23  Load effective-address tag check.
  // ======================================================================
  task phase_stim_load_addr_tags();
    emit_li32(5'd1, 32'h1000_0000);

    emit_load(5'd8, 5'd1, 12'h000, LW);
    emit_load(5'd9, 5'd1, 12'h004, LW);
    emit_load(5'd10, 5'd1, 12'h008, LW);
    emit_load(5'd11, 5'd1, 12'h010, LW);
    emit_load(5'd12, 5'd1, 12'h100, LW);
    emit_load(5'd13, 5'd1, 12'h3FC, LW);

    restore_mem_base();
  endtask

  // ======================================================================
  //  CHK:S-25  Load/store address variety.
  // ======================================================================
  task phase_stim_addr_variety();
    restore_mem_base();

    emit_load(5'd8, 5'd1, 12'hFFC, LW);
    emit_store(5'd16, 5'd1, 12'hFFC, 3'b010);

    emit_load(5'd8, 5'd16, 12'h000, LW);
    emit_store(5'd16, 5'd20, 12'h008, 3'b010);

    emit_load(5'd8, 5'd1, 12'h7FF, LW);
    emit_load(5'd8, 5'd1, 12'h800, LW);

    emit_load(5'd1, 5'd1, 12'h004, LW);
    emit_store(5'd1, 5'd1, 12'h008, 3'b010);

    emit_li32(5'd15, 32'hFFFFFFFC);
    emit_load(5'd8, 5'd15, 12'h004, LW);

    emit_li32(5'd15, 32'h00000000);
    emit_load(5'd8, 5'd15, 12'hFFC, LW);
  endtask

  virtual task body();
    if (run_stim_batch3) begin
      restore_mem_base();
      phase_stim_load_store_real();
      phase_stim_load_addr_tags();
      phase_stim_addr_variety();
    end
  endtask
endclass  // rv32im_dir_mem_seq
