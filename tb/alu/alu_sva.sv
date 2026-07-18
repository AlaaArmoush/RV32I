`ifndef ALU_SVA_SV
`define ALU_SVA_SV

import alu_pkg::*;

module alu_sva (
    input logic [31:0] src1,
    input logic [31:0] src2,
    input logic [4:0]  shamt,
    input alu_op_t     alu_control,
    input logic [31:0] alu_result,
    input logic        zero,
    input logic        last_bit
);

  logic signed [31:0] src1_s;
  assign src1_s = src1;

  wire [31:0] exp_sra;
  assign exp_sra = src1_s >>> shamt;

  always_comb begin : a_zero_flag
    assert (zero === (alu_result == 32'b0))
    else $error("[alu_sva] A1 FAIL: zero=%b but alu_result=0x%08h", zero, alu_result);
  end

  always_comb begin : a_last_bit_flag
    assert (last_bit === alu_result[0])
    else $error("[alu_sva] A2 FAIL: last_bit=%b but alu_result[0]=%b (result=0x%08h)",
                last_bit, alu_result[0], alu_result);
  end

  always_comb begin : a_invalid_zero
    if (alu_control == ALU_INVALID)
      assert (alu_result == 32'b0)
      else $error("[alu_sva] A3 FAIL: invalid op (0x%0h) produced non-zero result 0x%08h",
                  alu_control, alu_result);
  end

  always_comb begin : a_sll_uses_shamt
    if (alu_control == ALU_SLL)
      assert (alu_result == (src1 << shamt))
      else $error("[alu_sva] A4 FAIL: SLL result=0x%08h, expected src1<<shamt=0x%08h (src1=0x%08h shamt=%0d)",
                  alu_result, src1 << shamt, src1, shamt);
  end

  always_comb begin : a_srl_uses_shamt
    if (alu_control == ALU_SRL)
      assert (alu_result == (src1 >> shamt))
      else $error("[alu_sva] A4 FAIL: SRL result=0x%08h, expected src1>>shamt=0x%08h (src1=0x%08h shamt=%0d)",
                  alu_result, src1 >> shamt, src1, shamt);
  end

  always_comb begin : a_sra_uses_shamt
    if (alu_control == ALU_SRA)
      assert (alu_result == exp_sra)
      else $error("[alu_sva] A4 FAIL: SRA result=0x%08h, expected src1>>>shamt=0x%08h (src1=0x%08h shamt=%0d)",
                  alu_result, exp_sra, src1, shamt);
  end

endmodule

`endif
