module signextnd (
    // first 7 are opcode
    input logic [31:7] raw_src,
    // RISC-V have 5 immediate variants
    input logic [ 2:0] imm_type,

    output logic [31:0] imm_produced
);

  always_comb begin
    case (imm_type)
      // I-type
      3'b000: imm_produced = {{20{raw_src[31]}}, raw_src[31:20]};
      // S-type
      3'b001: imm_produced = {{20{raw_src[31]}}, raw_src[31:25], raw_src[11:7]};
      // B-type
      3'b010:
      imm_produced = {
        {19{raw_src[31]}}, raw_src[31], raw_src[7], raw_src[30:25], raw_src[11:8], 1'b0
      };
      // J-type
      3'b011: imm_produced = {{11{raw_src[31]}}, raw_src[31], raw_src[19:12], raw_src[20], raw_src[30:21], 1'b0};
      // U-type
      3'b100: imm_produced = {raw_src[31:12], 12'b0};

      default: imm_produced = 32'b0;
    endcase
  end

endmodule





