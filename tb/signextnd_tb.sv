module signextnd_tb;
  localparam logic [2:0] IMM_I       = 3'b000;
  localparam logic [2:0] IMM_S       = 3'b001;
  localparam logic [2:0] IMM_B       = 3'b010;
  localparam logic [2:0] IMM_J       = 3'b011;
  localparam logic [2:0] IMM_U       = 3'b100;
  localparam logic [2:0] IMM_INVALID = 3'b111;

  localparam int RANDOM_TESTS_PER_TYPE = 200;

  logic [31:7] raw_src;
  logic [ 2:0] imm_type;
  logic [31:0] imm_produced;

  int error_count = 0;
  int total_checks = 0;
  int passed_checks = 0;
  int directed_checks = 0;
  int random_checks = 0;
  int type_hits[8];

  signextnd dut (
      .raw_src(raw_src),
      .imm_type(imm_type),
      .imm_produced(imm_produced)
  );

  function automatic logic [31:0] golden_imm(
      input logic [31:7] src,
      input logic [2:0]  type_code
  );
    case (type_code)
      IMM_I:   golden_imm = {{20{src[31]}}, src[31:20]};
      IMM_S:   golden_imm = {{20{src[31]}}, src[31:25], src[11:7]};
      IMM_B:   golden_imm = {{19{src[31]}}, src[31], src[7], src[30:25], src[11:8], 1'b0};
      IMM_J:   golden_imm = {{11{src[31]}}, src[31], src[19:12], src[20], src[30:21], 1'b0};
      IMM_U:   golden_imm = {src[31:12], 12'b0};
      default: golden_imm = 32'b0;
    endcase
  endfunction

  function automatic string imm_name(input logic [2:0] type_code);
    case (type_code)
      IMM_I:       imm_name = "I";
      IMM_S:       imm_name = "S";
      IMM_B:       imm_name = "B";
      IMM_J:       imm_name = "J";
      IMM_U:       imm_name = "U";
      IMM_INVALID: imm_name = "INVALID";
      default:     imm_name = "UNKNOWN";
    endcase
  endfunction

  function automatic logic [31:7] encode_i(input logic [11:0] imm);
    logic [31:0] instruction_bits;
    instruction_bits = 32'b0;
    instruction_bits[31:20] = imm;
    return instruction_bits[31:7];
  endfunction

  function automatic logic [31:7] encode_s(input logic [11:0] imm);
    logic [31:0] instruction_bits;
    instruction_bits = 32'b0;
    instruction_bits[31:25] = imm[11:5];
    instruction_bits[11:7] = imm[4:0];
    return instruction_bits[31:7];
  endfunction

  function automatic logic [31:7] encode_b(input logic [12:0] imm);
    logic [31:0] instruction_bits;
    instruction_bits = 32'b0;
    instruction_bits[31] = imm[12];
    instruction_bits[7] = imm[11];
    instruction_bits[30:25] = imm[10:5];
    instruction_bits[11:8] = imm[4:1];
    return instruction_bits[31:7];
  endfunction

  function automatic logic [31:7] encode_j(input logic [20:0] imm);
    logic [31:0] instruction_bits;
    instruction_bits = 32'b0;
    instruction_bits[31] = imm[20];
    instruction_bits[19:12] = imm[19:12];
    instruction_bits[20] = imm[11];
    instruction_bits[30:21] = imm[10:1];
    return instruction_bits[31:7];
  endfunction

  function automatic logic [31:7] encode_u(input logic [19:0] imm_top);
    logic [31:0] instruction_bits;
    instruction_bits = 32'b0;
    instruction_bits[31:12] = imm_top;
    return instruction_bits[31:7];
  endfunction

  task automatic check_eq32(
      input string label,
      input logic [31:0] got,
      input logic [31:0] expected
  );
    total_checks++;
    if (got !== expected) begin
      $error("%s failed: expected 0x%08h, got 0x%08h raw=0x%07h type=%s",
             label,
             expected,
             got,
             raw_src,
             imm_name(imm_type));
      error_count++;
    end else begin
      passed_checks++;
    end
  endtask

  task automatic run_case(
      input string label,
      input logic [31:7] src_in,
      input logic [2:0]  type_in,
      input bit          is_random = 1'b0
  );
    logic [31:0] expected;

    raw_src = src_in;
    imm_type = type_in;
    #1;

    expected = golden_imm(src_in, type_in);
    type_hits[type_in]++;

    if (is_random) random_checks++;
    else directed_checks++;

    check_eq32({label, " IMM_", imm_name(type_in)}, imm_produced, expected);
  endtask

  task automatic run_directed_boundary_tests();
    $display("---------------------------------------");
    $display("Running directed sign extender boundary tests");
    $display("---------------------------------------");

    run_case("I zero", encode_i(12'h000), IMM_I);
    run_case("I max positive", encode_i(12'h7FF), IMM_I);
    run_case("I min negative", encode_i(12'h800), IMM_I);
    run_case("I minus one", encode_i(12'hFFF), IMM_I);

    run_case("S zero", encode_s(12'h000), IMM_S);
    run_case("S max positive", encode_s(12'h7FF), IMM_S);
    run_case("S min negative", encode_s(12'h800), IMM_S);
    run_case("S minus one", encode_s(12'hFFF), IMM_S);

    run_case("B smallest positive step", encode_b(13'h0002), IMM_B);
    run_case("B max positive", encode_b(13'h0FFE), IMM_B);
    run_case("B min negative", encode_b(13'h1000), IMM_B);
    run_case("B minus two", encode_b(13'h1FFE), IMM_B);

    run_case("J smallest positive step", encode_j(21'h000002), IMM_J);
    run_case("J max positive", encode_j(21'h0F_FFFE), IMM_J);
    run_case("J min negative", encode_j(21'h10_0000), IMM_J);
    run_case("J minus two", encode_j(21'h1F_FFFE), IMM_J);

    run_case("U zero", encode_u(20'h00000), IMM_U);
    run_case("U low bit set", encode_u(20'h00001), IMM_U);
    run_case("U high bit set", encode_u(20'h80000), IMM_U);
    run_case("U all ones", encode_u(20'hFFFFF), IMM_U);

    run_case("invalid type", encode_i(12'h123), IMM_INVALID);
  endtask

  task automatic run_random_tests();
    int unsigned seed;
    logic [11:0] i_imm;
    logic [11:0] s_imm;
    logic [12:0] b_imm;
    logic [20:0] j_imm;
    logic [19:0] u_imm;

    $display("---------------------------------------");
    $display("Running deterministic random sign extender tests");
    $display("---------------------------------------");

    seed = 32'h51E6_2026;
    void'($urandom(seed));

    for (int i = 0; i < RANDOM_TESTS_PER_TYPE; i++) begin
      i_imm = $urandom();
      run_case("random", encode_i(i_imm), IMM_I, 1'b1);

      s_imm = $urandom();
      run_case("random", encode_s(s_imm), IMM_S, 1'b1);

      b_imm = $urandom();
      b_imm[0] = 1'b0;
      run_case("random", encode_b(b_imm), IMM_B, 1'b1);

      j_imm = $urandom();
      j_imm[0] = 1'b0;
      run_case("random", encode_j(j_imm), IMM_J, 1'b1);

      u_imm = $urandom();
      run_case("random", encode_u(u_imm), IMM_U, 1'b1);
    end
  endtask

  task automatic check_coverage();
    logic [2:0] expected_types[6];

    expected_types[0] = IMM_I;
    expected_types[1] = IMM_S;
    expected_types[2] = IMM_B;
    expected_types[3] = IMM_J;
    expected_types[4] = IMM_U;
    expected_types[5] = IMM_INVALID;

    foreach (expected_types[i]) begin
      if (type_hits[expected_types[i]] == 0) begin
        $error("Coverage missing for immediate type %s", imm_name(expected_types[i]));
        error_count++;
      end
    end
  endtask

  task automatic finish_report();
    $display("---------------------------------------");
    $display("Sign extender TB summary");
    $display("  Directed cases     : %0d", directed_checks);
    $display("  Random cases       : %0d", random_checks);
    $display("  Total checks       : %0d", total_checks);
    $display("  Passed checks      : %0d", passed_checks);
    $display("  Failed checks      : %0d", error_count);
    $display("---------------------------------------");
    $display("Immediate type coverage");
    $display("  I                  : %0d", type_hits[IMM_I]);
    $display("  S                  : %0d", type_hits[IMM_S]);
    $display("  B                  : %0d", type_hits[IMM_B]);
    $display("  J                  : %0d", type_hits[IMM_J]);
    $display("  U                  : %0d", type_hits[IMM_U]);
    $display("  INVALID            : %0d", type_hits[IMM_INVALID]);
    $display("---------------------------------------");

    if (error_count == 0) begin
      $display("signextnd_tb PASSED");
      $finish;
    end else begin
      $fatal(1, "signextnd_tb FAILED with %0d error(s)", error_count);
    end
  endtask

  initial begin
    raw_src = 25'b0;
    imm_type = IMM_I;
    #1;

    run_directed_boundary_tests();
    run_random_tests();
    check_coverage();
    finish_report();
  end
endmodule
