`timescale 1ns / 1ps

module control (
    //main decoder
    input logic [6:0] op_code,
    input logic zero,
    output logic [2:0] imm_type,
    output logic mem_write,
    output logic reg_write,
    output logic alu_source,
    output logic [1:0] result_source,
    output logic pc_src,
    output logic [1:0] addr_base_src,

    //alu decoder
    input  logic [2:0] func3,
    input  logic [6:0] func7,
    output logic [2:0] alu_control
);


  logic [1:0] alu_op;
  logic branch;
  logic jump;

  always_comb begin : MAIN_DECODER
    case (op_code)
      // I-type
      7'b0000011: begin
        imm_type = 3'b000;
        mem_write = 1'b0;
        reg_write = 1'b1;
        alu_op = 2'b00;
        alu_source = 1'b1;
        result_source = 2'b01;
        branch = 1'b0;
        jump = 1'b0;
      end
      // I-type ALU
      7'b0010011: begin
        imm_type = 3'b000;
        mem_write = 1'b0;
        reg_write = 1'b1;
        alu_op = 2'b10;
        alu_source = 1'b1;
        result_source = 2'b00;
        branch = 1'b0;
        jump = 1'b0;

      end
      // S-type
      7'b0100011: begin
        imm_type = 3'b001;
        mem_write = 1'b1;
        reg_write = 1'b0;
        alu_op = 2'b00;
        alu_source = 1'b1;
        result_source = 2'b00;
        branch = 1'b0;
        jump = 1'b0;
      end
      //R-type
      7'b0110011: begin
        imm_type = 3'b000;
        mem_write = 1'b0;
        reg_write = 1'b1;
        alu_op = 2'b10;
        alu_source = 1'b0;
        result_source = 2'b00;
        branch = 1'b0;
        jump = 1'b0;
      end
      // U-type
      7'b0110111, 7'b0010111: begin
        imm_type = 3'b100;
        mem_write = 1'b0;
        reg_write = 1'b1;
        branch = 1'b0;
        result_source = 2'b11;
        jump = 1'b0;
        addr_base_src = op_code[5] ? 2'b01 : 2'b00;
      end
      // B-type
      7'b1100011: begin
        imm_type = 3'b010;
        mem_write = 1'b0;
        reg_write = 1'b0;
        alu_op = 2'b01;
        alu_source = 1'b0;
        result_source = 2'b00;
        branch = 1'b1;
        jump = 1'b0;
      end

      // J-type
      7'b1101111: begin
        imm_type = 3'b011;
        mem_write = 1'b0;
        reg_write = 1'b1;
        alu_op = 2'b00;
        alu_source = 1'b0;
        result_source = 2'b10;
        branch = 1'b0;
        jump = 1'b1;
      end

      default: begin
        imm_type = 3'b000;
        mem_write = 1'b0;
        reg_write = 1'b0;
        alu_op = 2'b11;
        alu_source = 1'b0;
        result_source = 2'b00;
        branch = 1'b0;
        jump = 1'b0;
      end
    endcase
  end



  assign pc_src = jump | (branch & zero);

  always_comb begin : ALU_DECODER
    case (alu_op)
      // LW, SW
      2'b00:   alu_control = 3'b000;
      // B-type
      2'b01:   alu_control = 3'b001;
      // R-type
      2'b10: begin
        case (func3)
          // ADD
          3'b000: alu_control = 3'b000;
          // OR
          3'b110: alu_control = 3'b011;
          // AND
          3'b111: alu_control = 3'b010;

          default: alu_control = 3'b111;
        endcase
      end
      default: alu_control = 3'b111;
    endcase
  end

endmodule
