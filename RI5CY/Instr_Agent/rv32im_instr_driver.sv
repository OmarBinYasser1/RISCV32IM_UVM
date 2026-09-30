class rv32im_instr_driver extends uvm_driver#(rv32im_instr_seq_item);
    `uvm_component_utils(rv32im_instr_driver);

    virtual rv32im_instr_if.mp_drv instr_vif;
    
    rv32im_instr_seq_item instr_item;

    function new (string name = "rv32im_instr_driver" , uvm_component parent = null);
        super.new(name , parent);
    endfunction

    task run_phase (uvm_phase phase);
        super.run_phase(phase);
         forever begin
            instr_item = rv32im_instr_seq_item::type_id::create("rv32im_instr_seq_item");
            seq_item_port.get_next_item(instr_item);
            drive(instr_item);     
            `uvm_info(get_name(),"INSTR DRIVER - Instuction is driven",UVM_HIGH);            
            seq_item_port.item_done();
        end
       
    endtask

    virtual task drive (input rv32im_instr_seq_item instr_item);
        @(instr_vif.cb_drv);
        instr_vif.cb_drv.instr_gnt_i <= instr_vif.cb_drv.instr_req_o;
        instr_vif.cb_drv.instr_rvalid_i <= instr_vif.cb_drv.instr_req_o;
        @(instr_vif.cb_drv iff (instr_vif.cb_drv.instr_req_o == 1));
        instr_vif.instr_gnt_i <= 1'b1; // Our Instruction Memory Model always available for any request
        instr_vif.instr_rvalid_i <= 1'b1; // Our Instruction Memory Model always send valid address
        instr_vif.instr_rdata_i <= instr_item.instruction;
    endtask

endclass // rv32im_instr_driver