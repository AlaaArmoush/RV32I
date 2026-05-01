`timescale 1ns / 1ps
/* verilator lint_off WIDTHTRUNC */

module memory_tb;
  localparam int DATA_WIDTH = 32;
  localparam int WORDS = 64;
  localparam int RANDOM_TESTS = 200;

  logic                  clk;
  logic                  rst_n;
  logic                  write_enable;
  logic [31:0]           address;
  logic [DATA_WIDTH-1:0] write_data;
  logic [DATA_WIDTH-1:0] read_data;
  logic [3:0]            byte_enable;

  int error_count = 0;
  int total_checks = 0;
  int passed_checks = 0;
  int write_count = 0;
  int read_count = 0;

  int seen_reset = 0;
  int seen_full_word = 0;
  int seen_low_half = 0;
  int seen_high_half = 0;
  int seen_random = 0;
  int seen_lane[4];

  logic [31:0] shadow_mem[WORDS];

  memory #(
      .WORDS(WORDS)
  ) dut (
      .clk(clk),
      .rst_n(rst_n),
      .write_enable(write_enable),
      .address(address),
      .byte_enable(byte_enable),
      .write_data(write_data),
      .read_data(read_data)
  );

  initial clk = 1'b0;
  always #0.5 clk = ~clk;

  task automatic check_eq32(
      input string label,
      input logic [31:0] got,
      input logic [31:0] expected
  );
    total_checks++;
    if (got !== expected) begin
      $error("%s failed: expected 0x%08h, got 0x%08h", label, expected, got);
      error_count++;
    end else begin
      passed_checks++;
    end
  endtask

  task automatic finish_report();
    $display("---------------------------------------");
    $display("Memory TB summary");
    $display("  Writes checked     : %0d", write_count);
    $display("  Reads checked      : %0d", read_count);
    $display("  Total checks       : %0d", total_checks);
    $display("  Passed checks      : %0d", passed_checks);
    $display("  Failed checks      : %0d", error_count);
    $display("---------------------------------------");
    $display("Coverage summary");
    $display("  reset              : %0d", seen_reset);
    $display("  full word writes   : %0d", seen_full_word);
    $display("  low half writes    : %0d", seen_low_half);
    $display("  high half writes   : %0d", seen_high_half);
    $display("  random writes      : %0d", seen_random);
    $display("  byte lane 0 writes : %0d", seen_lane[0]);
    $display("  byte lane 1 writes : %0d", seen_lane[1]);
    $display("  byte lane 2 writes : %0d", seen_lane[2]);
    $display("  byte lane 3 writes : %0d", seen_lane[3]);
    $display("---------------------------------------");

    if (error_count == 0) begin
      $display("memory_tb PASSED");
      $finish;
    end else begin
      $fatal(1, "memory_tb FAILED with %0d error(s)", error_count);
    end
  endtask

  function automatic logic [31:0] apply_byte_enable(
      input logic [31:0] old_word,
      input logic [31:0] new_word,
      input logic [3:0]  be
  );
    logic [31:0] merged;

    merged = old_word;
    for (int lane = 0; lane < 4; lane++) begin
      if (be[lane]) begin
        merged[8*lane+:8] = new_word[8*lane+:8];
      end
    end

    return merged;
  endfunction

  task automatic update_coverage(input logic [3:0] be, input bit is_random);
    if (be == 4'b1111) seen_full_word++;
    if (be == 4'b0011) seen_low_half++;
    if (be == 4'b1100) seen_high_half++;
    if (is_random) seen_random++;

    for (int lane = 0; lane < 4; lane++) begin
      if (be[lane]) seen_lane[lane]++;
    end
  endtask

  task automatic reset_memory();
    rst_n = 1'b0;
    write_enable = 1'b0;
    byte_enable = 4'b0000;
    address = 32'b0;
    write_data = 32'b0;

    @(posedge clk);
    #1ps;

    rst_n = 1'b1;
    seen_reset++;

    for (int i = 0; i < WORDS; i++) begin
      shadow_mem[i] = 32'b0;
    end
  endtask

  task automatic read_and_check(input int word_index, input string label);
    address = word_index << 2;
    write_enable = 1'b0;
    byte_enable = 4'b0000;
    #1ps;

    read_count++;
    check_eq32($sformatf("%s mem[%0d]", label, word_index),
               read_data,
               shadow_mem[word_index]);
  endtask

  task automatic write_word(
      input int word_index,
      input logic [31:0] data,
      input logic [3:0] be,
      input string label,
      input bit is_random = 1'b0
  );
    address = word_index << 2;
    write_data = data;
    byte_enable = be;
    write_enable = 1'b1;

    @(posedge clk);
    #1ps;

    write_enable = 1'b0;
    shadow_mem[word_index] = apply_byte_enable(shadow_mem[word_index], data, be);
    update_coverage(be, is_random);
    write_count++;

    read_and_check(word_index, label);
  endtask

  task automatic verify_reset_clears_memory();
    $display("---------------------------------------");
    $display("Verifying reset clears memory");
    $display("---------------------------------------");

    reset_memory();

    for (int i = 0; i < WORDS; i++) begin
      read_and_check(i, "reset");
    end
  endtask

  task automatic verify_directed_writes();
    $display("---------------------------------------");
    $display("Verifying directed word and byte-lane writes");
    $display("---------------------------------------");

    write_word(0, 32'hDEAD_BEEF, 4'b1111, "full word write");
    write_word(1, 32'hCAFE_BABE, 4'b1111, "full word write");
    write_word(2, 32'h1234_5678, 4'b1111, "full word write");
    write_word(3, 32'hA5A5_A5A5, 4'b1111, "full word write");

    write_word(4, 32'h1122_3344, 4'b1111, "partial setup");
    write_word(4, 32'h0000_00AA, 4'b0001, "byte lane 0");
    write_word(4, 32'h0000_BB00, 4'b0010, "byte lane 1");
    write_word(4, 32'h00CC_0000, 4'b0100, "byte lane 2");
    write_word(4, 32'hDD00_0000, 4'b1000, "byte lane 3");

    write_word(5, 32'h1122_3344, 4'b1111, "halfword setup");
    write_word(5, 32'h0000_AA55, 4'b0011, "low halfword");
    write_word(5, 32'hBEEF_0000, 4'b1100, "high halfword");

    write_word(6, 32'hFFFF_FFFF, 4'b0000, "disabled byte-enable");
  endtask

  task automatic verify_burst_writes();
    $display("---------------------------------------");
    $display("Verifying burst writes");
    $display("---------------------------------------");

    for (int i = 0; i < WORDS; i++) begin
      write_word(i, 32'(i * 32'h0000_0101), 4'b1111, "burst write");
    end

    for (int i = 0; i < WORDS; i++) begin
      read_and_check(i, "burst readback");
    end
  endtask

  task automatic verify_random_byte_enables();
    int unsigned seed;
    int word_index;
    logic [31:0] random_data;
    logic [3:0] random_be;

    $display("---------------------------------------");
    $display("Verifying deterministic random byte-enable writes");
    $display("---------------------------------------");

    seed = 32'hC0DE_2026;
    void'($urandom(seed));

    for (int i = 0; i < RANDOM_TESTS; i++) begin
      word_index = $urandom_range(0, WORDS - 1);
      random_data = $urandom();
      random_be = $urandom_range(0, 15);
      write_word(word_index, random_data, random_be, "random write", 1'b1);
    end

    for (int i = 0; i < WORDS; i++) begin
      read_and_check(i, "random final readback");
    end
  endtask

  initial begin
    verify_reset_clears_memory();
    verify_directed_writes();
    verify_burst_writes();
    verify_random_byte_enables();
    finish_report();
  end
endmodule
