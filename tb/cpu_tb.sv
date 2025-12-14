`timescale 1ns / 1ps
module cpu_tb;
  logic clk;
  logic rst_n;

  cpu dut (
      .clk  (clk),
      .rst_n(rst_n)
  );

  initial begin
    clk = 1'b0;
    forever #0.5 clk = ~clk;
  end

  task cpu_reset;
    begin
      $display("-> Applying Reset");
      rst_n = 1'b0;

      @(posedge clk);
      #1ps;

      rst_n = 1'b1;
      #1ps;

      $display("-> Reset Complete. PC is 0x%h", dut.pc);
    end
  endtask


  initial begin
    $display("---------------------------------------");
    $display("Starting CPU LW Test (x18 = MEM[x0 + 12])");
    $display("---------------------------------------");
    cpu_reset();
    if (dut.pc !== 32'h0000_0000) $error("Initial PC Mismatch: Expected 0, Got %h", dut.pc);
    @(posedge clk);

    @(posedge clk);
    $display("Cycle 1: LW executed");
    if (dut.regfile_u.registers[18] !== 32'hABCDEF11) begin
      $error("LW Test Failed! x18 expected 0xABCDEF11, Got 0x%h", dut.regfile_u.registers[18]);
    end else begin
      $display("LW Test Passed: Register x18 = 0x%h (Expected 0xABCDEF11)",
               dut.regfile_u.registers[18]);
    end

    $display("---------------------------------------");
    $display("Starting CPU SW Test (MEM[x0 + 16] = x18)");
    $display("---------------------------------------");
    // 16 / 4 = 4
    if (dut.dmemory.mem[4] !== 32'hFFFFFFFF)
      $error("Pre-test failed: Expected 0xFFFFFFFF, Got %h", dut.dmemory.mem[4]);

    @(posedge clk);
    $display("Cycle 2: SW expected");
    if (dut.dmemory.mem[4] !== 32'hABCDEF11)
      $error("SW Fail: Mem[4]=%h, Expected ABCDEF11", dut.dmemory.mem[4]);


    $display("---------------------------------------");
    $display("CPU Tests Completed");
    $display("---------------------------------------");
    $finish;
  end

endmodule
