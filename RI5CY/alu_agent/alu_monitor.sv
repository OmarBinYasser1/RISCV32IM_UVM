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

    forever begin

      @(posedge vif.cb_mon);

      if (vif.cb_mon.rst_n && vif.cb_mon.enable_i && vif.cb_mon.ready_o && vif.cb_mon.ex_ready_i) begin

        item = alu_item::type_id::create("item");

        item.pc_ex                = vif.cb_mon.pc_ex;
        item.operator             = vif.cb_mon.operator_i;
        item.operand_a            = vif.cb_mon.operand_a_i;
        item.operand_b            = vif.cb_mon.operand_b_i;
        item.operand_c            = vif.cb_mon.operand_c_i;
        item.result               = vif.cb_mon.result_o;
        item.comparison_result    = vif.cb_mon.comparison_result_o;

        `uvm_info("ALU_MON", item.convertTostring(), UVM_MEDIUM)
        analysis_port.write(item);
      end
    end
  endtask
endclass
