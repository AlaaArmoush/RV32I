`timescale 1ns / 1ps

module control (
    input  logic [6:0] op_code,          // Instruction opcode, selects the main instruction type
    input  logic       zero,             // ALU result is zero, used by BEQ/BNE
    input  logic       last_bit,         // ALU result bit 0, used by SLT/SLTU based branches
    output logic [2:0] imm_type,         // Immediate format: I, S, B, J, or U
    output logic       mem_write,        // Enables data-memory write for store instructions
    output logic       reg_write,        // Enables register-file write-back
    output logic       reg_write_gated,  // Register write enable after illegal-op blocking
    output logic       alu_source,       // ALU src2 select: 0=register, 1=immediate
    output logic [1:0] result_source,    // Write-back select: ALU, memory, PC+4, or target
    output logic       pc_src,           // Next-PC select: 0=PC+4, 1=branch/jump target
    output logic [1:0] addr_base_src,    // Target-base select: PC, immediate, or rs1

    input  logic [2:0] func3,            // funct3 field, selects instruction variant
    input  logic [6:0] func7,            // funct7 field, separates ops like ADD/SUB and SRL/SRA
    output logic [3:0] alu_control       // ALU operation select
);

  // imm_type:      000=I, 001=S, 010=B, 011=J, 100=U
  // result_source: 00=ALU result, 01=memory read, 10=PC+4, 11=pc_target
  // addr_base_src: 00=PC+imm, 01=imm only for LUI, 10=rs1+imm for JALR
  // alu_op:        00=ADD, 01=branch compare, 10=decode func3/func7, 11=invalid
  logic [1:0] alu_op;
  logic       branch;      // Current instruction is a conditional branch
  logic       jump;        // Current instruction is an unconditional jump
  logic       illegal_op;  // Blocks register writes for invalid ALU encodings

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
        alu_op        = 2'b00;
        alu_source    = 1'b1;
        result_source = 2'b01;

        case (func3)
          3'b000, 3'b001, 3'b010, 3'b100, 3'b101: reg_write = 1'b1;
          default: reg_write = 1'b0;
        endcase
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
        imm_type   = 3'b001;
        alu_op     = 2'b00;
        alu_source = 1'b1;

        case (func3)
          3'b000, 3'b001, 3'b010: mem_write = 1'b1;
          default: mem_write = 1'b0;
        endcase
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
      // JALR, I-type jump
      7'b1100111: begin
        imm_type = 3'b000;
        alu_op   = 2'b00;

        if (func3 == 3'b000) begin
          reg_write     = 1'b1;
          result_source = 2'b10;
          jump          = 1'b1;
          addr_base_src = 2'b10;
        end
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
