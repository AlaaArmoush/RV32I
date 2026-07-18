`ifndef ALU_COVERAGE_SV
`define ALU_COVERAGE_SV

import alu_pkg::*;

class alu_coverage;

  covergroup alu_cg with function sample(
      alu_op_t      op,
      opr_class_e   src1_cls,
      opr_class_e   src2_cls,
      shamt_class_e shamt_cls,
      res_class_e   result_cls,
      logic         flag_zero,
      logic         flag_last_bit,
      logic         is_shift,
      logic         is_cmp,
      cmp_rel_e     cmp_rel
  );
    option.per_instance = 1;

    cp_op: coverpoint op {
      bins add     = {ALU_ADD};
      bins sub     = {ALU_SUB};
      bins and_op  = {ALU_AND};
      bins or_op   = {ALU_OR};
      bins sll     = {ALU_SLL};
      bins slt     = {ALU_SLT};
      bins srl     = {ALU_SRL};
      bins sltu    = {ALU_SLTU};
      bins xor_op  = {ALU_XOR};
      bins sra     = {ALU_SRA};
      bins invalid = {ALU_INVALID};
    }

    cp_src1: coverpoint src1_cls {
      bins zero     = {OPR_ZERO};
      bins one      = {OPR_ONE};
      bins all_ones = {OPR_ALL_ONES};
      bins min_neg  = {OPR_MIN_NEG};
      bins max_pos  = {OPR_MAX_POS};
      bins random   = {OPR_RANDOM};
      illegal_bins  undef = default;
    }

    cp_src2: coverpoint src2_cls {
      bins zero     = {OPR_ZERO};
      bins one      = {OPR_ONE};
      bins all_ones = {OPR_ALL_ONES};
      bins min_neg  = {OPR_MIN_NEG};
      bins max_pos  = {OPR_MAX_POS};
      bins random   = {OPR_RANDOM};
      illegal_bins  undef = default;
    }

    cp_shamt: coverpoint shamt_cls {
      bins zero = {SH_ZERO};
      bins one  = {SH_ONE};
      bins mid  = {SH_MID};
      bins max  = {SH_MAX};
    }

    cp_result: coverpoint result_cls {
      bins zero     = {RES_ZERO};
      bins neg      = {RES_NEG};
      bins pos      = {RES_POS};
      bins all_ones = {RES_ALL_ONES};
    }

    cp_zero:     coverpoint flag_zero;
    cp_last_bit: coverpoint flag_last_bit;

    cp_cmp_rel: coverpoint cmp_rel {
      bins eq = {CMP_EQ};
      bins lt = {CMP_LT};
      bins gt = {CMP_GT};
      illegal_bins undef = default;
    }

    cp_is_shift: coverpoint is_shift;
    cp_is_cmp:   coverpoint is_cmp;

    cx_op_src1:     cross cp_op, cp_src1;
    cx_op_result:   cross cp_op, cp_result;
    cx_shift_shamt: cross cp_is_shift, cp_shamt;
    cx_cmp_rel:     cross cp_is_cmp,   cp_cmp_rel;
  endgroup

  function new();
    alu_cg = new();
  endfunction

  function void sample(alu_item it);
    alu_cg.sample(
      it.alu_control,
      it.src1_class,
      it.src2_class,
      it.shamt_class,
      it.result_class,
      it.zero,
      it.last_bit,
      logic'(it.alu_control inside {ALU_SLL, ALU_SRL, ALU_SRA}),
      logic'(it.alu_control inside {ALU_SLT, ALU_SLTU}),
      classify_cmp(it.src1, it.src2)
    );
  endfunction

endclass

`endif
