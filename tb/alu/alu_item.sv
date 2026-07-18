`ifndef ALU_ITEM_SV
`define ALU_ITEM_SV

import alu_pkg::*;

class alu_item;
  rand logic [31:0] src1, src2;
  rand logic [4:0] shamt;
  rand alu_op_t alu_control;

  logic [31:0] alu_result;
  logic zero, last_bit;

  constraint c_op_dist {
    alu_control dist {
      ALU_ADD     := 10,
      ALU_SUB     := 10,
      ALU_AND     := 10,
      ALU_OR      := 10,
      ALU_SLL     := 10,
      ALU_SLT     := 10,
      ALU_SRL     := 10,
      ALU_SLTU    := 10,
      ALU_XOR     := 10,
      ALU_SRA     := 10,
      ALU_INVALID := 2
    };
  }

  constraint c_shamt_range {shamt inside {[0:31]};}

  constraint c_src1_bias {
    src1 dist {
      32'h0000_0000 := 5,
      32'h0000_0001 := 5,
      32'hFFFF_FFFF := 5,
      32'h8000_0000 := 5,
      32'h7FFF_FFFF := 5,
      [32'h0000_0002 : 32'h7FFF_FFFE] :/ 37,
      [32'h8000_0001 : 32'hFFFF_FFFE] :/ 38
    };
  }

  constraint c_src2_bias {
    src2 dist {
      32'h0000_0000 := 5,
      32'h0000_0001 := 5,
      32'hFFFF_FFFF := 5,
      32'h8000_0000 := 5,
      32'h7FFF_FFFF := 5,
      [32'h0000_0002 : 32'h7FFF_FFFE] :/ 37,
      [32'h8000_0001 : 32'hFFFF_FFFE] :/ 38
    };
  }

  opr_class_e   src1_class;
  opr_class_e   src2_class;
  shamt_class_e shamt_class;
  res_class_e   result_class;

  function void classify_stimulus();
    src1_class  = classify_opr(src1);
    src2_class  = classify_opr(src2);
    shamt_class = classify_shamt(shamt);
  endfunction

  function void classify_result ();
    result_class = classify_res(alu_result);
  endfunction

  function string sprint ();
    return $sformatf(
      "op=%-6s src1=0x%08h src2=0x%08h shamt=%0d -> result=0x%08h zero=%b last_bit=%b",
      op_name(alu_control), src1, src2, shamt, alu_result, zero, last_bit
    );
  endfunction
endclass

`endif
