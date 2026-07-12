`timescale 1ns / 1ps

module regfile_tb;
  localparam int DEFAULT_RANDOM_TESTS = 1000;

  logic clk;

  regfile_if rf_if(clk);

  regfile dut (
      .clk(clk),
      .rst_n(rf_if.rst_n),
      .address1(rf_if.address1),
      .address2(rf_if.address2),
      .address3(rf_if.address3),
      .write_enable(rf_if.write_enable),
      .write_data(rf_if.write_data),
      .read_data1(rf_if.read_data1),
      .read_data2(rf_if.read_data2)
  );

  regfile_sva sva_i(rf_if);

  regfile_driver     driver;
  regfile_monitor    monitor;
  regfile_scoreboard scoreboard;
  regfile_coverage   coverage;

  int unsigned seed;
  int random_tests;

  initial clk = 1'b0;
  always #5 clk = ~clk;

  task automatic drive_sample_check(
      input regfile_item drive_item,
      input string phase = "directed",
      input bit is_random = 1'b0
  );
    regfile_item sampled_item;

    driver.drive_item(drive_item);
    monitor.sample_item(sampled_item, drive_item.name);

    scoreboard.observe_item(sampled_item, phase, is_random);
    coverage.sample(sampled_item);
  endtask

  task automatic check_reads(
      input bit [4:0] a1,
      input bit [4:0] a2,
      input string phase = "directed"
  );
    regfile_item item;

    item = new(phase);
    item.address1 = a1;
    item.address2 = a2;
    item.address3 = 5'd0;
    item.write_enable = 1'b0;
    item.write_data = 32'd0;

    drive_sample_check(item, phase, 1'b0);
  endtask

  task automatic write_reg(
      input bit [4:0] rd,
      input bit [31:0] data,
      input bit enable = 1'b1,
      input string phase = "directed"
  );
    regfile_item item;

    item = new(phase);
    item.address1 = rd;
    item.address2 = rd;
    item.address3 = rd;
    item.write_enable = enable;
    item.write_data = data;

    drive_sample_check(item, phase, 1'b0);
  endtask

  task automatic verify_reset();
    $display("---------------------------------------");
    $display("Verifying regfile reset");
    $display("---------------------------------------");

    driver.reset();
    scoreboard.reset_shadow();

    begin
      regfile_item reset_item;

      reset_item = new("reset_sample");
      reset_item.rst_n = 1'b0;
      reset_item.address1 = 5'd0;
      reset_item.address2 = 5'd0;
      reset_item.address3 = 5'd0;
      reset_item.write_enable = 1'b0;
      reset_item.write_data = 32'd0;
      reset_item.read_data1 = 32'd0;
      reset_item.read_data2 = 32'd0;

      coverage.sample(reset_item);
    end

    for (int i = 0; i < 32; i += 2) begin
      check_reads(5'(i), 5'(i + 1), "reset");
    end
  endtask

  task automatic verify_x0_behavior();
    $display("---------------------------------------");
    $display("Verifying x0 hardwired-zero behavior");
    $display("---------------------------------------");

    write_reg(5'd0, 32'hDEAD_BEEF, 1'b1, "x0 write ignored");
    check_reads(5'd0, 5'd0, "x0 readback");

    write_reg(5'd1, 32'h1234_5678, 1'b1, "normal write");
    check_reads(5'd0, 5'd1, "x0 with normal reg");
  endtask

  task automatic verify_read_after_write();
    $display("---------------------------------------");
    $display("Verifying same-cycle read-after-write behavior");
    $display("---------------------------------------");

    for (int rd = 1; rd < 8; rd++) begin
      write_reg(rd[4:0], 32'h1000_0000 + rd, 1'b1, "same-cycle raw");
      check_reads(rd[4:0], rd[4:0], "readback after write");
    end
  endtask

  task automatic verify_write_disable();
    $display("---------------------------------------");
    $display("Verifying write disable holds state");
    $display("---------------------------------------");

    write_reg(5'd9, 32'hAAAA_5555, 1'b1, "write enabled");
    write_reg(5'd9, 32'hFFFF_0000, 1'b0, "write disabled");
    check_reads(5'd9, 5'd9, "write disabled readback");
  endtask

  task automatic verify_data_patterns();
    $display("---------------------------------------");
    $display("Verifying directed data patterns");
    $display("---------------------------------------");

    write_reg(5'd10, 32'h0000_0000, 1'b1, "data zero");
    write_reg(5'd11, 32'hFFFF_FFFF, 1'b1, "data all ones");
    write_reg(5'd12, 32'h8000_0000, 1'b1, "data sign bit");
    write_reg(5'd13, 32'h0000_0001, 1'b1, "data walking bit");
    write_reg(5'd14, 32'h0000_8000, 1'b1, "data walking bit");
    write_reg(5'd15, 32'h0000_0002, 1'b1, "data walking bit");
    write_reg(5'd16, 32'h0000_0004, 1'b1, "data walking bit");
    write_reg(5'd17, 32'h0000_0008, 1'b1, "data walking bit");
    write_reg(5'd18, 32'h0000_0010, 1'b1, "data walking bit");
    write_reg(5'd19, 32'h0000_0080, 1'b1, "data walking bit");

    check_reads(5'd10, 5'd11, "pattern readback");
    check_reads(5'd12, 5'd13, "pattern readback");
    check_reads(5'd14, 5'd0,  "pattern readback");
  endtask

  task automatic verify_random_traffic();
    regfile_item item;
    int randomized_ok;

    $display("---------------------------------------");
    $display("Verifying constrained-random regfile traffic");
    $display("---------------------------------------");

    void'($urandom(seed));

    for (int i = 0; i < random_tests; i++) begin
      item = new($sformatf("random_%0d", i));

      randomized_ok = item.randomize();
      if (randomized_ok == 0) begin
        $fatal(1, "Failed to randomize regfile item at iteration %0d", i);
      end

      case (i % 16)
        0: begin
          item.write_enable = 1'b1;
          item.address3 = 5'd0;
          item.address1 = 5'd0;
        end

        1: begin
          item.write_enable = 1'b1;
          item.address1 = item.address3;
        end

        2: begin
          item.write_enable = 1'b1;
          item.address2 = item.address3;
        end

        3: begin
          item.address2 = item.address1;
        end

        4: begin
          item.write_enable = 1'b1;
          item.write_data = 32'h0000_0000;
        end

        5: begin
          item.write_enable = 1'b1;
          item.write_data = 32'hFFFF_FFFF;
        end

        6: begin
          item.write_enable = 1'b1;
          item.write_data = 32'h8000_0000;
        end

        default: begin
        end
      endcase

      drive_sample_check(item, "random", 1'b1);
    end
  endtask

    task automatic finish_report();
    scoreboard.report();

    if (scoreboard.error_count == 0) begin
      $display("regfile_tb PASSED");
      $finish;
    end else begin
      $fatal(1, "regfile_tb FAILED with %0d error(s)", scoreboard.error_count);
    end
  endtask

  initial begin
    seed = 32'hA11C_2026;
    random_tests = DEFAULT_RANDOM_TESTS;

    if ($value$plusargs("SEED=%d", seed)) begin
      $display("Using plusarg SEED=%0d", seed);
    end else begin
      $display("Using default SEED=%0d", seed);
    end

    if ($value$plusargs("RANDOM_TESTS=%d", random_tests)) begin
      $display("Using plusarg RANDOM_TESTS=%0d", random_tests);
    end else begin
      $display("Using default RANDOM_TESTS=%0d", random_tests);
    end

    driver = new(rf_if);
    monitor = new(rf_if);
    scoreboard = new();
    coverage = new();

    verify_reset();
    verify_x0_behavior();
    verify_read_after_write();
    verify_write_disable();
    verify_data_patterns();
    verify_random_traffic();

    finish_report();
  end

endmodule
