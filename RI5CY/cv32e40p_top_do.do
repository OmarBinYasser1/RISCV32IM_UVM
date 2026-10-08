quit -sim
vlib work
if {[catch {vlog -f files.f  -l compile.log -suppress 2583 -suppress 13314} ]} { return }
if {[catch {vsim -voptargs=+acc work.rv32im_top -uvmcontrol=all +UVM_NO_RELNOTES +UVM_VERBOSITY=UVM_HIGH  -sv_seed random -l sim.log +nowarn8315} ]} { return } 
do wave.do
add wave -position insertpoint  \
sim:/rv32im_top/u_core/core_i/pc_ex \
sim:/rv32im_top/u_core/core_i/pc_id \
sim:/rv32im_top/u_core/core_i/pc_if
run 0
run -all
#quit
