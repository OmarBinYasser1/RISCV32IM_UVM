class debug_interupt_seq extends uvm_sequence #(debug_interupt_transaction);
  `uvm_object_utils(debug_interupt_seq)

  function new(string name = "debug_interupt_seq");
    super.new(name);
  endfunction

  task body();
    forever begin
      debug_interupt_transaction tr;
      tr = debug_interupt_transaction::type_id::create("tr");

      // Set the transaction fields as needed
      tr.irq_i = 32'h0000_0000;
      tr.debug_req_i = 1'b0;
      tr.fetch_enable_i = 1'b1;

      // Start the sequence item
      start_item(tr);
      finish_item(tr);
    end
  endtask
endclass
