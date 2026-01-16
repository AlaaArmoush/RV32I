`timescale 1ns / 1ps

module control_tb;
  //main decoder inputs
  logic [6:0] op_code;
  logic zero;
  //outputs
  logic mem_write, reg_write, alu_source, result_source;
  logic [2:0] imm_type;
  //alu decoder inputs
  logic [2:0] func3;
  logic [6:0] func7;
  //outputs
  logic [2:0] alu_control;
  logic pc_src;
  control dut (
      .op_code(op_code),
      .zero(zero),
      .mem_write(mem_write),
      .reg_write(reg_write),
      .alu_source(alu_source),
      .result_source(result_source),
      .imm_type(imm_type),
      .func3(func3),
      .func7(func7),
      .alu_control(alu_control),
      .pc_src(pc_src)
  );
  initial begin
    $display("---------------------------------------");
    $display("Starting Control Unit Verification");
    $display("---------------------------------------");
    op_code = 7'b0;
    zero    = 1'b0;
    func3   = 3'b0;
    func7   = 7'b0;
    #1;
    $display("Test 1: LW Instruction (op_code=0000011)");
    op_code = 7'b0000011;
    #1;
    if (imm_type !== 3'b000) $error("LW Failed: imm_type expected 000, got %b", imm_type);
    if (mem_write !== 1'b0) $error("LW Failed: mem_write expected 0, got %b", mem_write);
    if (reg_write !== 1'b1) $error("LW Failed: reg_write expected 1, got %b", reg_write);
    if (alu_source !== 1'b1) $error("LW Failed: alu_source expected 1, got %b", alu_source);
    if (result_source !== 1'b1)
      $error("LW Failed: result_source expected 1, got %b", result_source);
    if (alu_control !== 3'b000)
      $error("LW Failed: alu_control expected 000 (ADD), got %b", alu_control);
    $display("LW Test Passed.");

    $display("Test 2: SW Instruction (op_code = 0100011)");
    op_code = 7'b0100011;
    #1;
    if (imm_type !== 3'b001) $error("SW Failed: imm_type expected 001, got %b", imm_type);
    if (mem_write !== 1'b1) $error("SW Failed: mem_write expected 1, got %b", mem_write);
    if (reg_write !== 1'b0) $error("SW Failed: reg_write expected 0, got %b", reg_write);
    if (alu_source !== 1'b1) $error("SW Failed: alu_source expected 1, got %b", alu_source);
    if (alu_control !== 3'b000)
      $error("SW Failed: alu_control expected 000 (ADD + Base), got %b", alu_control);
    $display("SW Test Passed.");

    $display("Test 3: ADD Instruction (op_code=0110011, func3=000)");
    op_code = 7'b0110011;
    func3   = 3'b000;
    #1;
    if (mem_write !== 1'b0) $error("ADD Failed: mem_write expected 0, got %b", mem_write);
    if (reg_write !== 1'b1) $error("ADD Failed: reg_write expected 1, got %b", reg_write);
    if (alu_source !== 1'b0) $error("ADD Failed: alu_source expected 0, got %b", alu_source);
    if (result_source !== 1'b0)
      $error("ADD Failed: result_source expected 0, got %b", result_source);
    if (alu_control !== 3'b000)
      $error("ADD Failed: alu_control expected 000 (ADD), got %b", alu_control);
    $display("ADD Test Passed.");

    $display("Test 4: AND Instruction (op_code=0110011, func3=111)");
    op_code = 7'b0110011;
    func3   = 3'b111;
    #1;
    if (mem_write !== 1'b0) $error("AND Failed: mem_write expected 0, got %b", mem_write);
    if (reg_write !== 1'b1) $error("AND Failed: reg_write expected 1, got %b", reg_write);
    if (alu_source !== 1'b0) $error("AND Failed: alu_source expected 0, got %b", alu_source);
    if (result_source !== 1'b0)
      $error("AND Failed: result_source expected 0, got %b", result_source);
    if (alu_control !== 3'b010)
      $error("AND Failed: alu_control expected 010 (AND), got %b", alu_control);
    $display("AND Test Passed.");

    $display("Test 5: OR Instruction (op_code=0110011)");
    op_code = 7'b0110011;
    func3   = 3'b110;
    #1;
    if (mem_write !== 1'b0) $error("OR Failed: mem_write expected 0, got %b", mem_write);
    if (reg_write !== 1'b1) $error("OR Failed: reg_write expected 1, got %b", reg_write);
    if (alu_source !== 1'b0) $error("OR Failed: alu_source expected 0, got %b", alu_source);
    if (result_source !== 1'b0)
      $error("OR Failed: result_source expected 0, got %b", result_source);
    if (alu_control !== 3'b011)
      $error("OR Failed: alu_control expected 011 (OR), got %b", alu_control);
    $display("OR Test Passed.");

    $display("Test 6.1: BEQ Instruction (op_code=1100011, zero=0) Branch Not Taken");
    op_code = 7'b1100011;
    zero = 0;
    #1;
    if (imm_type !== 3'b010) $error("BEQ Imm Type Fail");
    if (alu_control !== 3'b001) $error("BEQ ALU Control Fail (Expected SUB)");
    if (mem_write !== 0 || reg_write !== 0) $error("BEQ Mem/Reg Write Fail");
    if (alu_source !== 0) $error("BEQ ALU Source Fail (Expected Reg)");
    if (pc_src !== 0) $error("BEQ PC Source Fail (Expected 0 - Not Taken)");

    $display("Test 6.2: BEQ (Branch Taken)");
    zero = 1;  // Condition Met
    #1;
    if (pc_src !== 1) $error("BEQ PC Source Fail (Expected 1 - Taken)");
    $display("BEQ Test Passed.");

    $display("---------------------------------------");
    $display("Control Unit Tests All Passed Successfuly");
    $display("---------------------------------------");
    $finish;
  end
endmodule

