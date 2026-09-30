quit -sim
vlib work
if {[catch {vlog -f files.f  -l compile.log -suppress 2583 -suppress 13314} ]} { return }
if {[catch {vsim -voptargs=+acc work.rv32im_top -uvmcontrol=all +UVM_NO_RELNOTES +UVM_VERBOSITY=UVM_MEDIUM  -sv_seed random -l sim.log } ]} { quit -sim } 
add wave *
run 0
run -all
