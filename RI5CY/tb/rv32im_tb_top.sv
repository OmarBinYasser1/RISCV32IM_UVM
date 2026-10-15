module rv32im_top ();
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import riscv_pkg::*;


  int   CLK_PERIOD = 10;  // Used by the system scoreboard
  int   TESTS = 1000;

  // ------- Plusarg-driven configuration -------------------------------
  int run_stim_batch3       = 1;
  int relax_rd_rs           = 0;
  int preload_enable        = 1;
  int timing_check_enable   = 1;
  int timing_check_is_error = 0;
  int strict_branch_check   = 1;
  int check_link_values     = 1;
  int illegal_detect_enable = 1;

  logic clk_i = 0;
  wire  rst_ni;

  always #(CLK_PERIOD / 2) clk_i = ~clk_i;

  rv32im_instr_if instr_if (
      .clk  (clk_i),
      .pc_if(u_core.core_i.pc_if)
  );

  assign rst_ni = instr_if.rst_n;

  obi_data_if data_if (
      .clk  (clk_i),
      .rst_n(rst_ni)
  );

  debug_interupt_if debug_int_if (
      .clk  (clk_i),
      .rst_n(rst_ni)
  );

  cv32e40p_top #(
      .FPU             (0),
      .FPU_ADDMUL_LAT  (0),
      .FPU_OTHERS_LAT  (0),
      .ZFINX           (0),
      .COREV_PULP      (0),
      .COREV_CLUSTER   (0),
      .NUM_MHPMCOUNTERS(1)
  ) u_core (
      .rst_ni      (rst_ni),
      .clk_i       (clk_i),
      .scan_cg_en_i(debug_int_if.scan_cg_en_i),

      .fetch_enable_i (debug_int_if.fetch_enable_i),
      .pulp_clock_en_i('0),
      .core_sleep_o   (debug_int_if.core_sleep_o),

      .boot_addr_i        ('0),
      .mtvec_addr_i       ('0),
      .dm_halt_addr_i     ('0),
      .dm_exception_addr_i('0),
      .hart_id_i          ('0),

      .instr_addr_o  (instr_if.instr_addr_o),
      .instr_req_o   (instr_if.instr_req_o),
      .instr_gnt_i   (instr_if.instr_gnt_i),
      .instr_rvalid_i(instr_if.instr_rvalid_i),
      .instr_rdata_i (instr_if.instr_rdata_i),

      .data_addr_o  (data_if.data_addr_o),
      .data_req_o   (data_if.data_req_o),
      .data_gnt_i   (data_if.data_gnt_i),
      .data_we_o    (data_if.data_we_o),
      .data_be_o    (data_if.data_be_o),
      .data_wdata_o (data_if.data_wdata_o),
      .data_rvalid_i(data_if.data_rvalid_i),
      .data_rdata_i (data_if.data_rdata_i),

      .irq_i    (debug_int_if.irq_i),
      .irq_ack_o(debug_int_if.irq_ack_o),
      .irq_id_o (debug_int_if.irq_id_o),

      .debug_req_i      (debug_int_if.debug_req_i),
      .debug_havereset_o(debug_int_if.debug_havereset_o),
      .debug_running_o  (debug_int_if.debug_running_o),
      .debug_halted_o   (debug_int_if.debug_halted_o)
  );

  alu_if alu_if (
      .clk                (clk_i),
      .rst_n              (rst_ni),
      .pc_ex              (u_core.core_i.pc_ex),
      .enable_i           (u_core.core_i.ex_stage_i.alu_en_i),
      .operator_i         (u_core.core_i.ex_stage_i.alu_operator_i),
      .operand_a_i        (u_core.core_i.ex_stage_i.alu_operand_a_i),
      .operand_b_i        (u_core.core_i.ex_stage_i.alu_operand_b_i),
      .operand_c_i        (u_core.core_i.ex_stage_i.alu_operand_c_i),
      .result_o           (u_core.core_i.ex_stage_i.alu_result),
      .comparison_result_o(u_core.core_i.ex_stage_i.alu_cmp_result),
      .ready_o            (u_core.core_i.ex_stage_i.alu_ready),
      .ex_ready_i         (u_core.core_i.ex_stage_i.ex_ready_o)
  );

  mul_if mul_if (
      .clk           (clk_i),
      .rst_n         (rst_ni),
      .short_signed_i(u_core.core_i.ex_stage_i.mult_signed_mode_i),
      .enable_i      (u_core.core_i.ex_stage_i.mult_en_i),
      .operator_i    (u_core.core_i.ex_stage_i.mult_operator_i),
      .op_a_i        (u_core.core_i.ex_stage_i.mult_operand_a_i),
      .op_b_i        (u_core.core_i.ex_stage_i.mult_operand_b_i),
      .op_c_i        (u_core.core_i.ex_stage_i.mult_operand_c_i),
      .result_o      (u_core.core_i.ex_stage_i.mult_result),
      .ready_o       (u_core.core_i.ex_stage_i.mult_ready),
      .ex_ready_i    (u_core.core_i.ex_stage_i.ex_ready_o),
      // CHK:V-10/V-12  Destination register of the MUL (lower 5 bits).
      .rd_i          (u_core.core_i.ex_stage_i.regfile_alu_waddr_i[4:0])
  );

  // ---- I-08 SVA bind --------------------------------------------------
  bind cv32e40p_top mul_timing_sva u_mul_timing_sva (
      .clk        (clk_i),
      .rst_n      (rst_ni),
      .enable_i   (u_core.core_i.ex_stage_i.mult_en_i),
      .ready_o    (u_core.core_i.ex_stage_i.mult_ready),
      .ex_ready_i (u_core.core_i.ex_stage_i.ex_ready_o),
      .operator_i (u_core.core_i.ex_stage_i.mult_operator_i)
  );

  regfile_if regfile_if (
      .clk(clk_i),
      .rst_n(rst_ni),
      .pc_id(u_core.core_i.pc_id),
      .pc_trace_enable        (u_core.core_i.id_stage_i.instr_valid_i &
                               u_core.core_i.id_stage_i.id_ready_o    &
                               u_core.core_i.id_stage_i.is_decoding_o),
      .instr_rdata_id(u_core.core_i.id_stage_i.instr_rdata_i),
      .pc_trace_operand_a(u_core.core_i.id_stage_i.operand_a_fw_id),
      .pc_trace_operand_b(u_core.core_i.id_stage_i.operand_b_fw_id),
      .raddr_a_i(u_core.core_i.id_stage_i.regfile_addr_ra_id),
      .rdata_a_o(u_core.core_i.id_stage_i.regfile_data_ra_id),
      .rega_used_dec          (u_core.core_i.id_stage_i.rega_used_dec & u_core.core_i.id_stage_i.id_ready_o & u_core.core_i.id_stage_i.instr_valid_i),
      .raddr_b_i(u_core.core_i.id_stage_i.regfile_addr_rb_id),
      .rdata_b_o(u_core.core_i.id_stage_i.regfile_data_rb_id),
      .regb_used_dec          (u_core.core_i.id_stage_i.regb_used_dec & u_core.core_i.id_stage_i.id_ready_o & u_core.core_i.id_stage_i.instr_valid_i),
      .raddr_c_i(u_core.core_i.id_stage_i.regfile_addr_rc_id),
      .rdata_c_o(u_core.core_i.id_stage_i.regfile_data_rc_id),
      .regc_used_dec          (u_core.core_i.id_stage_i.regc_used_dec & u_core.core_i.id_stage_i.id_ready_o & u_core.core_i.id_stage_i.instr_valid_i),
      .waddr_a_i(u_core.core_i.id_stage_i.regfile_waddr_wb_i),
      .wdata_a_i(u_core.core_i.id_stage_i.regfile_wdata_wb_i),
      .we_a_i(u_core.core_i.id_stage_i.regfile_we_wb_power_i),
      .waddr_b_i(u_core.core_i.id_stage_i.regfile_alu_waddr_fw_i),
      .wdata_b_i(u_core.core_i.id_stage_i.regfile_alu_wdata_fw_i),
      .we_b_i                 (u_core.core_i.id_stage_i.regfile_alu_we_fw_power_i & u_core.core_i.ex_stage_i.alu_ready & u_core.core_i.ex_stage_i.mult_ready)
  );

  initial begin
    run_test("rv32im_base_test");
    $stop;
  end

//   initial begin
//     void'($value$plusargs("TESTS=%d",                 TESTS));
//     void'($value$plusargs("RUN_STIM_BATCH3=%d",       run_stim_batch3));
//     void'($value$plusargs("RELAX_RD_RS=%d",           relax_rd_rs));
//     void'($value$plusargs("PRELOAD_ENABLE=%d",        preload_enable));
//     void'($value$plusargs("TIMING_CHECK_ENABLE=%d",   timing_check_enable));
//     void'($value$plusargs("TIMING_CHECK_IS_ERROR=%d", timing_check_is_error));
//     void'($value$plusargs("STRICT_BRANCH_CHECK=%d",   strict_branch_check));
//     void'($value$plusargs("CHECK_LINK_VALUES=%d",     check_link_values));
//     void'($value$plusargs("ILLEGAL_DETECT_ENABLE=%d", illegal_detect_enable));
//   end

  initial begin
    uvm_config_db#(int)::set(null, "*", "TESTS", TESTS);

    uvm_config_db#(virtual rv32im_instr_if)::set(null, "*", "INSTR_IF",       instr_if);
    uvm_config_db#(virtual obi_data_if)::set    (null, "*", "DATA_IF",        data_if);
    uvm_config_db#(virtual debug_interupt_if)::set(null, "*", "DEBUG_INT_IF", debug_int_if);
    uvm_config_db#(virtual alu_if)::set         (null, "*", "ALU_IF",         alu_if);
    uvm_config_db#(virtual mul_if)::set         (null, "*", "MUL_IF",         mul_if);
    uvm_config_db#(virtual regfile_if)::set     (null, "*", "REG_IF",         regfile_if);

    uvm_config_db#(bit)::set(null, "*", "run_stim_batch3",       run_stim_batch3[0]);
    uvm_config_db#(bit)::set(null, "*", "relax_rd_rs",           relax_rd_rs[0]);
    uvm_config_db#(bit)::set(null, "*", "preload_enable",        preload_enable[0]);
    uvm_config_db#(bit)::set(null, "*", "timing_check_enable",   timing_check_enable[0]);
    uvm_config_db#(bit)::set(null, "*", "timing_check_is_error", timing_check_is_error[0]);
    uvm_config_db#(bit)::set(null, "*", "strict_branch_check",   strict_branch_check[0]);
    uvm_config_db#(bit)::set(null, "*", "check_link_values",     check_link_values[0]);
    uvm_config_db#(bit)::set(null, "*", "illegal_detect_enable", illegal_detect_enable[0]);
  end

endmodule  // rv32im_top