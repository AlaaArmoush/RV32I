`ifndef ALU_COVERAGE_SUV
`define ALU_COVERAGE_SUV

import alu_pkg::*;

class alu_coverage;
  alu_op_t      op;
  opr_class_e   src1_cls;
  opr_class_e   src2_cls;
  shamt_class_e shamt_cls;
  res_class_e   result_cls;
  cmp_rel_e     cmp_rel;
  logic         flag_zero;
  logic         flag_last_bit;

  covergroup alu_cg;
    // All 11 opcodes (10 valid + INVALID)
    cp_op: coverpoint op {
      bins add = {ALU_ADD};
      bins sub = {ALU_SUB};
      bins and_op = {ALU_AND};
      bins or_op = {ALU_OR};
      bins sll = {ALU_SLL};
      bins slt = {ALU_SLT};
      bins srl = {ALU_SRL};
      bins sltu = {ALU_SLTU};
      bins xor_op = {ALU_XOR};
      bins sra = {ALU_SRA};
      bins invalid = {ALU_INVALID};
    }

    cp_src1: coverpoint src1_cls;
    cp_src2: coverpoint src2_cls;

    cp_shamt: coverpoint shamt_cls;

    cp_result: coverpoint result_cls;

    cp_zero: coverpoint flag_zero;
    cp_last_bit: coverpoint flag_last_bit;

    cp_cmp_rel: coverpoint cmp_rel;

    cx_op_src1: cross cp_op, cp_src1;

    cx_op_result: cross cp_op, cp_result;

    cx_shift_shamt: cross cp_op, cp_shamt{
      ignore_bins non_shift = binsof (cp_op) intersect {
        ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_SLT, ALU_SLTU, ALU_XOR, ALU_INVALID
      };
    }

    // Cross: compare op x signed relationship between operands
    cx_cmp_rel: cross cp_op, cp_cmp_rel{
      ignore_bins non_cmp = binsof (cp_op) intersect {
        ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_SLL, ALU_SRL, ALU_SRA, ALU_XOR, ALU_INVALID
      };
    }
  endgroup

  function new();
    alu_cg = new();
  endfunction

  function sample (alu_item it);
    op            = it.alu_control;
    src1_cls      = it.src1_class;
    src2_cls      = it.src2_class;
    shamt_cls     = it.shamt_class;
    result_cls    = it.result_class;
    flag_zero     = it.zero;
    flag_last_bit = it.last_bit;
    cmp_rel       = classify_cmp(it.src1, it.src2);
    alu_cg.sample();
  endfunction
endclass : alu_coverage

`endif
