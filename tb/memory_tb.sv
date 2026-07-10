`timescale 1ns / 1ps

interface memory_if #(parameter int ADDR_WIDTH = 32) (
  input logic clk
);
  logic [ADDR_WIDTH-1:0] address;
  logic [31:0] write_data;
  logic write_enable;
  logic rst_n;
  logic [3:0] byte_enable;
  logic [31:0] read_data;

  modport driver (
      input  clk,
      input  read_data,
      output rst_n,
      output address,
      output write_data,
      output write_enable,
      output byte_enable
  );

  modport monitor (
      input clk,
      input rst_n,
      input address,
      input write_data,
      input write_enable,
      input byte_enable,
      input read_data
  );
endinterface

module memory_tb;
  localparam int WORDS = 64;
  localparam int CLK_PERIOD_NS = 10;
  logic clk = 1'b0;
  
  always #(CLK_PERIOD_NS / 2) clk = ~clk;

  memory_if mem_vif(.clk(clk));

  memory #(
      .WORDS(WORDS),
      .test_mem(""),
      .load_file_arg("")
  ) dut (
      .clk(mem_vif.clk),
      .address(mem_vif.address),
      .write_data(mem_vif.write_data),
      .write_enable(mem_vif.write_enable),
      .rst_n(mem_vif.rst_n),
      .byte_enable(mem_vif.byte_enable),
      .read_data(mem_vif.read_data)
  );

  task automatic init_bus();
    mem_vif.rst_n = 1'b1;
    mem_vif.address = '0;
    mem_vif.write_data = '0;
    mem_vif.write_enable = 1'b0;
    mem_vif.byte_enable = 4'b0000;
  endtask

  task automatic reset_dut();
    mem_vif.rst_n = 1'b0;
    repeat (2) @(posedge clk);
    mem_vif.rst_n = 1'b1;
    @(posedge clk);
  endtask

  initial begin
    $display("[MEM_TB] Starting memory DV refactor skeleton");

    init_bus();
    reset_dut();

    $display("[MEM_TB] Step 1 skeleton complete");
    $finish;
  end
endmodule
