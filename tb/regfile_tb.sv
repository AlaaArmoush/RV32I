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

module regfile_tb;
endmodule
