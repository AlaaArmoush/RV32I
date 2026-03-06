`timescale 1ns / 1ps

module control_tb;
  logic [6:0] op_code;
  logic       zero;
  logic       last_bit;  // NEW
  logic mem_write, reg_write, reg_write_gated, alu_source;
  logic [1:0] result_source;
  logic [2:0] imm_type;
  logic [2:0] func3;
  logic [6:0] func7;
  logic [3:0] alu_control;
  logic       pc_src;
  logic [1:0] addr_base_src;

  control dut (
      .op_code        (op_code),
      .zero           (zero),
      .last_bit       (last_bit),         // NEW
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

  initial begin
    $display("---------------------------------------");
    $display("Starting Control Unit Verification");
    $display("---------------------------------------");
    op_code  = 7'b0;
    zero     = 1'b0;
    last_bit = 1'b0;  // NEW
    func3    = 3'b0;
    func7    = 7'b0;
    #1;

    $display("Test 1: LW Instruction (op_code=0000011)");
    op_code = 7'b0000011;
    #1;
    if (imm_type !== 3'b000) $error("LW Failed: imm_type expected 000, got %b", imm_type);
    if (mem_write !== 1'b0) $error("LW Failed: mem_write expected 0, got %b", mem_write);
    if (reg_write !== 1'b1) $error("LW Failed: reg_write expected 1, got %b", reg_write);
    if (alu_source !== 1'b1) $error("LW Failed: alu_source expected 1, got %b", alu_source);
    if (result_source !== 2'b01)
      $error("LW Failed: result_source expected 01, got %b", result_source);
    if (alu_control !== 4'b0000)
      $error("LW Failed: alu_control expected 0000, got %b", alu_control);
    $display("LW Test Passed.");

    $display("Test 2: SW Instruction (op_code=0100011)");
    op_code = 7'b0100011;
    #1;
    if (imm_type !== 3'b001) $error("SW Failed: imm_type expected 001, got %b", imm_type);
    if (mem_write !== 1'b1) $error("SW Failed: mem_write expected 1, got %b", mem_write);
    if (reg_write !== 1'b0) $error("SW Failed: reg_write expected 0, got %b", reg_write);
    if (alu_source !== 1'b1) $error("SW Failed: alu_source expected 1, got %b", alu_source);
    if (alu_control !== 4'b0000)
      $error("SW Failed: alu_control expected 0000, got %b", alu_control);
    $display("SW Test Passed.");

    $display("Test 3: ADD Instruction (op_code=0110011, func3=000, func7=0000000)");
    op_code = 7'b0110011;
    func3   = 3'b000;
    func7   = 7'b0000000;
    #1;
    if (mem_write !== 1'b0) $error("ADD Failed: mem_write expected 0, got %b", mem_write);
    if (reg_write !== 1'b1) $error("ADD Failed: reg_write expected 1, got %b", reg_write);
    if (alu_source !== 1'b0) $error("ADD Failed: alu_source expected 0, got %b", alu_source);
    if (result_source !== 2'b00)
      $error("ADD Failed: result_source expected 00, got %b", result_source);
    if (alu_control !== 4'b0000)
      $error("ADD Failed: alu_control expected 0000, got %b", alu_control);
    $display("ADD Test Passed.");

    $display("Test 3b: SUB Instruction (op_code=0110011, func3=000, func7=0100000)");
    op_code = 7'b0110011;
    func3   = 3'b000;
    func7   = 7'b0100000;
    #1;
    if (alu_control !== 4'b0001)
      $error("SUB Failed: alu_control expected 0001, got %b", alu_control);
    if (reg_write !== 1'b1) $error("SUB Failed: reg_write expected 1, got %b", reg_write);
    $display("SUB Test Passed.");

    $display("Test 4: AND Instruction (op_code=0110011, func3=111)");
    op_code = 7'b0110011;
    func3   = 3'b111;
    func7   = 7'b0;
    #1;
    if (mem_write !== 1'b0) $error("AND Failed: mem_write expected 0, got %b", mem_write);
    if (reg_write !== 1'b1) $error("AND Failed: reg_write expected 1, got %b", reg_write);
    if (alu_source !== 1'b0) $error("AND Failed: alu_source expected 0, got %b", alu_source);
    if (alu_control !== 4'b0010)
      $error("AND Failed: alu_control expected 0010, got %b", alu_control);
    $display("AND Test Passed.");

    $display("Test 5: OR Instruction (op_code=0110011, func3=110)");
    op_code = 7'b0110011;
    func3   = 3'b110;
    #1;
    if (mem_write !== 1'b0) $error("OR Failed: mem_write expected 0, got %b", mem_write);
    if (reg_write !== 1'b1) $error("OR Failed: reg_write expected 1, got %b", reg_write);
    if (alu_source !== 1'b0) $error("OR Failed: alu_source expected 0, got %b", alu_source);
    if (alu_control !== 4'b0011)
      $error("OR Failed: alu_control expected 0011, got %b", alu_control);
    $display("OR Test Passed.");

    $display("Test 6.1: BEQ Instruction (op_code=1100011, zero=0) Branch Not Taken");
    op_code = 7'b1100011;
    func3   = 3'b000;
    zero    = 0;
    #1;
    if (imm_type !== 3'b010) $error("BEQ Failed: imm_type expected 010, got %b", imm_type);
    if (alu_control !== 4'b0001)
      $error("BEQ Failed: alu_control expected 0001, got %b", alu_control);
    if (mem_write !== 0 || reg_write !== 0) $error("BEQ Failed: mem_write/reg_write expected 0");
    if (alu_source !== 0) $error("BEQ Failed: alu_source expected 0, got %b", alu_source);
    if (pc_src !== 0) $error("BEQ Failed: pc_src expected 0 (not taken), got %b", pc_src);

    $display("Test 6.2: BEQ Branch Taken");
    zero = 1;
    #1;
    if (pc_src !== 1) $error("BEQ Failed: pc_src expected 1 (taken), got %b", pc_src);
    $display("BEQ Test Passed.");

    $display("Test 7: JAL Instruction (op_code=1101111)");
    op_code = 7'b1101111;
    zero    = 0;
    #1;
    if (imm_type !== 3'b011) $error("JAL Failed: imm_type expected 011, got %b", imm_type);
    if (reg_write !== 1'b1) $error("JAL Failed: reg_write expected 1, got %b", reg_write);
    if (result_source !== 2'b10)
      $error("JAL Failed: result_source expected 10, got %b", result_source);
    if (pc_src !== 1'b1) $error("JAL Failed: pc_src expected 1, got %b", pc_src);
    $display("JAL Test Passed.");

    $display("Test 8: ADDI Instruction (op_code=0010011, func3=000)");
    op_code = 7'b0010011;
    func3   = 3'b000;
    func7   = 7'b0;
    #1;
    if (alu_control !== 4'b0000)
      $error("ADDI Failed: alu_control expected 0000, got %b", alu_control);
    if (imm_type !== 3'b000) $error("ADDI Failed: imm_type expected 000, got %b", imm_type);
    if (mem_write !== 1'b0) $error("ADDI Failed: mem_write expected 0, got %b", mem_write);
    if (reg_write !== 1'b1) $error("ADDI Failed: reg_write expected 1, got %b", reg_write);
    if (reg_write_gated !== 1'b1)
      $error("ADDI Failed: reg_write_gated expected 1, got %b", reg_write_gated);
    if (alu_source !== 1'b1) $error("ADDI Failed: alu_source expected 1, got %b", alu_source);
    if (result_source !== 2'b00)
      $error("ADDI Failed: result_source expected 00, got %b", result_source);
    if (pc_src !== 1'b0) $error("ADDI Failed: pc_src expected 0, got %b", pc_src);
    $display("ADDI Test Passed.");

    $display("Test 9: LUI Instruction (op_code=0110111)");
    op_code = 7'b0110111;
    #1;
    if (imm_type !== 3'b100) $error("LUI Failed: imm_type expected 100, got %b", imm_type);
    if (reg_write !== 1'b1) $error("LUI Failed: reg_write expected 1, got %b", reg_write);
    if (addr_base_src !== 2'b01)
      $error("LUI Failed: addr_base_src expected 01, got %b", addr_base_src);
    if (result_source !== 2'b11)
      $error("LUI Failed: result_source expected 11, got %b", result_source);
    $display("LUI Test Passed.");

    $display("Test 10: AUIPC Instruction (op_code=0010111)");
    op_code = 7'b0010111;
    #1;
    if (imm_type !== 3'b100) $error("AUIPC Failed: imm_type expected 100, got %b", imm_type);
    if (addr_base_src !== 2'b00)
      $error("AUIPC Failed: addr_base_src expected 00, got %b", addr_base_src);
    if (result_source !== 2'b11)
      $error("AUIPC Failed: result_source expected 11, got %b", result_source);
    $display("AUIPC Test Passed.");

    $display("Test 11: SLTI Instruction (op_code=0010011, func3=010)");
    op_code = 7'b0010011;
    func3   = 3'b010;
    #1;
    if (alu_control !== 4'b0101)
      $error("SLTI Failed: alu_control expected 0101, got %b", alu_control);
    if (reg_write !== 1'b1) $error("SLTI Failed: reg_write expected 1, got %b", reg_write);
    if (reg_write_gated !== 1'b1)
      $error("SLTI Failed: reg_write_gated expected 1, got %b", reg_write_gated);
    $display("SLTI Test Passed.");

    $display("Test 12: SLTIU Instruction (op_code=0010011, func3=011)");
    op_code = 7'b0010011;
    func3   = 3'b011;
    #1;
    if (alu_control !== 4'b0111)
      $error("SLTIU Failed: alu_control expected 0111, got %b", alu_control);
    if (reg_write !== 1'b1) $error("SLTIU Failed: reg_write expected 1, got %b", reg_write);
    if (reg_write_gated !== 1'b1)
      $error("SLTIU Failed: reg_write_gated expected 1, got %b", reg_write_gated);
    $display("SLTIU Test Passed.");

    $display("Test 13: XORI Instruction (op_code=0010011, func3=100)");
    op_code = 7'b0010011;
    func3   = 3'b100;
    #1;
    if (alu_control !== 4'b1000)
      $error("XORI Failed: alu_control expected 1000, got %b", alu_control);
    if (reg_write !== 1'b1) $error("XORI Failed: reg_write expected 1, got %b", reg_write);
    if (reg_write_gated !== 1'b1)
      $error("XORI Failed: reg_write_gated expected 1, got %b", reg_write_gated);
    if (alu_source !== 1'b1) $error("XORI Failed: alu_source expected 1, got %b", alu_source);
    $display("XORI Test Passed.");

    $display("Test 14: ORI Instruction (op_code=0010011, func3=110)");
    op_code = 7'b0010011;
    func3   = 3'b110;
    #1;
    if (alu_control !== 4'b0011)
      $error("ORI Failed: alu_control expected 0011, got %b", alu_control);
    if (reg_write !== 1'b1) $error("ORI Failed: reg_write expected 1, got %b", reg_write);
    if (reg_write_gated !== 1'b1)
      $error("ORI Failed: reg_write_gated expected 1, got %b", reg_write_gated);
    if (alu_source !== 1'b1) $error("ORI Failed: alu_source expected 1, got %b", alu_source);
    $display("ORI Test Passed.");

    $display("Test 15: ANDI Instruction (op_code=0010011, func3=111)");
    op_code = 7'b0010011;
    func3   = 3'b111;
    #1;
    if (alu_control !== 4'b0010)
      $error("ANDI Failed: alu_control expected 0010, got %b", alu_control);
    if (reg_write !== 1'b1) $error("ANDI Failed: reg_write expected 1, got %b", reg_write);
    if (reg_write_gated !== 1'b1)
      $error("ANDI Failed: reg_write_gated expected 1, got %b", reg_write_gated);
    if (alu_source !== 1'b1) $error("ANDI Failed: alu_source expected 1, got %b", alu_source);
    $display("ANDI Test Passed.");

    $display("Test 16: SLLI (op_code=0010011, func3=001, func7=0000000)");
    op_code = 7'b0010011;
    func3   = 3'b001;
    func7   = 7'b0000000;
    #1;
    if (alu_control !== 4'b0100)
      $error("SLLI Failed: alu_control expected 0100, got %b", alu_control);
    if (reg_write_gated !== 1'b1)
      $error("SLLI Failed: reg_write_gated expected 1, got %b", reg_write_gated);
    if (alu_source !== 1'b1) $error("SLLI Failed: alu_source expected 1, got %b", alu_source);
    $display("SLLI Test Passed.");

    $display("Test 17: SLLI invalid func7 - reg_write_gated must be 0");
    op_code = 7'b0010011;
    func3   = 3'b001;
    func7   = 7'b0100000;
    #1;
    if (reg_write_gated !== 1'b0)
      $error("SLLI Invalid func7 Failed: reg_write_gated expected 0, got %b", reg_write_gated);
    $display("SLLI Invalid func7 Test Passed.");

    $display("Test 18: SRLI (op_code=0010011, func3=101, func7=0000000)");
    op_code = 7'b0010011;
    func3   = 3'b101;
    func7   = 7'b0000000;
    #1;
    if (alu_control !== 4'b0110)
      $error("SRLI Failed: alu_control expected 0110, got %b", alu_control);
    if (reg_write_gated !== 1'b1)
      $error("SRLI Failed: reg_write_gated expected 1, got %b", reg_write_gated);
    if (alu_source !== 1'b1) $error("SRLI Failed: alu_source expected 1, got %b", alu_source);
    $display("SRLI Test Passed.");

    $display("Test 19: SRAI (op_code=0010011, func3=101, func7=0100000)");
    op_code = 7'b0010011;
    func3   = 3'b101;
    func7   = 7'b0100000;
    #1;
    if (alu_control !== 4'b1001)
      $error("SRAI Failed: alu_control expected 1001, got %b", alu_control);
    if (reg_write_gated !== 1'b1)
      $error("SRAI Failed: reg_write_gated expected 1, got %b", reg_write_gated);
    if (alu_source !== 1'b1) $error("SRAI Failed: alu_source expected 1, got %b", alu_source);
    $display("SRAI Test Passed.");

    $display("Test 20: SRL/SRA invalid func7 - reg_write_gated must be 0");
    op_code = 7'b0010011;
    func3   = 3'b101;
    func7   = 7'b0000001;
    #1;
    if (reg_write_gated !== 1'b0)
      $error("SRLI/SRAI Invalid func7 Failed: reg_write_gated expected 0, got %b", reg_write_gated);
    $display("SRL/SRA Invalid func7 Test Passed.");

    // -------------------------------------------------------
    // B-TYPE TESTS
    // -------------------------------------------------------

    $display("Test 21.1: BNE not taken (zero=0 means not equal, but we want taken...)");
    op_code  = 7'b1100011;
    func3    = 3'b001;
    zero     = 1'b1;
    last_bit = 1'b0;
    #1;
    if (alu_control !== 4'b0001)
      $error("BNE Failed: alu_control expected 0001, got %b", alu_control);
    if (pc_src !== 1'b0) $error("BNE Failed: pc_src expected 0 (not taken), got %b", pc_src);

    $display("Test 21.2: BNE taken");
    zero = 1'b0;
    #1;
    if (pc_src !== 1'b1) $error("BNE Failed: pc_src expected 1 (taken), got %b", pc_src);
    $display("BNE Test Passed.");

    $display("Test 22.1: BLT not taken (src1 >= src2)");
    op_code  = 7'b1100011;
    func3    = 3'b100;
    last_bit = 1'b0;
    #1;
    if (alu_control !== 4'b0101)
      $error("BLT Failed: alu_control expected 0101, got %b", alu_control);
    if (pc_src !== 1'b0) $error("BLT Failed: pc_src expected 0 (not taken), got %b", pc_src);

    $display("Test 22.2: BLT taken (src1 < src2)");
    last_bit = 1'b1;
    #1;
    if (pc_src !== 1'b1) $error("BLT Failed: pc_src expected 1 (taken), got %b", pc_src);
    $display("BLT Test Passed.");

    $display("Test 23.1: BGE not taken (src1 < src2)");
    op_code  = 7'b1100011;
    func3    = 3'b101;
    last_bit = 1'b1;
    #1;
    if (alu_control !== 4'b0101)
      $error("BGE Failed: alu_control expected 0101, got %b", alu_control);
    if (pc_src !== 1'b0) $error("BGE Failed: pc_src expected 0 (not taken), got %b", pc_src);

    $display("Test 23.2: BGE taken (src1 >= src2)");
    last_bit = 1'b0;
    #1;
    if (pc_src !== 1'b1) $error("BGE Failed: pc_src expected 1 (taken), got %b", pc_src);
    $display("BGE Test Passed.");

    $display("Test 24.1: BLTU not taken (src1 >= src2 unsigned)");
    op_code  = 7'b1100011;
    func3    = 3'b110;
    last_bit = 1'b0;
    #1;
    if (alu_control !== 4'b0111)
      $error("BLTU Failed: alu_control expected 0111, got %b", alu_control);
    if (pc_src !== 1'b0) $error("BLTU Failed: pc_src expected 0 (not taken), got %b", pc_src);

    $display("Test 24.2: BLTU taken (src1 < src2 unsigned)");
    last_bit = 1'b1;
    #1;
    if (pc_src !== 1'b1) $error("BLTU Failed: pc_src expected 1 (taken), got %b", pc_src);
    $display("BLTU Test Passed.");

    $display("Test 25.1: BGEU not taken (src1 < src2 unsigned)");
    op_code  = 7'b1100011;
    func3    = 3'b111;
    last_bit = 1'b1;
    #1;
    if (alu_control !== 4'b0111)
      $error("BGEU Failed: alu_control expected 0111, got %b", alu_control);
    if (pc_src !== 1'b0) $error("BGEU Failed: pc_src expected 0 (not taken), got %b", pc_src);

    $display("Test 25.2: BGEU taken (src1 >= src2 unsigned)");
    last_bit = 1'b0;
    #1;
    if (pc_src !== 1'b1) $error("BGEU Failed: pc_src expected 1 (taken), got %b", pc_src);
    $display("BGEU Test Passed.");

    $display("---------------------------------------");
    $display("Control Unit Tests All Passed Successfully");
    $display("---------------------------------------");
    $finish;
  end
endmodule

