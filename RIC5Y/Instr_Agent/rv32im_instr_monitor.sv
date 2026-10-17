class rv32im_instr_monitor extends uvm_monitor;
    `uvm_component_utils(rv32im_instr_monitor);

    virtual rv32im_instr_if.mp_mon instr_vif;

    uvm_analysis_port#(rv32im_instr_seq_item) instr_mon_ap;

    rv32im_instr_seq_item instr_item;

    // FIFO tracking requested addresses on the OBI A-channel to match
    // responses returning on the R-channel
    logic [31:0] addr_fifo[$];

    function new (string name = "rv32im_instr_monitor" , uvm_component parent = null);
        super.new(name , parent);
    endfunction

    function void build_phase (uvm_phase phase);
        super.build_phase(phase);
        instr_mon_ap = new("instr_mon_ap",this);
    endfunction

    // ------------------------------------------------------------------
    // run_phase:
    //   A single deterministic loop handles both A-channel (request) and
    //   R-channel (response) activity.  Within a given clock edge the
    //   response is processed BEFORE the new request is enqueued, so the
    //   FIFO ordering is:
    //       [oldest outstanding request] ... [new request]
    //   which is the correct pairing for the OBI R-channel.
    // ------------------------------------------------------------------
    task run_phase (uvm_phase phase);
        super.run_phase(phase);
        forever begin
            @(instr_vif.cb_mon);

            if (!instr_vif.cb_mon.rst_n) begin
                addr_fifo.delete();
            end else begin

                // --- 1) R-channel response (uses the oldest request in FIFO)
                if (instr_vif.cb_mon.instr_rvalid_i) begin
                    instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
                    instr_item.instruction = instr_vif.cb_mon.instr_rdata_i;
                    if (addr_fifo.size() > 0)
                        instr_item.pc = addr_fifo.pop_front();
                    else
                        instr_item.pc = instr_vif.cb_mon.instr_addr_o;
                    instr_item.pc_if = instr_vif.cb_mon.pc_if;
                    i_decoder(instr_item);
                    `uvm_info("INSTR_MON", $sformatf("pc=0x%08h (rem=%0d) %s",
                              instr_item.pc, addr_fifo.size(),
                              instr_item.convert2string()), UVM_LOW);
                    instr_mon_ap.write(instr_item);
                end

                // --- 2) A-channel request (enqueue for a future response)
                if (instr_vif.cb_mon.instr_req_o && instr_vif.cb_mon.instr_gnt_i) begin
                    addr_fifo.push_back(instr_vif.cb_mon.instr_addr_o);
                    `uvm_info("INSTR_REQ", $sformatf("A-ch REQ addr=0x%08h (fifo_sz=%0d)",
                              instr_vif.cb_mon.instr_addr_o, addr_fifo.size()), UVM_LOW);
                end
            end
        end
    endtask

    function void i_decoder (ref rv32im_instr_seq_item item);
        bit [31:0] inst = item.instruction;
        // Extract the fields from the instructions
        item.opcode = opcode_t'(inst[6:0]);
        item.rd = inst[11:7];
        item.funct3 = inst[14:12];
        item.rs1 = inst[19:15];
        item.rs2 = inst[24:20];
        item.shamt = inst[24:20];
        item.funct7 = inst[31:25];
        case (item.opcode)
            OP_IMM, OP_LOAD, OP_JALR:
                item.i_imm12 = inst[31:20];          // standard I-type: bits [31:20]
            OP_STORE:
                item.i_imm12 = {inst[31:25], inst[11:7]};  // S-type split immediate
            default:
                item.i_imm12 = inst[31:20];          // fallback
        endcase
        item.u_imm20 = inst[31:12];
        item.jal_imm21 = {inst[31],inst[19:12],inst[20],inst[30:21],1'b0};
        item.b_imm13 = {inst[31],inst[7],inst[30:25],inst[11:8],1'b0};

        // Set some auxiliary fields for printing at the monitor / scoreboard
        case (item.opcode)
            OP_R : begin
                if(item.funct7 == 'd1) begin // rv32m operations
                    item.ALU_MUL_sel = MUL_DIV;
                    item.R_rv32m_ops = mul_div_ops_t'(item.funct3); // Identify the M operation
                end
                else begin
                    item.ALU_MUL_sel = ALU;
                    item.R_rv32i_ops = alu_ops_t'(item.funct3); // Identify the ALU operation
                end
            end

            OP_IMM : begin
                item.I_ops = I_ops_t'(item.funct3);
            end

            OP_BRANCH : begin
                item.B_ops = B_ops_t'(item.funct3);
            end

            OP_STORE : begin
                item.S_ops = S_ops_t'(item.funct3);
            end

            OP_LOAD : begin
                item.Load_ops = Load_ops_t'(item.funct3);
            end
        endcase

        if(item.opcode == OP_R)
            item.ALU_MUL_sel = (item.funct7 == 'd1)? MUL_DIV : ALU;

    endfunction

endclass // rv32im_instr_monitor