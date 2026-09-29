module rv32im_top ();
    
    int CLK_PERIOD = 10 ; // Used by the system scoreboard
    int TESTS = 1 ;


    bit clk_i , rst_ni;

    always #(CLK_PERIOD/2) clk_i = ~ clk_i;

    // Instruction Interface (OBI Interface) Instantiation
    rv32im_instr_if instr_if (.clk_i(clk_i));

    // TODO : Data Interface (OBI Interface) Instantiation


    // TODO : Debug_Interrupt Interface Instantiation


    // TODO : DUT Instantiation 
    cv32e40p_top #(
        .FPU                      ( 0 ),
        .FPU_ADDMUL_LAT           ( 0 ),
        .FPU_OTHERS_LAT           ( 0 ),
        .ZFINX                    ( 0 ),
        .COREV_PULP               ( 0 ),
        .COREV_CLUSTER            ( 0 ),
        .NUM_MHPMCOUNTERS         ( 1 )
    ) u_core (
        // Clock and reset
        .rst_ni                   (rst_ni),
        .clk_i                    (clk_i),
        .scan_cg_en_i             (),

        // Special control signals
        .fetch_enable_i           (),
        .pulp_clock_en_i          (),
        .core_sleep_o             (),

        // Configuration
        .boot_addr_i              (),
        .mtvec_addr_i             (),
        .dm_halt_addr_i           (),
        .dm_exception_addr_i      (),
        .hart_id_i                (),

        // Instruction memory interface
        .instr_addr_o             (instr_if.instr_addr_o),
        .instr_req_o              (instr_if.instr_req_o),
        .instr_gnt_i              (instr_if.instr_gnt_i),
        .instr_rvalid_i           (instr_if.instr_rvalid_i),
        .instr_rdata_i            (instr_if.instr_rdata_i),

        // Data memory interface
        .data_addr_o              (),
        .data_req_o               (),
        .data_gnt_i               (),
        .data_we_o                (),
        .data_be_o                (),
        .data_wdata_o             (),
        .data_rvalid_i            (),
        .data_rdata_i             (),

        // Interrupt interface
        .irq_i                    (),
        .irq_ack_o                (),
        .irq_id_o                 (),

        // Debug interface
        .debug_req_i              (),
        .debug_havereset_o        (),
        .debug_running_o          (),
        .debug_halted_o           ()
    );


    // TODO : Initially the reset is owned by the top until the debug+interrupt , data interfaces are integrated
    initial begin
        rst_ni = 0;
        repeat (5) @(negedge clk);
        rst_ni = 1;
        run_test(""); // Initially runs the base test     
    end

    // Store the Instruction COnfiguration Elements in the config_db 
    initial begin
        uvm_config_db#(int)::set(null, * , "TESTS", TESTS);
        uvm_config_db#(virtual instr_if)::set(null, * , "INSTR_IF", instr_if);   
    end

endmodule // rv32im_top