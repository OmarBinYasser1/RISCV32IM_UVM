# RV32IM UVM Verification Environment

A UVM-based verification environment for the **RV32IM** instruction set, targeting the open-source **OpenHW CV32E40P** core (configured with `FPU=0`, `COREV_PULP=0`, `COREV_CLUSTER=0`, `ZFINX=0`). The environment drives instructions and data over OBI interfaces, checks results with layered scoreboards, collects functional coverage, and monitors protocol and timing behaviour with SVA.

> **Simulator:** Questa / ModelSim (`vlog`/`vsim`, UVM 1.x, `-cover`). The run script is Tcl-based (`.do`).

---

## Table of Contents

- [RV32IM UVM Verification Environment](#rv32im-uvm-verification-environment)
  - [Table of Contents](#table-of-contents)
  - [Highlights](#highlights)
  - [Repository Layout](#repository-layout)
  - [Architecture](#architecture)
  - [Tests and Sequences](#tests-and-sequences)
  - [Checking](#checking)
    - [`riscv_alu_scoreboard`](#riscv_alu_scoreboard)
    - [`riscv_rf_scoreboard`](#riscv_rf_scoreboard)
    - [`riscv_system_scoreboard`](#riscv_system_scoreboard)
  - [Functional Coverage](#functional-coverage)
  - [Assertions](#assertions)
  - [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Run (GUI / Tcl)](#run-gui--tcl)
    - [Selecting a test](#selecting-a-test)
    - [Manual flow](#manual-flow)
  - [Configuration Knobs](#configuration-knobs)
  - [Verification Scope](#verification-scope)
  - [Traceability](#traceability)
  - [Known Notes](#known-notes)

---

## Highlights

- Multi-agent UVM environment: instruction, reactive data (OBI), debug/interrupt, plus passive ALU, MUL/DIV and register-file observation agents.
- Three scoreboards split by responsibility: arithmetic, register file, and system-level (PC flow, link values, LSU).
- 37 covergroups spanning ALU, MUL/DIV, control flow, register file/hazards and OBI.
- Constrained-random and directed sequences, composed per test through a virtual sequence.
- OBI protocol assertions for the instruction and data buses, and MUL/MULH timing assertions.
- Latest coverage report in this repository: **99.70 % total covergroup coverage** (1665 / 1693 bins hit), see `cv32e40p_top_Func_Covr.txt`.

## Repository Layout

```
RIC5Y/
├── files.f                    # Compile file list (RTL, interfaces, package, SVA, TB top)
├── cv32e40p_top_do.do         # Compile + simulate + coverage-report script
├── wave.do                    # Waveform setup
├── cv32e40p_top_Func_Covr.txt # Functional coverage report (generated)
├── rv32im_top.ucdb            # Coverage database (generated)
│
├── rtl/                       # CV32E40P core RTL (DUT) and packages
├── tb/                        # Testbench top, package, env, tests, virtual sequence
│   ├── rv32im_tb_top.sv       #   module rv32im_top: DUT, interfaces, binds, config_db
│   ├── riscv_pkg.sv           #   package including every UVM class (ordered)
│   ├── rv32im_env.sv          #   environment
│   ├── rv32im_test.sv         #   rv32im_base_test
│   ├── rv32im_virtual_seq.sv  #   top-level sequence orchestration
│   └── tests/                 #   derived tests (alu, muldiv, mem, ctrl_hazard, random)
│
├── Instr_Agent/               # Instruction OBI slave agent (+ Sequences/)
├── Data_agent/                # Reactive data OBI agent (memory model)
├── Debug_interupt_agent/      # Debug request / IRQ / fetch-enable agent
├── alu_agent/                 # Passive agent: ALU stage observation
├── mul_agent/                 # Passive agent: MUL/DIV stage observation
├── regfile_agent/             # Passive agent: register file / PC trace observation
│
├── sb/                        # Scoreboards (alu, rf, system)
├── Coverage/                  # Functional coverage subscribers
└── sva/                       # OBI protocol and MUL timing assertions
```

## Architecture

```
                 ┌──────────────────────── rv32im_base_test ───────────────────────┐
                 │  virtual sequence ──► instr seqs (queue) │ data seq │ debug seq  │
                 └───────────────┬───────────────┬───────────────┬─────────────────┘
                                 │               │               │
                          ┌──────▼─────┐  ┌──────▼──────┐  ┌─────▼───────┐
                          │ Instr agent│  │ Data agent  │  │ Debug/IRQ   │
                          │ (OBI slave)│  │ (reactive)  │  │ agent       │
                          └──────┬─────┘  └──────┬──────┘  └─────┬───────┘
                                 │               │               │
                          ┌──────▼───────────────▼───────────────▼──────┐
                          │             CV32E40P  (DUT)                 │
                          └──────┬───────────────┬──────────────┬───────┘
                                 │               │              │
                          ┌──────▼─────┐  ┌──────▼─────┐  ┌─────▼──────┐
                          │ ALU agent  │  │ MUL agent  │  │ RegFile    │   (passive monitors)
                          └──────┬─────┘  └──────┬─────┘  └─────┬──────┘
                                 └───────┬───────┴──────────────┘
                                         ▼
                   Scoreboards: alu_sb · rf_sb · system sb      Coverage: alu · mul · ctrl_flow · regfile · obi
```

| Component | Role |
|---|---|
| **Instruction agent** | Acts as the OBI instruction memory. Streams sequence-generated RV32IM instructions to the core and publishes monitored fetches. |
| **Reactive data agent** | Responds to core load/store traffic as the OBI data slave, with a tag-pattern memory preload (`PRELOAD_ENABLE`) and a golden-memory counterpart in the scoreboard. |
| **Debug/interrupt agent** | Drives `fetch_enable`, `debug_req`, `irq` and observes sleep/debug status. |
| **ALU / MUL / RegFile agents** | Passive monitors tapping internal EX-stage and ID-stage signals through interfaces bound in `rv32im_tb_top.sv`. |

## Tests and Sequences

All tests extend `rv32im_base_test`, which builds the environment, pushes configuration into the sequences, and reports **TEST PASSED / FAILED** based on the UVM error and fatal counts. Derived tests only override `add_sequences()`.

| Test | Purpose | Sequences |
|---|---|---|
| `rv32im_base_test` | Full regression (default in `tb_top`) | reset_init, rand_alu, rand_mem, rand_ctrl, dir_alu, dir_ctrl, dir_muldiv, dir_hazard, dir_mem, dir_corner, stream |
| `rv32im_random_test` | Random-only regression | reset_init, rand_alu, rand_mem, rand_ctrl, stream |
| `rv32im_alu_test` | ALU focus | reset_init, rand_alu, dir_alu, dir_corner |
| `rv32im_muldiv_test` | MUL/DIV focus | reset_init, rand_alu, dir_muldiv |
| `rv32im_mem_test` | Load/store focus | reset_init, rand_mem, dir_mem |
| `rv32im_ctrl_hazard_test` | Control flow and hazards | reset_init, rand_ctrl, dir_ctrl, dir_hazard |

Sequence files live in `Instr_Agent/Sequences/`. After the last instruction sequence, the virtual sequence waits for the pipeline to drain before ending the run.

## Checking

### `riscv_alu_scoreboard`
Arithmetic correctness for ALU, MUL, MULH*, DIV, DIVU, REM and REMU, plus latency checks (`mul_lat_p`, `mulh_lat_p`, `div_lat_p`). Timing checks are controlled by `TIMING_CHECK_ENABLE` and `TIMING_CHECK_IS_ERROR`.

### `riscv_rf_scoreboard`
Register-file read/write correctness and `x0` immutability.

### `riscv_system_scoreboard`
- **PC flow:** exact next-PC check from the DUT's ID-stage PC trace. Taken branches and JAL expect `PC + offset`; not-taken expect `PC + 4`; JALR expects `(rs1 + imm) & ~1`. Operands come from the forwarded ID-stage values (`STRICT_BRANCH_CHECK`).
- **Link / writeback values:** reference-model checks for JAL, JALR, AUIPC and LUI rd values (`CHECK_LINK_VALUES`).
- **Illegal instructions:** the next-PC check is suppressed once after an illegal word, since the core redirects to the trap vector (`ILLEGAL_DETECT_ENABLE`).
- **Data bus:** OBI protocol, address-alignment sanity, and load/store coherency against a golden memory.
- **Instruction mix** statistics and retirement accounting.

## Functional Coverage

| Subscriber | Covergroups |
|---|---|
| `alu_coverage` | addsub, slt, bitwise, shift, branch, div, rem, div_eq_operand, div_pattern, div_truncation, rem_divisor_2, div_latency |
| `mul_coverage` | mul, toggle, pair, mul_latency, mul_pattern, mul_regwalk, mul_x0 |
| `ctrl_flow_coverage` | jal, jalr, branch_instr, imm_bitwalk, load, store, branch_back2back, rtype_alu, lui_auipc |
| `regfile_coverage` | regfile, raw_hazard, raw_hazard_producer, hazard_matrix, same_reg, stream, x0_instr, illegal_instr |
| `obi_coverage` | obi_cg (including `we` x `gnt` / `rvalid` / outstanding crosses) |

## Assertions

| File | Module | Contents |
|---|---|---|
| `sva/obi_sva.sv` | `obi_instr_sva`, `obi_data_sva` | Reset behaviour, no-X after reset, address stability while waiting for grant, request held until grant, grant implies request, `rvalid` needs an outstanding transaction, max 2 outstanding, byte-enable legality (data bus). |
| `sva/mul_timing_sva.sv` | `mul_timing_sva` | `MUL` ready in 1 cycle; `MULH` / `MULHSU` / `MULHU` ready in exactly 5 cycles. Bound into `cv32e40p_top` from `rv32im_tb_top.sv`. |

## Getting Started

### Prerequisites
- Questa / ModelSim with UVM support and coverage licences.
- Run from the `RIC5Y/` directory (all paths in `files.f` are relative to it).

### Run (GUI / Tcl)

```tcl
cd RIC5Y
*Inside Questasim* do cv32e40p_top_do.do
*From Terminal* vsim.exe -do cv32e40p_top_do.do
```

The script will:
1. Create the `work` library and compile everything in `files.f` with `+cover -covercells`.
2. Launch `vsim` on `work.rv32im_top` with the selected plusargs and a fixed seed (`-sv_seed 523639485`; a `-sv_seed random` line is provided commented out).
3. Load `wave.do` and extra pipeline/prefetch signals.
4. Run to completion, save `rv32im_top.ucdb`, and write the report `cv32e40p_top_Func_Covr.txt`.

### Selecting a test

`rv32im_top` calls `run_test("rv32im_base_test")`. Override it from the command line, or uncomment the `UVM_TESTNAME` line in the `.do` file:

```tcl
set UVM_TESTNAME rv32im_muldiv_test
```

### Manual flow

```bash
vlib work
vlog -f files.f +cover -covercells -suppress 2583 -suppress 13314
vsim -voptargs=+acc work.rv32im_top -uvmcontrol=all +UVM_NO_RELNOTES \
     +UVM_TESTNAME=rv32im_alu_test +UVM_VERBOSITY=UVM_MEDIUM -cover -sv_seed random
```

## Configuration Knobs

Knobs are set at the top of `cv32e40p_top_do.do` and forwarded to `vsim` as plusargs.

| Knob | Default (`.do`) | Description |
|---|---|---|
| `UVM_VERBOSITY` | `UVM_MEDIUM` | UVM report verbosity. |
| `UVM_TESTNAME` | unset | Test to run. |
| `TESTS` | `100` | Randomised instructions per sequence phase. |
| `RUN_STIM_BATCH3` | `0` | `1` enables the additional directed stimulus phases (S-01..S-29). |
| `RELAX_RD_RS` | `0` | `1` relaxes the rd/rs register partition so RAW and same-register cases become reachable in random phases. |
| `PRELOAD_ENABLE` | `1` | Tag-pattern preload of the data memory. |
| `TIMING_CHECK_ENABLE` | `1` | Enable latency and timing checks. |
| `TIMING_CHECK_IS_ERROR` | `0` | `0` reports timing mismatches as `uvm_warning`, `1` as `uvm_error`. |
| `STRICT_BRANCH_CHECK` | `1` | Exact taken / not-taken next-PC check. |
| `CHECK_LINK_VALUES` | `1` | JAL / JALR / AUIPC / LUI rd value check. |
| `ILLEGAL_DETECT_ENABLE` | `1` | Suppress one next-PC check after an illegal word. |

## Verification Scope

**In scope:** RV32I integer ALU, loads/stores, branches and jumps, M-extension (MUL/MULH*/DIV*/REM*), register-file behaviour and hazards, PC flow, OBI instruction/data protocol, MUL/DIV latency.

**Out of scope:** Exception behaviour. Illegal encodings are driven and checked only for "architectural state unchanged", not for `mcause` / `mepc` / `mtvec` handling. Misaligned branch/jump targets and dedicated misaligned load/store stimulus are not generated. The trap-redirect PC check is intentionally skipped:

```systemverilog
// ASSUMPTION: trap redirect not checked (exceptions out of scope)
```

**Timing checks** are shipped in warning-only mode until the expected latencies are calibrated against simulation results. (like the fast path in the divider)

## Traceability

Stimulus, checks and coverage carry `// CHK:<ID>` comments that map back to the verification plan and action checklist (for example `CHK:V-01`, `C-03`, `I-05`). Sequence class names are intentionally neutral so they can be renamed once the plan is re-keyed. Search with `grep -rn "CHK:" .` to find the implementation of any item.

## Known Notes

- **Plusarg parsing in `tb_top`:** the `$value$plusargs` block in `rv32im_tb_top.sv` is currently commented out, so the knobs forwarded by the `.do` file are not read. The testbench uses its in-file defaults (for example `TESTS = 100`, `run_stim_batch3 = 1`). Uncomment that block for the `.do` settings to take effect.
- **OBI instruction SVA reset:** `obi_instr_sva` is instantiated with `.rst_n(rst_n_i)`, while the testbench reset net is `rst_ni`. Check that this connection is intended.
- **Generated artefacts** (`rv32im_top.ucdb`, `cv32e40p_top_Func_Covr.txt`, `work/`, logs) are outputs of a run and can be regenerated.
- The CV32E40P RTL under `rtl/` is third-party (OpenHW Group) and retains its original licence terms.