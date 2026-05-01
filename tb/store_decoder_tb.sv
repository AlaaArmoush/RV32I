`timescale 1ns / 1ps

module store_decoder_tb;
  logic [2:0]  func3;
  logic [1:0]  address_offset;
  logic [31:0] store_data_raw;
  logic [3:0]  byte_enable;
  logic [31:0] store_data;

  int error_count = 0;
  int total_checks = 0;
  int passed_checks = 0;
  int valid_cases = 0;
  int ignored_cases = 0;
  int func3_hits[8];
  int offset_hits[4];

  store_decoder dut (
      .func3(func3),
      .address_offset(address_offset),
      .store_data_raw(store_data_raw),
      .byte_enable(byte_enable),
      .store_data(store_data)
  );

  function automatic logic [3:0] expected_byte_enable(
      input logic [2:0] func3_in,
      input logic [1:0] offset_in
  );
    case (func3_in)
      3'b000: expected_byte_enable = 4'b0001 << offset_in;
      3'b001: expected_byte_enable = (offset_in[0] == 1'b0) ? (4'b0011 << offset_in) : 4'b0000;
      3'b010: expected_byte_enable = (offset_in == 2'b00) ? 4'b1111 : 4'b0000;
      default: expected_byte_enable = 4'b0000;
    endcase
  endfunction

  function automatic logic [31:0] expected_store_data(
      input logic [2:0]  func3_in,
      input logic [1:0]  offset_in,
      input logic [31:0] raw_in
  );
    case (func3_in)
      3'b000: expected_store_data = {24'b0, raw_in[7:0]} << (8 * offset_in);
      3'b001: begin
        if (offset_in[0] == 1'b0) expected_store_data = {16'b0, raw_in[15:0]} << (8 * offset_in);
        else expected_store_data = 32'b0;
      end
      3'b010: expected_store_data = (offset_in == 2'b00) ? raw_in : 32'b0;
      default: expected_store_data = 32'b0;
    endcase
  endfunction

  function automatic string store_name(input logic [2:0] func3_in);
    case (func3_in)
      3'b000: store_name = "SB";
      3'b001: store_name = "SH";
      3'b010: store_name = "SW";
      default: store_name = "UNSUPPORTED";
    endcase
  endfunction

  task automatic check_eq4(input string label, input logic [3:0] got, input logic [3:0] expected);
    total_checks++;
    if (got !== expected) begin
      $error("%s failed: expected %04b, got %04b", label, expected, got);
      error_count++;
    end else begin
      passed_checks++;
    end
  endtask

  task automatic check_eq32(input string label, input logic [31:0] got, input logic [31:0] expected);
    total_checks++;
    if (got !== expected) begin
      $error("%s failed: expected 0x%08h, got 0x%08h", label, expected, got);
      error_count++;
    end else begin
      passed_checks++;
    end
  endtask

  task automatic run_case(
      input logic [2:0]  func3_in,
      input logic [1:0]  offset_in,
      input logic [31:0] raw_in
  );
    logic [3:0] expected_be;
    logic [31:0] expected_data;
    string label;

    func3 = func3_in;
    address_offset = offset_in;
    store_data_raw = raw_in;
    #1;

    expected_be = expected_byte_enable(func3_in, offset_in);
    expected_data = expected_store_data(func3_in, offset_in, raw_in);
    label = $sformatf("%s func3=%03b offset=%0d raw=0x%08h",
                      store_name(func3_in),
                      func3_in,
                      offset_in,
                      raw_in);

    func3_hits[func3_in]++;
    offset_hits[offset_in]++;
    if (expected_be == 4'b0000) ignored_cases++;
    else valid_cases++;

    check_eq4({label, " byte_enable"}, byte_enable, expected_be);
    check_eq32({label, " store_data"}, store_data, expected_data);
  endtask

  task automatic finish_report();
    $display("---------------------------------------");
    $display("Store decoder TB summary");
    $display("  Valid store cases  : %0d", valid_cases);
    $display("  Ignored cases      : %0d", ignored_cases);
    $display("  Total checks       : %0d", total_checks);
    $display("  Passed checks      : %0d", passed_checks);
    $display("  Failed checks      : %0d", error_count);
    $display("---------------------------------------");
    $display("Coverage summary");
    $display("  SB                 : %0d", func3_hits[3'b000]);
    $display("  SH                 : %0d", func3_hits[3'b001]);
    $display("  SW                 : %0d", func3_hits[3'b010]);
    $display("  Unsupported func3  : %0d", func3_hits[3'b011] + func3_hits[3'b100] +
                                       func3_hits[3'b101] + func3_hits[3'b110] +
                                       func3_hits[3'b111]);
    $display("  Offset 0           : %0d", offset_hits[0]);
    $display("  Offset 1           : %0d", offset_hits[1]);
    $display("  Offset 2           : %0d", offset_hits[2]);
    $display("  Offset 3           : %0d", offset_hits[3]);
    $display("---------------------------------------");

    if (error_count == 0) begin
      $display("store_decoder_tb PASSED");
      $finish;
    end else begin
      $fatal(1, "store_decoder_tb FAILED with %0d error(s)", error_count);
    end
  endtask

  initial begin
    logic [31:0] data_patterns[4];

    data_patterns[0] = 32'hAABB_CCDD;
    data_patterns[1] = 32'h0000_0080;
    data_patterns[2] = 32'hFFFF_8001;
    data_patterns[3] = 32'h1234_5678;

    foreach (data_patterns[p]) begin
      for (int f = 0; f < 8; f++) begin
        for (int offset = 0; offset < 4; offset++) begin
          run_case(3'(f), 2'(offset), data_patterns[p]);
        end
      end
    end

    finish_report();
  end
endmodule
