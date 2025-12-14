module control_tb;
  //main decoder inputs
  logic [6:0] op_code;
  logic zero;
  //outputs
  logic mem_write, reg_write;
  logic [2:0] imm_type;

  //alu decoder inputs
  logic [2:0] func3;
  logic [6:0] func7;
  //outputs
  logic [2:0] alu_control;

  control dut (
      .op_code(op_code),
      .zero(zero),
      .mem_write(mem_write),
      .reg_write(reg_write),
      .imm_type(imm_type),
      .func3(func3),
      .func7(func7),
      .alu_control(alu_control)
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
    if (alu_control !== 3'b000)
      $error("LW Failed: alu_control expected 000 (ADD), got %b", alu_control);

    $display("LW Test Passed.");

    $display("Test 2: SW Instruction (op_code = 0100011)");
    op_code = 7'b0100011;

    #1;

    if (imm_type !== 3'b001) $error("SW Failed: imm_type expected 001, got %b", imm_type);
    if (mem_write !== 1'b1) $error("SW Failed: mem_write expected 1, got %b", mem_write);
    if (reg_write !== 1'b0) $error("SW Failed: reg_write expected 0, got %b", reg_write);
    if (alu_control !== 3'b000)
      $error("SW Failed: alu_control expected 000 (ADD + Base), got %b", alu_control);

    $display("SW Test Passed.");

    $display("---------------------------------------");
    $display("Control Unit Tests All Passed Successfuly");
    $display("---------------------------------------");
    $finish;
  end
endmodule
