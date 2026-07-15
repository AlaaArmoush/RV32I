package alu_pkg;
  typedef logic [3:0] alu_op_t;

  localparam alu_op_t ALU_ADD     = 4'b0000;
  localparam alu_op_t ALU_SUB     = 4'b0001;
  localparam alu_op_t ALU_AND     = 4'b0010;
  localparam alu_op_t ALU_OR      = 4'b0011;
  localparam alu_op_t ALU_SLL     = 4'b0100;
  localparam alu_op_t ALU_SLT     = 4'b0101;
  localparam alu_op_t ALU_SRL     = 4'b0110;
  localparam alu_op_t ALU_SLTU    = 4'b0111;
  localparam alu_op_t ALU_XOR     = 4'b1000;
  localparam alu_op_t ALU_SRA     = 4'b1001;
  localparam alu_op_t ALU_INVALID = 4'b1111; 
  
  // enums used bye ALU coverage
  typedef enum logic [2:0] {
    OPR_ZERO,
    OPR_ONE,
    OPR_ALL_ONES,
    OPR_MIN_NEG,
    OPR_MAX_POS,
    OPR_RANDOM
  } opr_class_e ;

  typedef enum logic [1:0] {
    SH_ZERO,
    SH_ONE,
    SH_MID,
    SH_MAX
  } shamt_class_e ;

  typedef enum logic [1:0] {
    RES_ZERO,
    RES_NEG,
    RES_POS,
    RES_ALL_ONES
  } res_class_e ;

  function automatic opr_class_e classify_opr(logic [31:0] v);
    if      (v == 32'h0000_0000) return OPR_ZERO;
    else if (v == 32'h0000_0001) return OPR_ONE;
    else if (v == 32'hFFFF_FFFF) return OPR_ALL_ONES;
    else if (v == 32'h8000_0000) return OPR_MIN_NEG;
    else if (v == 32'h7FFF_FFFF) return OPR_MAX_POS;
    else                         return OPR_RANDOM;
  endfunction

  function automatic shamt_class_e classify_shamt(logic [4:0] s);
    if      (s == 5'd0)  return SH_ZERO;
    else if (s == 5'd1)  return SH_ONE;
    else if (s == 5'd31) return SH_MAX;
    else                 return SH_MID;
  endfunction

  function automatic res_class_e classify_res(logic [31:0] r);
    if      (r == 32'h0000_0000) return RES_ZERO;
    else if (r == 32'hFFFF_FFFF) return RES_ALL_ONES;
    else if (r[31])              return RES_NEG;
    else                         return RES_POS;
  endfunction


  // Golden ALU Model
  function automatic logic [31:0] golden_alu(input logic [31:0] src1, input logic [31:0] src2, input logic [4:0] shamt, input alu_op_t op);
    case (op)
      ALU_ADD:  return src1 + src2;
      ALU_SUB:  return src1 - src2;
      ALU_AND:  return src1 & src2;
      ALU_OR:   return src1 | src2;
      ALU_SLL:  return src1 << shamt;
      ALU_SLT:  return {31'b0, $signed(src1) < $signed(src2)};
      ALU_SRL:  return src1 >> shamt;
      ALU_SLTU: return {31'b0, src1 < src2};
      ALU_XOR:  return src1 ^ src2;
      ALU_SRA:  return $signed(src1) >>> shamt;
      default:  return 32'b0;    endcase
  endfunction

  // print func
  function automatic string op_name(input alu_op_t op);
    case (op)
      ALU_ADD:     return "ADD";
      ALU_SUB:     return "SUB";
      ALU_AND:     return "AND";
      ALU_OR:      return "OR";
      ALU_SLL:     return "SLL";
      ALU_SLT:     return "SLT";
      ALU_SRL:     return "SRL";
      ALU_SLTU:    return "SLTU";
      ALU_XOR:     return "XOR";
      ALU_SRA:     return "SRA";
      ALU_INVALID: return "INVALID";
      default:     return "UNKNOWN";
    endcase
  endfunction
endpackage
