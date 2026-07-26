import control_pkg::*;

class control_generator;
  typedef struct {
    string      name;
    logic [6:0] op_code;
    logic [2:0] func3;
    logic [6:0] func7;
    logic       zero;
    logic       last_bit;
  } directed_vector_t;

  control_item transactions[$];

  int unsigned random_tests;
  int unsigned directed_count;
  int unsigned random_count;

  function new (int unsigned random_tests = 1000);
    this.random_tests = random_tests;
  endfunction

  function void add_directed (
    input string name,
    input logic [6:0] op_code,
    input logic [2:0] func3,
    input logic [6:0] func7,
    input logic zero, last_bit
  );
    control_item item;

    item = new(name);
    item.op_code = op_code;
    item.func3 = func3;
    item.func7 = func7;
    item.zero = zero;
    item.last_bit = last_bit;

    transactions.push_back(item);
    directed_count++;
  endfunction

  function void build_directed_sequence();
    directed_vector_t vectors[] = '{
      '{"LW",                     OP_LOAD,   3'b010, 7'b0000000, 1'b0, 1'b0},
      '{"invalid LOAD funct3",    OP_LOAD,   3'b111, 7'b0000000, 1'b0, 1'b0},
      '{"SW",                     OP_STORE,  3'b010, 7'b0000000, 1'b0, 1'b0},
      '{"invalid STORE funct3",   OP_STORE,  3'b101, 7'b0000000, 1'b0, 1'b0},

      '{"ADD",                    OP_RALU,   3'b000, 7'b0000000, 1'b0, 1'b0},
      '{"SUB",                    OP_RALU,   3'b000, 7'b0100000, 1'b0, 1'b0},
      '{"AND",                    OP_RALU,   3'b111, 7'b0000000, 1'b0, 1'b0},
      '{"OR",                     OP_RALU,   3'b110, 7'b0000000, 1'b0, 1'b0},
      '{"invalid R-type funct7",  OP_RALU,   3'b000, 7'b0000001, 1'b0, 1'b0},

      '{"ADDI",                   OP_IALU,   3'b000, 7'b0000000, 1'b0, 1'b0},
      '{"SLLI",                   OP_IALU,   3'b001, 7'b0000000, 1'b0, 1'b0},
      '{"invalid SLLI funct7",    OP_IALU,   3'b001, 7'b0100000, 1'b0, 1'b0},
      '{"SRLI",                   OP_IALU,   3'b101, 7'b0000000, 1'b0, 1'b0},
      '{"SRAI",                   OP_IALU,   3'b101, 7'b0100000, 1'b0, 1'b0},

      '{"LUI",                    OP_LUI,    3'b000, 7'b0000000, 1'b0, 1'b0},
      '{"AUIPC",                  OP_AUIPC,  3'b000, 7'b0000000, 1'b0, 1'b0},
      '{"JAL",                    OP_JAL,    3'b000, 7'b0000000, 1'b0, 1'b0},
      '{"JALR",                   OP_JALR,   3'b000, 7'b0000000, 1'b0, 1'b0},
      '{"invalid JALR funct3",    OP_JALR,   3'b001, 7'b0000000, 1'b0, 1'b0},

      '{"BEQ taken",              OP_BRANCH, 3'b000, 7'b0000000, 1'b1, 1'b0},
      '{"BEQ not taken",          OP_BRANCH, 3'b000, 7'b0000000, 1'b0, 1'b0},
      '{"BNE taken",              OP_BRANCH, 3'b001, 7'b0000000, 1'b0, 1'b0},
      '{"BNE not taken",          OP_BRANCH, 3'b001, 7'b0000000, 1'b1, 1'b0},
      '{"BLT taken",              OP_BRANCH, 3'b100, 7'b0000000, 1'b0, 1'b1},
      '{"BLT not taken",          OP_BRANCH, 3'b100, 7'b0000000, 1'b0, 1'b0},
      '{"BGE taken",              OP_BRANCH, 3'b101, 7'b0000000, 1'b0, 1'b0},
      '{"BGE not taken",          OP_BRANCH, 3'b101, 7'b0000000, 1'b0, 1'b1},
      '{"BLTU taken",             OP_BRANCH, 3'b110, 7'b0000000, 1'b0, 1'b1},
      '{"BLTU not taken",         OP_BRANCH, 3'b110, 7'b0000000, 1'b0, 1'b0},
      '{"BGEU taken",             OP_BRANCH, 3'b111, 7'b0000000, 1'b0, 1'b0},
      '{"BGEU not taken",         OP_BRANCH, 3'b111, 7'b0000000, 1'b0, 1'b1},

      '{"invalid BRANCH funct3",  OP_BRANCH, 3'b010, 7'b0000000, 1'b0, 1'b0},
      '{"unsupported opcode",     7'b1111111, 3'b000, 7'b0000000, 1'b0, 1'b0}
    };

    foreach (vectors[i]) begin
      control_item item;

      item = new(vectors[i].name);
      item.op_code = vectors[i].op_code;
      item.func3 = vectors[i].func3;
      item.func7 = vectors[i].func7;
      item.zero = vectors[i].zero;
      item.last_bit = vectors[i].last_bit;

      transactions.push_back(item);
    end

    directed_count = vectors.size();
  endfunction

  function void add_random (input encoding_class_e encoding_class, input int unsigned index);
    control_item item;
    string class_name;

    case (encoding_class)
      ENCODING_LEGAL: class_name = "legal";
      ENCODING_ILLEGAL: class_name = "illegal";
      ENCODING_UNSUPPORTED: class_name = "unsupported";
      default : class_name = "unknown";
    endcase

    item = new($sformatf("random %s %0d", class_name, index));

    if(!item.randomize() with {
      classify_encoding(op_code, func3, func7) == encoding_class;
      }) begin
        $fatal(1, "Failed to randomize %s control transaction %0d", class_name, index);
      end

    transactions.push_back(item);
    random_count++;
  endfunction

  function void build_random_sequence ();
    for(int unsigned i = 0; i < random_tests; i++)
      case (i % 3)
        0: add_random(ENCODING_LEGAL, i);
        1: add_random(ENCODING_ILLEGAL, i);
        2: add_random(ENCODING_UNSUPPORTED, i);
        default : $fatal(1, "Unreachable stimulus category");
      endcase
  endfunction

  function void generate_seq();
    transactions.delete();
    directed_count = 0;
    random_count = 0;

    build_directed_sequence();
    build_random_sequence();
  endfunction

endclass : control_generator
