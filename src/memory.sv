`timescale 1ns / 1ps

module memory #(
    parameter WORDS = 64,
    parameter test_mem = ""
) (
    input logic clk,
    input logic [31:0] address,
    input logic [31:0] write_data,
    input logic write_enable,
    input logic rst_n,

    output logic [31:0] read_data
);
  //byte addressed
  reg [31:0] mem[WORDS];

  initial begin
    $readmemh(test_mem, mem);
  end

  always_ff @(posedge clk) begin
    if (rst_n == 1'b0) begin
      for (int i = 0; i < WORDS; i++) begin
        mem[i] <= 32'b0;
      end
    end else if (write_enable) begin
      //ensure.multiple of 4 bytes (WORD alligned)
      if (address[1:0] == 2'b00) begin
        /* verilator lint_off WIDTHTRUNC */
        mem[address[31:2]] <= write_data;
        /* verilator lint_off WIDTHTRUNC */
      end
    end
  end


  always_comb begin
    /* verilator lint_off WIDTHTRUNC */
    read_data = mem[address[31:2]];
    /* verilator lint_on WIDTHTRUNC */
  end
endmodule

