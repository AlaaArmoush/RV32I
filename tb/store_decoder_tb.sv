`timescale 1ns / 1ps

module store_decoder_tb;
  logic [2:0]  func3;
  logic [1:0]  address_offset;
  logic [31:0] store_data_raw;
  logic [3:0]  byte_enable;
  logic [31:0] store_data;

  store_decoder dut (
      .func3(func3),
      .address_offset(address_offset),
      .store_data_raw(store_data_raw),
      .byte_enable(byte_enable),
      .store_data(store_data)
  );

  initial begin
    store_data_raw = 32'hAABBCCDD;

    // SB stores only the lowest byte: DD.
    func3 = 3'b000;

    address_offset = 2'b00; #1;
    if (byte_enable !== 4'b0001 || store_data !== 32'h000000DD)
      $fatal("SB offset 00 failed: byte_enable=%b store_data=%h", byte_enable, store_data);

    address_offset = 2'b01; #1;
    if (byte_enable !== 4'b0010 || store_data !== 32'h0000DD00)
      $fatal("SB offset 01 failed: byte_enable=%b store_data=%h", byte_enable, store_data);

    address_offset = 2'b10; #1;
    if (byte_enable !== 4'b0100 || store_data !== 32'h00DD0000)
      $fatal("SB offset 10 failed: byte_enable=%b store_data=%h", byte_enable, store_data);

    address_offset = 2'b11; #1;
    if (byte_enable !== 4'b1000 || store_data !== 32'hDD000000)
      $fatal("SB offset 11 failed: byte_enable=%b store_data=%h", byte_enable, store_data);

    // SH stores only the lowest halfword: CCDD.
    func3 = 3'b001;

    address_offset = 2'b00; #1;
    if (byte_enable !== 4'b0011 || store_data !== 32'h0000CCDD)
      $fatal("SH offset 00 failed: byte_enable=%b store_data=%h", byte_enable, store_data);

    address_offset = 2'b10; #1;
    if (byte_enable !== 4'b1100 || store_data !== 32'hCCDD0000)
      $fatal("SH offset 10 failed: byte_enable=%b store_data=%h", byte_enable, store_data);

    // Misaligned SH should write nothing.
    address_offset = 2'b01; #1;
    if (byte_enable !== 4'b0000 || store_data !== 32'h00000000)
      $fatal("SH offset 01 should be ignored: byte_enable=%b store_data=%h", byte_enable, store_data);

    // SW stores the full word, but only on word-aligned offset 00.
    func3 = 3'b010;

    address_offset = 2'b00; #1;
    if (byte_enable !== 4'b1111 || store_data !== 32'hAABBCCDD)
      $fatal("SW offset 00 failed: byte_enable=%b store_data=%h", byte_enable, store_data);

    address_offset = 2'b10; #1;
    if (byte_enable !== 4'b0000 || store_data !== 32'h00000000)
      $fatal("SW misaligned should be ignored: byte_enable=%b store_data=%h", byte_enable, store_data);

    $display("All store_decoder tests passed!");
    $finish;
  end
endmodule
