// Random-only regression: all random sequences + mixed stream.
class rv32im_random_test extends rv32im_base_test;
  `uvm_component_utils(rv32im_random_test);

  function new(string name = "rv32im_random_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void add_sequences();
    add_seq(rv32im_reset_init_seq::type_id::create("reset_init_seq"));
    add_seq(rv32im_rand_alu_seq::type_id::create("rand_alu_seq"));
    add_seq(rv32im_rand_mem_seq::type_id::create("rand_mem_seq"));
    add_seq(rv32im_rand_ctrl_seq::type_id::create("rand_ctrl_seq"));
    add_seq(rv32im_stream_seq::type_id::create("stream_seq"));
  endfunction
endclass // rv32im_random_test
