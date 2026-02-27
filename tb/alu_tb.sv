`timescale 1ns / 1ps

module alu_tb;
  logic [31:0] src1, src2, alu_result;
  logic [4:0] shamt;
  logic [3:0] alu_control;
  logic       zero;
  logic       last_bit;

  alu dut (
      .src1(src1),
      .src2(src2),
      .shamt(shamt),
      .alu_control(alu_control),
      .alu_result(alu_result),
      .zero(zero),
      .last_bit(last_bit)
  );

  logic [31:0] rand_src1, rand_src2, expected;
  logic [4:0] rand_shamt;

  initial begin
    shamt = 5'b0;

    $display("Test 1: ADD Operation (1000 iter)");
    alu_control = 4'b0000;
    for (int i = 0; i < 1000; i++) begin
      rand_src1 = $urandom();
      rand_src2 = $urandom();
      src1 = rand_src1;
      src2 = rand_src2;
      #1;
      expected = src1 + src2;
      if (alu_result !== expected)
        $error("ADD Failed! %d + %d = %d (Expected %d)", src1, src2, alu_result, expected);
    end

    $display("Test 2: AND Operation (1000 iter)");
    alu_control = 4'b0010;
    for (int i = 0; i < 1000; i++) begin
      rand_src1 = $urandom();
      rand_src2 = $urandom();
      src1 = rand_src1;
      src2 = rand_src2;
      #1;
      expected = src1 & src2;
      if (alu_result !== expected)
        $error("AND Failed! %h & %h = %h (Expected %h)", src1, src2, alu_result, expected);
    end

    $display("Test 3: OR Operation (1000 iter)");
    alu_control = 4'b0011;
    for (int i = 0; i < 1000; i++) begin
      rand_src1 = $urandom();
      rand_src2 = $urandom();
      src1 = rand_src1;
      src2 = rand_src2;
      #1;
      expected = src1 | src2;
      if (alu_result !== expected)
        $error("OR Failed! %h | %h = %h (Expected %h)", src1, src2, alu_result, expected);
    end

    $display("Test 4: Default Operation");
    alu_control = 4'b1111;
    rand_src1 = $urandom();
    rand_src2 = $urandom();
    src1 = rand_src1;
    src2 = rand_src2;
    #1;
    if (alu_result !== 32'b0) $error("Default Failed! Expected 0, Got %h", alu_result);

    $display("Test 5: Zero flag");
    alu_control = 4'b0000;
    src1 = 32'd12345;
    src2 = -32'd12345;
    #1;
    if (alu_result !== 0) $error("Zero logic math failed! 12345 + (-12345) = %d", alu_result);
    if (zero !== 1'b1) $error("Zero Flag Failed! Result is 0 but zero flag is %b", zero);

    $display("Test 6: SUB");
    alu_control = 4'b0001;
    for (int i = 0; i < 1000; i++) begin
      rand_src1 = $urandom();
      rand_src2 = $urandom();
      src1 = rand_src1;
      src2 = rand_src2;
      #1;
      expected = src1 - src2;
      if (alu_result !== expected)
        $error("SUB Failed! %h - %h = %h (Expected %h)", src1, src2, alu_result, expected);
    end

    $display("Test 7: Less Than Comparison (signed)");
    alu_control = 4'b0101;
    for (int i = 0; i < 1000; i++) begin
      rand_src1 = $urandom();
      rand_src2 = $urandom();
      src1 = rand_src1;
      src2 = rand_src2;
      #1;
      expected = {31'b0, $signed(src1) < $signed(src2)};
      if (alu_result !== expected)
        $error("SLT Failed! %h < %h = %h (Expected %h)", src1, src2, alu_result, expected);
    end

    $display("Test 8: Less Than Comparison (unsigned)");
    alu_control = 4'b0111;
    for (int i = 0; i < 1000; i++) begin
      rand_src1 = $urandom();
      rand_src2 = $urandom();
      src1 = rand_src1;
      src2 = rand_src2;
      #1;
      expected = {31'b0, src1 < src2};
      if (alu_result !== expected)
        $error("SLTU Failed! %h < %h = %h (Expected %h)", src1, src2, alu_result, expected);
    end

    $display("Test 9: XOR");
    alu_control = 4'b1000;
    for (int i = 0; i < 1000; i++) begin
      rand_src1 = $urandom();
      rand_src2 = $urandom();
      src1 = rand_src1;
      src2 = rand_src2;
      #1;
      expected = src1 ^ src2;
      if (alu_result !== expected)
        $error("XOR Failed! %h ^ %h = %h (Expected %h)", src1, src2, alu_result, expected);
    end

    $display("Test 10: SLL (1000 iter)");
    alu_control = 4'b0100;
    for (int i = 0; i < 1000; i++) begin
      rand_src1 = $urandom();
      rand_shamt = $urandom() % 32;
      src1 = rand_src1;
      shamt = rand_shamt;
      #1;
      expected = src1 << shamt;
      if (alu_result !== expected)
        $error("SLL Failed! %h << %0d = %h (Expected %h)", src1, shamt, alu_result, expected);
    end

    $display("Test 11: SRL (1000 iter)");
    alu_control = 4'b0110;
    for (int i = 0; i < 1000; i++) begin
      rand_src1 = $urandom();
      rand_shamt = $urandom() % 32;
      src1 = rand_src1;
      shamt = rand_shamt;
      #1;
      expected = src1 >> shamt;
      if (alu_result !== expected)
        $error("SRL Failed! %h >> %0d = %h (Expected %h)", src1, shamt, alu_result, expected);
    end

    $display("Test 12: SRA (1000 iter)");
    alu_control = 4'b1001;
    for (int i = 0; i < 1000; i++) begin
      rand_src1 = $urandom();
      rand_shamt = $urandom() % 32;
      src1 = rand_src1;
      shamt = rand_shamt;
      #1;
      expected = $signed(src1) >>> shamt;
      if (alu_result !== expected)
        $error("SRA Failed! %h >>> %0d = %h (Expected %h)", src1, shamt, alu_result, expected);
    end

    $display("Test 13: SRA sign extension check");
    alu_control = 4'b1001;
    src1 = 32'h80000000;  // most negative, MSB=1
    shamt = 5'd4;
    #1;
    expected = $signed(src1) >>> 4;  // should fill upper bits with 1s
    if (alu_result !== expected)
      $error("SRA Sign Ext Failed! %h >>> 4 = %h (Expected %h)", src1, alu_result, expected);

    $display("---------------------------------------");
    $display("ALU Tests passed successfully");
    $display("---------------------------------------");
    $finish;
  end
endmodule

