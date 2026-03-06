`timescale 1ns / 1ps

module alu (
    input logic [31:0] src1,
    input logic [31:0] src2,
    input logic [ 3:0] alu_control,
    input logic [ 4:0] shamt,

    output logic [31:0] alu_result,
    output logic zero,
    output logic last_bit
);

  wire signed [31:0] src1_s = src1;
  always_comb begin : alu_logic
    case (alu_control)
      // ADD
      4'b0000: alu_result = src1 + src2;
      // SUB
      4'b0001: alu_result = src1 - src2;
      // AND
      4'b0010: alu_result = src1 & src2;
      // OR
      4'b0011: alu_result = src1 | src2;
      // SLLI
      4'b0100: alu_result = src1 << shamt;
      // STLI
      4'b0101: alu_result = {31'b0, $signed(src1) < $signed(src2)};
      // SRLI
      4'b0110: alu_result = src1 >> shamt;
      // STLIU
      4'b0111: alu_result = {31'b0, src1 < src2};
      // XOR
      4'b1000: alu_result = src1 ^ src2;
      // SRAI
      4'b1001: alu_result = src1_s >>> shamt;

      default: alu_result = 32'b0;
    endcase
    zero = (alu_result == 32'b0);
    last_bit = alu_result[0];
  end

endmodule
