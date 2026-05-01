`timescale 1ns / 1ps

module load_decoder_tb;
  logic [2:0]  func3;
  logic [1:0]  address_offset;
  logic [31:0] mem_read_raw;
  logic [31:0] load_data;

  load_decoder dut (
      .func3(func3),
      .address_offset(address_offset),
      .mem_read_raw(mem_read_raw),
      .load_data(load_data)
  );

  initial begin
    mem_read_raw = 32'hAEAE5678;

    // LB sign-extends the selected byte.
    func3 = 3'b000;

    address_offset = 2'b00; #1;
    if (load_data !== 32'h00000078) $fatal("LB offset 00 failed: got %h", load_data);

    address_offset = 2'b10; #1;
    if (load_data !== 32'hFFFFFFAE) $fatal("LB offset 10 failed: got %h", load_data);

    // LH sign-extends the selected halfword.
    func3 = 3'b001;

    address_offset = 2'b00; #1;
    if (load_data !== 32'h00005678) $fatal("LH offset 00 failed: got %h", load_data);

    address_offset = 2'b10; #1;
    if (load_data !== 32'hFFFFAEAE) $fatal("LH offset 10 failed: got %h", load_data);

    // LW returns the full word unchanged.
    func3 = 3'b010;

    address_offset = 2'b00; #1;
    if (load_data !== 32'hAEAE5678) $fatal("LW failed: got %h", load_data);

    // LBU zero-extends the selected byte.
    func3 = 3'b100;

    address_offset = 2'b10; #1;
    if (load_data !== 32'h000000AE) $fatal("LBU offset 10 failed: got %h", load_data);

    // LHU zero-extends the selected halfword.
    func3 = 3'b101;

    address_offset = 2'b10; #1;
    if (load_data !== 32'h0000AEAE) $fatal("LHU offset 10 failed: got %h", load_data);

    // Misaligned halfword loads return zero in this simple core.
    address_offset = 2'b01; #1;
    if (load_data !== 32'h00000000) $fatal("LHU misaligned failed: got %h", load_data);

    $display("All load_decoder tests passed!");
    $finish;
  end
endmodule
