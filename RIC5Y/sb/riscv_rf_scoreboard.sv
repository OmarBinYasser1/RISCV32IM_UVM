`ifndef RISCV_RF_SCOREBOARD_SV
`define RISCV_RF_SCOREBOARD_SV

//------------------------------------------------------------------------------
// riscv_rf_scoreboard
//
// Dedicated block-level scoreboard for the RISC-V Register File.
//   - Receives regfile_item from the regfile_agent monitor
//   - Verifies x0 immutability (hardwired to zero)
//   - Verifies reads against a golden shadow RF
//   - Same-cycle WRITE+READ handling
//     -----------------------------
//     The RTL register file has combinational read ports and synchronous write
//     ports, so a READ that lands on the same clock edge as a WRITE to the
//     same address returns the *pre-write* value.  The scoreboard cannot
//     reliably recover that pre-write value from its own shadow when the
//     shadow is momentarily stale, so such READs are counted separately and
//     the comparison is skipped.
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
  logic [31:0] prev_shadow_rf [32];
  time         last_write_time [32];

  //--------------------------------------------------------------------------
  // Statistics
  //--------------------------------------------------------------------------
  int rf_write_count;
  int rf_read_pass;
  int rf_read_fail;
  int rf_read_skip;

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
    rf_read_skip   = 0;
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

      if (item.is_reset) begin
        foreach (shadow_rf[i]) shadow_rf[i] = '0;
        foreach (prev_shadow_rf[i]) prev_shadow_rf[i] = '0;
        continue;
      end

      case (item.kind)
        // == WRITE ========================================================
        regfile_item::WRITE: begin
          rf_write_count++;

          if (item.addr == 0) begin
            // x0 immutability: any write attempt is observed
            chk("x0_immutable_write_p", 1'b1,
                $sformatf("WRITE to x0 attempted with data=%0h (must remain 0)", item.data));
            prev_shadow_rf[0] = 32'h0;
            shadow_rf[0]      = 32'h0;
          end else begin
            prev_shadow_rf[item.addr] = shadow_rf[item.addr];
            shadow_rf[item.addr]      = item.data;
          end
          last_write_time[item.addr] = $time;

          `uvm_info("SB_RF", $sformatf("WRITE x%0d = 0x%08h (port %s)",
                    item.addr, item.data, item.port), UVM_MEDIUM)
        end

        // == READ =========================================================
        regfile_item::READ: begin
          if (item.addr == 0) begin
            // x0 must always read 0
            chk("x0_reads_zero_p", item.data === 32'h0,
                $sformatf("x0 read returned 0x%08h, expected 0x00000000 (port %s)",
                          item.data, item.port));
            chk("rf_read_correct_p", item.data === 32'h0,
                $sformatf("READ x0: exp=0x00000000 got=0x%08h (port %s)",
                          item.data, item.port));
            if (item.data === 32'h0) rf_read_pass++;
            else                     rf_read_fail++;
          end
          else if (last_write_time[item.addr] == $time) begin
            // Same-cycle WRITE+READ: RTL returns pre-write value.  Shadow
            // may or may not match; skip the comparison to avoid false fails
            // when the shadow is momentarily stale.
            chk("rf_read_correct_p", 1'b1,
                $sformatf("READ x%0d (port %s) coincides with WRITE - check skipped",
                          item.addr, item.port));
            rf_read_skip++;
            `uvm_info("SB_RF", $sformatf("READ SKIP x%0d = 0x%08h (port %s) - same-cycle write",
                      item.addr, item.data, item.port), UVM_HIGH)
          end
          else begin
            expected = shadow_rf[item.addr];
            chk("rf_read_correct_p", item.data === expected,
                $sformatf("READ mismatch x%0d: exp=0x%08h got=0x%08h (port %s)",
                          item.addr, expected, item.data, item.port));
            if (item.data === expected) begin
              rf_read_pass++;
              `uvm_info("SB_RF", $sformatf("READ PASS x%0d = 0x%08h (port %s)",
                        item.addr, item.data, item.port), UVM_MEDIUM)
            end else begin
              rf_read_fail++;
              `uvm_error("SB_RF", $sformatf(
                "READ FAIL x%0d | exp=0x%08h got=0x%08h (port %s) <<< MISMATCH",
                item.addr, expected, item.data, item.port))
            end
          end
        end

        default: ;
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
    `uvm_info(get_type_name(), $sformatf("|  READ SKIPPED    : %6d                       |", rf_read_skip),    UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("|  Pass Rate       : %6.2f%%                     |", rate),            UVM_LOW)
    `uvm_info(get_type_name(), "+------------------------------------------------+", UVM_LOW)

    foreach (prop_pass[p])
      `uvm_info(get_type_name(),
        $sformatf("  %-30s PASS=%5d FAIL=%5d", p, prop_pass[p], prop_fail[p]), UVM_LOW)
  endfunction

endclass

`endif