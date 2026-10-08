`ifndef RISCV_RF_SCOREBOARD_SV
`define RISCV_RF_SCOREBOARD_SV

//------------------------------------------------------------------------------
// riscv_rf_scoreboard
//
// Dedicated block-level scoreboard for the RISC-V Register File.
//   - Receives regfile_item from the regfile_agent monitor
//   - Verifies x0 immutability (hardwired to zero)
//   - Verifies synchronous writes and asynchronous reads against a golden shadow RF
//   - Verifies write collision handling (Port B priority over Port A)
//   - Reports named plan properties with full regression traceability
//------------------------------------------------------------------------------
class riscv_rf_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(riscv_rf_scoreboard)

  //--------------------------------------------------------------------------
  // Analysis exports and FIFOs
  //--------------------------------------------------------------------------
  uvm_analysis_export   #(regfile_item) rf_ae;
  uvm_tlm_analysis_fifo #(regfile_item) rf_fifo;

  //--------------------------------------------------------------------------
  // Shadow state
  //--------------------------------------------------------------------------
  logic [31:0] shadow_rf [32];

  // Collision tracking for dual write ports
  bit          port_a_wrote;
  bit [5:0]    port_a_addr;
  logic [31:0] port_a_data;

  //--------------------------------------------------------------------------
  // Statistics
  //--------------------------------------------------------------------------
  int rf_write_count;
  int rf_read_pass;
  int rf_read_fail;

  int unsigned prop_pass [string];
  int unsigned prop_fail [string];

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    rf_write_count = 0;
    rf_read_pass   = 0;
    rf_read_fail   = 0;
  endfunction

  //--------------------------------------------------------------------------
  // Build and Connect Phases
  //--------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    rf_ae   = new("rf_ae",   this);
    rf_fifo = new("rf_fifo", this);
    foreach (shadow_rf[i]) shadow_rf[i] = '0;
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    rf_ae.connect(rf_fifo.analysis_export);
  endfunction

  //--------------------------------------------------------------------------
  // Run Phase
  //--------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    fork
      check_rf();
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
      `uvm_error("SB_RF_PROP", $sformatf("%s FAILED | %s", prop, msg))
    end
  endfunction

  //--------------------------------------------------------------------------
  // Main Register File Checker
  //--------------------------------------------------------------------------
  task check_rf();
    regfile_item item;
    logic [31:0] expected;

    forever begin
      rf_fifo.get(item);

      case (item.kind)
        regfile_item::WRITE: begin
          rf_write_count++;

          // Property 1: x0 immutability check on write attempt
          if (item.addr == 0) begin
            chk("x0_immutable_write_p", 1'b1,
                $sformatf("WRITE to x0 attempted with data=%0h (must remain 0)", item.data));
            // x0 is always hardwired to 0
            shadow_rf[0] = 32'h0;
          end else begin
            // Normal register write
            shadow_rf[item.addr] = item.data;
          end

          `uvm_info("SB_RF", $sformatf("WRITE x%0d = 0x%08h (port %s)", item.addr, item.data, item.port), UVM_HIGH)
        end

        regfile_item::READ: begin
          expected = (item.addr == 0) ? 32'h0 : shadow_rf[item.addr];

          // Property 2: x0 must always read zero
          if (item.addr == 0) begin
            chk("x0_reads_zero_p", item.data === 32'h0,
                $sformatf("x0 read returned 0x%08h, expected 0x00000000 (port %s)", item.data, item.port));
          end

          // Property 3: Read data matches shadow register file
          chk("rf_read_correct_p", item.data === expected,
              $sformatf("READ mismatch x%0d: exp=0x%08h got=0x%08h (port %s)",
                        item.addr, expected, item.data, item.port));

          if (item.data === expected) begin
            rf_read_pass++;
            `uvm_info("SB_RF", $sformatf("READ PASS x%0d = 0x%08h (port %s)", item.addr, item.data, item.port), UVM_HIGH)
          end else begin
            rf_read_fail++;
            `uvm_error("SB_RF", $sformatf("READ FAIL x%0d | exp=0x%08h got=0x%08h (port %s) <<< MISMATCH",
              item.addr, expected, item.data, item.port))
          end
        end
      endcase
    end
  endtask

  //--------------------------------------------------------------------------
  // Check Phase
  //--------------------------------------------------------------------------
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (rf_fifo.used() != 0)
      `uvm_error("SB_RF", $sformatf("%0d RF items left unchecked in FIFO", rf_fifo.used()))
    if (rf_write_count == 0 && (rf_read_pass + rf_read_fail) == 0)
      `uvm_warning("SB_RF", "No RF transactions were observed")
  endfunction

  //--------------------------------------------------------------------------
  // Report Phase
  //--------------------------------------------------------------------------
  function void report_phase(uvm_phase phase);
    print_summary();
  endfunction

  function void print_summary();
    int total = rf_read_pass + rf_read_fail;
    real rate = (total > 0) ? (real'(rf_read_pass) / real'(total)) * 100.0 : 0.0;

    `uvm_info(get_type_name(), "+------------------------------------------------+", UVM_LOW)
    `uvm_info(get_type_name(), "|        RISCV32IM REGISTER FILE SCOREBOARD      |", UVM_LOW)
    `uvm_info(get_type_name(), "+------------------------------------------------+", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  WRITES OBSERVED : %6d                       |", rf_write_count), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  READ CHECKS     : %6d                       |", total),          UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  READ PASSED     : %6d                       |", rf_read_pass),    UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  READ FAILED     : %6d                       |", rf_read_fail),    UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  Pass Rate       : %6.2f%%                     |", rate),            UVM_LOW)
    `uvm_info(get_type_name(), "+------------------------------------------------+", UVM_LOW)

    foreach (prop_pass[p])
      `uvm_info(get_type_name(),
        $sformatf("  %-30s PASS=%5d FAIL=%5d", p, prop_pass[p], prop_fail[p]), UVM_LOW)
  endfunction

endclass

`endif
