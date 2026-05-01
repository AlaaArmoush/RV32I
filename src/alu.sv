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
  localparam logic [3:0] ALU_ADD  = 4'b0000;
  localparam logic [3:0] ALU_SUB  = 4'b0001;
  localparam logic [3:0] ALU_AND  = 4'b0010;
  localparam logic [3:0] ALU_OR   = 4'b0011;
  localparam logic [3:0] ALU_SLL  = 4'b0100;
  localparam logic [3:0] ALU_SLT  = 4'b0101;
  localparam logic [3:0] ALU_SRL  = 4'b0110;
  localparam logic [3:0] ALU_SLTU = 4'b0111;
  localparam logic [3:0] ALU_XOR  = 4'b1000;
  localparam logic [3:0] ALU_SRA  = 4'b1001;

  always_comb begin : alu_logic
    case (alu_control)
      ALU_ADD:  alu_result = src1 + src2;
      ALU_SUB:  alu_result = src1 - src2;
      ALU_AND:  alu_result = src1 & src2;
      ALU_OR:   alu_result = src1 | src2;
      ALU_SLL:  alu_result = src1 << shamt;
      ALU_SLT:  alu_result = {31'b0, $signed(src1) < $signed(src2)};
      ALU_SRL:  alu_result = src1 >> shamt;
      ALU_SLTU: alu_result = {31'b0, src1 < src2};
      ALU_XOR:  alu_result = src1 ^ src2;
      ALU_SRA:  alu_result = src1_s >>> shamt;
      default:  alu_result = 32'b0;
    endcase

    zero = (alu_result == 32'b0);
    last_bit = alu_result[0];
  end

endmodule
