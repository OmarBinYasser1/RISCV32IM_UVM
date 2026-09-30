class rv32im_virtual_seq extends uvm_sequence #(uvm_sequence_item);
  `uvm_object_utils(rv32im_virtual_seq);

  //  Declare the virtual sequencer as p_sequencer not m_sequencer
  `uvm_declare_p_sequencer(rv32im_virtual_seqr);

  //  Define the sequences that live in the virtual sequence
  // 1- Instruction Sequence 
  rv32im_instr_seq instr_seq;
  // 2- Data Sequence
  reactive_data_seq data_seq;
  // 3- Debug_Interrupt Sequence
  debug_interupt_seq debug_int_seq;

  //  Define the local sequencer handles to be connected from the env
  // 1- Instruction Sequencer
  rv32im_instr_seqr instr_seqr;
  // 2- Data Sequencer
  reactive_data_sequencer data_seqr;
  // 3- Debug_Interrupt Sequencer 
  debug_interupt_sequencer debug_int_seqr;

  //  Define the virual sequencer to connect its sub-sequencers to the local sequencers
  rv32im_virtual_seqr sys_vseqr;
  // virtual interface handles to drive the reset in the virual sequence

  virtual reset_if rst_if;

  //      ====================================================================

  function new(string name = "rv32im_virtual_seq");
    super.new(name);
    // Build the sub-sequences 
    instr_seq = rv32im_instr_seq::type_id::create("instr_seq");
    data_seq = reactive_data_seq::type_id::create("data_seq");
    debug_int_seq = debug_interupt_seq::type_id::create("debug_int_seq");
  endfunction

  virtual task body();
    // Connect the local sequencers to the virtual sequencer's sub-sequencers
    sys_vseqr = p_sequencer;
    instr_seqr = sys_vseqr.instr_seqr;
    data_seqr = sys_vseqr.data_seqr;
    debug_int_seqr = sys_vseqr.debug_int_seqr;

    // -----------------------------------------------------------------
    // Get the data interface handle from uvm_config_db
    // -----------------------------------------------------------------
    if (!uvm_config_db#(virtual reset_if)::get(null, get_full_name(), "RST_IF", rst_if)) begin
      `uvm_fatal(get_name(), "Failed to get rst_if!")
    end
    // -----------------------------------------------------------------
    // Drive System Reset (This toggles the top-level rst_ni wire)
    // 2. Drive Reset Cycle
    `uvm_info(get_name(), "Asserting System Reset (rst_n = 0)...", UVM_LOW)
    rst_if.rst_n <= 1'b0;

    repeat (20) @(posedge rst_if.clk);  // Hold active for 20 clock cycles

    `uvm_info(get_name(), "Releasing System Reset (rst_n = 1)...", UVM_LOW)
    rst_if.rst_n <= 1'b1;
    @(posedge rst_if.clk);  // Wait 1 cycle after releases

    // Run the sequences on the local sequencers
    fork
      begin
        `uvm_info(get_name(), "INSTR SEQ - Started", UVM_HIGH);
        instr_seq.start(instr_seqr);
        `uvm_info(get_name(), "INSTR SEQ - Finished", UVM_HIGH);
      end
      begin
        `uvm_info(get_name(), "DATA REACTIVE SEQ - Started", UVM_HIGH);
        data_seq.start(data_seqr);
      end
      begin
        `uvm_info(get_name(), "DEBUG DEFAULT SEQ - Started", UVM_HIGH);
        debug_int_seq.start(debug_int_seqr);
      end
    join_any
  endtask

endclass  // rv32im_virtual_seq
