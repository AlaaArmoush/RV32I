`timescale 1ns / 1ps

module alu (
    input logic [31:0] src1,
    input logic [31:0] src2,
    input logic [ 3:0] alu_control,

    output logic [31:0] alu_result,
    output logic zero,
    output logic last_bit
);
  always_comb begin : alu_logic
    case (alu_control)
      // ADD
      3'b000: alu_result = src1 + src2;
      // SUB
      3'b001: alu_result = src1 - src2;
      // AND
      3'b010: alu_result = src1 & src2;
      // OR
      3'b011: alu_result = src1 | src2;

      default: alu_result = 32'b0;
    endcase
    zero = (alu_result == 32'b0);
    last_bit = 1'b0;
  end

endmodule
