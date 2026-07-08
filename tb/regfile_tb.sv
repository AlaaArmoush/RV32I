`timescale 1ns / 1ps

interface regfile_if(input logic clk);
  logic rst_n;
  logic [4:0] address1;
  logic [4:0] address2;
  logic [4:0] address3;
  logic write_enable;
  logic [31:0] write_data;
  logic [31:0] read_data1;
  logic [31:0] read_data2;

  modport dut (
    input  clk,
    input  rst_n,
    input  address1,
    input  address2,
    input  address3,
    input  write_enable,
    input  write_data,
    output read_data1,
    output read_data2
  );

  modport driver (
    input clk,
    output rst_n,
    output address1,
    output address2,
    output address3,
    output write_enable,
    output write_data
  );

  modport monitor (
    input clk,
    input rst_n,
    input address1,
    input address2,
    input address3,
    input write_enable,
    input write_data,
    input read_data1,
    input read_data2
  );
  
endinterface

class regfile_item;
  rand bit [4:0]  address1;
  rand bit [4:0]  address2;
  rand bit [4:0]  address3;
  rand bit        write_enable;
  rand bit [31:0] write_data;

  logic        rst_n;
  logic [31:0] read_data1;
  logic [31:0] read_data2;

  string name;

  function new(string name = "regfile_item");
    this.name = name;
  endfunction

  function string sprint();
    return $sformatf(
        "%s rst_n=%0b a1=x%0d rd1=0x%08h a2=x%0d rd2=0x%08h we=%0b a3=x%0d wd=0x%08h",
        name, rst_n, address1, read_data1, address2, read_data2,
        write_enable, address3, write_data
    );
  endfunction
endclass


class regfile_driver;
  virtual regfile_if.driver vif;

  function new(virtual regfile_if.driver vif);
    this.vif = vif;  
  endfunction

  task reset();
    vif.rst_n        <= 1'b0;
    vif.address1     <= 5'd0;
    vif.address2     <= 5'd0;
    vif.address3     <= 5'd0;
    vif.write_enable <= 1'b0;
    vif.write_data   <= 32'd0;
    repeat (2) @(posedge vif.clk);

    vif.rst_n <= 1'b1;
    @(posedge vif.clk);
  endtask

  task drive_item(regfile_item item);
    @(negedge vif.clk);

    vif.address1     <= item.address1;
    vif.address2     <= item.address2;
    vif.address3     <= item.address3;
    vif.write_enable <= item.write_enable;
    vif.write_data   <= item.write_data;

    @(posedge vif.clk);
  endtask
endclass

class regfile_scoreboard;
  logic [31:0] shadow_regs[32];

  int error_count = 0;
  int total_checks = 0;
  int passed_checks = 0;
  int reset_checks = 0;
  int directed_checks = 0;
  int random_checks = 0;
  int write_count = 0;
  int write_disabled_count = 0;
  int x0_write_attempts = 0;
  int same_cycle_raw_checks = 0;

  function new();
    reset_shadow();
  endfunction

  function void reset_shadow();
    for (int i = 0; i < 32; i++) begin
      shadow_regs[i] = 32'd0;
    end
  endfunction

  function void check_eq32(
      input string label,
      input logic [31:0] got,
      input logic [31:0] expected
  );
    total_checks++;

    if (got !== expected) begin
      error_count++;
      $error("%s failed: expected 0x%08h, got 0x%08h", label, expected, got);
    end else begin
      passed_checks++;
    end
  endfunction

  function void observe_item(
      input regfile_item item,
      input string phase = "directed",
      input bit is_random = 1'b0
  );
    if (!item.rst_n) begin
      reset_shadow();
      return;
    end

    if (item.write_enable) begin
      if (item.address3 == 5'd0) begin
        x0_write_attempts++;
      end else begin
        shadow_regs[item.address3] = item.write_data;
        write_count++;
      end

      if ((item.address1 == item.address3) || (item.address2 == item.address3)) begin
        same_cycle_raw_checks++;
      end
    end else begin
      write_disabled_count++;
    end

    shadow_regs[0] = 32'd0;

    if (phase == "reset") begin
      reset_checks += 2;
    end else if (is_random) begin
      random_checks += 2;
    end else begin
      directed_checks += 2;
    end

    check_eq32(
        $sformatf("%s port1 x%0d", phase, item.address1),
        item.read_data1,
        shadow_regs[item.address1]
    );

    check_eq32(
        $sformatf("%s port2 x%0d", phase, item.address2),
        item.read_data2,
        shadow_regs[item.address2]
    );
  endfunction

  function void report();
    $display("---------------------------------------");
    $display("Regfile scoreboard summary");
    $display("  Reset checks          : %0d", reset_checks);
    $display("  Directed checks       : %0d", directed_checks);
    $display("  Random checks         : %0d", random_checks);
    $display("  Writes to real regs   : %0d", write_count);
    $display("  Disabled write cycles : %0d", write_disabled_count);
    $display("  x0 write attempts     : %0d", x0_write_attempts);
    $display("  Same-cycle RAW checks : %0d", same_cycle_raw_checks);
    $display("  Total checks          : %0d", total_checks);
    $display("  Passed checks         : %0d", passed_checks);
    $display("  Failed checks         : %0d", error_count);
    $display("---------------------------------------");
  endfunction
endclass

class regfile_monitor;
  virtual regfile_if.monitor vif;

  function new(virtual regfile_if.monitor vif);
    this.vif = vif;
  endfunction

  task sample_item(
      output regfile_item item,
      input string name = "monitored_item"
  );
    #1ps;

    item = new(name);
    item.rst_n        = vif.rst_n;
    item.address1     = vif.address1;
    item.address2     = vif.address2;
    item.address3     = vif.address3;
    item.write_enable = vif.write_enable;
    item.write_data   = vif.write_data;
    item.read_data1   = vif.read_data1;
    item.read_data2   = vif.read_data2;
  endtask
endclass

class regfile_coverage;
  covergroup regfile_cg with function sample(
      bit        reset_active,
      bit [4:0]  address1,
      bit [4:0]  address2,
      bit [4:0]  address3,
      bit        write_enable,
      bit [31:0] write_data,
      bit        raw_port1,
      bit        raw_port2,
      bit        same_read_address,
      bit        x0_write_readback
  );
    option.per_instance = 1;

    cp_reset: coverpoint reset_active {
      bins reset = {1};
      bins normal = {0};
    }

    cp_read_port1: coverpoint address1 {
      bins x0 = {0};
      bins low_regs = {[1:15]};
      bins high_regs = {[16:31]};
    }

    cp_read_port2: coverpoint address2 {
      bins x0 = {0};
      bins low_regs = {[1:15]};
      bins high_regs = {[16:31]};
    }

    cp_write_addr: coverpoint address3 {
      bins x0 = {0};
      bins low_regs = {[1:15]};
      bins high_regs = {[16:31]};
    }

    cp_write_enable: coverpoint write_enable {
      bins disabled = {0};
      bins enabled = {1};
    }

    cp_write_data: coverpoint write_data {
      bins zero = {32'h0000_0000};
      bins all_ones = {32'hFFFF_FFFF};
      bins sign_bit_set = {[32'h8000_0000:32'hFFFF_FFFE]};
      bins walking_bits[] = {
        32'h0000_0001,
        32'h0000_0002,
        32'h0000_0004,
        32'h0000_0008,
        32'h0000_0010,
        32'h0000_0080,
        32'h0000_8000,
        32'h8000_0000
      };
      bins other = default;
    }

    cp_raw_port1: coverpoint raw_port1 {
      bins no_raw = {0};
      bins raw = {1};
    }

    cp_raw_port2: coverpoint raw_port2 {
      bins no_raw = {0};
      bins raw = {1};
    }

    cp_same_read_address: coverpoint same_read_address {
      bins different = {0};
      bins same = {1};
    }

    cp_x0_write_readback: coverpoint x0_write_readback {
      bins no_attempt = {0};
      bins attempted = {1};
    }

    cross cp_write_addr, cp_write_enable;
    cross cp_read_port1, cp_write_addr;
    cross cp_read_port2, cp_write_addr;
    cross cp_raw_port1, cp_write_enable;
    cross cp_raw_port2, cp_write_enable;
    cross cp_x0_write_readback, cp_write_enable;
  endgroup

  function new();
    regfile_cg = new();
  endfunction

  function void sample(input regfile_item item);
    regfile_cg.sample(
        !item.rst_n,
        item.address1,
        item.address2,
        item.address3,
        item.write_enable,
        item.write_data,
        item.address1 == item.address3,
        item.address2 == item.address3,
        item.address1 == item.address2,
        (item.address3 == 5'd0) &&
            ((item.address1 == 5'd0) || (item.address2 == 5'd0))
    );
  endfunction
endclass

module regfile_sva(regfile_if.monitor mon);
  property port1_x0_reads_zero;
    @(posedge mon.clk)
      (mon.address1 == 5'd0) |-> (mon.read_data1 == 32'd0);
  endproperty

  property port2_x0_reads_zero;
    @(posedge mon.clk)
      (mon.address2 == 5'd0) |-> (mon.read_data2 == 32'd0);
  endproperty

  property x0_write_port1_stays_zero;
    @(negedge mon.clk) disable iff (!mon.rst_n)
      (mon.write_enable && (mon.address3 == 5'd0) && (mon.address1 == 5'd0))
      |-> (mon.read_data1 == 32'd0);
  endproperty

  property x0_write_port2_stays_zero;
    @(negedge mon.clk) disable iff (!mon.rst_n)
      (mon.write_enable && (mon.address3 == 5'd0) && (mon.address2 == 5'd0))
      |-> (mon.read_data2 == 32'd0);
  endproperty

  assert property (port1_x0_reads_zero)
    else $error("regfile x0 invariant failed on read port 1");

  assert property (port2_x0_reads_zero)
    else $error("regfile x0 invariant failed on read port 2");

  assert property (x0_write_port1_stays_zero)
    else $error("regfile x0 write attempt changed read port 1");

  assert property (x0_write_port2_stays_zero)
    else $error("regfile x0 write attempt changed read port 2");
endmodule

module regfile_tb;
  localparam int DEFAULT_RANDOM_TESTS = 1000;

  logic clk;

  regfile_if rf_if(clk);

  regfile dut (
      .clk(clk),
      .rst_n(rf_if.rst_n),
      .address1(rf_if.address1),
      .address2(rf_if.address2),
      .address3(rf_if.address3),
      .write_enable(rf_if.write_enable),
      .write_data(rf_if.write_data),
      .read_data1(rf_if.read_data1),
      .read_data2(rf_if.read_data2)
  );

  regfile_sva sva_i(rf_if);

  regfile_driver     driver;
  regfile_monitor    monitor;
  regfile_scoreboard scoreboard;
  regfile_coverage   coverage;

  int unsigned seed;
  int random_tests;

  initial clk = 1'b0;
  always #5 clk = ~clk;

  task automatic drive_sample_check(
      input regfile_item drive_item,
      input string phase = "directed",
      input bit is_random = 1'b0
  );
    regfile_item sampled_item;

    driver.drive_item(drive_item);
    monitor.sample_item(sampled_item, drive_item.name);

    scoreboard.observe_item(sampled_item, phase, is_random);
    coverage.sample(sampled_item);
  endtask

  task automatic check_reads(
      input bit [4:0] a1,
      input bit [4:0] a2,
      input string phase = "directed"
  );
    regfile_item item;

    item = new(phase);
    item.address1 = a1;
    item.address2 = a2;
    item.address3 = 5'd0;
    item.write_enable = 1'b0;
    item.write_data = 32'd0;

    drive_sample_check(item, phase, 1'b0);
  endtask

  task automatic write_reg(
      input bit [4:0] rd,
      input bit [31:0] data,
      input bit enable = 1'b1,
      input string phase = "directed"
  );
    regfile_item item;

    item = new(phase);
    item.address1 = rd;
    item.address2 = rd;
    item.address3 = rd;
    item.write_enable = enable;
    item.write_data = data;

    drive_sample_check(item, phase, 1'b0);
  endtask

  task automatic verify_reset();
    $display("---------------------------------------");
    $display("Verifying regfile reset");
    $display("---------------------------------------");

    driver.reset();
    scoreboard.reset_shadow();

    begin
      regfile_item reset_item;

      reset_item = new("reset_sample");
      reset_item.rst_n = 1'b0;
      reset_item.address1 = 5'd0;
      reset_item.address2 = 5'd0;
      reset_item.address3 = 5'd0;
      reset_item.write_enable = 1'b0;
      reset_item.write_data = 32'd0;
      reset_item.read_data1 = 32'd0;
      reset_item.read_data2 = 32'd0;

      coverage.sample(reset_item);
    end

    for (int i = 0; i < 32; i += 2) begin
      check_reads(5'(i), 5'(i + 1), "reset");
    end
  endtask

  task automatic verify_x0_behavior();
    $display("---------------------------------------");
    $display("Verifying x0 hardwired-zero behavior");
    $display("---------------------------------------");

    write_reg(5'd0, 32'hDEAD_BEEF, 1'b1, "x0 write ignored");
    check_reads(5'd0, 5'd0, "x0 readback");

    write_reg(5'd1, 32'h1234_5678, 1'b1, "normal write");
    check_reads(5'd0, 5'd1, "x0 with normal reg");
  endtask

  task automatic verify_read_after_write();
    $display("---------------------------------------");
    $display("Verifying same-cycle read-after-write behavior");
    $display("---------------------------------------");

    for (int rd = 1; rd < 8; rd++) begin
      write_reg(rd[4:0], 32'h1000_0000 + rd, 1'b1, "same-cycle raw");
      check_reads(rd[4:0], rd[4:0], "readback after write");
    end
  endtask

  task automatic verify_write_disable();
    $display("---------------------------------------");
    $display("Verifying write disable holds state");
    $display("---------------------------------------");

    write_reg(5'd9, 32'hAAAA_5555, 1'b1, "write enabled");
    write_reg(5'd9, 32'hFFFF_0000, 1'b0, "write disabled");
    check_reads(5'd9, 5'd9, "write disabled readback");
  endtask

  task automatic verify_data_patterns();
    $display("---------------------------------------");
    $display("Verifying directed data patterns");
    $display("---------------------------------------");

    write_reg(5'd10, 32'h0000_0000, 1'b1, "data zero");
    write_reg(5'd11, 32'hFFFF_FFFF, 1'b1, "data all ones");
    write_reg(5'd12, 32'h8000_0000, 1'b1, "data sign bit");
    write_reg(5'd13, 32'h0000_0001, 1'b1, "data walking bit");
    write_reg(5'd14, 32'h0000_8000, 1'b1, "data walking bit");
    write_reg(5'd15, 32'h0000_0002, 1'b1, "data walking bit");
    write_reg(5'd16, 32'h0000_0004, 1'b1, "data walking bit");
    write_reg(5'd17, 32'h0000_0008, 1'b1, "data walking bit");
    write_reg(5'd18, 32'h0000_0010, 1'b1, "data walking bit");
    write_reg(5'd19, 32'h0000_0080, 1'b1, "data walking bit");

    check_reads(5'd10, 5'd11, "pattern readback");
    check_reads(5'd12, 5'd13, "pattern readback");
    check_reads(5'd14, 5'd0,  "pattern readback");
  endtask

  task automatic verify_random_traffic();
    regfile_item item;
    int randomized_ok;

    $display("---------------------------------------");
    $display("Verifying constrained-random regfile traffic");
    $display("---------------------------------------");

    void'($urandom(seed));

    for (int i = 0; i < random_tests; i++) begin
      item = new($sformatf("random_%0d", i));

      randomized_ok = item.randomize();
      if (randomized_ok == 0) begin
        $fatal(1, "Failed to randomize regfile item at iteration %0d", i);
      end

      case (i % 16)
        0: begin
          item.write_enable = 1'b1;
          item.address3 = 5'd0;
          item.address1 = 5'd0;
        end

        1: begin
          item.write_enable = 1'b1;
          item.address1 = item.address3;
        end

        2: begin
          item.write_enable = 1'b1;
          item.address2 = item.address3;
        end

        3: begin
          item.address2 = item.address1;
        end

        4: begin
          item.write_enable = 1'b1;
          item.write_data = 32'h0000_0000;
        end

        5: begin
          item.write_enable = 1'b1;
          item.write_data = 32'hFFFF_FFFF;
        end

        6: begin
          item.write_enable = 1'b1;
          item.write_data = 32'h8000_0000;
        end

        default: begin
        end
      endcase

      drive_sample_check(item, "random", 1'b1);
    end
  endtask

    task automatic finish_report();
    scoreboard.report();

    if (scoreboard.error_count == 0) begin
      $display("regfile_tb PASSED");
      $finish;
    end else begin
      $fatal(1, "regfile_tb FAILED with %0d error(s)", scoreboard.error_count);
    end
  endtask

  initial begin
    seed = 32'hA11C_2026;
    random_tests = DEFAULT_RANDOM_TESTS;

    if ($value$plusargs("SEED=%d", seed)) begin
      $display("Using plusarg SEED=%0d", seed);
    end else begin
      $display("Using default SEED=%0d", seed);
    end

    if ($value$plusargs("RANDOM_TESTS=%d", random_tests)) begin
      $display("Using plusarg RANDOM_TESTS=%0d", random_tests);
    end else begin
      $display("Using default RANDOM_TESTS=%0d", random_tests);
    end

    driver = new(rf_if);
    monitor = new(rf_if);
    scoreboard = new();
    coverage = new();

    verify_reset();
    verify_x0_behavior();
    verify_read_after_write();
    verify_write_disable();
    verify_data_patterns();
    verify_random_traffic();

    finish_report();
  end

endmodule
