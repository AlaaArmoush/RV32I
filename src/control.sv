module control (
    //main decoder
    input logic [6:0] op_code,
    input logic zero,
    output logic [2:0] imm_type,
    output logic mem_write,
    output logic reg_write,
    //alu decoder 
    input logic [2:0] func3,
    input logic [6:0] func7,
    output logic [2:0] alu_control
);


  logic [1:0] alu_op;

  always_comb begin : MAIN_DECODER
    case (op_code)
      // LW (I-type)
      7'b0000011: begin
        imm_type = 3'b000;
        mem_write = 1'b0;
        reg_write = 1'b1;
        alu_op = 2'b00;
      end

      default: begin
        imm_type = 3'b000;
        mem_write = 1'b0;
        reg_write = 1'b0;
        alu_op = 2'b11;
      end
    endcase
  end


  always_comb begin : ALU_DECODER
    case (alu_op)
      // LW 
      2'b00:   alu_control = 3'b000;
      default: alu_control = 3'b111;
    endcase
  end

endmodule
