`timescale 1ns / 1ps

module control (
    input  logic [6:0] op_code,
    input  logic       zero,
    input  logic       last_bit,
    output logic [2:0] imm_type,
    output logic       mem_write,
    output logic       reg_write,
    output logic       reg_write_gated,
    output logic       alu_source,
    output logic [1:0] result_source,
    output logic       pc_src,
    output logic [1:0] addr_base_src,

    input  logic [2:0] func3,
    input  logic [6:0] func7,
    output logic [3:0] alu_control
);

  logic [1:0] alu_op;
  logic       branch;
  logic       jump;
  logic       illegal_op;

  always_comb begin : MAIN_DECODER
    imm_type      = 3'b000;
    mem_write     = 1'b0;
    reg_write     = 1'b0;
    alu_op        = 2'b00;
    alu_source    = 1'b0;
    result_source = 2'b00;
    branch        = 1'b0;
    jump          = 1'b0;
    addr_base_src = 2'b00;

    case (op_code)
      // I-type LOAD
      7'b0000011: begin
        imm_type      = 3'b000;
        mem_write     = 1'b0;
        reg_write     = 1'b1;
        alu_op        = 2'b00;
        alu_source    = 1'b1;
        result_source = 2'b01;
        branch        = 1'b0;
        jump          = 1'b0;
      end
      // I-type ALU
      7'b0010011: begin
        imm_type      = 3'b000;
        mem_write     = 1'b0;
        reg_write     = 1'b1;
        alu_op        = 2'b10;
        alu_source    = 1'b1;
        result_source = 2'b00;
        branch        = 1'b0;
        jump          = 1'b0;
      end
      // S-type
      7'b0100011: begin
        imm_type      = 3'b001;
        mem_write     = 1'b1;
        reg_write     = 1'b0;
        alu_op        = 2'b00;
        alu_source    = 1'b1;
        result_source = 2'b00;
        branch        = 1'b0;
        jump          = 1'b0;
      end
      // R-type
      7'b0110011: begin
        imm_type      = 3'b000;
        mem_write     = 1'b0;
        reg_write     = 1'b1;
        alu_op        = 2'b10;
        alu_source    = 1'b0;
        result_source = 2'b00;
        branch        = 1'b0;
        jump          = 1'b0;
      end
      // U-type
      7'b0110111, 7'b0010111: begin
        imm_type      = 3'b100;
        mem_write     = 1'b0;
        reg_write     = 1'b1;
        branch        = 1'b0;
        result_source = 2'b11;
        jump          = 1'b0;
        addr_base_src = op_code[5] ? 2'b01 : 2'b00;
      end
      // B-type
      7'b1100011: begin
        imm_type      = 3'b010;
        mem_write     = 1'b0;
        reg_write     = 1'b0;
        alu_op        = 2'b01;
        alu_source    = 1'b0;
        result_source = 2'b00;
        branch        = 1'b1;
        jump          = 1'b0;
      end
      // J-type
      7'b1101111: begin
        imm_type      = 3'b011;
        mem_write     = 1'b0;
        reg_write     = 1'b1;
        alu_op        = 2'b00;
        alu_source    = 1'b0;
        result_source = 2'b10;
        branch        = 1'b0;
        jump          = 1'b1;
      end
      default: begin
        imm_type      = 3'b000;
        mem_write     = 1'b0;
        reg_write     = 1'b0;
        alu_op        = 2'b11;
        alu_source    = 1'b0;
        result_source = 2'b00;
        branch        = 1'b0;
        jump          = 1'b0;
      end
    endcase
  end

  logic assert_branch;
  always_comb begin : BRANCH_LOGIC_DECODER
    case (func3)
      3'b000:  assert_branch = zero & branch;  // BEQ
      3'b001:  assert_branch = ~zero & branch;  // BNE
      3'b100:  assert_branch = last_bit & branch;  // BLT
      3'b101:  assert_branch = ~last_bit & branch;  // BGE
      3'b110:  assert_branch = last_bit & branch;  // BLTU
      3'b111:  assert_branch = ~last_bit & branch;  // BGEU
      default: assert_branch = 1'b0;
    endcase

  end
  assign pc_src = assert_branch | jump;

  assign reg_write_gated = reg_write & ~illegal_op;

  always_comb begin : ALU_DECODER
    illegal_op  = 1'b0;
    alu_control = 4'b1111;

    case (alu_op)
      // LW, SW
      2'b00:   alu_control = 4'b0000;
      // B-type
      2'b01: begin
        case (func3)
          3'b000:  alu_control = 4'b0001;  // BEQ  → SUB
          3'b001:  alu_control = 4'b0001;  // BNE  → SUB
          3'b100:  alu_control = 4'b0101;  // BLT  → SLT
          3'b101:  alu_control = 4'b0101;  // BGE  → SLT
          3'b110:  alu_control = 4'b0111;  // BLTU → SLTU
          3'b111:  alu_control = 4'b0111;  // BGEU → SLTU
          default: alu_control = 4'b1111;
        endcase
      end
      // R-type & I-type ALU
      2'b10: begin
        case (func3)
          3'b000: begin  // ADD/ADDI or SUB
            if (op_code == 7'b0110011) alu_control = (func7 == 7'b0100000) ? 4'b0001 : 4'b0000;
            else alu_control = 4'b0000;
          end
          3'b001: begin  // SLL / SLLI
            if (func7 == 7'b0000000) alu_control = 4'b0100;
            else begin
              alu_control = 4'b1111;
              illegal_op  = 1'b1;
            end
          end
          3'b010:  alu_control = 4'b0101;  // SLT / SLTI
          3'b011:  alu_control = 4'b0111;  // SLTU / SLTIU
          3'b100:  alu_control = 4'b1000;  // XOR / XORI
          3'b101: begin  // SRL/SRLI or SRA/SRAI
            if (func7 == 7'b0000000) alu_control = 4'b0110;
            else if (func7 == 7'b0100000) alu_control = 4'b1001;
            else begin
              alu_control = 4'b1111;
              illegal_op  = 1'b1;
            end
          end
          3'b110:  alu_control = 4'b0011;  // OR / ORI
          3'b111:  alu_control = 4'b0010;  // AND / ANDI
          default: alu_control = 4'b1111;
        endcase
      end
      default: alu_control = 4'b1111;
    endcase
  end

endmodule

