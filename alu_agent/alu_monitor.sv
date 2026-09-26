
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
    if (!uvm_config_db#(virtual alu_if)::get(this, "", "alu_vif", vif))
      `uvm_fatal("ALU_MON", "alu_if not found")
  endfunction


  task run_phase(uvm_phase phase);
    alu_item item;

    forever begin

      @(posedge vif.clk);

      if (vif.rst_n && vif.enable_i && vif.ready_o && vif.ex_ready_i) begin

        item = alu_item::type_id::create("item");

        item.operator  = vif.operator_i;
        item.operand_a = vif.operand_a_i;
        item.operand_b = vif.operand_b_i;
        item.result    = vif.result_o;

        `uvm_info("ALU_MON", item.convertTostring(), UVM_MEDIUM)
        analysis_port.write(item);
      end
    end
  endtask
endclass
