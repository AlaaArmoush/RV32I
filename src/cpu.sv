`timescale 1ns / 1ps

module cpu (
    input logic clk,
    input logic rst_n
);

  // PC
  logic [31:0] pc;
  logic [31:0] pc_next;
  logic [31:0] pc_branch;
  logic [31:0] pc_inc;

  always_comb begin : pc_computation
    pc_branch = pc + imm_produced;
    pc_inc = pc + 4;
  end

  always_comb begin : pc_select
    pc_next = pc_src ? pc_branch : pc_inc;
  end

  always_ff @(posedge clk) begin
    if (rst_n == 0) begin
      pc <= 32'b0;
    end else begin
      pc <= pc_next;
    end
  end

  // Instruction ROM
  wire [31:0] instruction;

  memory #(
      .test_mem("./tests/imemory.hex")
  ) imemory (
      .clk(clk),
      .address(pc),
      .write_data(32'b0),
      .write_enable(1'b0),
      .rst_n(1'b1),
      .read_data(instruction)
  );


  //Control Unit
  logic [6:0] op_code;
  logic [2:0] func3;
  assign op_code = instruction[6:0];
  assign func3   = instruction[14:12];
  wire zero;

  wire [2:0] alu_control;
  wire [2:0] imm_type;
  wire mem_write;
  wire reg_write;
  wire alu_source;
  wire [1:0] result_source;
  wire pc_src;

  control control_u (
      .op_code(op_code),
      .zero(zero),
      .imm_type(imm_type),
      .mem_write(mem_write),
      .reg_write(reg_write),
      .alu_source(alu_source),
      .result_source(result_source),
      .func3(func3),
      .func7(7'b0),
      .alu_control(alu_control),
      .pc_src(pc_src)
  );

  //Regfile
  logic [4:0] address1;
  logic [4:0] address2;
  logic [4:0] address3;
  //risc-v keeps src and dest regs always same position
  assign address1 = instruction[19:15];
  assign address2 = instruction[24:20];
  assign address3 = instruction[11:7];
  wire  [31:0] read_reg1;
  wire  [31:0] read_reg2;

  logic [31:0] write_back_data;
  always_comb begin : wb_select
    case (result_source)
      2'b00:   write_back_data = alu_result;
      2'b01:   write_back_data = mem_read;
      2'b10:   write_back_data = pc_inc;
      default: write_back_data = alu_result;
    endcase
  end

  regfile regfile_u (
      .clk(clk),
      .rst_n(rst_n),
      .address1(address1),
      .address2(address2),
      .write_enable(reg_write),
      .write_data(write_back_data),
      .address3(address3),
      .read_data1(read_reg1),
      .read_data2(read_reg2)
  );

  //Sign Extender
  logic [24:0] raw_src;
  assign raw_src = instruction[31:7];
  wire [31:0] imm_produced;

  signextnd signextnd_u (
      .raw_src(raw_src),
      .imm_type(imm_type),
      .imm_produced(imm_produced)
  );

  //ALU
  wire [31:0] alu_result;
  wire last_bit;
  logic [31:0] src2;

  always_comb begin : src2_select
    case (alu_source)
      1'b1: src2 = imm_produced;
      default: src2 = read_reg2;
    endcase
  end

  alu alu_u (
      .src1(read_reg1),
      .src2(src2),
      .alu_control(alu_control),
      .alu_result(alu_result),
      .zero(zero),
      .last_bit(last_bit)
  );

  // Data Memory
  wire [31:0] mem_read;

  memory #(
      .test_mem("./tests/dmemory.hex")
  ) dmemory (
      .clk(clk),
      .address(alu_result),
      .write_data(read_reg2),
      .write_enable(mem_write),
      .rst_n(1'b1),
      .read_data(mem_read)
  );
endmodule
