class alu_monitor extends uvm_monitor;
  `uvm_component_utils(alu_monitor)

  virtual alu_if vif;                          
  uvm_analysis_port #(alu_item) analysis_port;  

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_port = new("analysis_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction


  task run_phase(uvm_phase phase);
    alu_item item;
    int unsigned cyc = 0;   // cycles since enable_i last went high

    forever begin

      @(posedge vif.cb_mon);

      // Reset / no operation: clear the running cycle counter.
      if (!vif.cb_mon.rst_n || !vif.cb_mon.enable_i) begin
        cyc = 0;
        continue;
      end

      if (vif.cb_mon.ready_o && vif.cb_mon.ex_ready_i) begin

        item = alu_item::type_id::create("item");

        item.pc_ex                = vif.cb_mon.pc_ex;
        item.operator             = vif.cb_mon.operator_i;
        item.operand_a            = vif.cb_mon.operand_a_i;
        item.operand_b            = vif.cb_mon.operand_b_i;
        item.operand_c            = vif.cb_mon.operand_c_i;
        item.result               = vif.cb_mon.result_o;
        item.comparison_result    = vif.cb_mon.comparison_result_o;
        // CHK:C-10  Latency = cycles since enable_i first asserted this op.
        item.latency              = cyc + 1;

        `uvm_info("ALU_MON", item.convertTostring(), UVM_MEDIUM)
        analysis_port.write(item);

        cyc = 0;
      end else begin
        cyc++;
      end
    end
  endtask
endclass