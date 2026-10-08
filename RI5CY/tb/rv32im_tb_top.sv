module rv32im_top ();
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import riscv_pkg::*;


  int   CLK_PERIOD = 10;  // Used by the system scoreboard
  int   TESTS = 10;

  logic clk_i = 0;
  wire  rst_ni;

  always #(CLK_PERIOD / 2) clk_i = ~clk_i;
  
  // Instruction Interface (OBI Interface) Instantiation
  rv32im_instr_if instr_if (.clk(clk_i));
  
  assign rst_ni = instr_if.rst_n;

                                        // Active Interfaces (Driving / Monitoring)

  // Instruction Interface (OBI Interface) Instantiation
  obi_data_if data_if (
      .clk  (clk_i),
      .rst_n(rst_ni)
  );
  // Debug_Interrupt Interface Instantiation
  debug_interupt_if debug_int_if (
      .clk  (clk_i),
      .rst_n(rst_ni)
  );
  
  //  DUT Instantiation 
  cv32e40p_top #(
      .FPU             (0),
      .FPU_ADDMUL_LAT  (0),
      .FPU_OTHERS_LAT  (0),
      .ZFINX           (0),
      .COREV_PULP      (0),
      .COREV_CLUSTER   (0),
      .NUM_MHPMCOUNTERS(1)
  ) u_core (
      // Clock and reset
      .rst_ni      (rst_ni),
      .clk_i       (clk_i),
      .scan_cg_en_i(debug_int_if.scan_cg_en_i),

      // Special control signals
      .fetch_enable_i (debug_int_if.fetch_enable_i),
      .pulp_clock_en_i('0),
      .core_sleep_o   (debug_int_if.core_sleep_o),

      // Configuration
      .boot_addr_i        ('0),
      .mtvec_addr_i       ('0),
      .dm_halt_addr_i     ('0),
      .dm_exception_addr_i('0),
      .hart_id_i          ('0),

      // Instruction memory interface
      .instr_addr_o  (instr_if.instr_addr_o),
      .instr_req_o   (instr_if.instr_req_o),
      .instr_gnt_i   (instr_if.instr_gnt_i),
      .instr_rvalid_i(instr_if.instr_rvalid_i),
      .instr_rdata_i (instr_if.instr_rdata_i),

      // Data memory interface
      .data_addr_o  (data_if.data_addr_o),
      .data_req_o   (data_if.data_req_o),
      .data_gnt_i   (data_if.data_gnt_i),
      .data_we_o    (data_if.data_we_o),
      .data_be_o    (data_if.data_be_o),
      .data_wdata_o (data_if.data_wdata_o),
      .data_rvalid_i(data_if.data_rvalid_i),
      .data_rdata_i (data_if.data_rdata_i),

      // Interrupt interface
      .irq_i    (debug_int_if.irq_i),
      .irq_ack_o(debug_int_if.irq_ack_o),
      .irq_id_o (debug_int_if.irq_id_o),

      // Debug interface
      .debug_req_i      (debug_int_if.debug_req_i),
      .debug_havereset_o(debug_int_if.debug_havereset_o),
      .debug_running_o  (debug_int_if.debug_running_o),
      .debug_halted_o   (debug_int_if.debug_halted_o)
  );
                                        // Passive Interfaces (Monitoring Only)

        
    // ALU Interface Instantiation
    alu_if alu_if (
        .clk                  (clk_i),
        .rst_n                (rst_ni),
        .enable_i             (u_core.core_i.ex_stage_i.alu_en_i),
        .operator_i           (u_core.core_i.ex_stage_i.alu_operator_i),
        .operand_a_i          (u_core.core_i.ex_stage_i.alu_operand_a_i),
        .operand_b_i          (u_core.core_i.ex_stage_i.alu_operand_b_i),
        .operand_c_i          (u_core.core_i.ex_stage_i.alu_operand_c_i),
        .result_o             (u_core.core_i.ex_stage_i.alu_result),
        .comparison_result_o  (u_core.core_i.ex_stage_i.alu_cmp_result),
        .ready_o              (u_core.core_i.ex_stage_i.alu_ready),
        .ex_ready_i           (u_core.core_i.ex_stage_i.ex_ready_o)
    );
    // MUL Interface Instantiation
    mul_if mul_if (
        .clk            (clk_i),
        .rst_n          (rst_ni),
        .enable_i       (u_core.core_i.ex_stage_i.mult_en_i),
        .operator_i     (u_core.core_i.ex_stage_i.mult_operator_i),
        .op_a_i         (u_core.core_i.ex_stage_i.mult_operand_a_i),
        .op_b_i         (u_core.core_i.ex_stage_i.mult_operand_b_i),
        .op_c_i         (u_core.core_i.ex_stage_i.mult_operand_c_i),
        .result_o       (u_core.core_i.ex_stage_i.mult_result),
        .ready_o        (u_core.core_i.ex_stage_i.mult_ready),
        .ex_ready_i     (u_core.core_i.ex_stage_i.ex_ready_o)
    );
    // RegFile Interface Instantiation
    regfile_if regfile_if (
        .clk  (clk_i),
        .rst_n(rst_ni),
        // Read port a
        .raddr_a_i(u_core.core_i.id_stage_i.regfile_addr_ra_id),
        .rdata_a_o(u_core.core_i.id_stage_i.regfile_data_ra_id),
        // Read port b
        .raddr_b_i(u_core.core_i.id_stage_i.regfile_addr_rb_id),
        .rdata_b_o(u_core.core_i.id_stage_i.regfile_data_rb_id),
        // Read port c
        .raddr_c_i(u_core.core_i.id_stage_i.regfile_addr_rc_id),
        .rdata_c_o(u_core.core_i.id_stage_i.regfile_data_rc_id),
        // Write port a
        .waddr_a_i(u_core.core_i.id_stage_i.regfile_waddr_wb_i),
        .wdata_a_i(u_core.core_i.id_stage_i.regfile_wdata_wb_i),
        .we_a_i(u_core.core_i.id_stage_i.regfile_we_wb_power_i),
        // Write port b
        .waddr_b_i(u_core.core_i.id_stage_i.regfile_alu_waddr_fw_i),
        .wdata_b_i(u_core.core_i.id_stage_i.regfile_alu_wdata_fw_i),
        .we_b_i(u_core.core_i.id_stage_i.regfile_alu_we_fw_power_i)
    );


  // TODO : Initially the reset is owned by the top until the debug+interrupt , data interfaces are integrated
  initial begin
    run_test("rv32im_base_test");  // Initially runs the base test 
    $stop;
  end

  initial begin
    uvm_config_db#(int)::set(null, "*", "TESTS", TESTS);
    uvm_config_db#(virtual rv32im_instr_if)::set(null, "*", "INSTR_IF", instr_if);
    uvm_config_db#(virtual obi_data_if)::set(null, "*", "DATA_IF", data_if);
    uvm_config_db#(virtual debug_interupt_if)::set(null, "*", "DEBUG_INT_IF", debug_int_if);
    uvm_config_db#(virtual alu_if)::set(null, "*", "ALU_IF", alu_if);
    uvm_config_db#(virtual mul_if)::set(null, "*", "MUL_IF", mul_if);
    uvm_config_db#(virtual regfile_if)::set(null, "*", "REG_IF", regfile_if);
  end

endmodule  // rv32im_top
