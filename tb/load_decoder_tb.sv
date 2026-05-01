`timescale 1ns / 1ps

module load_decoder_tb;
  logic [2:0]  func3;
  logic [1:0]  address_offset;
  logic [31:0] mem_read_raw;
  logic [31:0] load_data;

  int error_count = 0;
  int total_checks = 0;
  int passed_checks = 0;
  int valid_cases = 0;
  int ignored_cases = 0;
  int func3_hits[8];
  int offset_hits[4];

  load_decoder dut (
      .func3(func3),
      .address_offset(address_offset),
      .mem_read_raw(mem_read_raw),
      .load_data(load_data)
  );

  function automatic logic [7:0] selected_byte(
      input logic [31:0] raw_in,
      input logic [1:0]  offset_in
  );
    selected_byte = raw_in >> (8 * offset_in);
  endfunction

  function automatic logic [15:0] selected_halfword(
      input logic [31:0] raw_in,
      input logic [1:0]  offset_in
  );
    case (offset_in)
      2'b00: selected_halfword = raw_in[15:0];
      2'b10: selected_halfword = raw_in[31:16];
      default: selected_halfword = 16'b0;
    endcase
  endfunction

  function automatic logic [31:0] expected_load_data(
      input logic [2:0]  func3_in,
      input logic [1:0]  offset_in,
      input logic [31:0] raw_in
  );
    logic [7:0] byte_value;
    logic [15:0] halfword_value;

    byte_value = selected_byte(raw_in, offset_in);
    halfword_value = selected_halfword(raw_in, offset_in);

    case (func3_in)
      3'b000: expected_load_data = {{24{byte_value[7]}}, byte_value};
      3'b001: expected_load_data = {{16{halfword_value[15]}}, halfword_value};
      3'b010: expected_load_data = raw_in;
      3'b100: expected_load_data = {24'b0, byte_value};
      3'b101: expected_load_data = {16'b0, halfword_value};
      default: expected_load_data = 32'b0;
    endcase
  endfunction

  function automatic bit case_is_valid(input logic [2:0] func3_in, input logic [1:0] offset_in);
    case (func3_in)
      3'b000, 3'b100: case_is_valid = 1'b1;
      3'b001, 3'b101: case_is_valid = (offset_in == 2'b00 || offset_in == 2'b10);
      3'b010: case_is_valid = (offset_in == 2'b00);
      default: case_is_valid = 1'b0;
    endcase
  endfunction

  function automatic string load_name(input logic [2:0] func3_in);
    case (func3_in)
      3'b000: load_name = "LB";
      3'b001: load_name = "LH";
      3'b010: load_name = "LW";
      3'b100: load_name = "LBU";
      3'b101: load_name = "LHU";
      default: load_name = "UNSUPPORTED";
    endcase
  endfunction

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
    logic [31:0] expected;
    string label;

    func3 = func3_in;
    address_offset = offset_in;
    mem_read_raw = raw_in;
    #1;

    expected = expected_load_data(func3_in, offset_in, raw_in);
    label = $sformatf("%s func3=%03b offset=%0d raw=0x%08h",
                      load_name(func3_in),
                      func3_in,
                      offset_in,
                      raw_in);

    func3_hits[func3_in]++;
    offset_hits[offset_in]++;
    if (case_is_valid(func3_in, offset_in)) valid_cases++;
    else ignored_cases++;

    check_eq32(label, load_data, expected);
  endtask

  task automatic finish_report();
    $display("---------------------------------------");
    $display("Load decoder TB summary");
    $display("  Valid load cases   : %0d", valid_cases);
    $display("  Ignored cases      : %0d", ignored_cases);
    $display("  Total checks       : %0d", total_checks);
    $display("  Passed checks      : %0d", passed_checks);
    $display("  Failed checks      : %0d", error_count);
    $display("---------------------------------------");
    $display("Coverage summary");
    $display("  LB                 : %0d", func3_hits[3'b000]);
    $display("  LH                 : %0d", func3_hits[3'b001]);
    $display("  LW                 : %0d", func3_hits[3'b010]);
    $display("  LBU                : %0d", func3_hits[3'b100]);
    $display("  LHU                : %0d", func3_hits[3'b101]);
    $display("  Unsupported func3  : %0d", func3_hits[3'b011] + func3_hits[3'b110] +
                                       func3_hits[3'b111]);
    $display("  Offset 0           : %0d", offset_hits[0]);
    $display("  Offset 1           : %0d", offset_hits[1]);
    $display("  Offset 2           : %0d", offset_hits[2]);
    $display("  Offset 3           : %0d", offset_hits[3]);
    $display("---------------------------------------");

    if (error_count == 0) begin
      $display("load_decoder_tb PASSED");
      $finish;
    end else begin
      $fatal(1, "load_decoder_tb FAILED with %0d error(s)", error_count);
    end
  endtask

  initial begin
    logic [31:0] data_patterns[5];

    data_patterns[0] = 32'hAEAE_5678;
    data_patterns[1] = 32'h0000_007F;
    data_patterns[2] = 32'h0000_0080;
    data_patterns[3] = 32'h8001_7FFF;
    data_patterns[4] = 32'hFFFF_FFFF;

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
