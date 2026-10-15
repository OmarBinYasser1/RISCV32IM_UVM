`ifndef RISCV_SYSTEM_SCOREBOARD_SV
`define RISCV_SYSTEM_SCOREBOARD_SV

//------------------------------------------------------------------------------
// riscv_system_scoreboard
//
// System-level scoreboard for the RISCV32IM core.
//   - Receives regfile_item from regfile_agent monitor (PC_TRACE flow & link values)
//   - Receives rv32im_instr_seq_item from instr_agent monitor
//   - Receives data_transaction from data_agent monitor
//
// Performs:
//   1. PC-flow correctness using the DUT's own ID-stage PC trace
//   2. Link register / architectural rd writeback checks (JAL, JALR, AUIPC, LUI)
//   3. Instruction retirement & instruction mix statistics
//   4. Data memory interface protocol, address alignment, and load/store coherency checks
//   5. Traceability reporting for system verification plan properties
//
// Scope division:
//   - Arithmetic correctness (ALU, DIV, REM, MUL, MULH*) & timing: riscv_alu_scoreboard
//   - Register file read/write correctness & x0 immutability:      riscv_rf_scoreboard
//   - System-level flow, link values, LSU/data bus & mix:          riscv_system_scoreboard
//------------------------------------------------------------------------------
class riscv_system_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(riscv_system_scoreboard)

  //--------------------------------------------------------------------------
  // Analysis exports
  //--------------------------------------------------------------------------
  uvm_analysis_export #(regfile_item)          rf_ae;
  uvm_analysis_export #(rv32im_instr_seq_item) instr_ae;
  uvm_analysis_export #(data_transaction)      data_ae;

  //--------------------------------------------------------------------------
  // TLM FIFOs
  //--------------------------------------------------------------------------
  uvm_tlm_analysis_fifo #(regfile_item)          rf_fifo;
  uvm_tlm_analysis_fifo #(rv32im_instr_seq_item) instr_fifo;
  uvm_tlm_analysis_fifo #(data_transaction)      data_fifo;

  //--------------------------------------------------------------------------
  // Scoreboard configuration & constants
  //--------------------------------------------------------------------------
  bit check_link_values     = 1;
  bit strict_branch_check   = 1;
  bit illegal_detect_enable = 1;

  bit          preload_enable = 1;
  localparam bit [31:0] PRELOAD_BASE  = 32'h1000_0000;
  localparam int unsigned PRELOAD_LEN = 256;

  //--------------------------------------------------------------------------
  // Shadow state
  //--------------------------------------------------------------------------
  // shadow_rf is maintained on writes solely to provide rs1 base register snapshots for JALR target PC calculation
  logic [31:0] shadow_rf [32];
  bit   [31:0] shadow_mem [bit [31:2]];

  //--------------------------------------------------------------------------
  // PC-trace state
  //--------------------------------------------------------------------------
  logic [31:0] pc_tr_prev_pc;
  logic [31:0] pc_tr_prev_instr;
  logic [31:0] pc_tr_prev_rs1_snapshot;
  logic [31:0] pc_tr_prev_rs1_branch;
  logic [31:0] pc_tr_prev_rs2_branch;
  bit          pc_tr_prev_valid;

  // CHK:C-02/C-14  Expected rd-value queue, per destination register.
  typedef struct {
    bit [31:0] pc;
    bit [4:0]  rd;
    bit [31:0] exp_value;
    string     prop;
  } exp_wr_t;
  exp_wr_t exp_wr_q [32][$];

  // CHK:C-04  Set when the currently-decoded instruction is illegal.
  bit suppress_next_pc_check;

  //--------------------------------------------------------------------------
  // Statistics
  //--------------------------------------------------------------------------
  int instr_count, instr_r_type, instr_i_type, instr_load, instr_store, instr_branch, instr_jump, instr_other;
  int mem_store_count, mem_load_count, mem_align_pass, mem_align_fail;
  int pc_pass, pc_fail;
  int mem_load_pass, mem_load_fail;

  int unsigned prop_pass [string];
  int unsigned prop_fail [string];

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    instr_count     = 0; instr_r_type    = 0; instr_i_type    = 0;
    instr_load      = 0; instr_store     = 0; instr_branch    = 0;
    instr_jump      = 0; instr_other     = 0;
    mem_store_count = 0; mem_load_count  = 0;
    mem_align_pass  = 0; mem_align_fail  = 0;
    pc_pass         = 0; pc_fail         = 0;
    mem_load_pass   = 0; mem_load_fail   = 0;
    pc_tr_prev_valid        = 0;
    suppress_next_pc_check  = 0;
    for (int i = 0; i < 32; i++) shadow_rf[i] = 32'h0;
  endfunction

  //--------------------------------------------------------------------------
  // CHK:I-05  Matching preload.
  //--------------------------------------------------------------------------
  function void preload_shadow_mem();
    for (int unsigned i = 0; i < PRELOAD_LEN; i++) begin
      bit [31:0] byte_addr;
      bit [31:2] word_addr;
      byte_addr = PRELOAD_BASE + (i * 4);
      word_addr = byte_addr[31:2];
      shadow_mem[word_addr] = byte_addr;
    end
  endfunction

  //--------------------------------------------------------------------------
  // Build Phase
  //--------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    rf_ae      = new("rf_ae",      this);
    instr_ae   = new("instr_ae",   this);
    data_ae    = new("data_ae",    this);

    rf_fifo    = new("rf_fifo",    this);
    instr_fifo = new("instr_fifo", this);
    data_fifo  = new("data_fifo",  this);

    void'(uvm_config_db#(bit)::get(this, "", "check_link_values",     check_link_values));
    void'(uvm_config_db#(bit)::get(this, "", "strict_branch_check",   strict_branch_check));
    void'(uvm_config_db#(bit)::get(this, "", "illegal_detect_enable", illegal_detect_enable));
    void'(uvm_config_db#(bit)::get(this, "", "preload_enable",        preload_enable));

    foreach (shadow_rf[i]) shadow_rf[i] = '0;

    if (preload_enable) preload_shadow_mem();
  endfunction

  //--------------------------------------------------------------------------
  // Connect Phase
  //--------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    rf_ae.connect(rf_fifo.analysis_export);
    instr_ae.connect(instr_fifo.analysis_export);
    data_ae.connect(data_fifo.analysis_export);
  endfunction

  //--------------------------------------------------------------------------
  // Run Phase
  //--------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    fork
      check_rf();
      check_instr();
      check_data();
    join_none
  endtask

  //--------------------------------------------------------------------------
  // Property bookkeeping
  //--------------------------------------------------------------------------
  function void chk(string prop, bit ok, string msg);
    if (!prop_pass.exists(prop)) begin
      prop_pass[prop] = 0;
      prop_fail[prop] = 0;
    end
    if (ok) prop_pass[prop]++;
    else begin
      prop_fail[prop]++;
      `uvm_error("SB_PROP", $sformatf("%s FAILED | %s", prop, msg))
    end
  endfunction

  //--------------------------------------------------------------------------
  // Helpers
  //--------------------------------------------------------------------------

  // CHK:C-04  Minimal reimplementation of the RV32IM decoder's illegal cases.
  function automatic bit is_illegal_encoding(bit [31:0] i);
    bit [6:0] op = i[6:0];
    bit [2:0] f3 = i[14:12];
    bit [6:0] f7 = i[31:25];

    case (op)
      7'h33: begin
        if (f7 == 7'h00) return 1'b0;
        if (f7 == 7'h20) return (f3 == 3'b000 || f3 == 3'b101) ? 1'b0 : 1'b1;
        if (f7 == 7'h01) return 1'b0;
        return 1'b1;
      end
      7'h13: begin
        if (f3 == 3'b001) return (f7 != 7'h00) ? 1'b1 : 1'b0;
        if (f3 == 3'b101) return ((f7 == 7'h00) || (f7 == 7'h20)) ? 1'b0 : 1'b1;
        return (f3 inside {3'b000, 3'b010, 3'b011, 3'b100, 3'b110, 3'b111}) ? 1'b0 : 1'b1;
      end
      7'h03: return (f3 inside {3'b000, 3'b001, 3'b010, 3'b100, 3'b101}) ? 1'b0 : 1'b1;
      7'h23: return (f3 inside {3'b000, 3'b001, 3'b010}) ? 1'b0 : 1'b1;
      7'h63: return (f3 inside {3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111}) ? 1'b0 : 1'b1;
      7'h6f: return 1'b0;
      7'h67: return (f3 == 3'b000) ? 1'b0 : 1'b1;
      7'h37: return 1'b0;
      7'h17: return 1'b0;
      7'h0f: return 1'b0;
      7'h73: return 1'b0;
      default: return 1'b1;
    endcase
  endfunction

  function void enqueue_expected_wr(bit [31:0] pc, bit [4:0] rd,
                                    bit [31:0] val, string prop);
    exp_wr_t e;
    e.pc        = pc;
    e.rd        = rd;
    e.exp_value = val;
    e.prop      = prop;
    exp_wr_q[rd].push_back(e);
  endfunction

  //--------------------------------------------------------------------------
  // Register File Receiver (PC_TRACE & link-value WRITE checks)
  //--------------------------------------------------------------------------
  task check_rf();
    regfile_item item;

    forever begin
      rf_fifo.get(item);

      if (item.is_reset) begin
        foreach (exp_wr_q[i]) exp_wr_q[i].delete();
        pc_tr_prev_valid       = 0;
        suppress_next_pc_check = 0;
        foreach (shadow_rf[i]) shadow_rf[i] = '0;
        continue;
      end

      case (item.kind)
        regfile_item::WRITE: begin
          if (item.addr != 0) begin
            shadow_rf[item.addr] = item.data;

            // Check architectural rd writeback for link/immediate instructions (C-14/C-02)
            if (check_link_values && exp_wr_q[item.addr].size() > 0) begin
              exp_wr_t e = exp_wr_q[item.addr].pop_front();
              chk(e.prop, item.data === e.exp_value,
                  $sformatf("%s x%0d exp=%08h got=%08h (pc=%08h)",
                            e.prop, item.addr, e.exp_value, item.data, e.pc));
            end
          end else begin
            shadow_rf[0] = 32'h0;
          end
        end

        regfile_item::PC_TRACE: begin
          process_pc_trace(item);
        end

        // READ items: verified by riscv_rf_scoreboard
        default: ;
      endcase
    end
  endtask

  //--------------------------------------------------------------------------
  // PC-flow check + C-02/C-03/C-04/C-14
  //--------------------------------------------------------------------------
  function void process_pc_trace(regfile_item it);
    logic [31:0] pc_cur  = it.pc_id;
    logic [31:0] ins_cur = it.instr;
    logic [31:0] exp_pc, alt_pc;
    bit          has_alt;
    string       tag;
    string       prop;
    logic [12:0] b_imm;
    logic [20:0] j_imm;
    logic [11:0] i_imm;

    // CHK:C-04  Suppress next PC check once after an illegal instruction.
    if (pc_tr_prev_valid && suppress_next_pc_check) begin
      suppress_next_pc_check = 0;
      `uvm_info("SB_PC",
        $sformatf("Suppress next-PC check (illegal prior): prev=0x%08h cur=0x%08h",
                  pc_tr_prev_pc, pc_cur), UVM_HIGH)
      pc_tr_prev_pc    = pc_cur;
      pc_tr_prev_instr = ins_cur;
      update_branch_snapshot(ins_cur, it.op_a_fw, it.op_b_fw);
      pc_tr_prev_valid = 1;
      return;
    end

    if (pc_tr_prev_valid) begin
      has_alt = 0;
      alt_pc  = '0;
      prop    = "seq_pc_p";

      case (pc_tr_prev_instr[6:0])
        7'h63: begin
          prop    = "branch_pc_p";
          b_imm   = {pc_tr_prev_instr[31],
                     pc_tr_prev_instr[7],
                     pc_tr_prev_instr[30:25],
                     pc_tr_prev_instr[11:8], 1'b0};
          if (strict_branch_check) begin
            bit taken;
            case (pc_tr_prev_instr[14:12])
              3'b000: taken = (pc_tr_prev_rs1_branch == pc_tr_prev_rs2_branch);
              3'b001: taken = (pc_tr_prev_rs1_branch != pc_tr_prev_rs2_branch);
              3'b100: taken = ($signed(pc_tr_prev_rs1_branch) <  $signed(pc_tr_prev_rs2_branch));
              3'b101: taken = ($signed(pc_tr_prev_rs1_branch) >= $signed(pc_tr_prev_rs2_branch));
              3'b110: taken = (pc_tr_prev_rs1_branch <  pc_tr_prev_rs2_branch);
              3'b111: taken = (pc_tr_prev_rs1_branch >= pc_tr_prev_rs2_branch);
              default: taken = 1'b0;
            endcase
            exp_pc = taken ? (pc_tr_prev_pc + {{19{b_imm[12]}}, b_imm})
                           : (pc_tr_prev_pc + 4);
          end else begin
            exp_pc  = pc_tr_prev_pc + 4;
            alt_pc  = pc_tr_prev_pc + {{19{b_imm[12]}}, b_imm};
            has_alt = 1;
          end
        end
        7'h6F: begin
          prop    = "jal_pc_p";
          j_imm   = {pc_tr_prev_instr[31],
                     pc_tr_prev_instr[19:12],
                     pc_tr_prev_instr[20],
                     pc_tr_prev_instr[30:21], 1'b0};
          exp_pc  = pc_tr_prev_pc + {{11{j_imm[20]}}, j_imm};
        end
        7'h67: begin
          prop    = "jalr_pc_p";
          i_imm   = pc_tr_prev_instr[31:20];
          exp_pc  = (pc_tr_prev_rs1_snapshot + {{20{i_imm[11]}}, i_imm}) & ~32'h1;
        end
        default: begin
          prop    = "seq_pc_p";
          exp_pc  = pc_tr_prev_pc + 4;
        end
      endcase

      tag = $sformatf("prev pc=0x%08h (0x%08h) -> cur pc=0x%08h ; exp 0x%08h%s",
                      pc_tr_prev_pc, pc_tr_prev_instr, pc_cur, exp_pc,
                      has_alt ? $sformatf(" or 0x%08h", alt_pc) : "");

      if (pc_cur === exp_pc || (has_alt && pc_cur === alt_pc)) begin
        pc_pass++;
        chk(prop, 1'b1, tag);
      end else begin
        pc_fail++;
        chk(prop, 1'b0, tag);
      end
    end

    // CHK:C-02/C-14  Enqueue expected rd value for JAL/JALR/AUIPC/LUI.
    if (check_link_values) begin
      case (ins_cur[6:0])
        7'h6f: if (ins_cur[11:7] != 5'h0)
                 enqueue_expected_wr(pc_cur, ins_cur[11:7], pc_cur + 4,
                                     "jal_link_p");
        7'h67: if (ins_cur[11:7] != 5'h0)
                 enqueue_expected_wr(pc_cur, ins_cur[11:7], pc_cur + 4,
                                     "jalr_link_p");
        7'h17: if (ins_cur[11:7] != 5'h0)
                 enqueue_expected_wr(pc_cur, ins_cur[11:7],
                                     pc_cur + {ins_cur[31:12], 12'b0},
                                     "auipc_result_p");
        7'h37: if (ins_cur[11:7] != 5'h0)
                 enqueue_expected_wr(pc_cur, ins_cur[11:7],
                                     {ins_cur[31:12], 12'b0},
                                     "lui_result_p");
      endcase
    end

    // CHK:C-04
    if (illegal_detect_enable && is_illegal_encoding(ins_cur))
      suppress_next_pc_check = 1;

    pc_tr_prev_pc    = pc_cur;
    pc_tr_prev_instr = ins_cur;
    update_branch_snapshot(ins_cur, it.op_a_fw, it.op_b_fw);
    pc_tr_prev_valid = 1;
  endfunction

  // CHK:C-03  Snapshot the operand values the DUT's branch comparator sees.
  function void update_branch_snapshot(bit [31:0] ins,
                                       bit [31:0] op_a, bit [31:0] op_b);
    if (ins[6:0] == 7'h67) begin
      pc_tr_prev_rs1_snapshot = shadow_rf[ins[19:15]];
    end
    if (ins[6:0] == 7'h63) begin
      pc_tr_prev_rs1_branch = op_a;
      pc_tr_prev_rs2_branch = op_b;
    end
  endfunction

  //--------------------------------------------------------------------------
  // Instruction-stream statistics
  //--------------------------------------------------------------------------
  task check_instr();
    rv32im_instr_seq_item curr;
    forever begin
      instr_fifo.get(curr);
      instr_count++;
      case (curr.opcode)
        OP_R:            instr_r_type++;
        OP_IMM:          instr_i_type++;
        OP_LOAD:         instr_load++;
        OP_STORE:        instr_store++;
        OP_BRANCH:       instr_branch++;
        OP_JAL, OP_JALR: instr_jump++;
        default:         instr_other++;
      endcase

      `uvm_info("SB_INSTR", $sformatf("RETIRED #%0d %s pc=0x%08h",
        instr_count, curr.convert2string(), curr.pc), UVM_HIGH)
    end
  endtask

  //--------------------------------------------------------------------------
  // Shadow Memory Helpers
  //--------------------------------------------------------------------------
  function void write_shadow_mem(logic [31:0] addr, logic [31:0] data, logic [3:0] be);
    bit [31:2] wa = addr[31:2];
    if (!shadow_mem.exists(wa)) shadow_mem[wa] = '0;
    for (int i = 0; i < 4; i++) begin
      if (be[i]) shadow_mem[wa][(i*8)+:8] = data[(i*8)+:8];
    end
  endfunction

  function logic [31:0] read_shadow_mem(logic [31:0] addr);
    bit [31:2] wa = addr[31:2];
    return shadow_mem.exists(wa) ? shadow_mem[wa] : 32'h0;
  endfunction

  //--------------------------------------------------------------------------
  // Memory Bus / LSU Checker Task
  //--------------------------------------------------------------------------
  task check_data();
    data_transaction item;
    logic [31:0] expected;
    logic [3:0] be;
    bit match;

    forever begin
      data_fifo.get(item);

      if (item.data_req_o) begin
        if (item.data_we_o) begin
          mem_store_count++;
          write_shadow_mem(item.data_addr_o, item.data_wdata_o, item.data_be_o);
          case (item.data_be_o)
            4'b1111: begin
              if (item.data_addr_o[1:0] == 2'b00) mem_align_pass++;
              else begin
                mem_align_fail++;
                `uvm_error("SB_MEM", $sformatf("Misaligned word store addr=0x%08h be=%0b", item.data_addr_o, item.data_be_o))
              end
            end
            4'b0011,
            4'b1100: begin
              if (item.data_addr_o[0] == 1'b0) mem_align_pass++;
              else begin
                mem_align_fail++;
                `uvm_error("SB_MEM", $sformatf("Misaligned halfword store addr=0x%08h be=%0b", item.data_addr_o, item.data_be_o))
              end
            end
            default: mem_align_pass++;
          endcase
          `uvm_info("SB_MEM", $sformatf("STORE addr=0x%08h wdata=0x%08h be=%0b",
            item.data_addr_o, item.data_wdata_o, item.data_be_o), UVM_HIGH)

        end else begin
          mem_load_count++;
          expected = read_shadow_mem(item.data_addr_o);

          match = 1'b1;
          be = (item.data_be_o == 4'b0000) ? 4'b1111 : item.data_be_o;
          for (int i = 0; i < 4; i++) begin
            if (be[i] && item.data_rdata_i[(i*8)+:8] !== expected[(i*8)+:8])
              match = 1'b0;
          end

          if (match) begin
            mem_load_pass++;
            chk("mem_load_data_p", 1'b1, "");
            `uvm_info("SB_MEM", $sformatf("LOAD PASS addr=0x%08h exp=0x%08h got=0x%08h be=%04b",
              item.data_addr_o, expected, item.data_rdata_i, item.data_be_o), UVM_HIGH)
          end else begin
            mem_load_fail++;
            chk("mem_load_data_p", 1'b0, $sformatf(
              "LOAD FAIL addr=0x%08h exp=0x%08h got=0x%08h be=%04b",
              item.data_addr_o, expected, item.data_rdata_i, item.data_be_o));
          end
        end
      end
    end
  endtask

  //--------------------------------------------------------------------------
  // Check Phase
  //--------------------------------------------------------------------------
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (rf_fifo.used() != 0)
      `uvm_error("SB_RF", $sformatf("%0d RF items left unchecked in FIFO", rf_fifo.used()))
    if (instr_fifo.used() != 0)
      `uvm_error("SB_INSTR", $sformatf("%0d Instruction items left unchecked in FIFO", instr_fifo.used()))
    if (data_fifo.used() != 0)
      `uvm_error("SB_DATA", $sformatf("%0d Data bus items left unchecked in FIFO", data_fifo.used()))

    for (int i = 1; i < 32; i++) begin
      if (exp_wr_q[i].size() > 0) begin
        `uvm_error("SB_PROP",
          $sformatf("link_value queue not empty for x%0d (%0d entries) at end of test",
                    i, exp_wr_q[i].size()))
      end
    end
  endfunction

  //--------------------------------------------------------------------------
  // Report Phase
  //--------------------------------------------------------------------------
  function void report_phase(uvm_phase phase);
    print_summary();
  endfunction

  function void print_summary();
    `uvm_info(get_type_name(), "+----------------------------------------------------+", UVM_LOW)
    `uvm_info(get_type_name(), "|        RISCV32IM SYSTEM SCOREBOARD RESULTS         |", UVM_LOW)
    `uvm_info(get_type_name(), "+----------------------------------------------------+", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  INSTRUCTIONS: TOTAL=%5d (R=%0d I=%0d LD=%0d ST=%0d) |",
      instr_count, instr_r_type, instr_i_type, instr_load, instr_store), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  BRANCH/JUMP : TOTAL=%5d (BR=%0d JMP=%0d)             |",
      instr_branch + instr_jump, instr_branch, instr_jump), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  PC FLOW     : PASS=%5d  FAIL=%5d (pipeline pc_id) |",
      pc_pass, pc_fail), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  DATA BUS    : LOADS=%5d  STORES=%5d (AlignFail=%0d)|",
      mem_load_count, mem_store_count, mem_align_fail), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  LOAD DATA   : PASS=%5d  FAIL=%5d                  |",
      mem_load_pass, mem_load_fail), UVM_LOW)
    `uvm_info(get_type_name(), "+----------------------------------------------------+", UVM_LOW)

    foreach (prop_pass[p])
      `uvm_info(get_type_name(),
        $sformatf("  %-30s PASS=%5d FAIL=%5d", p, prop_pass[p], prop_fail[p]), UVM_LOW)
  endfunction

endclass

`endif