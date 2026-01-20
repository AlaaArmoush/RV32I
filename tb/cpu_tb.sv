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
    if (dut.dmemory.mem[4] !== 32'hF2F2F2F2)
      $error("Pre-test failed: Expected 0xF2F2F2F2, Got %h", dut.dmemory.mem[4]);

    @(posedge clk);
    $display("Cycle 2: SW expected");
    if (dut.dmemory.mem[4] !== 32'hABCDEF11) begin
      $error("SW Fail: Mem[4]=%h, Expected ABCDEF11", dut.dmemory.mem[4]);
    end else begin
      $display("SW Test Passed: Mem[4] = 0x%h (Expected 0xABCDEF11)", dut.dmemory.mem[4]);
    end

    $display("---------------------------------------");
    $display("Starting CPU LW Test 2 (x17 = MEM[x0 + 20])");
    $display("---------------------------------------");
    @(posedge clk);
    $display("Cycle 3: LW executed");
    if (dut.regfile_u.registers[17] !== 32'h12345678) begin
      $error("LW Test 2 Failed! x17 expected 0x12345678, Got 0x%h", dut.regfile_u.registers[17]);
    end else begin
      $display("LW Test 2 Passed: Register x17 = 0x%h (Expected 0x12345678)",
               dut.regfile_u.registers[17]);
    end

    $display("---------------------------------------");
    $display("Starting CPU ADD Test (x19 = x18 + x17)");
    $display("---------------------------------------");
    @(posedge clk);
    $display("Cycle 4: ADD executed");
    if (dut.regfile_u.registers[19] !== 32'hBE024589) begin
      $error("ADD Test Failed! x19 expected 0xBE024589, Got 0x%h", dut.regfile_u.registers[19]);
    end else begin
      $display("ADD Test Passed: Register x19 = 0x%h (Expected 0xBE024589)",
               dut.regfile_u.registers[19]);
    end

    $display("---------------------------------------");
    $display("Starting CPU AND Test (x21 = x18 & x19)");
    $display("---------------------------------------");
    @(posedge clk);
    $display("Cycle 5: AND executed");
    if (dut.regfile_u.registers[21] !== 32'hAA004501) begin
      $error("AND Test Failed! x21 expected 0xAA004501, Got 0x%h", dut.regfile_u.registers[21]);
    end else begin
      $display("AND Test Passed: Register x21 = 0x%h (Expected 0xAA004501)",
               dut.regfile_u.registers[21]);
    end

    $display("---------------------------------------");
    $display("Starting CPU LW Test 3 (x5 = MEM[x0 + 24])");
    $display("---------------------------------------");
    @(posedge clk);
    $display("Cycle 6: LW executed");
    if (dut.regfile_u.registers[5] !== 32'h125F552D) begin
      $error("LW Test 3 Failed! x5 expected 0x125F552D, Got 0x%h", dut.regfile_u.registers[5]);
    end else begin
      $display("LW Test 3 Passed: Register x5 = 0x%h (Expected 0x125F552D)",
               dut.regfile_u.registers[5]);
    end

    $display("---------------------------------------");
    $display("Starting CPU LW Test 4 (x6 = MEM[x0 + 28])");
    $display("---------------------------------------");
    @(posedge clk);
    $display("Cycle 7: LW executed");
    if (dut.regfile_u.registers[6] !== 32'h7F4FD46A) begin
      $error("LW Test 4 Failed! x6 expected 0x7F4FD46A, Got 0x%h", dut.regfile_u.registers[6]);
    end else begin
      $display("LW Test 4 Passed: Register x6 = 0x%h (Expected 0x7F4FD46A)",
               dut.regfile_u.registers[6]);
    end

    $display("---------------------------------------");
    $display("Starting CPU OR Test (x7 = x5 | x6)");
    $display("---------------------------------------");
    @(posedge clk);
    $display("Cycle 8: OR executed");
    if (dut.regfile_u.registers[7] !== 32'h7F5FD56F) begin
      $error("OR Test Failed! x7 expected 0x7F5FD56F, Got 0x%h", dut.regfile_u.registers[7]);
    end else begin
      $display("OR Test Passed: Register x7 = 0x%h (Expected 0x7F5FD56F)",
               dut.regfile_u.registers[7]);
    end

    $display("---------------------------------------");
    $display("Starting CPU NOP Test");
    $display("---------------------------------------");
    @(posedge clk);
    $display("Cycle 9: NOP executed (PC should advance by 4)");
    if (dut.pc !== 32'h00000024) begin
      $error("NOP Test Failed! PC expected 0x00000024, Got 0x%h", dut.pc);
    end else begin
      $display("NOP Test Passed: PC = 0x%h (Expected 0x00000024)", dut.pc);
    end

    $display("---------------------------------------");
    $display("Starting CPU BEQ Test 1 (Not Taken: beq x6, x7, 12)");
    $display("---------------------------------------");
    @(posedge clk);
    $display("Cycle 10: BEQ executed (x6=0x%h, x7=0x%h)", dut.regfile_u.registers[6],
             dut.regfile_u.registers[7]);
    if (dut.pc !== 32'h00000028) begin
      $error("BEQ Test 1 Failed! PC expected 0x00000028 (Not Taken), Got 0x%h", dut.pc);
    end else begin
      $display("BEQ Test 1 Passed: PC = 0x%h (Branch Not Taken)", dut.pc);
    end

    $display("---------------------------------------");
    $display("Starting CPU LW Test 5 (x22 = MEM[x0 + 8])");
    $display("---------------------------------------");
    @(posedge clk);
    $display("Cycle 11: LW executed (Setup for BEQ Test 2)");
    if (dut.regfile_u.registers[22] !== 32'hABCDEF11) begin
      $error("LW Test 5 Failed! x22 expected 0xABCDEF11, Got 0x%h", dut.regfile_u.registers[22]);
    end else begin
      $display("LW Test 5 Passed: Register x22 = 0x%h (Expected 0xABCDEF11)",
               dut.regfile_u.registers[22]);
    end

    $display("---------------------------------------");
    $display("Starting CPU BEQ Test 2 (Taken: beq x18, x22, 16)");
    $display("---------------------------------------");
    @(posedge clk);
    $display("Cycle 12: BEQ executed (x18=0x%h, x22=0x%h)", dut.regfile_u.registers[18],
             dut.regfile_u.registers[22]);
    if (dut.pc !== 32'h0000003C) begin
      $error("BEQ Test 2 Failed! PC expected 0x0000003C (Taken), Got 0x%h", dut.pc);
    end else begin
      $display("BEQ Test 2 Passed: PC = 0x%h (Branch Taken)", dut.pc);
    end

    $display("---------------------------------------");
    $display("Starting CPU LW Test 6 (x22 = MEM[x0 + 0])");
    $display("---------------------------------------");
    @(posedge clk);
    $display("Cycle 13: LW executed");
    if (dut.regfile_u.registers[22] !== 32'hAEAEAEAE) begin
      $error("LW Test 6 Failed! x22 expected 0xAEAEAEAE, Got 0x%h", dut.regfile_u.registers[22]);
    end else begin
      $display("LW Test 6 Passed: Register x22 = 0x%h (Expected 0xAEAEAEAE)",
               dut.regfile_u.registers[22]);
    end

    $display("---------------------------------------");
    $display("Starting CPU BEQ Test 3 (Backward Branch: beq x22, x22, -8)");
    $display("---------------------------------------");
    @(posedge clk);
    $display("Cycle 14: BEQ executed (x22=0x%h, x22=0x%h)", dut.regfile_u.registers[22],
             dut.regfile_u.registers[22]);
    if (dut.pc !== 32'h00000038) begin
      $error("BEQ Test 3 Failed! PC expected 0x00000038 (Backward Branch), Got 0x%h", dut.pc);
    end else begin
      $display("BEQ Test 3 Passed: PC = 0x%h (Backward Branch Taken)", dut.pc);
    end

    $display("---------------------------------------");
    $display("Starting CPU BEQ Test 4 (Jump Out: beq x0, x0, 12)");
    $display("---------------------------------------");
    @(posedge clk);
    $display("Cycle 15: BEQ executed (x0=0x%h, x0=0x%h)", dut.regfile_u.registers[0],
             dut.regfile_u.registers[0]);
    if (dut.pc !== 32'h00000044) begin
      $error("BEQ Test 4 Failed! PC expected 0x00000044 (Jump Out), Got 0x%h", dut.pc);
    end else begin
      $display("BEQ Test 4 Passed: PC = 0x%h (Jump Out of Loop)", dut.pc);
    end

    $display("---------------------------------------");
    $display("Starting CPU NOP Test 2");
    $display("---------------------------------------");
    @(posedge clk);
    $display("Cycle 16: NOP executed (PC should advance by 4)");
    if (dut.pc !== 32'h00000048) begin
      $error("NOP Test 2 Failed! PC expected 0x00000048, Got 0x%h", dut.pc);
    end else begin
      $display("NOP Test 2 Passed: PC = 0x%h (Expected 0x00000048)", dut.pc);
    end

    $display("---------------------------------------");
    $display("Starting CPU JAL Test 1 (Forward Jump: jal x1, 12)");
    $display("---------------------------------------");
    @(posedge clk);
    $display("Cycle 17: JAL executed (Target PC = 0x48 + 12 = 0x54)");
    if (dut.pc !== 32'h00000054) begin
      $error("JAL Test 1 Failed! PC expected 0x00000054, Got 0x%h", dut.pc);
    end else begin
      $display("JAL Test 1 PC Passed: PC = 0x%h (Expected 0x00000054)", dut.pc);
    end
    if (dut.regfile_u.registers[1] !== 32'h0000004C) begin
      $error("JAL Test 1 Link Failed! x1 expected 0x0000004C, Got 0x%h",
             dut.regfile_u.registers[1]);
    end else begin
      $display("JAL Test 1 Link Passed: Register x1 = 0x%h (Expected 0x0000004C)",
               dut.regfile_u.registers[1]);
    end

    $display("---------------------------------------");
    $display("Starting CPU JAL Test 2 (Backward Jump: jal x1, -4)");
    $display("---------------------------------------");
    @(posedge clk);
    $display("Cycle 18: JAL executed (Target PC = 0x54 - 4 = 0x50)");
    if (dut.pc !== 32'h00000050) begin
      $error("JAL Test 2 Failed! PC expected 0x00000050, Got 0x%h", dut.pc);
    end else begin
      $display("JAL Test 2 PC Passed: PC = 0x%h (Expected 0x00000050)", dut.pc);
    end
    if (dut.regfile_u.registers[1] !== 32'h00000058) begin
      $error("JAL Test 2 Link Failed! x1 expected 0x00000058, Got 0x%h",
             dut.regfile_u.registers[1]);
    end else begin
      $display("JAL Test 2 Link Passed: Register x1 = 0x%h (Expected 0x00000058)",
               dut.regfile_u.registers[1]);
    end


    $display("---------------------------------------");
    $display("Starting CPU JAL Test 3 (Jump Out: jal x1, 12)");
    $display("---------------------------------------");
    @(posedge clk);
    $display("Cycle 19: JAL executed (Target PC = 0x50 + 12 = 0x5C)");
    if (dut.pc !== 32'h0000005C) begin
      $error("JAL Test 3 Failed! PC expected 0x0000005C, Got 0x%h", dut.pc);
    end else begin
      $display("JAL Test 3 Passed: PC = 0x%h (Jump Out of Loop)", dut.pc);
    end

    $display("---------------------------------------");
    $display("Starting CPU LW Test 7 (Post-JAL: x7 = MEM[x0 + 12])");
    $display("---------------------------------------");
    @(posedge clk);
    $display("Cycle 20: LW executed");
    if (dut.regfile_u.registers[7] !== 32'hABCDEF11) begin
      $error("LW Test 7 Failed! x7 expected 0xABCDEF11, Got 0x%h", dut.regfile_u.registers[7]);
    end else begin
      $display("LW Test 7 Passed: Register x7 = 0x%h (Expected 0xABCDEF11)",
               dut.regfile_u.registers[7]);
    end

    $display("---------------------------------------");
    $display("Starting CPU NOP Test 3");
    $display("---------------------------------------");
    @(posedge clk);
    $display("Cycle 21: NOP executed (PC should advance by 4)");
    if (dut.pc !== 32'h00000064) begin
      $error("NOP Test 3 Failed! PC expected 0x00000064, Got 0x%h", dut.pc);
    end else begin
      $display("NOP Test 3 Passed: PC = 0x%h (Expected 0x00000064)", dut.pc);
    end

    $display("---------------------------------------");
    $display("Starting CPU LW Test 8 (ADDI Prep: x18 = MEM[x0 + 0])");
    $display("---------------------------------------");
    @(posedge clk);
    $display("Cycle 22: LW executed");
    if (dut.regfile_u.registers[18] !== 32'hAEAEAEAE) begin
      $error("LW Test 8 Failed! x18 expected 0xAEAEAEAE, Got 0x%h", dut.regfile_u.registers[18]);
    end else begin
      $display("LW Test 8 Passed: Register x18 = 0x%h (Expected 0xAEAEAEAE)",
               dut.regfile_u.registers[18]);
    end

    $display("---------------------------------------");
    $display("Starting CPU ADDI Test (x23 = x18 + 0x0BC)");
    $display("---------------------------------------");
    @(posedge clk);
    $display("Cycle 23: ADDI executed");
    if (dut.regfile_u.registers[23] !== 32'hAEAEAF6A) begin
      $error("ADDI Test Failed! x23 expected 0xAEAEAF6A, Got 0x%h", dut.regfile_u.registers[23]);
    end else begin
      $display("ADDI Test Passed: Register x23 = 0x%h (Expected 0xAEAEAF6A)",
               dut.regfile_u.registers[23]);
    end

    @(posedge clk);

    $display("---------------------------------------");
    $display("Starting CPU AUIPC Test (auipc x5, 0x12345)");
    $display("---------------------------------------");
    @(posedge clk);
    $display("Cycle 25: AUIPC executed");
    if (dut.regfile_u.registers[5] !== 32'h12345070) begin
      $error("AUIPC Fail: x5 expected 0x12345070, Got %h", dut.regfile_u.registers[5]);
    end else begin
      $display("AUIPC Test Passed: x5 = %h", dut.regfile_u.registers[5]);
    end

    $display("---------------------------------------");
    $display("Starting CPU LUI Test (lui x5, 0xABCDE)");
    $display("---------------------------------------");
    @(posedge clk);
    $display("Cycle 26: LUI executed");
    if (dut.regfile_u.registers[5] !== 32'hABCDE000) begin
      $error("LUI Fail: x5 expected 0xABCDE000, Got %h", dut.regfile_u.registers[5]);
    end else begin
      $display("LUI Test Passed: x5 = %h", dut.regfile_u.registers[5]);
    end

    @(posedge clk);
    $display("---------------------------------------");
    $display("CPU Tests Completed Successfully");
    $display("---------------------------------------");
    $finish;
  end

endmodule



