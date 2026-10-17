###############################################################################
# wave_rv32im.do
#   Wave setup for the rv32im UVM testbench (top = rv32im_top)
#   Usage (ModelSim/QuestaSim):
#       vsim -do "do wave_rv32im.do; run -all" rv32im_top
#   or, after the design is already loaded:
#       do wave_rv32im.do
###############################################################################

onerror {resume}

###############################################################################
# System / top-level
###############################################################################
add wave -noupdate -group System_Top          /rv32im_top/clk_i
add wave -noupdate -group System_Top          /rv32im_top/rst_ni
add wave -noupdate -group System_Top -radix decimal /rv32im_top/CLK_PERIOD
add wave -noupdate -group System_Top -radix decimal /rv32im_top/TESTS

###############################################################################
# Instruction Interface (OBI) — inst: instr_if
#   rv32im_instr_if
###############################################################################
add wave -noupdate -group Instr_IF                 /rv32im_top/instr_if/rst_n
add wave -noupdate -group Instr_IF                 /rv32im_top/instr_if/instr_req_o
add wave -noupdate -group Instr_IF -radix hex     {/rv32im_top/instr_if/instr_addr_o}
add wave -noupdate -group Instr_IF                 /rv32im_top/instr_if/instr_gnt_i
add wave -noupdate -group Instr_IF                 /rv32im_top/instr_if/instr_rvalid_i
add wave -noupdate -group Instr_IF -radix hex     {/rv32im_top/instr_if/instr_rdata_i}

###############################################################################
# Data Interface (OBI) — inst: data_if
#   obi_data_if
###############################################################################
add wave -noupdate -group Data_IF                 /rv32im_top/data_if/clk
add wave -noupdate -group Data_IF                 /rv32im_top/data_if/rst_n
add wave -noupdate -group Data_IF                 /rv32im_top/data_if/data_req_o
add wave -noupdate -group Data_IF                 /rv32im_top/data_if/data_gnt_i
add wave -noupdate -group Data_IF                 /rv32im_top/data_if/data_we_o
add wave -noupdate -group Data_IF -radix bin     {/rv32im_top/data_if/data_be_o}
add wave -noupdate -group Data_IF -radix hex     {/rv32im_top/data_if/data_addr_o}
add wave -noupdate -group Data_IF -radix hex     {/rv32im_top/data_if/data_wdata_o}
add wave -noupdate -group Data_IF                 /rv32im_top/data_if/data_rvalid_i
add wave -noupdate -group Data_IF -radix hex     {/rv32im_top/data_if/data_rdata_i}

###############################################################################
# Debug & Interrupt Interface — inst: debug_int_if
#   debug_interupt_if
###############################################################################
add wave -noupdate -group Debug_Int_IF                 /rv32im_top/debug_int_if/clk
add wave -noupdate -group Debug_Int_IF                 /rv32im_top/debug_int_if/rst_n
add wave -noupdate -group Debug_Int_IF -radix hex     {/rv32im_top/debug_int_if/irq_i}
add wave -noupdate -group Debug_Int_IF                 /rv32im_top/debug_int_if/irq_ack_o
add wave -noupdate -group Debug_Int_IF -radix unsigned {/rv32im_top/debug_int_if/irq_id_o}
add wave -noupdate -group Debug_Int_IF                 /rv32im_top/debug_int_if/scan_cg_en_i
add wave -noupdate -group Debug_Int_IF                 /rv32im_top/debug_int_if/debug_req_i
add wave -noupdate -group Debug_Int_IF                 /rv32im_top/debug_int_if/debug_havereset_o
add wave -noupdate -group Debug_Int_IF                 /rv32im_top/debug_int_if/debug_running_o
add wave -noupdate -group Debug_Int_IF                 /rv32im_top/debug_int_if/debug_halted_o
add wave -noupdate -group Debug_Int_IF                 /rv32im_top/debug_int_if/fetch_enable_i
add wave -noupdate -group Debug_Int_IF                 /rv32im_top/debug_int_if/core_sleep_o

###############################################################################
# ALU Interface — inst: alu_if
#   alu_if
###############################################################################
add wave -noupdate -group ALU_IF                 /rv32im_top/alu_if/clk
add wave -noupdate -group ALU_IF                 /rv32im_top/alu_if/rst_n
add wave -noupdate -group ALU_IF                 /rv32im_top/alu_if/enable_i
add wave -noupdate -group ALU_IF -radix bin     {/rv32im_top/alu_if/operator_i}
add wave -noupdate -group ALU_IF -radix hex     {/rv32im_top/alu_if/operand_a_i}
add wave -noupdate -group ALU_IF -radix hex     {/rv32im_top/alu_if/operand_b_i}
add wave -noupdate -group ALU_IF -radix hex     {/rv32im_top/alu_if/operand_c_i}
add wave -noupdate -group ALU_IF -radix hex     {/rv32im_top/alu_if/result_o}
add wave -noupdate -group ALU_IF                 /rv32im_top/alu_if/comparison_result_o
add wave -noupdate -group ALU_IF                 /rv32im_top/alu_if/ready_o
add wave -noupdate -group ALU_IF                 /rv32im_top/alu_if/ex_ready_i

###############################################################################
# MUL Interface — inst: mul_if
#   mul_if
###############################################################################
add wave -noupdate -group MUL_IF                 /rv32im_top/mul_if/clk
add wave -noupdate -group MUL_IF                 /rv32im_top/mul_if/rst_n
add wave -noupdate -group MUL_IF                 /rv32im_top/mul_if/enable_i
add wave -noupdate -group MUL_IF -radix bin     {/rv32im_top/mul_if/operator_i}
add wave -noupdate -group MUL_IF -radix hex     {/rv32im_top/mul_if/op_a_i}
add wave -noupdate -group MUL_IF -radix hex     {/rv32im_top/mul_if/op_b_i}
add wave -noupdate -group MUL_IF -radix hex     {/rv32im_top/mul_if/op_c_i}
add wave -noupdate -group MUL_IF -radix hex     {/rv32im_top/mul_if/result_o}
add wave -noupdate -group MUL_IF                 /rv32im_top/mul_if/ready_o
add wave -noupdate -group MUL_IF                 /rv32im_top/mul_if/ex_ready_i

###############################################################################
# Register File Interface — inst: regfile_if
#   regfile_if
###############################################################################
add wave -noupdate -group RegFile_IF                 /rv32im_top/regfile_if/clk
add wave -noupdate -group RegFile_IF                 /rv32im_top/regfile_if/rst_n
add wave -noupdate -group RegFile_IF -radix unsigned {/rv32im_top/regfile_if/raddr_a_i}
add wave -noupdate -group RegFile_IF -radix hex     {/rv32im_top/regfile_if/rdata_a_o}
add wave -noupdate -group RegFile_IF -radix unsigned {/rv32im_top/regfile_if/raddr_b_i}
add wave -noupdate -group RegFile_IF -radix hex     {/rv32im_top/regfile_if/rdata_b_o}
add wave -noupdate -group RegFile_IF -radix unsigned {/rv32im_top/regfile_if/raddr_c_i}
add wave -noupdate -group RegFile_IF -radix hex     {/rv32im_top/regfile_if/rdata_c_o}
add wave -noupdate -group RegFile_IF -radix unsigned {/rv32im_top/regfile_if/waddr_a_i}
add wave -noupdate -group RegFile_IF -radix hex     {/rv32im_top/regfile_if/wdata_a_i}
add wave -noupdate -group RegFile_IF                 /rv32im_top/regfile_if/we_a_i
add wave -noupdate -group RegFile_IF -radix unsigned {/rv32im_top/regfile_if/waddr_b_i}
add wave -noupdate -group RegFile_IF -radix hex     {/rv32im_top/regfile_if/wdata_b_i}
add wave -noupdate -group RegFile_IF                 /rv32im_top/regfile_if/we_b_i

###############################################################################
# DUT (cv32e40p_top) — top-level ports only, so you can eyeball the wiring
# from the interfaces into the core.
###############################################################################
add wave -noupdate -group DUT_u_core                 /rv32im_top/u_core/clk_i
add wave -noupdate -group DUT_u_core                 /rv32im_top/u_core/rst_ni
add wave -noupdate -group DUT_u_core                 /rv32im_top/u_core/fetch_enable_i
add wave -noupdate -group DUT_u_core                 /rv32im_top/u_core/core_sleep_o

add wave -noupdate -group DUT_u_core -radix hex     {/rv32im_top/u_core/instr_addr_o}
add wave -noupdate -group DUT_u_core                 /rv32im_top/u_core/instr_req_o
add wave -noupdate -group DUT_u_core                 /rv32im_top/u_core/instr_gnt_i
add wave -noupdate -group DUT_u_core                 /rv32im_top/u_core/instr_rvalid_i
add wave -noupdate -group DUT_u_core -radix hex     {/rv32im_top/u_core/instr_rdata_i}

add wave -noupdate -group DUT_u_core -radix hex     {/rv32im_top/u_core/data_addr_o}
add wave -noupdate -group DUT_u_core                 /rv32im_top/u_core/data_req_o
add wave -noupdate -group DUT_u_core                 /rv32im_top/u_core/data_gnt_i
add wave -noupdate -group DUT_u_core                 /rv32im_top/u_core/data_we_o
add wave -noupdate -group DUT_u_core -radix bin     {/rv32im_top/u_core/data_be_o}
add wave -noupdate -group DUT_u_core -radix hex     {/rv32im_top/u_core/data_wdata_o}
add wave -noupdate -group DUT_u_core                 /rv32im_top/u_core/data_rvalid_i
add wave -noupdate -group DUT_u_core -radix hex     {/rv32im_top/u_core/data_rdata_i}

add wave -noupdate -group DUT_u_core -radix hex     {/rv32im_top/u_core/irq_i}
add wave -noupdate -group DUT_u_core                 /rv32im_top/u_core/irq_ack_o
add wave -noupdate -group DUT_u_core -radix unsigned {/rv32im_top/u_core/irq_id_o}

add wave -noupdate -group DUT_u_core                 /rv32im_top/u_core/debug_req_i
add wave -noupdate -group DUT_u_core                 /rv32im_top/u_core/debug_havereset_o
add wave -noupdate -group DUT_u_core                 /rv32im_top/u_core/debug_running_o
add wave -noupdate -group DUT_u_core                 /rv32im_top/u_core/debug_halted_o

###############################################################################
# Window Layout
###############################################################################
TreeUpdate [SetDefaultTree]
quietly wave cursor active 1
configure wave -namecolwidth 300
configure wave -valuecolwidth 80
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timelineunits ns
update

wave zoom full
WaveRestoreCursors {{Cursor 1} {0 ns} 0}