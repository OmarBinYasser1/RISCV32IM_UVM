// ALU focus: random ALU + directed ALU + corner cases.
class rv32im_alu_test extends rv32im_base_test;
  `uvm_component_utils(rv32im_alu_test);

  function new(string name = "rv32im_alu_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void add_sequences();
    add_seq(rv32im_reset_init_seq::type_id::create("reset_init_seq"));
    add_seq(rv32im_rand_alu_seq::type_id::create("rand_alu_seq"));
    add_seq(rv32im_dir_alu_seq::type_id::create("dir_alu_seq"));
    add_seq(rv32im_dir_corner_seq::type_id::create("dir_corner_seq"));
  endfunction
endclass // rv32im_alu_test
