# RI5CY (CV32E40P) UVM Verification Environment

UVM testbench for the OpenHW CV32E40P (RI5CY) core, targeting the RV32IM instruction subset. The environment drives the core through its instruction, data and debug/interrupt interfaces, and passively observes the ALU, multiplier and register file inside the core to check results against a reference model in the scoreboard.

Simulator: Siemens QuestaSim (Till the server is available for running).

---

## 1. Directory Layout

```
RI5CY/
├── cv32e40p_top_do.do        # Compile + simulate script (entry point)
├── wave.do                   # Waveform setup, called by the do file
├── files.f                   # Compile file list (RTL, interfaces, package, top)
│
├── tb/                       # Test, env, virtual sequencer/sequence, top module, package
├── Instr_Agent/              # Active agent: instruction fetch interface (OBI)
├── Data_agent/               # Reactive agent: data memory interface (OBI)
├── Debug_interupt_agent/     # Active agent: debug request / interrupt / fetch enable
├── alu_agent/                # Passive agent: monitors the ALU inside the core
├── mul_agent/                # Passive agent: monitors the multiplier inside the core
├── regfile_agent/            # Passive agent: monitors the register file inside the core
├── system_scoreboard/        # System scoreboard
└── rtl/                      # CV32E40P design sources (not covered here)
```

---

## 2. Where to Find Each Component

### Top level and environment (`tb/`)

| File | Contents |
|---|---|
| `rv32im_tb_top.sv` | Top module `rv32im_top`. Generates the clock, instantiates the DUT and all interfaces, hooks the passive interfaces to internal core signals, sets the virtual interfaces in `uvm_config_db`, and calls `run_test("rv32im_base_test")`. |
| `riscv_pkg.sv` | Package that includes every UVM class in the correct compile order. Check here first to see what is part of the build. |
| `rv32im_test.sv` | `rv32im_base_test`. Builds the env, reads the interface and `TESTS` count from the config DB, creates the instruction config object and starts the virtual sequence. |
| `rv32im_env.sv` | `rv32im_env`. Instantiates all six agents and the scoreboard, and connects monitor analysis ports to the scoreboard. |
| `rv32im_virtual_seqr.sv` | Virtual sequencer holding handles to the instruction, data and debug/interrupt sequencers. |
| `rv32im_virtual_seq.sv` | Virtual sequence. Forks the instruction, reactive data and debug/interrupt sequences. |

### Active / reactive agents

| Folder | Role | Files |
|---|---|---|
| `Instr_Agent/` | Feeds instructions to the core | `rv32im_instr_agent`, `_driver`, `_monitor`, `_seqr`, `_seq`, `_seq_item`, `_config`, `_if` |
| `Data_agent/` | Responds to the core's load/store requests (reactive) | `reactive_data_agent`, `_driver`, `_monitor`, `_sequencer`, `_seq`, plus `data_transaction.sv` and `obi_data_if.sv` |
| `Debug_interupt_agent/` | Drives `irq_i`, `debug_req_i`, `fetch_enable_i` and observes the debug/interrupt outputs | `debug_interupt_agent`, `_driver`, `_monitor`, `_sequencer`, `_seq`, `_transaction`, `_if` |

### Passive agents (monitor only, no driver or sequencer)

| Folder | Observes | Files |
|---|---|---|
| `alu_agent/` | ALU operator, operands and result in `ex_stage` | `alu_agent`, `alu_monitor`, `alu_item`, `alu_if` |
| `mul_agent/` | Multiplier operator, operands and result in `ex_stage` | `mul_agent`, `mul_monitor`, `mul_item`, `mul_if` |
| `regfile_agent/` | Register file read/write ports in `id_stage` | `regfile_agent`, `regfile_monitor`, `regfile_item`, `regfile_if` |

The interfaces of the passive agents are connected to the core through hierarchical references in `rv32im_tb_top.sv` (e.g. `u_core.core_i.ex_stage_i.alu_result`), so a change in the RTL hierarchy needs to be reflected there.

### Scoreboard (`system_scoreboard/`)

| File | Contents |
|---|---|
| `riscv_scoreboard.sv` | The scoreboard used by the environment. Contains the ALU golden model, multiplier check and register file shadow model. It also has analysis exports for instruction and data transactions, which are connected but not yet used for end-to-end checking (marked as TODO in the source). |

### Analysis connectivity

```
instr_agent.instr_mon_ap   ──► sb.instr_ae
data_agent.transaction_ap  ──► sb.data_ae
alu_agt.mon.analysis_port  ──► sb.alu_ae
mul_agt.mon.analysis_port  ──► sb.mul_ae
rf_agt.mon.analysis_port   ──► sb.rf_ae
```

---

## 3. Running the Simulation in QuestaSim

### What the do file does

`cv32e40p_top_do.do` runs these steps in order:

1. `quit -sim` – closes any simulation that is already loaded.
2. `vlib work` – creates the `work` library.
3. `vlog -f files.f` – compiles RTL, interfaces, the UVM package and the top module. The log goes to `compile.log`. The script stops here if compilation fails.
4. `vsim work.rv32im_top` – loads the design with full visibility (`+acc`), `UVM_HIGH` verbosity, a random seed, and the log goes to `sim.log`.
5. `do wave.do` – adds the waveform groups.
6. `run 0` followed by `run -all` – initializes, then runs until the test finishes.

### Steps

1. Open QuestaSim.
2. Change to the project root. This matters because `files.f` uses relative paths:

   ```tcl
   cd <path>/RI5CY
   ```

3. Run the script from the transcript window:

   ```tcl
   do cv32e40p_top_do.do
   ```

Or, from a terminal, to launch QuestaSim and run it in one go:

```bash
cd <path>/RI5CY
vsim -do cv32e40p_top_do.do
```

Use `vsim -c -do cv32e40p_top_do.do` for batch mode without the GUI. In that case, uncomment the `quit` line at the end of the do file, otherwise the session stays open after the run.

### Output

- `compile.log` – compilation messages
- `sim.log` – simulation and UVM report
- `work/` – compiled library

Scoreboard results are reported with the `SB_ALU`, `SB_MUL` and `SB_RF` message IDs, so they can be filtered in the transcript or log with those tags.

---

## 4. Next Phase Steps

### Planned enhancements

1. **Richer logging.** Improve the log output for the datapath (operands, results and forwarding as seen at the ALU, multiplier and register file) and for instruction decoding, so a failing transaction can be traced back to the instruction that caused it without opening the waveform.

2. **Coverage.** Add functional coverage collectors for:
   - System-wide coverage (instruction mix, instruction sequences, data accesses, debug/interrupt activity).
   - The ALU and MUL agents (operators, operand corner cases, result ranges).
   - The register file agent (register usage on each read/write port, read-after-write patterns).

3. **Register file initialization sequence.** Add a sequence that writes known values into the register file right after reset, so the shadow model starts in the same state as the design and later reads are meaningful.

4. **Instruction and data checks in the scoreboard.** The instruction and data monitors are already connected to the scoreboard, but their FIFOs are not consumed yet. The checks currently supported are:
   - ALU: arithmetic and logic operations (branch comparisons are not checked)
   - MUL
   - Register file

   Instruction-level (fetched and decoded instruction versus what the core executed) and data-level (load/store address, byte enables, write data and returned read data) checks are to be added on top of these.

5. **Multiple outstanding data requests.** Extend the data driver in `Data_agent/` so it can accept and track more than one data memory request at a time, instead of serving them one by one.

6. **Modular checking.** Move part of the checking out of the central system scoreboard into separate checkers for the ALU, MUL and register file. The scoreboard then keeps only the checks that need a system view, and each unit can be checked, reused and debugged on its own.

### Open items carried over from the code

**Stimulus**
- Instruction sequence: build a virtual sequence that produces a wider variety of instructions. The current sequence only generates ALU-type R-format instructions.
- Instruction mix: the current instruction count and mix is an initial setup. The ratios of the instruction types still need to be made configurable for designated sub-programs.
- Weighted distributions: R, I, load, store and branch operations are currently picked uniformly from their allowed sets. Weighted distributions can be added if a skewed mix is needed.
- J/U-type instructions have no constraints yet, apart from the destination register, which could be a general constraint.

**Scoreboard**
- Branch comparisons: the ALU comparison operators report on `comparison_result_o`, which the ALU interface does not capture yet, so they are skipped by the checker.
- MUL_MAC32 and MUL_MSU32 are modelled in the multiplier reference, but it still has to be confirmed whether they are within the verification scope.
- Register file write pass count: a write is currently counted as a pass when it is recorded in the shadow model, not after a comparison. It needs to be decided what a pass should mean for writes.

**Register file agent**
- Add the `id_valid_o` signal to the register file interface and its clocking block, and use it as the read enable in the register file monitor.

**Environment**
- Optionally add analysis exports at the edge of each agent, so the environment connects to the agent rather than to the monitor inside it.


-------------------------------------------------------------
SCoreboard
--------------------------------------------------------------
1- functionality 
2- register WB , data WB 
3- add pc in our transaction 
4- check on timing  
add  (inst mon -> issue cycle = num) (reg mon -> write_reg cycle = NUM2 ) (exec_clk_cycle  -> alu_monitor)
   sub 
   div 2- 32 clk cycles
   wirte - reg = 4+12

   add x4 x2 x1
   predictor (write_reg - issue =4)

  
   SB 103
         l    l   l    l
   1004        x  x     x
   1008  x
   10012
    x x x x 
   1st transaction ->  1004 ( x x x )
   2nd transaction -> 1008    (x)
   int wrte_reg cycle=0;
   @posedge clk 
   wrtie_reg cycle=1;

   5- check on merging missaligned addresses
----------------------------------------------------------------------
Tasks
--------------------------------------------------------------------
*** generate sequences , add coverage 

 1- karim : instr_sequences , add pc to the transaction , (optional clk cycles to calculate the timing , assertions obi_instr_if) , add decode in monitor 
 2-: omar : data_agent (handel the outstanding transactions) + assertions
 3-: youssef : 
 4- abdelrahman : 



   s


