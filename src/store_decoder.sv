`timescale 1ns / 1ps

module store_decoder (
    input  logic [2:0]  func3,           // Store type: 000=sb, 001=sh, 010=sw
    input  logic [1:0]  address_offset, 
    input  logic [31:0] store_data_raw, 

    output logic [3:0]  byte_enable, 
    output logic [31:0] store_data
);

  always_comb begin
    // Default: unsupported or misaligned stores write nothing.
    byte_enable = 4'b0000;
    store_data  = 32'b0;

    case (func3)
      // SB
      3'b000: begin
        byte_enable = 4'b0001 << address_offset;
        store_data  = {24'b0, store_data_raw[7:0]} << (8 * address_offset);
      end

      // SH
      3'b001: begin
        if (address_offset[0] == 1'b0) begin
          byte_enable = 4'b0011 << address_offset;
          store_data  = {16'b0, store_data_raw[15:0]} << (8 * address_offset);
        end
      end

      // SW
      3'b010: begin
        if (address_offset == 2'b00) begin
          byte_enable = 4'b1111;
          store_data  = store_data_raw;
        end
      end

      default: begin
        byte_enable = 4'b0000;
        store_data  = 32'b0;
      end
    endcase
  end

endmodule
