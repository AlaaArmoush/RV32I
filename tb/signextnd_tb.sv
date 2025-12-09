module signextnd_tb;
  logic [31:7] raw_src;
  logic [ 2:0] imm_type;
  logic [31:0] imm_produced;

  signextnd dut (
      .raw_src(raw_src),
      .imm_type(imm_type),
      .imm_produced(imm_produced)
  );


  // Golden Model 
  function bit [31:0] calc_expected(bit [31:7] src, bit [3:0] type_code);
    /* verilator lint_off WIDTHEXPAND */
    bit [31:0] expected_imm;
    // bit signed for automatic extension
    bit signed [11:0] i_imm;
    bit signed [11:0] s_imm;
    bit signed [12:0] b_imm;
    bit signed [20:0] j_imm;  // 20 bits shifted by 1 
    bit signed [31:12] u_imm;  // upper 20 bits

    case (type_code)
      //I-type
      3'b000: begin
        i_imm = src[31:20];
        expected_imm = i_imm;
      end
      // S-type
      3'b001: begin
        s_imm = {src[31:25], src[11:7]};
        expected_imm = s_imm;
      end
      // B-type
      3'b010: begin
        b_imm = {raw_src[31], raw_src[7], raw_src[30:25], raw_src[11:8], 1'b0};
        expected_imm = b_imm;
      end
      // J-type
      3'b011: begin
        j_imm = {src[31], src[19:12], src[20], src[30:21], 1'b0};
        expected_imm = j_imm;
      end
      // U-type
      3'b100: begin
        u_imm = src[31:12];
        expected_imm = {u_imm, 12'b0};
      end

      default: expected_imm = 32'b0;
    endcase
    return expected_imm;
    /* verilator lint_on WIDTHEXPAND */
  endfunction

  function void check(bit [31:0] expected, bit [31:0] actual);
    if (actual != expected) begin
      $error("MISMATCH! Type: %b, Raw: %h", imm_type, raw_src);
      $error("  -> Expected: %h, Got: %h (Decimal: %0d)", expected, actual, actual);
    end
  endfunction

  // Test 
  initial begin
    $display("---------------------------------------");
    $display("Starting Sign Extender Verification");
    $display("---------------------------------------");

    imm_type = 3'b000;
    $display("Testing I-Type (Immediate, Load/JALR)");
    raw_src = {12'd123, 13'b0};
    #1;
    check(calc_expected(raw_src, imm_type), imm_produced);
    raw_src = {-12'sd123, 13'b0};
    #1;
    check(calc_expected(raw_src, imm_type), imm_produced);
    for (int i = 0; i < 100; i++) begin
      bit [11:0] imm_val;
      void'(std::randomize(imm_val));
      raw_src = {imm_val, 13'b0};
      #1;
      check(calc_expected(raw_src, imm_type), imm_produced);
    end

    imm_type = 3'b001;
    $display("Testing S-Type (Store)");
    for (int i = 0; i < 100; i++) begin
      bit [11:0] imm_val;
      void'(std::randomize(imm_val));

      raw_src = {(imm_val[11:5] << 25), (imm_val[4:0] << 7)};
      raw_src = raw_src[31:7];
      #1;
      check(calc_expected(raw_src, imm_type), imm_produced);
    end

    imm_type = 3'b010;
    $display("Testing B-type (Branch)");
    for (int i = 0; i < 100; i++) begin
      bit [12:0] imm_val;
      void'(std::randomize(imm_val));
      imm_val[0] = 0;
      raw_src = {
        imm_val[12] << 24,  // Imm[12] -> Inst[31]
        imm_val[11] << 0,  // Imm[11] -> Inst[7]
        imm_val[10:5] << 18,  // Imm[10:5] -> Inst[30:25]
        imm_val[4:1] << 1  // Imm[4:1] -> Inst[11:8]
      };
      raw_src = raw_src[31:7];
      #1;
      check(calc_expected(raw_src, imm_type), imm_produced);
    end

    imm_type = 3'b011;
    $display("Testing J-type (JAL");
    for (int i = 0; i < 100; i++) begin
      bit [20:0] imm_val;
      void'(std::randomize(imm_val));
      imm_val[0] = 0;
      raw_src = {
        imm_val[20] << 24,  // Imm[20] -> Inst[31]
        imm_val[19:12] << 5,  // Imm[19:12] -> Inst[19:12]
        imm_val[11] << 13,  // Imm[11] -> Inst[20]
        imm_val[10:1] << 14  // Imm[10:1] -> Inst[30:21]
      };
      raw_src = raw_src[31:7];
      #1;
      check(calc_expected(raw_src, imm_type), imm_produced);
    end

    imm_type = 3'b100;
    $display("Testing U-type (LUI/AUIPC)");
    for (int i = 0; i < 100; i++) begin
      bit [19:0] imm_val_top;
      void'(std::randomize(imm_val_top));
      raw_src = {imm_val_top, 5'b0};
      raw_src = raw_src[31:7];
      #1;
      check(calc_expected(raw_src, imm_type), imm_produced);
    end

    $display("---------------------------------------");
    $display("Sign Extender Tests All Passed Successfully.");
    $display("---------------------------------------");
    $finish;
  end
endmodule
