# ===================== UVM settings (edit manually) =====================
# UVM_VERBOSITY : UVM_NONE | UVM_LOW | UVM_MEDIUM | UVM_HIGH | UVM_FULL | UVM_DEBUG
#                 always passed to vsim as +UVM_VERBOSITY=<value>
# UVM_TESTNAME  : not set by default -> +UVM_TESTNAME is NOT passed to vsim.
#                 Uncomment the line below and set a test name to pass +UVM_TESTNAME=<value>
# (the unset line makes re-running this file in the same vsim session honour a commented-out UVM_TESTNAME)
unset -nocomplain UVM_TESTNAME
set UVM_VERBOSITY UVM_MEDIUM
# set UVM_TESTNAME my_test
# ========================================================================
quit -sim
file delete compile.log
transcript file ""
file delete sim.log
vlib work
if {[catch {vlog -f files.f  +cover -covercells -l compile.log -suppress 2583 -suppress 13314 } ]} { return }
set UVM_PLUSARGS [list +UVM_VERBOSITY=$UVM_VERBOSITY]
if {[info exists UVM_TESTNAME] && $UVM_TESTNAME ne ""} { lappend UVM_PLUSARGS +UVM_TESTNAME=$UVM_TESTNAME }
if {[catch {vsim -voptargs=+acc work.rv32im_top -uvmcontrol=all +UVM_NO_RELNOTES {*}$UVM_PLUSARGS -cover -classdebug  -sv_seed random -l sim.log } ]} { quit -sim } 
do wave.do
add wave -position insertpoint  \
sim:/rv32im_top/u_core/core_i/ex_stage_i/alu_ready \
sim:/rv32im_top/u_core/core_i/ex_stage_i/mult_ready \
sim:/rv32im_top/u_core/core_i/pc_if \
sim:/rv32im_top/u_core/core_i/pc_id \
sim:/rv32im_top/u_core/core_i/pc_ex \
sim:/rv32im_top/u_core/core_i/id_stage_i/rega_used_dec \
sim:/rv32im_top/u_core/core_i/id_stage_i/regb_used_dec \
sim:/rv32im_top/u_core/core_i/id_stage_i/regc_used_dec \
sim:/rv32im_top/u_core/core_i/if_stage_i/prefetch_buffer_i/instruction_obi_i/trans_valid_i \
sim:/rv32im_top/u_core/core_i/if_stage_i/prefetch_buffer_i/instruction_obi_i/state_q \
sim:/rv32im_top/u_core/core_i/if_stage_i/prefetch_buffer_i/prefetch_controller_i/busy_o \
sim:/rv32im_top/u_core/core_i/if_stage_i/prefetch_buffer_i/prefetch_controller_i/req_i \
sim:/rv32im_top/u_core/core_i/if_stage_i/prefetch_buffer_i/prefetch_controller_i/cnt_q \
sim:/rv32im_top/u_core/core_i/if_stage_i/prefetch_buffer_i/prefetch_controller_i/fifo_cnt_masked
coverage save rv32im_top.ucdb -onexit -du cv32e40p_top 
run 0
run -all
coverage report -detail -cvg -directive -comments -output cv32e40p_top_Func_Covr.txt
coverage report -summary
#quit -sim 
#vcover report rv32im_top.ucdb -annotate -all -details -output cv32e40p_top_Code_Covr.txt



# Sv_Seed = 1208626153