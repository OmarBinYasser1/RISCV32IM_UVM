`ifndef RISCV_SCOREBOARD_SV
`define RISCV_SCOREBOARD_SV

class riscv_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(riscv_scoreboard)

  uvm_analysis_export #(alu_item)     alu_ae;
  uvm_analysis_export #(mul_item)     mul_ae;
  uvm_analysis_export #(regfile_item) rf_ae;

  uvm_tlm_analysis_fifo #(alu_item)     alu_fifo;
  uvm_tlm_analysis_fifo #(mul_item)     mul_fifo;
  uvm_tlm_analysis_fifo #(regfile_item) rf_fifo;

  logic [31:0] shadow_rf [32];

  int alu_pass, alu_fail;
  int mul_pass, mul_fail;
  int rf_pass,  rf_fail;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    alu_pass = 0; alu_fail = 0;
    mul_pass = 0; mul_fail = 0;
    rf_pass = 0; rf_fail = 0;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    alu_ae   = new("alu_ae",   this);
    mul_ae   = new("mul_ae",   this);
    rf_ae    = new("rf_ae",    this);
    alu_fifo = new("alu_fifo", this);
    mul_fifo = new("mul_fifo", this);
    rf_fifo  = new("rf_fifo",  this);
    foreach (shadow_rf[i]) shadow_rf[i] = '0;
  endfunction

  function void connect_phase(uvm_phase phase);
    alu_ae.connect(alu_fifo.analysis_export);
    mul_ae.connect(mul_fifo.analysis_export);
    rf_ae .connect(rf_fifo.analysis_export);
  endfunction

  task run_phase(uvm_phase phase);
    fork
      check_alu();
      check_mul();
      check_rf();
    join_none
  endtask

  function automatic logic [31:0] alu_golden(
      input logic [6:0]  op,
      input logic [31:0] a,
      input logic [31:0] b
  );
    logic signed [31:0] sa = signed'(a);
    logic signed [31:0] sb = signed'(b);
    logic [31:0] res;

    case (op)
      7'b0011000: res = a + b;
      7'b0011001: res = a - b;
      7'b0011010: res = a + b;
      7'b0011011: res = a - b;
      7'b0101111: res = a ^ b;
      7'b0101110: res = a | b;
      7'b0010101: res = a & b;
      7'b0100100: res = 32'(sa >>> b[4:0]);
      7'b0100101: res = a >> b[4:0];
      7'b0100111: res = a << b[4:0];
      // Branch-condition comparisons output to comparison_result_o, NOT result_o.
      // alu_if only captures result_o, so these are skipped to avoid false failures.
      7'b0000000: res = 'x;   // ALU_LTS  -> comparison_result_o
      7'b0000001: res = 'x;   // ALU_LTU  -> comparison_result_o
      7'b0001100: res = 'x;   // ALU_EQ   -> comparison_result_o
      7'b0001101: res = 'x;   // ALU_NE   -> comparison_result_o
      7'b0001010: res = 'x;   // ALU_GES  -> comparison_result_o
      7'b0001011: res = 'x;   // ALU_GEU  -> comparison_result_o
      // SLT/SLTU write to result_o (rd destination) — keep these
      7'b0000010: res = (sa < sb) ? 1 : 0;  // ALU_SLTS
      7'b0000011: res = (a  < b ) ? 1 : 0;  // ALU_SLTU
      7'b0010000: res = (sa < sb) ? a : b;
      7'b0010001: res = (a < b) ? a : b;
      7'b0010010: res = (sa > sb) ? a : b;
      7'b0010011: res = (a > b) ? a : b;
      7'b0010100: res = (sa < 0) ? -sa : a;
      7'b0110001: res = (b == 0) ? '1 : 32'(sa / sb);
      7'b0110000: res = (b == 0) ? '1 : a / b;
      7'b0110011: res = (b == 0) ? a : 32'(sa % sb);
      7'b0110010: res = (b == 0) ? a : a % b;
      default:    res = 'x;
    endcase
    return res;
  endfunction

  task check_alu();
    alu_item item;
    logic [31:0] expected;
    forever begin
      alu_fifo.get(item);
      expected = alu_golden(item.operator, item.operand_a, item.operand_b);

      if (expected === 'x) begin
        `uvm_warning("SB_ALU", $sformatf("Unknown ALU op=7'b%0b — skipping check", item.operator))
      end else if (item.result === expected) begin
        alu_pass++;
        `uvm_info("SB_ALU", $sformatf("PASS | op=%0h a=%0h b=%0h | exp=%0h got=%0h",
          item.operator, item.operand_a, item.operand_b, expected, item.result), UVM_HIGH)
      end else begin
        alu_fail++;
        `uvm_error("SB_ALU", $sformatf("FAIL | op=%0h a=%0h b=%0h | exp=%0h got=%0h  <<< MISMATCH",
          item.operator, item.operand_a, item.operand_b, expected, item.result))
      end
    end
  endtask

  function automatic logic [31:0] mul_golden(
      input logic [2:0]  op,
      input logic [31:0] a,
      input logic [31:0] b,
      input logic [31:0] c
  );
    logic signed [31:0] sa = signed'(a);
    logic signed [31:0] sb = signed'(b);
    logic signed [63:0] wide_s;
    logic signed [63:0] wide_acc;
    logic [31:0] res;

    case (op)
      // MUL_I: lower 32 bits of unsigned product
      3'b010: res = a * b;
      // MUL_H: upper 32 bits of signed x signed product
      // NOTE: mul_if lacks short_signed_i, so we cannot distinguish MULH/MULHSU/MULHU.
      // We assume signed x signed here. It will fail for unsigned variants.
      3'b110: begin
                wide_s = sa * sb;
                res = wide_s[63:32];
              end
      // MUL_MAC32: c + a*b
      3'b000: res = c + a * b;
      // MUL_MSU32: c - a*b
      3'b001: res = c - a * b;
      default: res = 'x;
    endcase
    return res;
  endfunction

  task check_mul();
    mul_item item;
    logic [31:0] expected;
    forever begin
      mul_fifo.get(item);
      expected = mul_golden(item.operator, item.operand_a, item.operand_b, item.operand_c);

      if (expected === 'x) begin
        `uvm_warning("SB_MUL", $sformatf("Unknown MUL op=3'b%0b — skipping", item.operator))
      end else if (item.result === expected) begin
        mul_pass++;
        `uvm_info("SB_MUL", $sformatf("PASS | op=%0b a=%0h b=%0h c=%0h | exp=%0h got=%0h",
          item.operator, item.operand_a, item.operand_b, item.operand_c, expected, item.result), UVM_HIGH)
      end else begin
        mul_fail++;
        `uvm_error("SB_MUL", $sformatf("FAIL | op=%0b a=%0h b=%0h c=%0h | exp=%0h got=%0h  <<< MISMATCH",
          item.operator, item.operand_a, item.operand_b, item.operand_c, expected, item.result))
      end
    end
  endtask

  task check_rf();
    regfile_item item;
    logic [31:0] expected; 
    forever begin
      rf_fifo.get(item);
      case (item.kind)
        regfile_item::WRITE: begin
          if (item.addr != 0)
            shadow_rf[item.addr] = item.data;
          rf_pass++;
          `uvm_info("SB_RF", $sformatf("WRITE x%0d = %0h (port %s)", item.addr, item.data, item.port), UVM_HIGH)
        end
        regfile_item::READ: begin
          expected = (item.addr == 0) ? '0 : shadow_rf[item.addr];
          if (item.data === expected) begin
            rf_pass++;
            `uvm_info("SB_RF", $sformatf("READ PASS x%0d = %0h (port %s)", item.addr, item.data, item.port), UVM_HIGH)
          end else begin
            rf_fail++;
            `uvm_error("SB_RF", $sformatf("READ FAIL x%0d | exp=%0h got=%0h (port %s)  <<< MISMATCH",
              item.addr, expected, item.data, item.port))
          end
        end
      endcase
    end
  endtask

  function void report_phase(uvm_phase phase);
    print_summary();
  endfunction

  function void print_summary();
    int total_p = alu_pass + mul_pass + rf_pass;
    int total_f = alu_fail + mul_fail + rf_fail;
    int total   = total_p + total_f;
    real rate   = (total > 0) ? (real'(total_p) / real'(total)) * 100.0 : 0.0;

    `uvm_info(get_type_name(), "\n", UVM_LOW)
    `uvm_info(get_type_name(), "╔══════════════════════════════════════════════╗", UVM_LOW)
    `uvm_info(get_type_name(), "║      RISCV32IM SYSTEM SCOREBOARD RESULTS     ║", UVM_LOW)
    `uvm_info(get_type_name(), "╠══════════════════════════════════════════════╣", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("║  ALU : PASS=%4d  FAIL=%4d               ║", alu_pass, alu_fail), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("║  MUL : PASS=%4d  FAIL=%4d               ║", mul_pass, mul_fail), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("║  RF  : PASS=%4d  FAIL=%4d               ║", rf_pass,  rf_fail),  UVM_LOW)
    `uvm_info(get_type_name(), "╠══════════════════════════════════════════════╣", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("║  TOTAL CHECKS : %6d                     ║", total),   UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("║  PASSED       : %6d                     ║", total_p), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("║  FAILED       : %6d                     ║", total_f), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("║  Pass Rate    : %6.2f%%                    ║", rate),    UVM_LOW)
    `uvm_info(get_type_name(), "╚══════════════════════════════════════════════╝", UVM_LOW)
  endfunction

endclass

`endif
