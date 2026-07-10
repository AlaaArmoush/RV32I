`timescale 1ns / 1ps

interface memory_if #(parameter int ADDR_WIDTH = 32) (
  input logic clk
);
  logic [ADDR_WIDTH-1:0] address;
  logic [31:0] write_data;
  logic write_enable;
  logic rst_n;
  logic [3:0] byte_enable;
  logic [31:0] read_data;

  modport driver (
      input  clk,
      input  read_data,
      output rst_n,
      output address,
      output write_data,
      output write_enable,
      output byte_enable
  );

  modport monitor (
      input clk,
      input rst_n,
      input address,
      input write_data,
      input write_enable,
      input byte_enable,
      input read_data
  );
endinterface

typedef enum int{
  MEM_OP_RESET,
  MEM_OP_READ,
  MEM_OP_WRITE,
  MEM_OP_WRITE_DISABLED
} memory_op_e;


class memory_item;
  rand memory_op_e op;
  rand int unsigned word_index;
  rand logic [31:0] write_data;
  rand logic [3:0] byte_enable;

  int unsigned words = 64;

  logic [31:0] address;
  logic [31:0] read_data;
  logic rst_n;
  int unsigned cycle;

  constraint legal_word_c {
    word_index < words;
  }

  constraint op_byte_enable_c {
    (op == MEM_OP_WRITE) -> byte_enable != 4'b0000;
    (op == MEM_OP_READ) -> byte_enable == 4'b0000;
    (op == MEM_OP_WRITE_DISABLED) -> byte_enable != 4'b0000;
    (op == MEM_OP_RESET) -> byte_enable == 4'b0000;
  }

  constraint op_dist_c {
    op dist {
      MEM_OP_READ := 45,
      MEM_OP_WRITE := 45,
      MEM_OP_WRITE_DISABLED := 8,
      MEM_OP_RESET := 2
    };
  }

  constraint byte_enable_dist_c {
    byte_enable dist {
      4'b0000 := 1,
      4'b0001 := 8,
      4'b0010 := 8,
      4'b0100 := 8,
      4'b1000 := 8,
      4'b0011 := 8,
      4'b1100 := 8,
      4'b1111 := 16,
      [4'b0001:4'b1111] := 10
    };
  }

  function new (int unsigned words = 64);
    this.words = words;
  endfunction

  function post_randomize ();
    // Convert word index to byte address. Each 32-bit word is 4 bytes
    // so word N starts at byte address N*4.
    address = word_index << 2;
  endfunction

  function memory_item clone();
    memory_item item = new(words);

    item.op = op;
    item.word_index = word_index;
    item.write_data = write_data;
    item.byte_enable = byte_enable;
    item.address = address;
    item.read_data = read_data;
    item.rst_n = rst_n;
    item.cycle = cycle;

    return item;
  endfunction

  function string op_name();
    case (op)
      MEM_OP_RESET: return "RESET";
      MEM_OP_READ: return "READ";
      MEM_OP_WRITE: return "WRITE";
      MEM_OP_WRITE_DISABLED: return "WRITE_DISABLED";
      default: return "UNKNOWN";
    endcase
  endfunction

  function string sprint();
    return $sformatf(
        "op=%s word=%0d addr=0x%08h we_data=0x%08h be=%04b rdata=0x%08h rst_n=%0b cycle=%0d",
        op_name(), word_index, address, write_data, byte_enable, read_data, rst_n, cycle);
  endfunction
endclass : memory_item

module memory_tb;
  localparam int WORDS = 64;
  localparam int CLK_PERIOD_NS = 10;
  logic clk = 1'b0;
  
  always #(CLK_PERIOD_NS / 2) clk = ~clk;

  memory_if mem_vif(.clk(clk));

  memory #(
      .WORDS(WORDS),
      .test_mem(""),
      .load_file_arg("")
  ) dut (
      .clk(mem_vif.clk),
      .address(mem_vif.address),
      .write_data(mem_vif.write_data),
      .write_enable(mem_vif.write_enable),
      .rst_n(mem_vif.rst_n),
      .byte_enable(mem_vif.byte_enable),
      .read_data(mem_vif.read_data)
  );

  task automatic init_bus();
    mem_vif.rst_n = 1'b1;
    mem_vif.address = '0;
    mem_vif.write_data = '0;
    mem_vif.write_enable = 1'b0;
    mem_vif.byte_enable = 4'b0000;
  endtask

  task automatic reset_dut();
    mem_vif.rst_n = 1'b0;
    repeat (2) @(posedge clk);
    mem_vif.rst_n = 1'b1;
    @(posedge clk);
  endtask

  initial begin
    $display("[MEM_TB] Starting memory DV refactor skeleton");

    init_bus();
    reset_dut();

    $display("[MEM_TB] Step 1 skeleton complete");
    $finish;
  end
endmodule
