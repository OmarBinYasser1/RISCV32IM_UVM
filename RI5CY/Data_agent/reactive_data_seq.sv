class reactive_data_seq extends uvm_sequence #(data_transaction);

  `uvm_object_utils(reactive_data_seq);
  `uvm_declare_p_sequencer(reactive_data_sequencer);

  // Word-aligned sparse memory (Key = Word Address addr[31:2], Value = 32-bit Data)
  bit [31:0] mem[bit [31:2]];

  function new(string name = "reactive_data_seq");
    super.new(name);
  endfunction

  virtual task body();
    data_transaction req_item;
    data_transaction rsp_item;

    forever begin
      // 1. Fetch incoming request from sequencer's FIFO
      p_sequencer.req_fifo_x.get(req_item);

      // 2. Create response transaction
      rsp_item = data_transaction::type_id::create("rsp_item");
      rsp_item.set_id_info(req_item);

      // 3. Register transaction with driver
      start_item(rsp_item);

      // 4. Randomize delay
      if (!rsp_item.randomize() with {
            gnt_delay == 0;  // Set to desired delay cycles

          }) begin
        `uvm_error("RND_FAIL", "Randomization failed for rsp_item")
      end

      // Copy address context
      rsp_item.data_addr_o = req_item.data_addr_o;
      rsp_item.data_we_o   = req_item.data_we_o;
      rsp_item.data_be_o   = req_item.data_be_o;

      // 5. Execute Memory Access
      if (req_item.data_we_o) begin
        // WRITE Operation
        write_to_memory(req_item.data_addr_o, req_item.data_wdata_o, req_item.data_be_o);
      end else begin
        // READ Operation
        rsp_item.data_rdata_i = read_from_memory(req_item.data_addr_o);
      end

      // 6. Pass item to driver
      finish_item(rsp_item);
    end
  endtask

  // Helper function: Read 32-bit word
  function bit [31:0] read_from_memory(bit [31:0] addr);
    bit [31:2] word_addr = addr[31:2];
    return mem.exists(word_addr) ? mem[word_addr] : 32'h0000_0000;
  endfunction

  // Helper function: Write with byte-enable masking
  function void write_to_memory(bit [31:0] addr, bit [31:0] data, bit [3:0] be);
    bit [31:2] word_addr = addr[31:2];
    bit [31:0] current_val = mem.exists(word_addr) ? mem[word_addr] : 32'h0000_0000;

    for (int i = 0; i < 4; i++) begin
      if (be[i]) begin
        current_val[(i*8)+:8] = data[(i*8)+:8];
      end
    end

    mem[word_addr] = current_val;
  endfunction

endclass
