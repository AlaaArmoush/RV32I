`timescale 1ns / 1ps

interface regfile_if(input logic clk);
  logic rst_n;
  logic [4:0] address1;
  logic [4:0] address2;
  logic [4:0] address3;
  logic write_enable;
  logic [31:0] write_data;
  logic [31:0] read_data1;
  logic [31:0] read_data2;

  modport dut (
    input  clk,
    input  rst_n,
    input  address1,
    input  address2,
    input  address3,
    input  write_enable,
    input  write_data,
    output read_data1,
    output read_data2
  );

  modport driver (
    input clk,
    output rst_n,
    output address1,
    output address2,
    output address3,
    output write_enable,
    output write_data
  );

  modport monitor (
    input clk,
    input rst_n,
    input address1,
    input address2,
    input address3,
    input write_enable,
    input write_data,
    input read_data1,
    input read_data2
  );
  
endinterface
