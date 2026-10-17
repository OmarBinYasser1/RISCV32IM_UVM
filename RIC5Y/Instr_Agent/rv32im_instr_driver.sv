// =============================================================================
// rv32im_instr_driver
//
// OBI slave for the instruction bus.
// =============================================================================
class rv32im_instr_driver extends uvm_driver#(rv32im_instr_seq_item);
    `uvm_component_utils(rv32im_instr_driver);

    virtual rv32im_instr_if.mp_drv instr_vif;

    rv32im_instr_seq_item instr_item;
    int driven_insts;

    // Mailbox holding data for accepted transactions awaiting R-channel response
    mailbox #(logic [31:0]) pending_resp;

    function new (string name = "rv32im_instr_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase (uvm_phase phase);
        super.run_phase(phase);
        pending_resp = new();

        // Safe initial state
        instr_vif.cb_drv.instr_gnt_i    <= 0;
        instr_vif.cb_drv.instr_rvalid_i <= 0;
        instr_vif.cb_drv.instr_rdata_i  <= 0;
        instr_vif.cb_drv.rst_n          <= 0;

        // Consume reset items from the sequencer.  Reset is driven low for
        // each rst_n==0 item; the first operational item is held for the
        // A-channel to accept.
        forever begin
            seq_item_port.get_next_item(instr_item);
            instr_vif.cb_drv.rst_n <= instr_item.rst_n;
            if (!instr_item.rst_n) begin
                instr_vif.cb_drv.instr_gnt_i <= 0;
                @(instr_vif.cb_drv);
                seq_item_port.item_done();
            end else begin
                flush_reqs();
                break;
            end
        end

        // Assert reset release and fork parallel A/R channel handlers
        instr_vif.cb_drv.rst_n <= 1;
        fork
            a_channel_thread();
            r_channel_thread();
        join_none
    endtask

    task automatic flush_reqs ();
        bit [31:0] inst;
        while (pending_resp.try_get(inst)) ;
    endtask

    // =======================================================================
    // A-channel thread: OBI slave request handler
    //
    // Memory is always ready to grant.  A transfer completes on the edge where
    // req_o and gnt_i are both high.  gnt is pulsed for exactly one cycle.
    // =======================================================================
    task a_channel_thread();
        forever begin
            @(instr_vif.cb_drv);

            if (instr_vif.cb_drv.instr_req_o === 1'b1) begin
                driven_insts++;

                // Pulse gnt for exactly one cycle
                instr_vif.cb_drv.instr_gnt_i <= 1'b1;
                @(instr_vif.cb_drv);
                instr_vif.cb_drv.instr_gnt_i <= 1'b0;

                // Enqueue the response data and signal the sequence
                pending_resp.put(instr_item.instruction);
                `uvm_info("INSTR_DRV",
                    $sformatf("A-ch #%0d accepted (req & gnt) rdata=0x%08h",
                              driven_insts, instr_item.instruction), UVM_LOW)
                seq_item_port.item_done();

                // Fetch the next instruction.  While this blocks, gnt stays
                // at 0, so the DUT never sees an accept without a response.
                seq_item_port.get_next_item(instr_item);
            end
            // Otherwise leave gnt at its current (low) value; nothing to do.
        end
    endtask

    // =======================================================================
    // R-channel thread: OBI slave response handler
    //
    // rvalid is asserted for exactly one clock cycle per accepted A-channel
    // transaction.  A full idle cycle is inserted between responses so the
    // deassertion of rvalid is actually observed by the DUT.
    // =======================================================================
    task r_channel_thread();
        logic [31:0] rdata;
        forever begin
            while (pending_resp.num() == 0) begin
                instr_vif.cb_drv.instr_rvalid_i <= 0;
                instr_vif.cb_drv.instr_rdata_i  <= 0;
                @(instr_vif.cb_drv);
            end

            pending_resp.get(rdata);

            instr_vif.cb_drv.instr_rvalid_i <= 1;
            instr_vif.cb_drv.instr_rdata_i  <= rdata;
            `uvm_info("INSTR_DRV",
                $sformatf("R-ch: rvalid sent rdata=0x%08h", rdata), UVM_HIGH)
            @(instr_vif.cb_drv);
        end
    endtask

endclass