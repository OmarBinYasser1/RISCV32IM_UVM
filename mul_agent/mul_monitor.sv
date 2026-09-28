
class mul_monitor extends uvm_monitor;
  `uvm_component_utils(mul_monitor)

  virtual mul_if vif;
  uvm_analysis_port #(mul_item) analysis_port;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_port = new("analysis_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mul_if)::get(this, "", "mul_vif", vif))
      `uvm_fatal("MUL_MON", "mul_if not found")
  endfunction

  task run_phase(uvm_phase phase);
    mul_item item;

    forever begin
      @(posedge vif.clk);

      if (vif.rst_n && vif.enable_i && vif.ready_o && vif.ex_ready_i) begin

        item = mul_item::type_id::create("item");

        item.operator  = vif.operator_i;
        item.operand_a = vif.op_a_i;
        item.operand_b = vif.op_b_i;
        item.operand_c = vif.op_c_i;
        item.result    = vif.result_o;

        `uvm_info("MUL_MON", item.convertTostring(), UVM_MEDIUM)

        analysis_port.write(item);
      end
    end
  endtask
endclass
