quit -sim
file delete compile.log
transcript file ""
file delete sim.log
vlib work
if {[catch {vlog -f files.f  -l compile.log -suppress 2583 -suppress 13314} ]} { return }
if {[catch {vsim -voptargs=+acc work.rv32im_top -uvmcontrol=all +UVM_NO_RELNOTES +UVM_VERBOSITY=UVM_MEDIUM  -sv_seed random -l sim.log +nowarn8315} ]} { return } 
#if {[catch {vsim -voptargs=+acc work.rv32im_top -uvmcontrol=all +UVM_NO_RELNOTES +UVM_VERBOSITY=UVM_MEDIUM  -sv_seed 1208626153 -l sim.log +nowarn8315} ]} { return } 
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
run 0
run -all
#stop
#quit


# Sv_Seed = 1208626153