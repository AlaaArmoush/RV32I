`timescale 1ns / 1ps

module regfile_tb;
  localparam int RANDOM_TESTS = 1000;

  logic        clk;
  logic        rst_n;
  logic [4:0]  address1;
  logic [4:0]  address2;
  logic [4:0]  address3;
  logic        write_enable;
  logic [31:0] write_data;
  logic [31:0] read_data1;
  logic [31:0] read_data2;

  logic [31:0] shadow_regs[32];

  int error_count = 0;
  int total_checks = 0;
  int passed_checks = 0;
  int directed_checks = 0;
  int random_checks = 0;
  int write_count = 0;
  int x0_write_attempts = 0;
  int read_after_write_checks = 0;

  regfile dut (
      .clk(clk),
      .rst_n(rst_n),
      .address1(address1),
      .address2(address2),
      .address3(address3),
      .write_enable(write_enable),
      .write_data(write_data),
      .read_data1(read_data1),
      .read_data2(read_data2)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

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

  task automatic scoreboard_reset();
    for (int i = 0; i < 32; i++) begin
      shadow_regs[i] = 32'b0;
    end
  endtask

  task automatic apply_reset();
    rst_n = 1'b0;
    write_enable = 1'b0;
    address1 = 5'b0;
    address2 = 5'b0;
    address3 = 5'b0;
    write_data = 32'b0;
    scoreboard_reset();

    @(posedge clk);
    #1ps;
    rst_n = 1'b1;
  endtask

  task automatic drive_reads(input logic [4:0] a1, input logic [4:0] a2);
    address1 = a1;
    address2 = a2;
    #1ps;
  endtask

  task automatic check_reads(
      input logic [4:0] a1,
      input logic [4:0] a2,
      input string label,
      input bit is_random = 1'b0
  );
    drive_reads(a1, a2);

    if (is_random) random_checks += 2;
    else directed_checks += 2;

    check_eq32($sformatf("%s port1 x%0d", label, a1), read_data1, shadow_regs[a1]);
    check_eq32($sformatf("%s port2 x%0d", label, a2), read_data2, shadow_regs[a2]);
  endtask

  task automatic write_reg(
      input logic [4:0] rd,
      input logic [31:0] data,
      input bit enable = 1'b1
  );
    @(negedge clk);
    address3 = rd;
    write_data = data;
    write_enable = enable;

    @(posedge clk);
    #1ps;

    write_enable = 1'b0;

    if (enable) begin
      if (rd == 5'd0) begin
        x0_write_attempts++;
      end else begin
        shadow_regs[rd] = data;
        write_count++;
      end
    end

    shadow_regs[0] = 32'b0;
  endtask

  task automatic verify_reset();
    $display("---------------------------------------");
    $display("Verifying regfile reset");
    $display("---------------------------------------");

    apply_reset();

    for (int i = 0; i < 32; i += 2) begin
      check_reads(5'(i), 5'(i + 1), "reset");
    end
  endtask

  task automatic verify_x0_behavior();
    $display("---------------------------------------");
    $display("Verifying x0 hardwired-zero behavior");
    $display("---------------------------------------");

    write_reg(5'd0, 32'hDEAD_BEEF);
    check_reads(5'd0, 5'd0, "x0 write ignored");

    write_reg(5'd1, 32'h1234_5678);
    check_reads(5'd0, 5'd1, "x0 read with normal reg");
  endtask

  task automatic verify_read_after_write();
    $display("---------------------------------------");
    $display("Verifying read-after-write behavior");
    $display("---------------------------------------");

    for (int rd = 1; rd < 8; rd++) begin
      write_reg(rd[4:0], 32'h1000_0000 + rd);
      read_after_write_checks += 2;
      check_reads(rd[4:0], rd[4:0], "read-after-write");
    end
  endtask

  task automatic verify_write_disable();
    $display("---------------------------------------");
    $display("Verifying write disable holds state");
    $display("---------------------------------------");

    write_reg(5'd9, 32'hAAAA_5555);
    write_reg(5'd9, 32'hFFFF_0000, 1'b0);
    check_reads(5'd9, 5'd9, "write disabled");
  endtask

  task automatic verify_random_traffic();
    int unsigned seed;
    logic [4:0] rand_a1;
    logic [4:0] rand_a2;
    logic [4:0] rand_a3;
    logic [31:0] rand_data;
    logic rand_enable;

    $display("---------------------------------------");
    $display("Verifying deterministic random regfile traffic");
    $display("---------------------------------------");

    seed = 32'hA11C_2026;
    void'($urandom(seed));

    for (int i = 0; i < RANDOM_TESTS; i++) begin
      rand_a1 = $urandom_range(0, 31);
      rand_a2 = $urandom_range(0, 31);
      rand_a3 = $urandom_range(0, 31);
      rand_data = $urandom();
      rand_enable = $urandom_range(0, 1);

      @(negedge clk);
      address1 = rand_a1;
      address2 = rand_a2;
      address3 = rand_a3;
      write_data = rand_data;
      write_enable = rand_enable;

      @(posedge clk);
      #1ps;

      if (rand_enable) begin
        if (rand_a3 == 5'd0) begin
          x0_write_attempts++;
        end else begin
          shadow_regs[rand_a3] = rand_data;
          write_count++;
        end
      end

      shadow_regs[0] = 32'b0;
      write_enable = 1'b0;

      check_reads(rand_a1, rand_a2, "random", 1'b1);
    end
  endtask

  task automatic finish_report();
    $display("---------------------------------------");
    $display("Regfile TB summary");
    $display("  Directed checks       : %0d", directed_checks);
    $display("  Random checks         : %0d", random_checks);
    $display("  Writes to real regs   : %0d", write_count);
    $display("  x0 write attempts     : %0d", x0_write_attempts);
    $display("  RAW check pairs       : %0d", read_after_write_checks / 2);
    $display("  Total checks          : %0d", total_checks);
    $display("  Passed checks         : %0d", passed_checks);
    $display("  Failed checks         : %0d", error_count);
    $display("---------------------------------------");

    if (error_count == 0) begin
      $display("regfile_tb PASSED");
      $finish;
    end else begin
      $fatal(1, "regfile_tb FAILED with %0d error(s)", error_count);
    end
  endtask

  initial begin
    verify_reset();
    verify_x0_behavior();
    verify_read_after_write();
    verify_write_disable();
    verify_random_traffic();
    finish_report();
  end
endmodule
