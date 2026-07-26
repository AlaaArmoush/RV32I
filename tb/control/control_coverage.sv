import control_pkg::*;

class control_coverage;
  typedef enum int unsigned {
    FAMILY_LOAD,
    FAMILY_STORE,
    FAMILY_RALU,
    FAMILY_IALU,
    FAMILY_BRANCH,
    FAMILY_JALR,
    FAMILY_JAL,
    FAMILY_LUI,
    FAMILY_AUIPC,
    FAMILY_UNSUPPORTED
  } opcode_family_e;

  typedef enum int unsigned {
    FUNCT7_ZERO,
    FUNCT7_ALT,
    FUNCT7_OTHER
  } funct7_class_e;

  int unsigned samples;

  covergroup control_cg with function sample (
      opcode_family_e opcode_family,
      logic [2:0] func3,
      funct7_class_e funct7_class,
      logic zero,
      logic last_bit,
      encoding_class_e encoding_class,
      logic mem_write,
      logic reg_write,
      logic reg_write_gated,
      logic alu_source,
      logic [1:0] result_source,
      logic pc_src,
      logic [1:0] addr_base_src,
      logic [3:0] alu_control
  );
    option.per_instance = 1;

    cp_opcode_family: coverpoint opcode_family {
      bins load = {FAMILY_LOAD};
      bins store = {FAMILY_STORE};
      bins ralu = {FAMILY_RALU};
      bins ialu = {FAMILY_IALU};
      bins branch = {FAMILY_BRANCH};
      bins jalr = {FAMILY_JALR};
      bins jal = {FAMILY_JAL};
      bins lui = {FAMILY_LUI};
      bins auipc = {FAMILY_AUIPC};
      bins unsupported = {FAMILY_UNSUPPORTED};
    }

    cp_func3: coverpoint func3 {bins values[] = {[3'b000 : 3'b111]};}

    cp_funct7_class: coverpoint funct7_class {
      bins zero = {FUNCT7_ZERO}; bins alt = {FUNCT7_ALT}; bins other = {FUNCT7_OTHER};
    }

    cp_branch_func3: coverpoint func3 iff (opcode_family == FAMILY_BRANCH) {
      bins beq = {3'b000};
      bins bne = {3'b001};
      bins blt = {3'b100};
      bins bge = {3'b101};
      bins bltu = {3'b110};
      bins bgeu = {3'b111};

      ignore_bins unsupported = {3'b010, 3'b011};
    }

    cp_branch_zero: coverpoint zero iff (opcode_family == FAMILY_BRANCH) {
      bins clear = {1'b0}; bins set = {1'b1};
    }

    cp_branch_last_bit: coverpoint last_bit iff (opcode_family == FAMILY_BRANCH) {
      bins clear = {1'b0}; bins set = {1'b1};
    }

    cp_branch_taken: coverpoint pc_src iff (opcode_family == FAMILY_BRANCH) {
      bins not_taken = {1'b0}; bins taken = {1'b1};
    }

    cp_alu_opcode: coverpoint opcode_family iff (opcode_family inside {FAMILY_RALU, FAMILY_IALU}) {
      bins ralu = {FAMILY_RALU}; bins ialu = {FAMILY_IALU};
    }

    cp_alu_func3: coverpoint func3 iff (opcode_family inside {FAMILY_RALU, FAMILY_IALU}) {
      bins values[] = {[3'b000 : 3'b111]};
    }

    cp_alu_funct7: coverpoint funct7_class iff (opcode_family inside {FAMILY_RALU, FAMILY_IALU}) {
      bins zero = {FUNCT7_ZERO}; bins alt = {FUNCT7_ALT}; bins other = {FUNCT7_OTHER};
    }

    cp_encoding_class: coverpoint encoding_class {
      bins legal = {ENCODING_LEGAL};
      bins illegal = {ENCODING_ILLEGAL};
      bins unsupported = {ENCODING_UNSUPPORTED};
    }

    cp_mem_write: coverpoint mem_write {bins disabled = {1'b0}; bins enabled = {1'b1};}

    cp_reg_write: coverpoint reg_write {bins disabled = {1'b0}; bins enabled = {1'b1};}

    cp_reg_write_gated: coverpoint reg_write_gated {bins disabled = {1'b0}; bins enabled = {1'b1};}

    cp_alu_source: coverpoint alu_source {bins register = {1'b0}; bins immediate = {1'b1};}

    cp_result_source: coverpoint result_source {
      bins alu_result = {2'b00};
      bins memory = {2'b01};
      bins pc_plus_4 = {2'b10};
      bins target = {2'b11};
    }

    cp_pc_src: coverpoint pc_src {bins sequential = {1'b0}; bins target = {1'b1};}

    cp_addr_base_src: coverpoint addr_base_src {
      bins pc = {2'b00};
      bins immediate = {2'b01};
      bins rs1 = {2'b10};

      illegal_bins reserved = {2'b11};
    }

    cp_alu_control: coverpoint alu_control {
      bins add = {ALU_ADD};
      bins sub = {ALU_SUB};
      bins and_op = {ALU_AND};
      bins or_op = {ALU_OR};
      bins sll = {ALU_SLL};
      bins slt = {ALU_SLT};
      bins srl = {ALU_SRL};
      bins sltu = {ALU_SLTU};
      bins xor_op = {ALU_XOR};
      bins sra = {ALU_SRA};
      bins invalid = {ALU_INV};

      illegal_bins unused = default;
    }

    cx_opcode_func3: cross cp_opcode_family, cp_func3;

    cx_alu_decode: cross cp_alu_opcode, cp_alu_func3, cp_alu_funct7;

    cx_branch_outcome: cross cp_branch_func3, cp_branch_taken;

    cx_opcode_writeback: cross cp_opcode_family, cp_result_source{
      ignore_bins load_not_memory =
            binsof(cp_opcode_family.load) &&
            !binsof(cp_result_source.memory);

      ignore_bins alu_family_not_alu =
            binsof(cp_opcode_family) intersect {
              FAMILY_STORE,
              FAMILY_RALU,
              FAMILY_IALU,
              FAMILY_BRANCH,
              FAMILY_UNSUPPORTED
            } &&
            !binsof(cp_result_source.alu_result);

      ignore_bins upper_not_target =
            binsof(cp_opcode_family) intersect {
              FAMILY_LUI,
              FAMILY_AUIPC
            } &&
            !binsof(cp_result_source.target);

      ignore_bins jal_not_pc4 =
            binsof(cp_opcode_family.jal) &&
            !binsof(cp_result_source.pc_plus_4);

      ignore_bins jalr_memory = binsof (cp_opcode_family.jalr) && binsof (cp_result_source.memory);

      ignore_bins jalr_target = binsof (cp_opcode_family.jalr) && binsof (cp_result_source.target);
    }

    cx_encoding_gated_write: cross cp_encoding_class, cp_reg_write_gated{
      illegal_bins illegal_write =
            binsof(cp_encoding_class.illegal) &&
            binsof(cp_reg_write_gated.enabled);

      illegal_bins unsupported_write =
            binsof(cp_encoding_class.unsupported) &&
            binsof(cp_reg_write_gated.enabled);
    }
  endgroup

  function new();
    samples = 0;
    control_cg = new();
  endfunction

  function opcode_family_e classify_opcode(input logic [6:0] op_code);
    case (op_code)
      OP_LOAD:   return FAMILY_LOAD;
      OP_STORE:  return FAMILY_STORE;
      OP_RALU:   return FAMILY_RALU;
      OP_IALU:   return FAMILY_IALU;
      OP_BRANCH: return FAMILY_BRANCH;
      OP_JALR:   return FAMILY_JALR;
      OP_JAL:    return FAMILY_JAL;
      OP_LUI:    return FAMILY_LUI;
      OP_AUIPC:  return FAMILY_AUIPC;
      default:   return FAMILY_UNSUPPORTED;
    endcase
  endfunction

  function funct7_class_e classify_funct7(input logic [6:0] func7);
    case (func7)
      7'b0000000: return FUNCT7_ZERO;
      7'b0100000: return FUNCT7_ALT;
      default:    return FUNCT7_OTHER;
    endcase
  endfunction

  function void sample (input control_item item);
    control_cg.sample(classify_opcode(item.op_code), item.func3, classify_funct7(item.func7),
                      item.zero, item.last_bit, classify_encoding(
                      item.op_code, item.func3, item.func7), item.mem_write, item.reg_write,
                      item.reg_write_gated, item.alu_source, item.result_source, item.pc_src,
                      item.addr_base_src, item.alu_control);

    samples++;
  endfunction

  function void report();
    $display("Control coverage samples: %0d", samples);
  endfunction
endclass : control_coverage
