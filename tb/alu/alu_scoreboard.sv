`ifndef ALU_SCOREBOARD_SV
`define ALU_SCOREBOARD_SV

import alu_pkg::*;

class alu_scoreboard;
  //counters
  int unsigned total  = 0;
  int unsigned passed = 0;
  int unsigned failed = 0;

  function void check(alu_item it);
    logic [31:0] exp_result = golden_alu(it.src1, it.src2, it.shamt, it.alu_control);
    logic exp_zero = (exp_result == 32'b0);
    logic exp_last_bit = exp_result[0];
    string tag = $sformatf(
        "op=%-6s src1=0x%08h src2=0x%08h shamt=%0d",
        op_name(
            it.alu_control
        ),
        it.src1,
        it.src2,
        it.shamt
    );

    total++;

    if (it.alu_result !== exp_result) begin
      $error("[scoreboard] RESULT MISMATCH  %s  got=0x%08h  exp=0x%08h", tag, it.alu_result,
             exp_result);
      failed++;
      return;
    end

    if (it.zero !== exp_zero) begin
      $error("[scoreboard] ZERO FLAG MISMATCH  %s  result=0x%08h  got=%b  exp=%b", tag,
             it.alu_result, it.zero, exp_zero);
      failed++;
      return;
    end

    if (it.last_bit !== exp_last_bit) begin
      $error("[scoreboard] LAST_BIT MISMATCH  %s  result=0x%08h  got=%b  exp=%b", tag,
             it.alu_result, it.last_bit, exp_last_bit);
      failed++;
      return;
    end

    if (it.alu_control == ALU_INVALID && it.alu_result !== 32'b0) begin
      $error("[scoreboard] INVALID OP non-zero result  %s  got=0x%08h", tag, it.alu_result);
      failed++;
      return;
    end

    passed++;
  endfunction

  function void report();
    $display("------------------------------------------------------------");
    $display("[scoreboard] total=%0d  passed=%0d  failed=%0d", total, passed, failed);
    $display("------------------------------------------------------------");
    if (failed != 0) $fatal(1, "[scoreboard] ALU DV FAILED with %0d error(s)", failed);
    else $display("[scoreboard] ALU DV PASSED");
  endfunction

endclass : alu_scoreboard

`endif
