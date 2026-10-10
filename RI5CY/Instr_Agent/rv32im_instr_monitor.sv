class rv32im_instr_monitor extends uvm_monitor;
    `uvm_component_utils(rv32im_instr_monitor);

    
    virtual rv32im_instr_if.mp_mon instr_vif;

    uvm_analysis_port#(rv32im_instr_seq_item) instr_mon_ap;
    
    rv32im_instr_seq_item instr_item;


    function new (string name = "rv32im_instr_monitor" , uvm_component parent = null);
        super.new(name , parent);
    endfunction

    function void build_phase (uvm_phase phase);
        super.build_phase(phase);  
        instr_mon_ap = new("instr_mon_ap",this);
    endfunction

    task run_phase (uvm_phase phase);
        super.run_phase(phase);
        forever begin
            instr_item = rv32im_instr_seq_item::type_id::create("instr_item");
            i_monitor(instr_item);
            i_decoder(instr_item);
            `uvm_info("INSTR_MON",instr_item.convert2string(),UVM_LOW);
            instr_mon_ap.write(instr_item);
        end
    endtask

    task i_monitor (ref rv32im_instr_seq_item instr_item); // Instruction Monitor
        @(instr_vif.cb_mon iff (instr_vif.cb_mon.instr_rvalid_i == 1));
        instr_item.instruction = instr_vif.cb_mon.instr_rdata_i;
        instr_item.pc = instr_vif.cb_mon.instr_addr_o;
        instr_item.pc_if = instr_vif.cb_mon.pc_if;
    endtask

    function void i_decoder (ref rv32im_instr_seq_item item);
        bit [31:0] inst = item.instruction;
        // Extract the fields from the instructions
        item.opcode = opcode_t'(inst[6:0]);
        item.rd = inst[11:7];
        item.funct3 = inst[14:12];
        item.rs1 = inst[19:15];
        item.rs2 = inst[24:20];
        item.funct7 = inst[31:25];
        item.i_imm12[11:5] = inst[31:25]; // funct7
        item.i_imm12[4:0] = (item.opcode == OP_IMM)? inst[24:20] : inst[11:7];
        item.u_imm20 = inst[31:12];
        item.jal_imm21 = {inst[31],inst[19:12],inst[20],inst[30:21],1'b0};
        item.b_imm13 = {inst[31],inst[7],inst[30:25],inst[11:8],1'b0};

        // Set some auxiliary fields for printing at the monitor / scoreboard
        case (item.opcode)
            OP_R : begin
                if(item.funct7 == 'd1) begin // rv32m operations
                    item.ALU_MUL_sel = MUL_DIV;
                    item.R_rv32m_ops = mul_div_ops_t'(item.funct3); // Idenify the M operation 
                end
                else begin
                    item.ALU_MUL_sel = ALU;
                    item.R_rv32i_ops = alu_ops_t'(item.funct3); // Identify the ALU operation
                    // Note : There is no dedicated item member that tells whether it is ADD or SUB / SRL or SRA
                    // Hence : The identification will be done while printing 
                end
            end

            OP_IMM : begin
                item.I_ops = I_ops_t'(item.funct3);
                // Note : There is no dedicated item member that tells whether it is SRLI or SRAI
                // Hence : The identification will be done while printing 
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