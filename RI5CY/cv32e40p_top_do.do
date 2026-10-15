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

# ===================== Plusargs (edit manually) =========================
# TESTS            : number of randomised instructions per phase.
#                    Passed as +TESTS=<n>; tb_top default is 100.
# RUN_STIM_BATCH3  : 1 = enable the Batch-3 directed stimulus phases
#                    (S-01..S-29).  Default 0 = base regression unchanged.
# RELAX_RD_RS      : 1 = relax rd/rs partition (I-03); RAW / same-register
#                    corners become reachable in the random phases.
# PRELOAD_ENABLE   : 1 = tag-pattern preload in the data driver (I-05).
#                    Default 1; set 0 to restore empty-memory behaviour.
#
# Batch-5 timing checkers (H-B4 warning-only default):
# TIMING_CHECK_ENABLE   : 1 (default) = enable C-10/C-11 timing checks.
# TIMING_CHECK_IS_ERROR : 0 (default) = warnings;  1 = uvm_error.
#
# Optional scoreboard overrides (uncomment to pass; default behaviour is
# identical to what the scoreboard uses when the variable is unset):
#   STRICT_BRANCH_CHECK   1 (default) = exact taken/not-taken next-PC check (C-03).
#   CHECK_LINK_VALUES     1 (default) = JAL/JALR/AUIPC/LUI link-value queue (C-14).
#   ILLEGAL_DETECT_ENABLE 1 (default) = suppress one next-PC check after an
#                                       illegal word (C-04).
# ========================================================================
set TESTS                 100
set RUN_STIM_BATCH3       0
set RELAX_RD_RS           0
set PRELOAD_ENABLE        1
set TIMING_CHECK_ENABLE   1
# set TIMING_CHECK_IS_ERROR 1
# set STRICT_BRANCH_CHECK   1
# set CHECK_LINK_VALUES     1
# set ILLEGAL_DETECT_ENABLE 1

quit -sim
file delete compile.log
transcript file ""
file delete sim.log
vlib work
if {[catch {vlog -f files.f +cover -covercells -l compile.log -suppress 2583 -suppress 13314 }]} { return }

# ---------------- Build the vsim plusarg list ----------------
set UVM_PLUSARGS [list +UVM_VERBOSITY=$UVM_VERBOSITY]
if {[info exists UVM_TESTNAME] && $UVM_TESTNAME ne ""} {
    lappend UVM_PLUSARGS +UVM_TESTNAME=$UVM_TESTNAME
}
lappend UVM_PLUSARGS +TESTS=$TESTS
lappend UVM_PLUSARGS +RUN_STIM_BATCH3=$RUN_STIM_BATCH3
lappend UVM_PLUSARGS +RELAX_RD_RS=$RELAX_RD_RS
lappend UVM_PLUSARGS +PRELOAD_ENABLE=$PRELOAD_ENABLE
lappend UVM_PLUSARGS +TIMING_CHECK_ENABLE=$TIMING_CHECK_ENABLE
if {[info exists TIMING_CHECK_IS_ERROR]}  { lappend UVM_PLUSARGS +TIMING_CHECK_IS_ERROR=$TIMING_CHECK_IS_ERROR }
if {[info exists STRICT_BRANCH_CHECK]}   { lappend UVM_PLUSARGS +STRICT_BRANCH_CHECK=$STRICT_BRANCH_CHECK }
if {[info exists CHECK_LINK_VALUES]}     { lappend UVM_PLUSARGS +CHECK_LINK_VALUES=$CHECK_LINK_VALUES }
if {[info exists ILLEGAL_DETECT_ENABLE]} { lappend UVM_PLUSARGS +ILLEGAL_DETECT_ENABLE=$ILLEGAL_DETECT_ENABLE }

#if {[catch {vsim -voptargs=+acc work.rv32im_top -uvmcontrol=all +UVM_NO_RELNOTES {*}$UVM_PLUSARGS -cover -classdebug -sv_seed random -l sim.log}]} { quit -sim }
if {[catch {vsim -voptargs=+acc work.rv32im_top -uvmcontrol=all +UVM_NO_RELNOTES {*}$UVM_PLUSARGS -cover -classdebug -sv_seed 523639485 -l sim.log}]} { quit -sim }

do wave.do
add wave -position insertpoint \
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
#coverage report -summary
coverage report -summary -cvg -assert
#quit -sim
#vcover report rv32im_top.ucdb -annotate -all -details -output cv32e40p_top_Code_Covr.txt