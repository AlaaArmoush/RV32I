`timescale 1ns / 1ps

module cpu_tb;
  logic clk;
  logic rst_n;

  cpu dut (
      .clk  (clk),
      .rst_n(rst_n)
  );

  // ------------------------------------------------------------
  // Verification state
  // ------------------------------------------------------------
  int error_count = 0;
  int total_checks = 0;
  int passed_checks = 0;
  int reg_checks = 0;
  int mem_checks = 0;
  int pc_checks = 0;
  int coverage_points = 0;
  int coverage_hits = 0;

  logic [31:0] exp_regs[32];
  logic [31:0] exp_mem[64];
  logic [31:0] exp_pc;

  int seen_lw = 0;
  int seen_sw = 0;
  int seen_sb = 0;
  int seen_sh = 0;
  int seen_lb = 0;
  int seen_lh = 0;
  int seen_lbu = 0;
  int seen_lhu = 0;
  int seen_branch_taken = 0;
  int seen_branch_not_taken = 0;
  int seen_jal = 0;
  int seen_jalr = 0;

  // ------------------------------------------------------------
  // Clock
  // ------------------------------------------------------------
  initial begin
    clk = 1'b0;
    forever #0.5 clk = ~clk;
  end

  // ------------------------------------------------------------
  // Generic self-checking helpers
  // ------------------------------------------------------------
  task automatic check_eq32(
      input string label,
      input logic [31:0] got,
      input logic [31:0] expected
  );
    total_checks++;
    if (got !== expected) begin
      $error("%s failed: expected 0x%08h, got 0x%08h", label, expected, got);
      error_count++;
    end else begin
      passed_checks++;
    end
  endtask

  task automatic print_scoreboard_summary();
    $display("---------------------------------------");
    $display("Scoreboard summary");
    $display("  Register comparisons : %0d", reg_checks);
    $display("  Memory comparisons   : %0d", mem_checks);
    $display("  PC comparisons       : %0d", pc_checks);
    $display("  Total checks         : %0d", total_checks);
    $display("  Passed checks        : %0d", passed_checks);
    $display("  Failed checks        : %0d", error_count);
  endtask

  task automatic print_coverage_summary();
    $display("---------------------------------------");
    $display("Coverage summary");
    $display("  lw                  : %0d", seen_lw);
    $display("  sw                  : %0d", seen_sw);
    $display("  sb                  : %0d", seen_sb);
    $display("  sh                  : %0d", seen_sh);
    $display("  lb                  : %0d", seen_lb);
    $display("  lh                  : %0d", seen_lh);
    $display("  lbu                 : %0d", seen_lbu);
    $display("  lhu                 : %0d", seen_lhu);
    $display("  branch taken        : %0d", seen_branch_taken);
    $display("  branch not taken    : %0d", seen_branch_not_taken);
    $display("  jal                 : %0d", seen_jal);
    $display("  jalr                : %0d", seen_jalr);
    $display("  Coverage hit points : %0d/%0d", coverage_hits, coverage_points);
  endtask

  task automatic finish_report(input string tb_name);
    print_scoreboard_summary();
    print_coverage_summary();

    if (error_count == 0) begin
      $display("---------------------------------------");
      $display("%s PASSED", tb_name);
      $display("---------------------------------------");
      $finish;
    end else begin
      $fatal(1, "%s FAILED with %0d error(s)", tb_name, error_count);
    end
  endtask

  // ------------------------------------------------------------
  // CPU-specific check helpers
  // ------------------------------------------------------------
  task automatic check_pc(input logic [31:0] expected, input string label);
    pc_checks++;
    check_eq32({label, " PC"}, dut.pc, expected);
  endtask

  task automatic check_reg(
      input int reg_id,
      input logic [31:0] expected,
      input string label
  );
    reg_checks++;
    check_eq32($sformatf("%s x%0d", label, reg_id),
               dut.regfile_u.registers[reg_id],
               expected);
  endtask

  task automatic check_mem_word(
      input int word_index,
      input logic [31:0] expected,
      input string label
  );
    mem_checks++;
    check_eq32($sformatf("%s mem[%0d]", label, word_index),
               dut.dmemory.mem[word_index],
               expected);
  endtask

  task automatic step_cpu(input string label);
    @(posedge clk);
    #1ps;
    $display("Executed: %-35s PC=0x%08h", label, dut.pc);
  endtask

  // ------------------------------------------------------------
  // Scoreboard helpers
  // ------------------------------------------------------------
  task automatic scoreboard_reset();
    for (int i = 0; i < 32; i++) begin
      exp_regs[i] = 32'b0;
    end

    for (int i = 0; i < 64; i++) begin
      exp_mem[i] = dut.dmemory.mem[i];
    end

    exp_pc = 32'b0;
  endtask

  task automatic expect_reg(input int reg_id, input logic [31:0] value);
    if (reg_id != 0) begin
      exp_regs[reg_id] = value;
    end
    exp_regs[0] = 32'b0;
  endtask

  task automatic expect_mem(input int word_index, input logic [31:0] value);
    exp_mem[word_index] = value;
  endtask

  task automatic expect_pc(input logic [31:0] value);
    exp_pc = value;
  endtask

  task automatic compare_reg(input int reg_id, input string label);
    check_reg(reg_id, exp_regs[reg_id], label);
  endtask

  task automatic compare_mem(input int word_index, input string label);
    check_mem_word(word_index, exp_mem[word_index], label);
  endtask

  task automatic compare_pc(input string label);
    check_pc(exp_pc, label);
  endtask

  // ------------------------------------------------------------
  // Reset
  // ------------------------------------------------------------
  task automatic reset_cpu();
    $display("---------------------------------------");
    $display("Applying reset");
    $display("---------------------------------------");

    rst_n = 1'b0;
    @(posedge clk);
    #1ps;

    rst_n = 1'b1;
    #1ps;

    check_pc(32'h00000000, "Reset");
    scoreboard_reset();
  endtask

  // ------------------------------------------------------------
  // Coverage check
  // ------------------------------------------------------------
  task automatic check_seen(input string name, input int count);
    coverage_points++;
    if (count == 0) begin
      $error("Coverage missing: %s", name);
      error_count++;
    end else begin
      coverage_hits++;
    end
  endtask

  task automatic check_cpu_coverage();
    check_seen("lw", seen_lw);
    check_seen("sw", seen_sw);
    check_seen("sb", seen_sb);
    check_seen("sh", seen_sh);
    check_seen("lb", seen_lb);
    check_seen("lh", seen_lh);
    check_seen("lbu", seen_lbu);
    check_seen("lhu", seen_lhu);
    check_seen("branch taken", seen_branch_taken);
    check_seen("branch not taken", seen_branch_not_taken);
    check_seen("jal", seen_jal);
    check_seen("jalr", seen_jalr);
  endtask

  // ------------------------------------------------------------
  // Feature verification sections
  // ------------------------------------------------------------

  task automatic verify_word_load_store_and_basic_alu();
    $display("---------------------------------------");
    $display("Verifying word load/store and basic ALU");
    $display("---------------------------------------");

    step_cpu("lw x18, 12(x0)");
    seen_lw++;
    expect_reg(18, 32'hABCDEF11);
    compare_reg(18, "LW x18");

    step_cpu("sw x18, 16(x0)");
    seen_sw++;
    expect_mem(4, 32'hABCDEF11);
    compare_mem(4, "SW x18");

    step_cpu("lw x17, 20(x0)");
    seen_lw++;
    expect_reg(17, 32'h12345678);
    compare_reg(17, "LW x17");

    step_cpu("add x19, x18, x17");
    expect_reg(19, 32'hBE024589);
    compare_reg(19, "ADD x19");

    step_cpu("and x21, x18, x19");
    expect_reg(21, 32'hAA004501);
    compare_reg(21, "AND x21");

    step_cpu("lw x5, 24(x0)");
    seen_lw++;
    expect_reg(5, 32'h125F552D);
    compare_reg(5, "LW x5");

    step_cpu("lw x6, 28(x0)");
    seen_lw++;
    expect_reg(6, 32'h7F4FD46A);
    compare_reg(6, "LW x6");

    step_cpu("or x7, x5, x6");
    expect_reg(7, 32'h7F5FD56F);
    compare_reg(7, "OR x7");

    step_cpu("nop");
    expect_pc(32'h00000024);
    compare_pc("NOP");
  endtask

  task automatic verify_branches();
    $display("---------------------------------------");
    $display("Verifying branches");
    $display("---------------------------------------");

    step_cpu("beq x6, x7, 12 not taken");
    seen_branch_not_taken++;
    expect_pc(32'h00000028);
    compare_pc("BEQ not taken");

    step_cpu("lw x22, 8(x0)");
    seen_lw++;
    expect_reg(22, 32'hABCDEF11);
    compare_reg(22, "LW x22");

    step_cpu("beq x18, x22, 16 taken");
    seen_branch_taken++;
    expect_pc(32'h0000003C);
    compare_pc("BEQ taken");

    step_cpu("lw x22, 0(x0)");
    seen_lw++;
    expect_reg(22, 32'hAEAEAEAE);
    compare_reg(22, "LW x22 loop body");

    step_cpu("beq x22, x22, -8 taken");
    seen_branch_taken++;
    expect_pc(32'h00000038);
    compare_pc("BEQ backward taken");

    step_cpu("beq x0, x0, 12 taken");
    seen_branch_taken++;
    expect_pc(32'h00000044);
    compare_pc("BEQ jump out");

    step_cpu("nop");
    expect_pc(32'h00000048);
    compare_pc("Post-BEQ NOP");
  endtask

  task automatic verify_jal();
    $display("---------------------------------------");
    $display("Verifying JAL");
    $display("---------------------------------------");

    step_cpu("jal x1, 12");
    seen_jal++;
    expect_pc(32'h00000054);
    expect_reg(1, 32'h0000004C);
    compare_pc("JAL forward");
    compare_reg(1, "JAL forward link");

    step_cpu("jal x1, -4");
    seen_jal++;
    expect_pc(32'h00000050);
    expect_reg(1, 32'h00000058);
    compare_pc("JAL backward");
    compare_reg(1, "JAL backward link");

    step_cpu("jal x1, 12");
    seen_jal++;
    expect_pc(32'h0000005C);
    expect_reg(1, 32'h00000054);
    compare_pc("JAL jump out");
    compare_reg(1, "JAL jump out link");
  endtask

  task automatic verify_immediates_and_compare_ops();
    $display("---------------------------------------");
    $display("Verifying immediates and compares");
    $display("---------------------------------------");

    step_cpu("lw x7, 12(x0)");
    seen_lw++;
    expect_reg(7, 32'hABCDEF11);
    compare_reg(7, "Post-JAL LW x7");

    step_cpu("nop");
    expect_pc(32'h00000064);
    compare_pc("Post-JAL NOP");

    step_cpu("lw x18, 0(x0)");
    seen_lw++;
    expect_reg(18, 32'hAEAEAEAE);
    compare_reg(18, "ADDI prep LW x18");

    step_cpu("addi x23, x18, 0x0BC");
    expect_reg(23, 32'hAEAEAF6A);
    compare_reg(23, "ADDI x23");

    step_cpu("nop");

    step_cpu("auipc x5, 0x12345");
    expect_reg(5, 32'h12345070);
    compare_reg(5, "AUIPC x5");

    step_cpu("lui x5, 0xABCDE");
    expect_reg(5, 32'hABCDE000);
    compare_reg(5, "LUI x5");

    step_cpu("nop");

    step_cpu("slti x21, x18, 100");
    expect_reg(21, 32'h00000001);
    compare_reg(21, "SLTI x21");

    step_cpu("nop");

    step_cpu("sltiu x22, x18, 0xfff");
    expect_reg(22, 32'h00000001);
    compare_reg(22, "SLTIU x22");

    step_cpu("nop");

    step_cpu("xor x8, x18, x23");
    expect_reg(8, 32'h000001C4);
    compare_reg(8, "XOR x8");

    step_cpu("nop");
  endtask

  task automatic verify_blt_and_jalr();
    $display("---------------------------------------");
    $display("Verifying BLT and JALR");
    $display("---------------------------------------");

    step_cpu("blt x17, x18, 8 not taken");
    seen_branch_not_taken++;
    expect_pc(32'h00000098);
    compare_pc("BLT not taken");

    step_cpu("blt x18, x17, 8 taken");
    seen_branch_taken++;
    expect_pc(32'h000000A0);
    compare_pc("BLT taken");
    compare_reg(8, "BLT poison check");

    step_cpu("nop at 0xA0");
    expect_pc(32'h000000A4);
    compare_pc("JALR setup NOP");

    step_cpu("addi x7, x0, 0x0C0");
    expect_reg(7, 32'h000000C0);
    compare_reg(7, "JALR base");

    step_cpu("jalr x1, -11(x7)");
    seen_jalr++;
    expect_pc(32'h000000B4);
    expect_reg(1, 32'h000000AC);
    compare_pc("JALR aligned target");
    compare_reg(1, "JALR link");
    compare_reg(8, "JALR poison check");

    step_cpu("addi x9, x0, 5");
    expect_reg(9, 32'h00000005);
    compare_reg(9, "JALR landing");
  endtask

  task automatic verify_partial_stores();
    $display("---------------------------------------");
    $display("Verifying SB/SH stores");
    $display("---------------------------------------");

    step_cpu("sw x0, 32(x0)");
    seen_sw++;
    expect_mem(8, 32'h00000000);
    compare_mem(8, "clear partial-store word");

    step_cpu("sb x17, 33(x0)");
    seen_sb++;
    expect_mem(8, 32'h00007800);
    compare_mem(8, "SB lane 1");

    step_cpu("sb x23, 35(x0)");
    seen_sb++;
    expect_mem(8, 32'h6A007800);
    compare_mem(8, "SB lane 3");

    step_cpu("sh x17, 36(x0)");
    seen_sh++;
    expect_mem(9, 32'h00005678);
    compare_mem(9, "SH lower half");

    step_cpu("sh x18, 38(x0)");
    seen_sh++;
    expect_mem(9, 32'hAEAE5678);
    compare_mem(9, "SH upper half");
  endtask

  task automatic verify_partial_loads();
    $display("---------------------------------------");
    $display("Verifying LB/LH/LBU/LHU loads");
    $display("---------------------------------------");

    step_cpu("lb x24, 33(x0)");
    seen_lb++;
    expect_reg(24, 32'h00000078);
    compare_reg(24, "LB x24");

    step_cpu("lbu x25, 35(x0)");
    seen_lbu++;
    expect_reg(25, 32'h0000006A);
    compare_reg(25, "LBU x25");

    step_cpu("lh x26, 38(x0)");
    seen_lh++;
    expect_reg(26, 32'hFFFFAEAE);
    compare_reg(26, "LH x26 sign extend");

    step_cpu("lhu x27, 38(x0)");
    seen_lhu++;
    expect_reg(27, 32'h0000AEAE);
    compare_reg(27, "LHU x27 zero extend");

    step_cpu("lh x28, 36(x0)");
    seen_lh++;
    expect_reg(28, 32'h00005678);
    compare_reg(28, "LH x28 positive");
  endtask

  // ------------------------------------------------------------
  // Main test
  // ------------------------------------------------------------
  initial begin
    reset_cpu();

    verify_word_load_store_and_basic_alu();
    verify_branches();
    verify_jal();
    verify_immediates_and_compare_ops();
    verify_blt_and_jalr();
    verify_partial_stores();
    verify_partial_loads();

    check_cpu_coverage();
    finish_report("cpu_tb");
  end

endmodule
