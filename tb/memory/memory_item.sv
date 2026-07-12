`timescale 1ns / 1ps

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
  logic write_enable;
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

  function void post_randomize();
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
    item.write_enable = write_enable;
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
