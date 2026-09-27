module rv32im_top ();
    
    int CLK_PERIOD = 10 ; // Used by the system scoreboard
    int TESTS = 1 ;


    bit clk_i , rst_ni;

    always #(CLK_PERIOD/2) clk_i = ~ clk_i;


    // DUT Instantiation TODO
    cv32e40p_top /* #() */ cv32e40p_top (


    );

    // Instruction Interface (OBI Interface) Instantiation
    rv32im_instr_if instr_if (.clk_i(clk_i));
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