import control_pkg::*;

module control_sva (
    input logic       sample_clk,
    input logic [6:0] op_code,
    input logic [2:0] func3,
    input logic [6:0] func7,
    input logic       zero,
    input logic       last_bit,
    input logic [2:0] imm_type,
    input logic       mem_write,
    input logic       reg_write,
    input logic       reg_write_gated,
    input logic       alu_source,
    input logic [1:0] result_source,
    input logic       pc_src,
    input logic [1:0] addr_base_src,
    input logic [3:0] alu_control
);

  property controls_known;
    @(posedge sample_clk)
      !$isunknown({
        op_code,
        func3,
        func7,
        zero,
        last_bit,
        imm_type,
        mem_write,
        reg_write,
        reg_write_gated,
        alu_source,
        result_source,
        pc_src,
        addr_base_src,
        alu_control
      });
  endproperty

  property memory_write_is_legal_store;
    @(posedge sample_clk)
      mem_write |->
          ((op_code == OP_STORE) &&
           is_legal_encoding(op_code, func3, func7));
  endproperty

  property gated_write_matches_legal_decode;
    @(posedge sample_clk)
      reg_write_gated ==
          (reg_write && is_legal_encoding(op_code, func3, func7));
  endproperty

  property branch_never_writes_register;
    @(posedge sample_clk)
      (op_code == OP_BRANCH) |-> !reg_write_gated;
  endproperty

  property store_never_writes_register;
    @(posedge sample_clk)
      (op_code == OP_STORE) |-> !reg_write_gated;
  endproperty

  property branch_pc_decision_is_correct;
    @(posedge sample_clk)
      (op_code == OP_BRANCH) |->
          (pc_src ==
              (((func3 == 3'b000) && zero) ||
               ((func3 == 3'b001) && !zero) ||
               ((func3 == 3'b100) && last_bit) ||
               ((func3 == 3'b101) && !last_bit) ||
               ((func3 == 3'b110) && last_bit) ||
               ((func3 == 3'b111) && !last_bit)));
  endproperty

  property jal_controls_are_consistent;
    @(posedge sample_clk)
      (op_code == OP_JAL) |->
          (pc_src &&
           reg_write_gated &&
           !mem_write &&
           (imm_type == IMM_J) &&
           (result_source == 2'b10) &&
           (addr_base_src == 2'b00));
  endproperty

  property legal_jalr_controls_are_consistent;
    @(posedge sample_clk)
      ((op_code == OP_JALR) &&
       is_legal_encoding(op_code, func3, func7)) |->
          (pc_src &&
           reg_write_gated &&
           !mem_write &&
           (imm_type == IMM_I) &&
           (result_source == 2'b10) &&
           (addr_base_src == 2'b10));
  endproperty

  property lui_controls_are_consistent;
    @(posedge sample_clk)
      (op_code == OP_LUI) |->
          (!pc_src &&
           reg_write_gated &&
           !mem_write &&
           (imm_type == IMM_U) &&
           (result_source == 2'b11) &&
           (addr_base_src == 2'b01));
  endproperty

  property auipc_controls_are_consistent;
    @(posedge sample_clk)
      (op_code == OP_AUIPC) |->
          (!pc_src &&
           reg_write_gated &&
           !mem_write &&
           (imm_type == IMM_U) &&
           (result_source == 2'b11) &&
           (addr_base_src == 2'b00));
  endproperty

  property unsupported_opcode_has_no_side_effects;
    @(posedge sample_clk)
      !is_supported_opcode(op_code) |->
          (!mem_write &&
           !reg_write &&
           !reg_write_gated &&
           !pc_src);
  endproperty

  property illegal_encoding_has_no_side_effects;
    @(posedge sample_clk)
      (is_supported_opcode(op_code) &&
       !is_legal_encoding(op_code, func3, func7)) |->
          (!mem_write &&
           !reg_write_gated &&
           !pc_src);
  endproperty

  assert property (controls_known)
    else $error("[CONTROL_SVA] Sampled inputs or outputs contain X/Z");

  assert property (memory_write_is_legal_store)
    else $error(
        "[CONTROL_SVA] mem_write asserted for non-store or illegal store"
    );

  assert property (gated_write_matches_legal_decode)
    else $error(
        "[CONTROL_SVA] reg_write_gated inconsistent with decode legality"
    );

  assert property (branch_never_writes_register)
    else $error("[CONTROL_SVA] Branch asserted reg_write_gated");

  assert property (store_never_writes_register)
    else $error("[CONTROL_SVA] Store asserted reg_write_gated");

  assert property (branch_pc_decision_is_correct)
    else $error(
        "[CONTROL_SVA] Incorrect branch decision: func3=%03b zero=%0b "
        "last_bit=%0b pc_src=%0b",
        func3,
        zero,
        last_bit,
        pc_src
    );

  assert property (jal_controls_are_consistent)
    else $error("[CONTROL_SVA] Inconsistent JAL controls");

  assert property (legal_jalr_controls_are_consistent)
    else $error("[CONTROL_SVA] Inconsistent legal JALR controls");

  assert property (lui_controls_are_consistent)
    else $error("[CONTROL_SVA] Inconsistent LUI controls");

  assert property (auipc_controls_are_consistent)
    else $error("[CONTROL_SVA] Inconsistent AUIPC controls");

  assert property (unsupported_opcode_has_no_side_effects)
    else $error(
        "[CONTROL_SVA] Unsupported opcode produced an architectural side effect"
    );

  assert property (illegal_encoding_has_no_side_effects)
    else $error(
        "[CONTROL_SVA] Illegal encoding produced an architectural side effect"
    );
endmodule : control_sva
