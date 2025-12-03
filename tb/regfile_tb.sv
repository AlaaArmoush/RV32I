`timescale 1ns / 1ps

module regfile_tb;

  //DUT
  logic clk;
  logic rst_n;
  logic [4:0] address1, address2, address3;
  logic write_enable;
  logic [31:0] write_data;
  logic [31:0] read_data1, read_data2;

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

  class RegTx;
    rand bit [4:0] a1, a2, a3;
    rand bit [31:0] w_data;
    rand bit w_en;
  endclass

  class Scoreboard;
    bit [31:0] shadow_regs[32];
    int error_count = 0;

    function new();
      for (int i = 0; i < 32; i++) shadow_regs[i] = 0;
    endfunction

    function void predict(RegTx tx);
      if (tx.w_en && tx.a3 != 0) begin
        shadow_regs[tx.a3] = tx.w_data;
      end
    endfunction

    function void check(bit [31:0] rd1, bit [31:0] rd2, bit [4:0] a1, bit [4:0] a2);
      if (rd1 !== shadow_regs[a1]) begin
        $error("Mismatch Port 1! Addr: %0d, Exp: %h, Got: %h", a1, shadow_regs[a1], rd1);
        error_count++;
      end
      if (rd2 !== shadow_regs[a2]) begin
        $error("Mismatch Port 2! Addr: %0d, Exp: %h, Got: %h", a2, shadow_regs[a2], rd2);
        error_count++;
      end
    endfunction
  endclass

  // test execution
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  RegTx tx;
  Scoreboard sb;

  initial begin
    sb = new();
    tx = new();

    rst_n = 0;
    write_enable = 0;
    #15 rst_n = 1;

    $display("starting random test...");

    for (int i = 0; i < 1000; i++) begin
      if (!tx.randomize()) $fatal("Randomization failed");
      //drive inputs at negedge for safe setup time
      @(negedge clk);
      address1 = tx.a1;
      address2 = tx.a2;
      address3 = tx.a3;
      write_data = tx.w_data;
      write_enable = tx.w_en;

      // write happens here
      @(posedge clk);
      #1 sb.predict(tx);
      sb.check(read_data1, read_data2, tx.a1, tx.a2);
    end

    //explicit check for reg0
    @(negedge clk);
    write_enable = 1;
    address3 = 0;
    write_data = 32'hDEADBEEF;
    @(posedge clk);
    #1 if (read_data1 !== 0 && address1 == 0) $error("x0 was overwritten");

    if (sb.error_count == 0) $display("TEST PASSED: 1000 random vectors checked.");
    else $display("TEST FAILED: %0d errors found.", sb.error_count);

    $finish;
  end
endmodule




