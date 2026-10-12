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

        // Phase 0: Consume reset items from sequencer
        forever begin
            seq_item_port.get_next_item(instr_item);
            instr_vif.cb_drv.rst_n <= instr_item.rst_n;
            if (!instr_item.rst_n) begin
                instr_vif.cb_drv.instr_gnt_i <= 0;
                @(instr_vif.cb_drv);
                seq_item_port.item_done();
            end else begin
                // First operational instruction received; keep item for A-channel
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

    // =======================================================================
    // A-channel thread: OBI slave request handler
    // Memory is always ready to grant (gnt_i = 1).
    // An actual transfer occurs ONLY when req_o == 1 and gnt_i == 1 at the clock edge.
    // =======================================================================
    task a_channel_thread();
        forever begin
            instr_vif.cb_drv.instr_gnt_i <= 1'b1;

            @(instr_vif.cb_drv);

            // Valid transaction accepted on this clock edge
            if (instr_vif.cb_drv.instr_req_o === 1'b1) begin
                driven_insts++;
                pending_resp.put(instr_item.instruction);
                `uvm_info("INSTR_DRV",
                    $sformatf("A-ch #%0d accepted (req & gnt) rdata=0x%08h",
                              driven_insts, instr_item.instruction), UVM_LOW)
                seq_item_port.item_done();

                // Fetch next instruction
                seq_item_port.get_next_item(instr_item);
            end
        end
    endtask

    // =======================================================================
    // R-channel thread: OBI slave response handler
    // Returns rvalid = 1 exactly once for every accepted A-channel transaction.
    // =======================================================================
    task r_channel_thread();
        logic [31:0] rdata;
        forever begin
            // Wait until a response is pending in the mailbox
            while (pending_resp.num() == 0) begin
                instr_vif.cb_drv.instr_rvalid_i <= 0;
                instr_vif.cb_drv.instr_rdata_i  <= 0;
                @(instr_vif.cb_drv);
            end

            // Pop one pending response
            pending_resp.get(rdata);

            // Assert rvalid for exactly ONE clock cycle
            instr_vif.cb_drv.instr_rvalid_i <= 1;
            instr_vif.cb_drv.instr_rdata_i  <= rdata;
            `uvm_info("INSTR_DRV",
                $sformatf("R-ch: rvalid sent rdata=0x%08h", rdata), UVM_HIGH)
            @(instr_vif.cb_drv);

            // De-assert rvalid
            instr_vif.cb_drv.instr_rvalid_i <= 0;
            instr_vif.cb_drv.instr_rdata_i  <= 0;
        end
    endtask

endclass // rv32im_instr_driver