`timescale 1ns / 1ps

module load_decoder (
    input  logic [2:0]  func3,           // Load type: 000=lb, 001=lh, 010=lw, 100=lbu, 101=lhu
    input  logic [1:0]  address_offset,
    input  logic [31:0] mem_read_raw,

    output logic [31:0] load_data
);

  logic [7:0]  selected_byte;
  logic [15:0] selected_halfword;

  always_comb begin
    // Shift the wanted byte down to [7:0], then truncate into selected_byte.
    selected_byte = mem_read_raw >> (8 * address_offset);

    // Halfword loads are valid at offsets 00 and 10
    selected_halfword = 16'b0;
    if (address_offset == 2'b00) begin
      selected_halfword = mem_read_raw[15:0];
    end else if (address_offset == 2'b10) begin
      selected_halfword = mem_read_raw[31:16];
    end

    load_data = 32'b0;

    case (func3)
      3'b000:  load_data = {{24{selected_byte[7]}}, selected_byte};          // LB
      3'b001:  load_data = {{16{selected_halfword[15]}}, selected_halfword}; // LH
      3'b010:  load_data = mem_read_raw;                                     // LW
      3'b100:  load_data = {24'b0, selected_byte};                           // LBU
      3'b101:  load_data = {16'b0, selected_halfword};                       // LHU
      default: load_data = 32'b0;
    endcase
  end

endmodule
