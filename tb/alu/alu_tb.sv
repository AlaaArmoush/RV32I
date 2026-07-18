`timescale 1ns / 1ps

module alu_tb;
  import alu_pkg::*;

  logic    [31:0] src1;
  logic    [31:0] src2;
  logic    [ 4:0] shamt;
  alu_op_t        alu_control;
  logic    [31:0] alu_result;
  logic           zero;
  logic           last_bit;

  alu dut (
      .src1       (src1),
      .src2       (src2),
      .shamt      (shamt),
      .alu_control(alu_control),
      .alu_result (alu_result),
      .zero       (zero),
      .last_bit   (last_bit)
  );

  alu_sva u_sva (
      .src1       (src1),
      .src2       (src2),
      .shamt      (shamt),
      .alu_control(alu_control),
      .alu_result (alu_result),
      .zero       (zero),
      .last_bit   (last_bit)
  );

  alu_generator  gen;
  alu_scoreboard sb;
  alu_coverage   cov;

  task automatic apply_and_sample(alu_item it);
    src1        = it.src1;
    src2        = it.src2;
    shamt       = it.shamt;
    alu_control = it.alu_control;
    #1;
    it.alu_result = alu_result;
    it.zero       = zero;
    it.last_bit   = last_bit;
    it.classify_result();
  endtask

  //timeout
  initial begin
    #5_000_000;
    $fatal(1, "[alu_tb] TIMEOUT: simulation did not finish in time");
  end

  initial begin
    src1 = '0;
    src2 = '0;
    shamt = '0;
    alu_control = ALU_ADD;
    #1;

    gen = new();
    sb  = new();
    cov = new();

    gen.run();

    $display("[alu_tb] running %0d transactions ...", gen.items.size());

    foreach (gen.items[i]) begin
      apply_and_sample(gen.items[i]);
      sb.check(gen.items[i]);
      cov.sample(gen.items[i]);
    end

    sb.report();
    $finish;
  end
endmodule
