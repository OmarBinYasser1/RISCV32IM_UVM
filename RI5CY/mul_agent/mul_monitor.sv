`ifndef MUL_MONITOR_SV
`define MUL_MONITOR_SV

class mul_monitor extends uvm_monitor;
  `uvm_component_utils(mul_monitor)

  virtual mul_if vif;
  uvm_analysis_port #(mul_item) analysis_port;

  // Watchdog: report an error if the multiplier never raises ready_o
  int unsigned max_cycles = 32;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_port = new("analysis_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    mul_item     item;
    int unsigned cyc      = 0;   // cycles since this operation started (1 = first enable_i cycle)
    int unsigned lat      = 0;   // cycle number of the FIRST ready_o
    bit          lat_done = 0;

    forever begin
      @(posedge vif.clk);

      // No operation in flight (or reset / flush): restart the count
      if (!vif.rst_n || !vif.enable_i) begin
        cyc = 0; lat_done = 0;
        continue;
      end

      cyc++;

      // Latency = first cycle where the multiplier says its result is ready.
      // (ex_ready_i may hold the stage longer; that is a stall, not latency.)
      if (vif.ready_o && !lat_done) begin
        lat = cyc; lat_done = 1;
      end

      // Operation completes when the result is ready AND the EX stage accepts it
      if (vif.ready_o && vif.ex_ready_i) begin
        item = mul_item::type_id::create("item");

        item.operator    = vif.operator_i;
        item.signed_mode = vif.short_signed_i;
        item.operand_a   = vif.op_a_i;
        item.operand_b   = vif.op_b_i;
        item.operand_c   = vif.op_c_i;
        item.result      = vif.result_o;
        item.latency     = lat;

        `uvm_info("MUL_MON", item.convert2string(), UVM_MEDIUM)
        analysis_port.write(item);

        cyc = 0; lat_done = 0;
      end
      else if (!lat_done && cyc > max_cycles) begin
        `uvm_error("MUL_MON", $sformatf("multiplier did not assert ready_o within %0d cycles (op=%0b)",
                                         max_cycles, vif.operator_i))
        cyc = 0; lat_done = 0;
      end
    end
  endtask
endclass

`endif
