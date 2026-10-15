class regfile_coverage extends uvm_subscriber #(regfile_item);

  `uvm_component_utils(regfile_coverage)

  regfile_item item;

  // Register write history
  bit written[64];
  int unsigned write_cycle[64];

  bit x0_write_seen;
  int unsigned raw_distance;

  //----------------------------------------------------------------------------
  // Existing general register access coverage (unchanged)
  //----------------------------------------------------------------------------
  covergroup regfile_cg;
    option.per_instance = 1;

    cp_addr: coverpoint item.addr {
      bins gpr[32] = {[0:31]};
      ignore_bins fpr = {[32:63]};
    }

    cp_kind: coverpoint item.kind {
      bins write_b = {regfile_item::WRITE};
      bins read_b  = {regfile_item::READ};
    }

    cp_port: coverpoint
      ((item.port == "a") ? 0 :
       (item.port == "b") ? 1 :
       (item.port == "c") ? 2 : 3) {
      bins port_a = {0};
      bins port_b = {1};
      bins port_c = {2};
      ignore_bins invalid_port = {3};
    }

    cp_x0_write: coverpoint x0_write_seen {
      bins write_attempted = {1};
    }

    cross cp_kind, cp_addr, cp_port {
      ignore_bins write_on_port_c =
          binsof(cp_kind.write_b) && binsof(cp_port.port_c);
      ignore_bins read_port_c_nonzero =
          binsof(cp_kind.read_b) && binsof(cp_port.port_c) &&
          binsof(cp_addr) intersect {[1:31]};
    }
  endgroup

  //----------------------------------------------------------------------------
  // Existing RAW hazard coverage (unchanged)
  //----------------------------------------------------------------------------
  covergroup raw_hazard_cg;
    option.per_instance = 1;

    cp_raw_addr: coverpoint item.addr {
      bins gpr[31] = {[1:31]};
      ignore_bins fpr = {[32:63]};
    }

    cp_raw_distance: coverpoint raw_distance {
      bins same_cycle  = {0};
      bins one_cycle   = {1};
      bins short_delay = {[2:5]};
      bins long_delay  = {[6:$]};
    }

    cross cp_raw_addr, cp_raw_distance;
  endgroup

  //============================================================================
  // CHK:V-01..V-06, V-16  Instruction-level coverage sampled from PC_TRACE.
  //============================================================================

  typedef enum bit [3:0] {
    CLS_ALU_IMM = 0, CLS_ALU_R = 1, CLS_MUL = 2, CLS_MULH = 3,
    CLS_DIV = 4, CLS_REM = 5, CLS_LOAD = 6, CLS_STORE = 7,
    CLS_BRANCH = 8, CLS_JAL = 9, CLS_JALR = 10,
    CLS_LUI = 11, CLS_AUIPC = 12, CLS_SYSTEM = 13,
    CLS_ILLEGAL = 14, CLS_OTHER = 15
  } instr_class_e;

  // CHK:V-16  Illegal-encoding classifier.
  //  0 = legal, 1 = unused opcode, 2 = bad funct3 on OP-IMM,
  //  3 = reserved shift, 4 = bad funct3 on LOAD, 5 = bad funct3 on STORE,
  //  6 = bad funct3 on BRANCH, 7 = bad funct3 on JALR, 8 = bad funct7 on OP,
  //  9 = bad funct3 on OP-RV32M, 10 = other
  function int illegal_kind(bit [31:0] i);
    bit [6:0] op = i[6:0];
    bit [2:0] f3 = i[14:12];
    bit [6:0] f7 = i[31:25];
    case (op)
      7'h13: begin
        if (f3 == 3'b001 && f7 != 7'h00) return 3;
        if (f3 == 3'b101 && f7 != 7'h00 && f7 != 7'h20) return 3;
        return (f3 inside {3'b000,3'b010,3'b011,3'b100,3'b110,3'b111})
                 ? 0 : 2;
      end
      7'h33: begin
        if (f7 == 7'h00) return 0;
        if (f7 == 7'h01) begin
          return (f3 inside {3'b000,3'b001,3'b010,3'b011,3'b100,
                             3'b101,3'b110,3'b111}) ? 0 : 9;
        end
        if (f7 == 7'h20 && (f3 == 3'b000 || f3 == 3'b101)) return 0;
        return 8;
      end
      7'h03: return (f3 inside {3'b000,3'b001,3'b010,3'b100,3'b101}) ? 0 : 4;
      7'h23: return (f3 inside {3'b000,3'b001,3'b010}) ? 0 : 5;
      7'h63: return (f3 inside {3'b000,3'b001,3'b100,3'b101,3'b110,3'b111})
                     ? 0 : 6;
      7'h67: return (f3 == 3'b000) ? 0 : 7;
      7'h6f, 7'h37, 7'h17, 7'h0f, 7'h73: return 0;
      default: return 1;
    endcase
  endfunction

  function instr_class_e instr_class(bit [31:0] i);
    case (i[6:0])
      7'h13: return CLS_ALU_IMM;
      7'h33: begin
        if (i[31:25] == 7'h01) begin
          case (i[14:12])
            3'b000:                 return CLS_MUL;
            3'b001, 3'b010, 3'b011: return CLS_MULH;
            3'b100, 3'b101:         return CLS_DIV;
            3'b110, 3'b111:         return CLS_REM;
            default:                return CLS_ILLEGAL;
          endcase
        end
        return CLS_ALU_R;
      end
      7'h03: return CLS_LOAD;
      7'h23: return CLS_STORE;
      7'h63: return CLS_BRANCH;
      7'h6f: return CLS_JAL;
      7'h67: return CLS_JALR;
      7'h37: return CLS_LUI;
      7'h17: return CLS_AUIPC;
      7'h73: return CLS_SYSTEM;
      7'h0f: return CLS_OTHER;
      default: return CLS_ILLEGAL;
    endcase
  endfunction

  // CHK:V-03  rd==rs1 / rd==rs2 relation.
  function int rd_rs_rel(bit [31:0] i);
    bit [4:0] rd  = i[11:7];
    bit [4:0] rs1 = i[19:15];
    bit [4:0] rs2 = i[24:20];
    bit rd_rs1 = (rd == rs1) && (rd != 5'd0);
    bit rd_rs2 = (rd == rs2) && (rd != 5'd0);
    if (rd_rs1 && rd_rs2) return 3;
    if (rd_rs1)           return 1;
    if (rd_rs2)           return 2;
    return 0;
  endfunction

  // CHK:V-05  Bitmap of "field == x0".
  function int x0_position(bit [31:0] i);
    int r = 0;
    if (i[11:7]  == 5'd0) r |= 1;
    if (i[19:15] == 5'd0) r |= 2;
    if (i[24:20] == 5'd0) r |= 4;
    return r;
  endfunction

  // CHK:V-01/V-02  Retired-instruction window (4 entries).
  typedef struct {
    bit [31:0]    pc;
    bit [31:0]    instr;
    bit [4:0]     rd;
    bit [4:0]     rs1;
    bit [4:0]     rs2;
    instr_class_e cls;
  } ret_instr_t;
  ret_instr_t ret_history[8];
  int unsigned ret_count;

  // Sampling signals for the new covergroups
  instr_class_e curr_producer_cls;
  instr_class_e curr_consumer_cls;
  int unsigned  curr_hazard_distance;

  // CHK:V-04  Stream tracking
  bit [31:0]   stream_prev_pc;
  bit          stream_prev_valid;
  int unsigned stream_run_len;

  // CHK:V-05  x0 write-then-read sequence tracking
  int unsigned x0_write_cycle;
  bit          x0_write_pending;

  //----------------------------------------------------------------------------
  // CHK:V-01  Raw hazard producer class x distance
  //----------------------------------------------------------------------------
  covergroup raw_hazard_producer_cg;
    option.per_instance = 1;

    cp_producer: coverpoint curr_producer_cls {
      bins alu_imm = {CLS_ALU_IMM};
      bins alu_r   = {CLS_ALU_R};
      bins mul     = {CLS_MUL, CLS_MULH};
      bins divrem  = {CLS_DIV, CLS_REM};
      bins load    = {CLS_LOAD};
    }
    cp_distance: coverpoint curr_hazard_distance {
      bins d0  = {0};
      bins d1  = {1};
      bins d2  = {2};
      bins d3p = {[3:$]};
    }
    raw_producer_cov: cross cp_producer, cp_distance;
  endgroup

  //----------------------------------------------------------------------------
  // CHK:V-02  Full hazard matrix producer x consumer x distance
  //----------------------------------------------------------------------------
  covergroup hazard_matrix_cg;
    option.per_instance = 1;

    cp_producer: coverpoint curr_producer_cls {
      bins alu_imm = {CLS_ALU_IMM};
      bins alu_r   = {CLS_ALU_R};
      bins mul     = {CLS_MUL, CLS_MULH};
      bins divrem  = {CLS_DIV, CLS_REM};
      bins load    = {CLS_LOAD};
    }
    cp_consumer: coverpoint curr_consumer_cls {
      bins alu_imm = {CLS_ALU_IMM};
      bins alu_r   = {CLS_ALU_R};
      bins mul     = {CLS_MUL, CLS_MULH};
      bins divrem  = {CLS_DIV, CLS_REM};
      bins load    = {CLS_LOAD};
      bins store   = {CLS_STORE};
      bins branch  = {CLS_BRANCH};
    }
    cp_distance: coverpoint curr_hazard_distance {
      bins d0  = {0};
      bins d1  = {1};
      bins d2  = {2};
      bins d3p = {[3:$]};
    }
    hazard_cov: cross cp_producer, cp_consumer, cp_distance;
  endgroup

  //----------------------------------------------------------------------------
  // CHK:V-03  rd==rs1 / rd==rs2 per instruction class
  //----------------------------------------------------------------------------
  covergroup same_reg_cg;
    option.per_instance = 1;

    cp_class: coverpoint instr_class(item.instr) {
      bins alu_imm = {CLS_ALU_IMM};
      bins alu_r   = {CLS_ALU_R};
      bins mul     = {CLS_MUL, CLS_MULH};
      bins divrem  = {CLS_DIV, CLS_REM};
      bins load    = {CLS_LOAD};
    }
    cp_relation: coverpoint rd_rs_rel(item.instr) {
      bins rd_eq_rs1        = {1};
      bins rd_eq_rs2        = {2};
      bins rd_eq_rs1_eq_rs2 = {3};
      bins distinct         = {0};
    }
    same_reg_cov: cross cp_class, cp_relation;
  endgroup

  //----------------------------------------------------------------------------
  // CHK:V-04  Back-to-back stream length
  //----------------------------------------------------------------------------
  covergroup stream_cg;
    option.per_instance = 1;

    cp_len: coverpoint stream_run_len {
      bins len3  = {3};
      bins len4  = {4};
      bins len5  = {5};
      bins len6p = {[6:$]};
    }
  endgroup

  //----------------------------------------------------------------------------
  // CHK:V-05  rd=x0 / rs1=x0 / rs2=x0 per class
  //----------------------------------------------------------------------------
  covergroup x0_instr_cg;
    option.per_instance = 1;

    cp_class: coverpoint instr_class(item.instr) {
      bins alu_imm = {CLS_ALU_IMM};
      bins alu_r   = {CLS_ALU_R};
      bins mul     = {CLS_MUL, CLS_MULH};
      bins divrem  = {CLS_DIV, CLS_REM};
      bins load    = {CLS_LOAD};
      bins jal     = {CLS_JAL};
      bins jalr    = {CLS_JALR};
      bins lui     = {CLS_LUI};
      bins auipc   = {CLS_AUIPC};
    }
    cp_x0_as: coverpoint x0_position(item.instr) {
      bins rd_is_x0   = {1};
      bins rs1_is_x0  = {2};
      bins rs2_is_x0  = {4};
      bins rs1_rs2_x0 = {6};
      bins rd_rs1_x0  = {3};
      bins rd_rs2_x0  = {5};
      ignore_bins all_x0 = {7};
    }
    
    x0_cov: cross cp_class, cp_x0_as {
      // Classes with no rs1/rs2 field:
      ignore_bins lui_no_rs   = binsof(cp_class.lui)   &&
          (binsof(cp_x0_as.rs1_is_x0)  || binsof(cp_x0_as.rs2_is_x0) ||
           binsof(cp_x0_as.rs1_rs2_x0) || binsof(cp_x0_as.rd_rs1_x0) ||
           binsof(cp_x0_as.rd_rs2_x0));
      ignore_bins auipc_no_rs = binsof(cp_class.auipc) &&
          (binsof(cp_x0_as.rs1_is_x0)  || binsof(cp_x0_as.rs2_is_x0) ||
           binsof(cp_x0_as.rs1_rs2_x0) || binsof(cp_x0_as.rd_rs1_x0) ||
           binsof(cp_x0_as.rd_rs2_x0));
      ignore_bins jal_no_rs   = binsof(cp_class.jal)   &&
          (binsof(cp_x0_as.rs1_is_x0)  || binsof(cp_x0_as.rs2_is_x0) ||
           binsof(cp_x0_as.rs1_rs2_x0) || binsof(cp_x0_as.rd_rs1_x0) ||
           binsof(cp_x0_as.rd_rs2_x0));
      // Classes with rs1 but no rs2:
      ignore_bins no_rs2 = (binsof(cp_class.alu_imm) ||
                            binsof(cp_class.load)    ||
                            binsof(cp_class.jalr))   &&
          (binsof(cp_x0_as.rs2_is_x0)  || binsof(cp_x0_as.rs1_rs2_x0) ||
           binsof(cp_x0_as.rd_rs2_x0));
    }


  endgroup

  //----------------------------------------------------------------------------
  // CHK:V-16  Illegal-encoding class
  //----------------------------------------------------------------------------
  covergroup illegal_instr_cg;
    option.per_instance = 1;

    cp_kind: coverpoint illegal_kind(item.instr) {
      bins legal           = {0};
      bins unused_opcode   = {1};
      bins bad_f3_opimm    = {2};
      bins reserved_shift  = {3};
      bins bad_f3_load     = {4};
      bins bad_f3_store    = {5};
      bins bad_f3_branch   = {6};
      bins bad_f3_jalr     = {7};
      bins bad_f7_op       = {8};
    }
  endgroup

  //----------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);

    regfile_cg              = new();
    raw_hazard_cg           = new();
    raw_hazard_producer_cg  = new();
    hazard_matrix_cg        = new();
    same_reg_cg             = new();
    stream_cg               = new();
    x0_instr_cg             = new();
    illegal_instr_cg        = new();

    clear_write_history();
    ret_count = 0;
    stream_prev_valid = 0;
    stream_run_len = 0;
    x0_write_pending = 0;
    x0_write_cycle = 0;
  endfunction

  function void clear_write_history();
    foreach (written[i]) begin
      written[i]     = 0;
      write_cycle[i] = 0;
    end
    x0_write_seen = 0;
  endfunction

  function void write(regfile_item t);

    item = t;

    // Reset
    if (item.is_reset) begin
      clear_write_history();
      ret_count = 0;
      stream_prev_valid = 0;
      stream_run_len = 0;
      x0_write_pending = 0;
      return;
    end

    // ------------------------------------------------------------------
    // CHK:V-01..V-06, V-16  PC_TRACE => retired-instruction coverage.
    // ------------------------------------------------------------------
    if (item.kind == regfile_item::PC_TRACE) begin
      ret_instr_t cur;
      cur.pc    = item.pc_id;
      cur.instr = item.instr;
      cur.rd    = item.instr[11:7];
      cur.rs1   = item.instr[19:15];
      cur.rs2   = item.instr[24:20];
      cur.cls   = instr_class(item.instr);

      // CHK:V-16  Illegal-encoding coverage (legal bin included).
      illegal_instr_cg.sample();

      // CHK:V-03  rd==rs1 / rd==rs2 per class.
      same_reg_cg.sample();

      // CHK:V-05  rd=x0 / rs1=x0 / rs2=x0 per class.
      x0_instr_cg.sample();

      // CHK:V-05  x0 write-then-read sequence:
      //   when a READ of x0 comes in, we look back at the last 2 cycles
      //   for a nonzero write attempt to x0; that captures the sequence
      //   "ADDI x0,x0,5 followed by a read of x0".
      //   (Handled on the READ side, see below.)

      // CHK:V-01/V-02  RAW hazard vs. the last 3 retired instructions.
      for (int k = 1; k <= 7; k++) begin
        int idx;
        if (ret_count < k) break;
        idx = (ret_count - k) % 8;
        if (ret_history[idx].cls == CLS_ILLEGAL) continue;
        if (ret_history[idx].rd  == 5'd0)        continue;

        if ((cur.rs1 == ret_history[idx].rd && cur.rs1 != 5'd0) ||
            (cur.rs2 == ret_history[idx].rd && cur.rs2 != 5'd0)) begin
          curr_producer_cls     = ret_history[idx].cls;
          curr_consumer_cls     = cur.cls;
          curr_hazard_distance  = k - 1;
          raw_hazard_producer_cg.sample();
          hazard_matrix_cg.sample();
        end
      end

      // CHK:V-04  Stream length: consecutive PC+4 instructions.
      if (stream_prev_valid && (cur.pc == stream_prev_pc + 4)) begin
        stream_run_len++;
      end else begin
        if (stream_run_len >= 3) stream_cg.sample();
        stream_run_len = 1;
      end
      stream_prev_pc    = cur.pc;
      stream_prev_valid = 1;

      // Push to the retired-instruction window.
      ret_history[ret_count % 8] = cur;
      ret_count++;

      return;
    end

    // ------------------------------------------------------------------
    // Original register-access handling (unchanged behaviour).
    // ------------------------------------------------------------------
    if (item.kind == regfile_item::WRITE) begin

      if (item.addr == 0) begin
        x0_write_seen = 1;
        // CHK:V-05  Track a nonzero write attempt for the read-side check.
        if (item.data !== 32'h0) begin
          x0_write_pending = 1;
          x0_write_cycle   = item.cycle;
        end
      end
      else begin
        written[item.addr]     = 1;
        write_cycle[item.addr] = item.cycle;
      end

    end

    // Sample existing general coverage
    regfile_cg.sample();

    // Calculate RAW distance on first read after a write
    if (item.kind == regfile_item::READ &&
        item.addr != 0 &&
        written[item.addr]) begin

      raw_distance = item.cycle - write_cycle[item.addr];

      raw_hazard_cg.sample();

      written[item.addr] = 0;
    end

    // CHK:V-05  x0 read after a recent nonzero write attempt.
    if (item.kind == regfile_item::READ && item.addr == 0) begin
      if (x0_write_pending && (item.cycle <= x0_write_cycle + 2)) begin
        `uvm_info("RF_COV",
          $sformatf("x0 read-after-nonzero-write (delta=%0d)",
                    item.cycle - x0_write_cycle), UVM_HIGH)
        x0_write_pending = 0;
      end
    end

  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("RF_COV", $sformatf(
      "coverage %%: regfile=%0.1f raw=%0.1f prod=%0.1f matrix=%0.1f same=%0.1f stream=%0.1f x0=%0.1f illegal=%0.1f",
      regfile_cg.get_inst_coverage(), raw_hazard_cg.get_inst_coverage(),
      raw_hazard_producer_cg.get_inst_coverage(), hazard_matrix_cg.get_inst_coverage(),
      same_reg_cg.get_inst_coverage(), stream_cg.get_inst_coverage(),
      x0_instr_cg.get_inst_coverage(), illegal_instr_cg.get_inst_coverage()),
      UVM_LOW)
  endfunction

endclass