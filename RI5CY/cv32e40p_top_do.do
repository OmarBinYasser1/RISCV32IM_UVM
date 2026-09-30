quit -sim
vlib work
if {[catch {vlog -f files.f  -l compile.log -suppress 2583 -suppress 13314} ]} { return }
if {[catch {vsim -voptargs=+acc work.rv32im_top -uvmcontrol=all +UVM_NO_RELNOTES +UVM_VERBOSITY=UVM_MEDIUM  -sv_seed random -l sim.log } ]} { return } 
add wave sim:/rv32im_top/u_core/*
run 0
run -all
# quit
