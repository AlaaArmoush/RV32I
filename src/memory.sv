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
    input logic [3:0] byte_enable, // 4 cause 32/8 = 4

    output logic [31:0] read_data
);
  //byte addressed
  logic [31:0] mem [0:WORDS-1];

  initial begin
    if (test_mem != "") begin
      $readmemh(test_mem, mem);
    end
  end


  always_ff @(posedge clk) begin
    if (rst_n == 1'b0) begin
      for (int i = 0; i < WORDS; i++) begin
        mem[i] <= 32'b0;
      end
    end else if (write_enable) begin
      /* verilator lint_off WIDTHTRUNC */
      for(int i = 0; i < 4; i++) begin
        if(byte_enable[i]) begin
          mem[address[31:2]][8*i +: 8] <= write_data[8*i +: 8];
        end
      end
      /* verilator lint_on WIDTHTRUNC */
    end
  end


  always_comb begin
    /* verilator lint_off WIDTHTRUNC */
    read_data = mem[address[31:2]];
    /* verilator lint_on WIDTHTRUNC */
  end
endmodule

