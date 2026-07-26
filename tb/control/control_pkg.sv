package control_pkg;
  typedef enum logic [6:0] {
    OP_LOAD   = 7'b0000011,
    OP_IALU   = 7'b0010011,
    OP_STORE  = 7'b0100011,
    OP_RALU   = 7'b0110011,
    OP_LUI    = 7'b0110111,
    OP_BRANCH = 7'b1100011,
    OP_JALR   = 7'b1100111,
    OP_JAL    = 7'b1101111,
    OP_AUIPC  = 7'b0010111
  } opcode_e;

  typedef struct packed {
    logic [2:0] imm_type;
    logic mem_write;
    logic reg_write;
    logic reg_write_gated;
    logic alu_source;
    logic [1:0] result_source;
    logic pc_src;
    logic [1:0] addr_base_src;
    logic [3:0] alu_control;
  } control_expected_t;

  // ALU control codes
  localparam logic [3:0] ALU_ADD = 4'b0000;
  localparam logic [3:0] ALU_SUB = 4'b0001;
  localparam logic [3:0] ALU_AND = 4'b0010;
  localparam logic [3:0] ALU_OR = 4'b0011;
  localparam logic [3:0] ALU_SLL = 4'b0100;
  localparam logic [3:0] ALU_SLT = 4'b0101;
  localparam logic [3:0] ALU_SRL = 4'b0110;
  localparam logic [3:0] ALU_SLTU = 4'b0111;
  localparam logic [3:0] ALU_XOR = 4'b1000;
  localparam logic [3:0] ALU_SRA = 4'b1001;
  localparam logic [3:0] ALU_INV = 4'b1111;

  // imm_type encoding
  localparam logic [2:0] IMM_I = 3'b000;
  localparam logic [2:0] IMM_S = 3'b001;
  localparam logic [2:0] IMM_B = 3'b010;
  localparam logic [2:0] IMM_J = 3'b011;
  localparam logic [2:0] IMM_U = 3'b100;

  typedef enum logic [1:0] {
    ENCODING_LEGAL,
    ENCODING_ILLEGAL,
    ENCODING_UNSUPPORTED
  } encoding_class_e;

  function automatic bit is_supported_opcode(input logic [6:0] op_code);
    return op_code inside {
      OP_LOAD,
      OP_IALU,
      OP_STORE,
      OP_RALU,
      OP_LUI,
      OP_BRANCH,
      OP_JALR,
      OP_JAL,
      OP_AUIPC
    };
  endfunction

  function automatic bit is_legal_encoding(input logic [6:0] op_code, input logic [2:0] func3,
                                           input logic [6:0] func7);
    case (op_code)
      OP_LOAD: return func3 inside {3'b000, 3'b001, 3'b010, 3'b100, 3'b101};

      OP_STORE: return func3 inside {3'b000, 3'b001, 3'b010};

      OP_BRANCH: return func3 inside {3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111};

      OP_JALR: return func3 == 3'b000;

      OP_RALU: begin
        case (func3)
          3'b000, 3'b101: return func7 inside {7'b0000000, 7'b0100000};

          default: return func7 == 7'b0000000;
        endcase
      end

      OP_IALU: begin
        case (func3)
          3'b001: return func7 == 7'b0000000;

          3'b101: return func7 inside {7'b0000000, 7'b0100000};

          default: return 1'b1;
        endcase
      end

      OP_LUI, OP_AUIPC, OP_JAL: return 1'b1;

      default: return 1'b0;
    endcase
  endfunction

  function automatic encoding_class_e classify_encoding(
      input logic [6:0] op_code, input logic [2:0] func3, input logic [6:0] func7);
    if (!is_supported_opcode(op_code)) return ENCODING_UNSUPPORTED;

    if (!is_legal_encoding(op_code, func3, func7)) return ENCODING_ILLEGAL;

    return ENCODING_LEGAL;
  endfunction

  // golden module
  function automatic control_expected_t golden_decode(
      input logic [6:0] op_code, input logic [2:0] func3, input logic [6:0] func7, input logic zero,
      input logic last_bit);

    control_expected_t exp;
    logic [1:0] alu_op;
    logic branch, jump, illegal_op, assert_branch;

    //defaults
    exp.imm_type      = IMM_I;
    exp.mem_write     = 1'b0;
    exp.reg_write     = 1'b0;
    exp.alu_source    = 1'b0;
    exp.result_source = 2'b00;
    exp.addr_base_src = 2'b00;
    exp.pc_src        = 1'b0;
    exp.alu_control   = ALU_INV;
    alu_op            = 2'b00;
    branch            = 1'b0;
    jump              = 1'b0;
    illegal_op        = 1'b0;

    //main decoder
    case (op_code)
      OP_LOAD: begin
        exp.imm_type      = IMM_I;
        alu_op            = 2'b00;
        exp.alu_source    = 1'b1;
        exp.result_source = 2'b01;
        case (func3)
          3'b000, 3'b001, 3'b010, 3'b100, 3'b101: exp.reg_write = 1'b1;
          default:                                exp.reg_write = 1'b0;
        endcase
      end

      OP_IALU: begin
        exp.imm_type      = IMM_I;
        exp.mem_write     = 1'b0;
        exp.reg_write     = 1'b1;
        alu_op            = 2'b10;
        exp.alu_source    = 1'b1;
        exp.result_source = 2'b00;
        branch            = 1'b0;
        jump              = 1'b0;
      end

      OP_STORE: begin
        exp.imm_type   = IMM_S;
        alu_op         = 2'b00;
        exp.alu_source = 1'b1;
        case (func3)
          3'b000, 3'b001, 3'b010: exp.mem_write = 1'b1;
          default:                exp.mem_write = 1'b0;
        endcase
      end

      OP_RALU: begin
        exp.imm_type      = IMM_I;
        exp.mem_write     = 1'b0;
        exp.reg_write     = 1'b1;
        alu_op            = 2'b10;
        exp.alu_source    = 1'b0;
        exp.result_source = 2'b00;
        branch            = 1'b0;
        jump              = 1'b0;
      end

      OP_LUI, OP_AUIPC: begin
        exp.imm_type      = IMM_U;
        exp.mem_write     = 1'b0;
        exp.reg_write     = 1'b1;
        branch            = 1'b0;
        exp.result_source = 2'b11;
        jump              = 1'b0;
        exp.addr_base_src = op_code[5] ? 2'b01 : 2'b00;
      end

      OP_BRANCH: begin
        exp.imm_type      = IMM_B;
        exp.mem_write     = 1'b0;
        exp.reg_write     = 1'b0;
        alu_op            = 2'b01;
        exp.alu_source    = 1'b0;
        exp.result_source = 2'b00;
        branch            = 1'b1;
        jump              = 1'b0;
      end

      OP_JAL: begin
        exp.imm_type      = IMM_J;
        exp.mem_write     = 1'b0;
        exp.reg_write     = 1'b1;
        alu_op            = 2'b00;
        exp.alu_source    = 1'b0;
        exp.result_source = 2'b10;
        branch            = 1'b0;
        jump              = 1'b1;
      end

      OP_JALR: begin
        exp.imm_type = IMM_I;
        alu_op       = 2'b00;
        if (func3 == 3'b000) begin
          exp.reg_write     = 1'b1;
          exp.result_source = 2'b10;
          jump              = 1'b1;
          exp.addr_base_src = 2'b10;
        end
      end

      default: begin
        exp.imm_type      = IMM_I;
        exp.mem_write     = 1'b0;
        exp.reg_write     = 1'b0;
        alu_op            = 2'b11;
        exp.alu_source    = 1'b0;
        exp.result_source = 2'b00;
        branch            = 1'b0;
        jump              = 1'b0;
      end
    endcase

    // Branch decision
    case (func3)
      3'b000:  assert_branch = zero & branch;
      3'b001:  assert_branch = ~zero & branch;
      3'b100:  assert_branch = last_bit & branch;
      3'b101:  assert_branch = ~last_bit & branch;
      3'b110:  assert_branch = last_bit & branch;
      3'b111:  assert_branch = ~last_bit & branch;
      default: assert_branch = 1'b0;
    endcase
    exp.pc_src = assert_branch | jump;

    //ALU decoder
    case (alu_op)
      2'b00: exp.alu_control = ALU_ADD;

      2'b01: begin
        case (func3)
          3'b000, 3'b001: exp.alu_control = ALU_SUB;
          3'b100, 3'b101: exp.alu_control = ALU_SLT;
          3'b110, 3'b111: exp.alu_control = ALU_SLTU;
          default:        exp.alu_control = ALU_INV;
        endcase
      end

      2'b10: begin
        case (func3)
          3'b000: begin
            if (op_code == OP_RALU) begin
              if (func7 == 7'b0000000) exp.alu_control = ALU_ADD;
              else if (func7 == 7'b0100000) exp.alu_control = ALU_SUB;
              else illegal_op = 1'b1;
            end else begin
              exp.alu_control = ALU_ADD;
            end
          end
          3'b001: begin
            if (func7 == 7'b0000000) exp.alu_control = ALU_SLL;
            else illegal_op = 1'b1;
          end
          3'b010: begin
            if (op_code == OP_RALU && func7 != 7'b0000000) illegal_op = 1'b1;
            else exp.alu_control = ALU_SLT;
          end
          3'b011: begin
            if (op_code == OP_RALU && func7 != 7'b0000000) illegal_op = 1'b1;
            else exp.alu_control = ALU_SLTU;
          end
          3'b100: begin
            if (op_code == OP_RALU && func7 != 7'b0000000) illegal_op = 1'b1;
            else exp.alu_control = ALU_XOR;
          end
          3'b101: begin
            if (func7 == 7'b0000000) exp.alu_control = ALU_SRL;
            else if (func7 == 7'b0100000) exp.alu_control = ALU_SRA;
            else illegal_op = 1'b1;
          end
          3'b110: begin
            if (op_code == OP_RALU && func7 != 7'b0000000) illegal_op = 1'b1;
            else exp.alu_control = ALU_OR;
          end
          3'b111: begin
            if (op_code == OP_RALU && func7 != 7'b0000000) illegal_op = 1'b1;
            else exp.alu_control = ALU_AND;
          end
          default: exp.alu_control = ALU_INV;
        endcase
      end

      default: exp.alu_control = ALU_INV;
    endcase
    exp.reg_write_gated = exp.reg_write & ~illegal_op;

    return exp;
  endfunction
endpackage
