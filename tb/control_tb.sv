`timescale 1ns / 1ps

module control_tb;
  logic [6:0] op_code;
  logic       zero;
  logic       last_bit;
  logic       mem_write;
  logic       reg_write;
  logic       reg_write_gated;
  logic       alu_source;
  logic [1:0] result_source;
  logic [2:0] imm_type;
  logic [2:0] func3;
  logic [6:0] func7;
  logic [3:0] alu_control;
  logic       pc_src;
  logic [1:0] addr_base_src;

  int error_count = 0;
  int total_checks = 0;
  int passed_checks = 0;
  int valid_vectors = 0;
  int invalid_vectors = 0;
  int branch_vectors = 0;

  typedef struct {
    logic [6:0] op_code;
    logic [2:0] func3;
    logic [6:0] func7;
    logic       zero;
    logic       last_bit;
    logic [2:0] imm_type;
    logic       mem_write;
    logic       reg_write;
    logic       reg_write_gated;
    logic       alu_source;
    logic [1:0] result_source;
    logic       pc_src;
    logic [1:0] addr_base_src;
    logic [3:0] alu_control;
    bit         is_invalid;
    bit         is_branch_case;
    string      name;
  } control_vec_t;

  control dut (
      .op_code        (op_code),
      .zero           (zero),
      .last_bit       (last_bit),
      .mem_write      (mem_write),
      .reg_write      (reg_write),
      .reg_write_gated(reg_write_gated),
      .alu_source     (alu_source),
      .result_source  (result_source),
      .imm_type       (imm_type),
      .func3          (func3),
      .func7          (func7),
      .alu_control    (alu_control),
      .pc_src         (pc_src),
      .addr_base_src  (addr_base_src)
  );

  task automatic check_eq1(input string label, input logic got, input logic expected);
    total_checks++;
    if (got !== expected) begin
      $error("%s failed: expected %b, got %b", label, expected, got);
      error_count++;
    end else begin
      passed_checks++;
    end
  endtask

  task automatic check_eq2(input string label, input logic [1:0] got, input logic [1:0] expected);
    total_checks++;
    if (got !== expected) begin
      $error("%s failed: expected %02b, got %02b", label, expected, got);
      error_count++;
    end else begin
      passed_checks++;
    end
  endtask

  task automatic check_eq3(input string label, input logic [2:0] got, input logic [2:0] expected);
    total_checks++;
    if (got !== expected) begin
      $error("%s failed: expected %03b, got %03b", label, expected, got);
      error_count++;
    end else begin
      passed_checks++;
    end
  endtask

  task automatic check_eq4(input string label, input logic [3:0] got, input logic [3:0] expected);
    total_checks++;
    if (got !== expected) begin
      $error("%s failed: expected %04b, got %04b", label, expected, got);
      error_count++;
    end else begin
      passed_checks++;
    end
  endtask

  task automatic apply_and_check(input control_vec_t vec);
    op_code = vec.op_code;
    func3 = vec.func3;
    func7 = vec.func7;
    zero = vec.zero;
    last_bit = vec.last_bit;
    #1;

    $display("Vector: %s", vec.name);

    check_eq3({vec.name, " imm_type"}, imm_type, vec.imm_type);
    check_eq1({vec.name, " mem_write"}, mem_write, vec.mem_write);
    check_eq1({vec.name, " reg_write"}, reg_write, vec.reg_write);
    check_eq1({vec.name, " reg_write_gated"}, reg_write_gated, vec.reg_write_gated);
    check_eq1({vec.name, " alu_source"}, alu_source, vec.alu_source);
    check_eq2({vec.name, " result_source"}, result_source, vec.result_source);
    check_eq1({vec.name, " pc_src"}, pc_src, vec.pc_src);
    check_eq2({vec.name, " addr_base_src"}, addr_base_src, vec.addr_base_src);
    check_eq4({vec.name, " alu_control"}, alu_control, vec.alu_control);

    if (vec.is_invalid) invalid_vectors++;
    else valid_vectors++;

    if (vec.is_branch_case) branch_vectors++;
  endtask

  task automatic finish_report();
    $display("---------------------------------------");
    $display("Control TB summary");
    $display("  Valid vectors      : %0d", valid_vectors);
    $display("  Invalid vectors    : %0d", invalid_vectors);
    $display("  Branch vectors     : %0d", branch_vectors);
    $display("  Total checks       : %0d", total_checks);
    $display("  Passed checks      : %0d", passed_checks);
    $display("  Failed checks      : %0d", error_count);
    $display("---------------------------------------");

    if (error_count == 0) begin
      $display("control_tb PASSED");
      $finish;
    end else begin
      $fatal(1, "control_tb FAILED with %0d error(s)", error_count);
    end
  endtask

  initial begin
    control_vec_t vec;

    $display("---------------------------------------");
    $display("Starting table-driven control verification");
    $display("---------------------------------------");

    vec = '{7'b0000011, 3'b010, 7'b0000000, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1, 1'b1,
            1'b1, 2'b01, 1'b0, 2'b00, 4'b0000, 1'b0, 1'b0, "LW"};
    apply_and_check(vec);

    vec = '{7'b0000011, 3'b111, 7'b0000000, 1'b0, 1'b0, 3'b000, 1'b0, 1'b0, 1'b0,
            1'b1, 2'b01, 1'b0, 2'b00, 4'b0000, 1'b1, 1'b0, "invalid LOAD funct3"};
    apply_and_check(vec);

    vec = '{7'b0100011, 3'b010, 7'b0000000, 1'b0, 1'b0, 3'b001, 1'b1, 1'b0, 1'b0,
            1'b1, 2'b00, 1'b0, 2'b00, 4'b0000, 1'b0, 1'b0, "SW"};
    apply_and_check(vec);

    vec = '{7'b0100011, 3'b101, 7'b0000000, 1'b0, 1'b0, 3'b001, 1'b0, 1'b0, 1'b0,
            1'b1, 2'b00, 1'b0, 2'b00, 4'b0000, 1'b1, 1'b0, "invalid STORE funct3"};
    apply_and_check(vec);

    vec = '{7'b0110011, 3'b000, 7'b0000000, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1, 1'b1,
            1'b0, 2'b00, 1'b0, 2'b00, 4'b0000, 1'b0, 1'b0, "ADD"};
    apply_and_check(vec);

    vec = '{7'b0110011, 3'b000, 7'b0100000, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1, 1'b1,
            1'b0, 2'b00, 1'b0, 2'b00, 4'b0001, 1'b0, 1'b0, "SUB"};
    apply_and_check(vec);

    vec = '{7'b0110011, 3'b111, 7'b0000000, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1, 1'b1,
            1'b0, 2'b00, 1'b0, 2'b00, 4'b0010, 1'b0, 1'b0, "AND"};
    apply_and_check(vec);

    vec = '{7'b0110011, 3'b110, 7'b0000000, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1, 1'b1,
            1'b0, 2'b00, 1'b0, 2'b00, 4'b0011, 1'b0, 1'b0, "OR"};
    apply_and_check(vec);

    vec = '{7'b0110011, 3'b000, 7'b0000001, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1, 1'b0,
            1'b0, 2'b00, 1'b0, 2'b00, 4'b1111, 1'b1, 1'b0, "invalid R-type funct7"};
    apply_and_check(vec);

    vec = '{7'b0010011, 3'b000, 7'b0000000, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1, 1'b1,
            1'b1, 2'b00, 1'b0, 2'b00, 4'b0000, 1'b0, 1'b0, "ADDI"};
    apply_and_check(vec);

    vec = '{7'b0010011, 3'b001, 7'b0000000, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1, 1'b1,
            1'b1, 2'b00, 1'b0, 2'b00, 4'b0100, 1'b0, 1'b0, "SLLI"};
    apply_and_check(vec);

    vec = '{7'b0010011, 3'b001, 7'b0100000, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1, 1'b0,
            1'b1, 2'b00, 1'b0, 2'b00, 4'b1111, 1'b1, 1'b0, "invalid SLLI funct7"};
    apply_and_check(vec);

    vec = '{7'b0010011, 3'b101, 7'b0000000, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1, 1'b1,
            1'b1, 2'b00, 1'b0, 2'b00, 4'b0110, 1'b0, 1'b0, "SRLI"};
    apply_and_check(vec);

    vec = '{7'b0010011, 3'b101, 7'b0100000, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1, 1'b1,
            1'b1, 2'b00, 1'b0, 2'b00, 4'b1001, 1'b0, 1'b0, "SRAI"};
    apply_and_check(vec);

    vec = '{7'b0110111, 3'b000, 7'b0000000, 1'b0, 1'b0, 3'b100, 1'b0, 1'b1, 1'b1,
            1'b0, 2'b11, 1'b0, 2'b01, 4'b0000, 1'b0, 1'b0, "LUI"};
    apply_and_check(vec);

    vec = '{7'b0010111, 3'b000, 7'b0000000, 1'b0, 1'b0, 3'b100, 1'b0, 1'b1, 1'b1,
            1'b0, 2'b11, 1'b0, 2'b00, 4'b0000, 1'b0, 1'b0, "AUIPC"};
    apply_and_check(vec);

    vec = '{7'b1101111, 3'b000, 7'b0000000, 1'b0, 1'b0, 3'b011, 1'b0, 1'b1, 1'b1,
            1'b0, 2'b10, 1'b1, 2'b00, 4'b0000, 1'b0, 1'b0, "JAL"};
    apply_and_check(vec);

    vec = '{7'b1100111, 3'b000, 7'b0000000, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1, 1'b1,
            1'b0, 2'b10, 1'b1, 2'b10, 4'b0000, 1'b0, 1'b0, "JALR"};
    apply_and_check(vec);

    vec = '{7'b1100111, 3'b001, 7'b0000000, 1'b0, 1'b0, 3'b000, 1'b0, 1'b0, 1'b0,
            1'b0, 2'b00, 1'b0, 2'b00, 4'b0000, 1'b1, 1'b0, "invalid JALR funct3"};
    apply_and_check(vec);

    vec = '{7'b1100011, 3'b000, 7'b0000000, 1'b1, 1'b0, 3'b010, 1'b0, 1'b0, 1'b0,
            1'b0, 2'b00, 1'b1, 2'b00, 4'b0001, 1'b0, 1'b1, "BEQ taken"};
    apply_and_check(vec);

    vec = '{7'b1100011, 3'b000, 7'b0000000, 1'b0, 1'b0, 3'b010, 1'b0, 1'b0, 1'b0,
            1'b0, 2'b00, 1'b0, 2'b00, 4'b0001, 1'b0, 1'b1, "BEQ not taken"};
    apply_and_check(vec);

    vec = '{7'b1100011, 3'b001, 7'b0000000, 1'b0, 1'b0, 3'b010, 1'b0, 1'b0, 1'b0,
            1'b0, 2'b00, 1'b1, 2'b00, 4'b0001, 1'b0, 1'b1, "BNE taken"};
    apply_and_check(vec);

    vec = '{7'b1100011, 3'b100, 7'b0000000, 1'b0, 1'b1, 3'b010, 1'b0, 1'b0, 1'b0,
            1'b0, 2'b00, 1'b1, 2'b00, 4'b0101, 1'b0, 1'b1, "BLT taken"};
    apply_and_check(vec);

    vec = '{7'b1100011, 3'b101, 7'b0000000, 1'b0, 1'b0, 3'b010, 1'b0, 1'b0, 1'b0,
            1'b0, 2'b00, 1'b1, 2'b00, 4'b0101, 1'b0, 1'b1, "BGE taken"};
    apply_and_check(vec);

    vec = '{7'b1100011, 3'b110, 7'b0000000, 1'b0, 1'b1, 3'b010, 1'b0, 1'b0, 1'b0,
            1'b0, 2'b00, 1'b1, 2'b00, 4'b0111, 1'b0, 1'b1, "BLTU taken"};
    apply_and_check(vec);

    vec = '{7'b1100011, 3'b111, 7'b0000000, 1'b0, 1'b0, 3'b010, 1'b0, 1'b0, 1'b0,
            1'b0, 2'b00, 1'b1, 2'b00, 4'b0111, 1'b0, 1'b1, "BGEU taken"};
    apply_and_check(vec);

    finish_report();
  end
endmodule
