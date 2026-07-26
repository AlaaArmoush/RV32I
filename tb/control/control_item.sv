class control_item;
  rand logic [6:0] op_code;
  rand logic zero, last_bit;
  rand logic [2:0] func3;
  rand logic [6:0] func7;

  logic [2:0] imm_type;
  logic mem_write, reg_write, reg_write_gated, alu_source;
  logic [1:0] result_source;
  logic pc_src;
  logic [1:0] addr_base_src;
  logic [3:0] alu_control;

  // debug label
  string name;

  function new(string name = "control_item");
    this.name = name;
  endfunction

  function string inputs_to_string();
    return $sformatf(
        "%s: opcode=%07b func3=%03b func7=%07b zero=%0b last_bit=%0b",
        name,
        op_code,
        func3,
        func7,
        zero,
        last_bit
    );
  endfunction

  function string outputs_to_string();
    return $sformatf(
        {
          "imm_type=%03b mem_write=%0b reg_write=%0b ",
          "reg_write_gated=%0b alu_source=%0b result_source=%02b ",
          "pc_src=%0b addr_base_src=%02b alu_control=%04b"
        },
        imm_type,
        mem_write,
        reg_write,
        reg_write_gated,
        alu_source,
        result_source,
        pc_src,
        addr_base_src,
        alu_control
    );
  endfunction
endclass : control_item
