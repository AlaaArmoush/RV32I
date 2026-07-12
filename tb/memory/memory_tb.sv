`timescale 1ns / 1ps

module memory_tb;
  localparam int WORDS = 64;
  localparam int CLK_PERIOD_NS = 10;
  logic clk = 1'b0;
  
  mailbox #(memory_item) request_mb;
  mailbox #(memory_item) observed_mb;

  memory_sequence seq;
  memory_driver driver;
  memory_monitor monitor;
  memory_scoreboard scoreboard;
  memory_coverage coverage;

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

  memory_sva #(
      .WORDS(WORDS)
  ) sva_i (
      .mon(mem_vif)
  );

  task automatic init_bus();
    mem_vif.rst_n = 1'b1;
    mem_vif.address = '0;
    mem_vif.write_data = '0;
    mem_vif.write_enable = 1'b0;
    mem_vif.byte_enable = 4'b0000;
    mem_vif.txn_valid = 1'b0;
  endtask

  task automatic reset_dut();
    mem_vif.rst_n = 1'b0;
    repeat (2) @(posedge clk);
    mem_vif.rst_n = 1'b1;
    @(posedge clk);
  endtask

  initial begin
    int unsigned expected_item_count;
    int unsigned timeout_cycles;
    int unsigned random_tests;
    int unsigned seed;

    seed = 32'h2026_0712;
    random_tests = 500;

    if ($value$plusargs("SEED=%d", seed)) begin
      $display("[MEM_TB] Using plusarg SEED=%0d", seed);
    end else begin
      $display("[MEM_TB] Using default SEED=%0d", seed);
    end

    if ($value$plusargs("RANDOM_TESTS=%d", random_tests)) begin
      $display("[MEM_TB] Using plusarg RANDOM_TESTS=%0d", random_tests);
    end else begin
      $display("[MEM_TB] Using default RANDOM_TESTS=%0d", random_tests);
    end

    void'($urandom(seed));

    $display("[MEM_TB] Starting memory DV environment");

    request_mb = new();
    observed_mb = new();

    seq = new(request_mb, WORDS);
    driver = new(mem_vif.driver, request_mb);
    monitor = new(mem_vif.monitor, observed_mb, WORDS);
    coverage = new(WORDS);
    scoreboard = new(observed_mb, WORDS, coverage);

    driver.verbose = 1'b0;
    monitor.verbose = 1'b0;
    scoreboard.verbose = 1'b0;

    init_bus();

    fork : env_threads
      driver.run();
      monitor.run();
      scoreboard.run();
    join_none

    seq.run_directed_smoke();
    seq.run_random(random_tests);

    expected_item_count = seq.generated_count;
    timeout_cycles = 200 + (expected_item_count * 4);

    fork : completion_or_timeout
      begin
        wait (scoreboard.checked_count >= expected_item_count);
      end

      begin
        repeat (timeout_cycles) @(posedge clk);
        $fatal(1,
               "[MEM_TB] Timeout waiting for scoreboard: checked=%0d expected=%0d",
               scoreboard.checked_count,
               expected_item_count);
      end
    join_any

    disable completion_or_timeout;

    scoreboard.report();
    coverage.report();

    $display("[MEM_TB] PASS checked=%0d random_tests=%0d seed=%0d",
             scoreboard.checked_count,
             random_tests,
             seed);
    disable env_threads;
    $finish;
  end
endmodule
