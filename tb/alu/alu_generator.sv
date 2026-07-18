`ifndef ALU_GENERATOR_SV
`define ALU_GENERATOR_SV

import alu_pkg::*;

class alu_generator;
  int unsigned rand_count = 1000;  // can override with +RANDOM_TESTS plusarg
  int unsigned seed = 42;  // override with +SEED plusarg

  alu_item items[$];

  local function alu_item make_item(logic [31:0] src1, logic [31:0] src2, logic [4:0] shamt,
                                    alu_op_t op);
    alu_item item = new();
    item.src1 = src1;
    item.src2 = src2;
    item.shamt = shamt;
    item.alu_control = op;
    item.classify_stimulus();
    return item;
  endfunction

  local function void gen_directed();
    foreach (CORNERS[i]) begin
      foreach (CORNERS[j]) begin
        foreach (ALL_OPS[k]) begin
          if (ALL_OPS[k] inside {ALU_SLL, ALU_SRL, ALU_SRA}) continue;
          items.push_back(make_item(CORNERS[i], CORNERS[j], 5'd0, ALL_OPS[k]));
        end
      end
    end

    foreach (CORNERS[i]) begin
      foreach (SHAMTS[j]) begin
        for (int k = 0; k < $size(SHIFT_OPS); k++) begin
          items.push_back(make_item(CORNERS[i], 32'd0, SHAMTS[j], SHIFT_OPS[k]));
        end
      end
    end

    // Signed/unsigned comparison edge cases
    items.push_back(make_item(32'h8000_0000, 32'h0000_0001, 5'd0, ALU_SLT));
    items.push_back(make_item(32'h8000_0000, 32'h0000_0001, 5'd0, ALU_SLTU));

    //equal operands
    foreach (CORNERS[i]) begin
      items.push_back(make_item(CORNERS[i], CORNERS[i], 5'd0, ALU_SUB));
      items.push_back(make_item(CORNERS[i], CORNERS[i], 5'd0, ALU_XOR));
      items.push_back(make_item(CORNERS[i], CORNERS[i], 5'd0, ALU_SLT));
      items.push_back(make_item(CORNERS[i], CORNERS[i], 5'd0, ALU_SLTU));
    end
  endfunction

  local function void gen_random();
    alu_item it;
    void'($urandom(seed));
    repeat (rand_count) begin
      it = new();
      if (!it.randomize()) $fatal(1, "[alu_generator] randomize() failed");
      it.classify_stimulus();
      items.push_back(it);
    end
  endfunction

  function void run();
    int tmp;
    if ($value$plusargs("SEED=%d", tmp)) seed = tmp;
    if ($value$plusargs("RANDOM_TESTS=%d", tmp)) rand_count = tmp;

    $display("[alu_generator] seed=%0d  rand_count=%0d", seed, rand_count);
    items.delete();
    gen_directed();
    gen_random();
    $display("[alu_generator] total items: %0d  (directed=%0d  random=%0d)", items.size(),
             items.size() - rand_count, rand_count);
  endfunction
endclass

`endif
