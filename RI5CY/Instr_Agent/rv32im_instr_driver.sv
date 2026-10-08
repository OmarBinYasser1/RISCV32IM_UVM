class rv32im_instr_driver extends uvm_driver#(rv32im_instr_seq_item);
    `uvm_component_utils(rv32im_instr_driver);

    virtual rv32im_instr_if.mp_drv instr_vif;
    
    rv32im_instr_seq_item instr_item;

    function new (string name = "rv32im_instr_driver" , uvm_component parent = null);
        super.new(name , parent);
    endfunction

    task run_phase (uvm_phase phase);
        super.run_phase(phase);

        // Initialize outputs
        instr_vif.cb_drv.instr_gnt_i    <= 0;
        instr_vif.cb_drv.instr_rvalid_i <= 0;
        instr_vif.cb_drv.instr_rdata_i  <= 0;
        instr_vif.cb_drv.rst_n           <= 0;

        forever begin
            instr_item = rv32im_instr_seq_item::type_id::create("rv32im_instr_seq_item");
            seq_item_port.get_next_item(instr_item);
            drive(instr_item);
            `uvm_info(get_name(), $sformatf("INSTR DRIVER - Instruction driven: 0x%08h (rst_n=%0b) @ %0t",
                instr_item.instruction, instr_item.rst_n, $time), UVM_LOW);
            seq_item_port.item_done();
        end
       
    endtask

    // OBI-compliant zero-latency instruction memory model:
    //   - During reset: drive rst_n=0, keep gnt/rvalid/rdata=0
    //   - After reset:  on every cycle where instr_req_o=1, immediately
    //                   grant and return rdata (zero-latency ROM model)
    virtual task drive (input rv32im_instr_seq_item instr_item);
        @(instr_vif.cb_drv);

        // Always update rst_n
        instr_vif.cb_drv.rst_n <= instr_item.rst_n;

        if (!instr_item.rst_n) begin
            // In reset: de-assert everything
            instr_vif.cb_drv.instr_gnt_i    <= 0;
            instr_vif.cb_drv.instr_rvalid_i <= 0;
            instr_vif.cb_drv.instr_rdata_i  <= 0;
        end else begin
            // Out of reset: wait for the core to request an instruction
            @(instr_vif.cb_drv iff (instr_vif.cb_drv.instr_req_o == 1));

            // Immediately grant and provide the instruction data (zero-latency ROM)
            instr_vif.cb_drv.instr_gnt_i    <= 1;
            instr_vif.cb_drv.instr_rvalid_i <= 1;
            instr_vif.cb_drv.instr_rdata_i  <= instr_item.instruction;

            // One cycle later, de-assert handshake signals
            @(instr_vif.cb_drv);
            instr_vif.cb_drv.instr_gnt_i    <= 0;
            instr_vif.cb_drv.instr_rvalid_i <= 0;
        end
    endtask

endclass // rv32im_instr_driver