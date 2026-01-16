`timescale 1ns / 1ps
module alu_tb;
  logic [31:0] src1, src2, alu_result;
  logic [2:0] alu_control;
  logic zero;
  logic last_bit;
  alu dut (
      .src1(src1),
      .src2(src2),
      .alu_control(alu_control),
      .alu_result(alu_result),
      .zero(zero),
      .last_bit(last_bit)
  );
  logic [31:0] rand_src1, rand_src2, expected;
  initial begin
    $display("Test 1: ADD Operation (1000 iter)");
    alu_control = 3'b000;
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
    alu_control = 3'b010;
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
    alu_control = 3'b011;
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
    alu_control = 3'b111;
    rand_src1 = $urandom();
    rand_src2 = $urandom();
    src1 = rand_src1;
    src2 = rand_src2;
    #1;
    if (alu_result !== 32'b0) $error("Default Failed! Expected 0, Got %h", alu_result);

    $display("Test 5: Zero flag");
    alu_control = 3'b000;
    src1 = 32'd12345;
    src2 = -32'd12345;
    #1;
    if (alu_result !== 0) $error("Zero logic math failed! 12345 + (-12345) = %d", alu_result);
    if (zero !== 1'b1) $error("Zero Flag Failed! Result is 0 but zero flag is %b", zero);

    $display("Test 6: SUB");
    alu_control = 3'b001;
    for (int i = 0; i < 1000; i++) begin
      rand_src1 = $urandom();
      rand_src2 = $urandom();
      src1 = rand_src1;
      src2 = rand_src2;
      #1;
      expected = src1 - src2;
      if (alu_result !== expected)
        $error("SUB Failed! %h | %h = %h (Expected %h)", src1, src2, alu_result, expected);
    end


    $display("---------------------------------------");
    $display("ALU Tests passed successfully");
    $display("---------------------------------------");
    $finish;
  end
endmodule


