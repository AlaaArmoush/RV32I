`timescale 1ns / 1ps

module alu_tb;
  localparam int RANDOM_TESTS_PER_OP = 500;

  localparam logic [3:0] ALU_ADD     = 4'b0000;
  localparam logic [3:0] ALU_SUB     = 4'b0001;
  localparam logic [3:0] ALU_AND     = 4'b0010;
  localparam logic [3:0] ALU_OR      = 4'b0011;
  localparam logic [3:0] ALU_SLL     = 4'b0100;
  localparam logic [3:0] ALU_SLT     = 4'b0101;
  localparam logic [3:0] ALU_SRL     = 4'b0110;
  localparam logic [3:0] ALU_SLTU    = 4'b0111;
  localparam logic [3:0] ALU_XOR     = 4'b1000;
  localparam logic [3:0] ALU_SRA     = 4'b1001;
  localparam logic [3:0] ALU_INVALID = 4'b1111;

  logic [31:0] src1;
  logic [31:0] src2;
  logic [4:0]  shamt;
  logic [3:0]  alu_control;
  logic [31:0] alu_result;
  logic        zero;
  logic        last_bit;

  int error_count = 0;
  int total_checks = 0;
  int passed_checks = 0;
  int directed_checks = 0;
  int random_checks = 0;
  int zero_checks = 0;
  int last_bit_checks = 0;
  int op_hits[16];

  alu dut (
      .src1(src1),
      .src2(src2),
      .shamt(shamt),
      .alu_control(alu_control),
      .alu_result(alu_result),
      .zero(zero),
      .last_bit(last_bit)
  );

  function automatic logic [31:0] expected_alu(
      input logic [31:0] src1_in,
      input logic [31:0] src2_in,
      input logic [4:0]  shamt_in,
      input logic [3:0]  alu_control_in
  );
    case (alu_control_in)
      ALU_ADD:     expected_alu = src1_in + src2_in;
      ALU_SUB:     expected_alu = src1_in - src2_in;
      ALU_AND:     expected_alu = src1_in & src2_in;
      ALU_OR:      expected_alu = src1_in | src2_in;
      ALU_SLL:     expected_alu = src1_in << shamt_in;
      ALU_SLT:     expected_alu = {31'b0, $signed(src1_in) < $signed(src2_in)};
      ALU_SRL:     expected_alu = src1_in >> shamt_in;
      ALU_SLTU:    expected_alu = {31'b0, src1_in < src2_in};
      ALU_XOR:     expected_alu = src1_in ^ src2_in;
      ALU_SRA:     expected_alu = $signed(src1_in) >>> shamt_in;
      default:     expected_alu = 32'b0;
    endcase
  endfunction

  function automatic string op_name(input logic [3:0] op);
    case (op)
      ALU_ADD:     op_name = "ADD";
      ALU_SUB:     op_name = "SUB";
      ALU_AND:     op_name = "AND";
      ALU_OR:      op_name = "OR";
      ALU_SLL:     op_name = "SLL";
      ALU_SLT:     op_name = "SLT";
      ALU_SRL:     op_name = "SRL";
      ALU_SLTU:    op_name = "SLTU";
      ALU_XOR:     op_name = "XOR";
      ALU_SRA:     op_name = "SRA";
      ALU_INVALID: op_name = "INVALID";
      default:     op_name = "UNKNOWN";
    endcase
  endfunction

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

  task automatic check_eq1(
      input string label,
      input logic got,
      input logic expected
  );
    total_checks++;
    if (got !== expected) begin
      $error("%s failed: expected %b, got %b", label, expected, got);
      error_count++;
    end else begin
      passed_checks++;
    end
  endtask

  task automatic run_case(
      input string label,
      input logic [31:0] src1_in,
      input logic [31:0] src2_in,
      input logic [4:0]  shamt_in,
      input logic [3:0]  alu_control_in,
      input bit          is_random = 1'b0
  );
    logic [31:0] expected;

    src1 = src1_in;
    src2 = src2_in;
    shamt = shamt_in;
    alu_control = alu_control_in;
    #1;

    expected = expected_alu(src1_in, src2_in, shamt_in, alu_control_in);
    op_hits[alu_control_in]++;

    if (is_random) random_checks++;
    else directed_checks++;

    check_eq32({label, " ", op_name(alu_control_in), " result"}, alu_result, expected);

    zero_checks++;
    check_eq1({label, " ", op_name(alu_control_in), " zero"}, zero, expected == 32'b0);

    last_bit_checks++;
    check_eq1({label, " ", op_name(alu_control_in), " last_bit"}, last_bit, expected[0]);
  endtask

  task automatic run_directed_corner_tests();
    logic [31:0] values[5];
    logic [4:0] shift_values[3];

    $display("---------------------------------------");
    $display("Running directed ALU corner tests");
    $display("---------------------------------------");

    values[0] = 32'h0000_0000;
    values[1] = 32'h0000_0001;
    values[2] = 32'hFFFF_FFFF;
    values[3] = 32'h8000_0000;
    values[4] = 32'h7FFF_FFFF;

    shift_values[0] = 5'd0;
    shift_values[1] = 5'd1;
    shift_values[2] = 5'd31;

    foreach (values[i]) begin
      foreach (values[j]) begin
        run_case("directed", values[i], values[j], 5'd0, ALU_ADD);
        run_case("directed", values[i], values[j], 5'd0, ALU_SUB);
        run_case("directed", values[i], values[j], 5'd0, ALU_AND);
        run_case("directed", values[i], values[j], 5'd0, ALU_OR);
        run_case("directed", values[i], values[j], 5'd0, ALU_XOR);
        run_case("directed", values[i], values[j], 5'd0, ALU_SLT);
        run_case("directed", values[i], values[j], 5'd0, ALU_SLTU);
      end
    end

    foreach (values[i]) begin
      foreach (shift_values[j]) begin
        run_case("directed shift", values[i], 32'b0, shift_values[j], ALU_SLL);
        run_case("directed shift", values[i], 32'b0, shift_values[j], ALU_SRL);
        run_case("directed shift", values[i], 32'b0, shift_values[j], ALU_SRA);
      end
    end

    run_case("signed negative less than positive", 32'h8000_0000, 32'h0000_0001, 5'd0, ALU_SLT);
    run_case("unsigned max greater than one", 32'hFFFF_FFFF, 32'h0000_0001, 5'd0, ALU_SLTU);
    run_case("invalid op", 32'h1234_5678, 32'hCAFE_BABE, 5'd7, ALU_INVALID);
  endtask

  task automatic run_random_tests();
    int unsigned seed;
    logic [3:0] valid_ops[10];

    $display("---------------------------------------");
    $display("Running deterministic random ALU tests");
    $display("---------------------------------------");

    seed = 32'hA1A2_2026;
    void'($urandom(seed));

    valid_ops[0] = ALU_ADD;
    valid_ops[1] = ALU_SUB;
    valid_ops[2] = ALU_AND;
    valid_ops[3] = ALU_OR;
    valid_ops[4] = ALU_SLL;
    valid_ops[5] = ALU_SLT;
    valid_ops[6] = ALU_SRL;
    valid_ops[7] = ALU_SLTU;
    valid_ops[8] = ALU_XOR;
    valid_ops[9] = ALU_SRA;

    foreach (valid_ops[op_index]) begin
      for (int i = 0; i < RANDOM_TESTS_PER_OP; i++) begin
        run_case("random",
                 $urandom(),
                 $urandom(),
                 $urandom_range(0, 31),
                 valid_ops[op_index],
                 1'b1);
      end
    end
  endtask

  task automatic check_coverage();
    logic [3:0] expected_ops[11];

    expected_ops[0] = ALU_ADD;
    expected_ops[1] = ALU_SUB;
    expected_ops[2] = ALU_AND;
    expected_ops[3] = ALU_OR;
    expected_ops[4] = ALU_SLL;
    expected_ops[5] = ALU_SLT;
    expected_ops[6] = ALU_SRL;
    expected_ops[7] = ALU_SLTU;
    expected_ops[8] = ALU_XOR;
    expected_ops[9] = ALU_SRA;
    expected_ops[10] = ALU_INVALID;

    foreach (expected_ops[i]) begin
      if (op_hits[expected_ops[i]] == 0) begin
        $error("Coverage missing for ALU op %s", op_name(expected_ops[i]));
        error_count++;
      end
    end
  endtask

  task automatic finish_report();
    $display("---------------------------------------");
    $display("ALU TB summary");
    $display("  Directed cases     : %0d", directed_checks);
    $display("  Random cases       : %0d", random_checks);
    $display("  Zero flag checks   : %0d", zero_checks);
    $display("  Last bit checks    : %0d", last_bit_checks);
    $display("  Total checks       : %0d", total_checks);
    $display("  Passed checks      : %0d", passed_checks);
    $display("  Failed checks      : %0d", error_count);
    $display("---------------------------------------");
    $display("Operation coverage");
    $display("  ADD                : %0d", op_hits[ALU_ADD]);
    $display("  SUB                : %0d", op_hits[ALU_SUB]);
    $display("  AND                : %0d", op_hits[ALU_AND]);
    $display("  OR                 : %0d", op_hits[ALU_OR]);
    $display("  SLL                : %0d", op_hits[ALU_SLL]);
    $display("  SLT                : %0d", op_hits[ALU_SLT]);
    $display("  SRL                : %0d", op_hits[ALU_SRL]);
    $display("  SLTU               : %0d", op_hits[ALU_SLTU]);
    $display("  XOR                : %0d", op_hits[ALU_XOR]);
    $display("  SRA                : %0d", op_hits[ALU_SRA]);
    $display("  INVALID            : %0d", op_hits[ALU_INVALID]);
    $display("---------------------------------------");

    if (error_count == 0) begin
      $display("alu_tb PASSED");
      $finish;
    end else begin
      $fatal(1, "alu_tb FAILED with %0d error(s)", error_count);
    end
  endtask

  initial begin
    src1 = 32'b0;
    src2 = 32'b0;
    shamt = 5'b0;
    alu_control = ALU_ADD;
    #1;

    run_directed_corner_tests();
    run_random_tests();
    check_coverage();
    finish_report();
  end
endmodule
