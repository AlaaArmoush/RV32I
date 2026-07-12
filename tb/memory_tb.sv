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

class memory_sequence;
  mailbox #(memory_item) request_mb;
  int unsigned words;

  function new (mailbox #(memory_item) request_mb, int unsigned words = 64);
    this.request_mb = request_mb;
    this.words = words;
  endfunction

  function memory_item make_item (memory_op_e op, int unsigned word_index, logic [31:0] write_data = 32'h0000_0000, logic [3:0] byte_enable = 4'h0);
    memory_item item = new(words);

    item.op = op;
    item.word_index = word_index;
    item.write_data = write_data;
    item.byte_enable = byte_enable;
    item.address = word_index << 2;
    item.read_data = '0;
    item.rst_n = 1'b1;
    item.cycle = 0;

    return item;
  endfunction

  task send_reset();
    memory_item item;
    item = make_item(MEM_OP_RESET, 0);
    request_mb.put(item);
  endtask

  task send_read(int unsigned word_index);
    memory_item item;
    item = make_item(MEM_OP_READ, word_index);
    request_mb.put(item);
  endtask

  task send_write(int unsigned word_index, logic [31:0] write_data, logic [3:0] byte_enable = 4'hF);
    memory_item item;
    item = make_item(MEM_OP_WRITE, word_index, write_data, byte_enable);
    request_mb.put(item);
  endtask

  task send_write_disabled(int unsigned word_index, logic [31:0] write_data, logic [3:0] byte_enable = 4'hF);
    memory_item item;
    item = make_item(MEM_OP_WRITE_DISABLED, word_index, write_data, byte_enable);
    request_mb.put(item);
  endtask

  task run_directed_smoke();
    send_reset();

    send_write(0, 32'h1122_3344, 4'b1111);
    send_read(0);

    send_write(1, 32'haaaa_bbbb, 4'b0011);
    send_read(1);

    send_write(1, 32'hcccc_dddd, 4'b1100);
    send_read(1);

    send_write(words - 1, 32'hffff_0001, 4'b1111);
    send_read(words - 1);

    send_write(2, 32'h1234_5678, 4'b1111);
    send_write_disabled(2, 32'hdead_beef, 4'b1111);
    send_read(2);

    send_write(3, 32'h0000_00ff, 4'b0001);
    send_write(3, 32'h0000_ff00, 4'b0010);
    send_write(3, 32'h00ff_0000, 4'b0100);
    send_write(3, 32'hff00_0000, 4'b1000);
    send_read(3);
  endtask
endclass : memory_sequence

class memory_driver;
  virtual memory_if.driver vif;
  mailbox #(memory_item) request_mb;

  bit verbose; // for debugging
  int unsigned driven_count;

  function new (virtual memory_if.driver vif, mailbox #(memory_item) request_mb);
    this.vif = vif;
    this.request_mb = request_mb;
    this.verbose = 1'b0;
    this.driven_count = 0;
  endfunction

  task drive_idle();
    vif.rst_n <= 1'b1;
    vif.address <= '0;
    vif.write_data <= '0;
    vif.write_enable <= 1'b0;
    vif.byte_enable <= 4'b0000;
  endtask

  task run();
    memory_item item;

    drive_idle();

    forever begin
      request_mb.get(item);
      drive_item(item);
      driven_count++;

      if(verbose) begin
        $display("[MEM_DRIVER] drove %s", item.sprint());
      end
    end
  endtask
  
  //drive on negative edge and read on posedge
  task drive_item(memory_item item);
    case (item.op)
      MEM_OP_RESET: begin
        @(negedge vif.clk);
        vif.rst_n <= 1'b0;
        vif.address <= '0;
        vif.write_data <= '0;
        vif.write_enable <= 1'b0;
        vif.byte_enable <= 4'b0000;

        @(posedge vif.clk);

        @(negedge vif.clk);
        vif.rst_n <= 1'b1;
        vif.write_enable <= 1'b0;
        vif.byte_enable <= 4'b0000;

        @(posedge vif.clk);
      end

      MEM_OP_READ: begin
        @(negedge vif.clk);
        vif.rst_n <= 1'b1;
        vif.address <= item.address;
        vif.write_data <= '0;
        vif.write_enable <= 1'b0;
        vif.byte_enable <= 4'b0000;

        @(posedge vif.clk);
      end

      MEM_OP_WRITE: begin
        @(negedge vif.clk);
        vif.rst_n <= 1'b1;
        vif.address <= item.address;
        vif.write_data <= item.write_data;
        vif.write_enable <= 1'b1;
        vif.byte_enable <= item.byte_enable;

        @(posedge vif.clk);
      end

      MEM_OP_WRITE_DISABLED: begin
        @(negedge vif.clk);
        vif.rst_n <= 1'b1;
        vif.address <= item.address;
        vif.write_data <= item.write_data;
        vif.write_enable <= 1'b0;
        vif.byte_enable <= item.byte_enable;

        @(posedge vif.clk);
      end

      default: begin
        $fatal(1, "[MEM_DRIVER] Unknown memory operation");
      end
    endcase
  endtask
endclass : memory_driver


class memory_monitor;
  virtual memory_if.monitor vif;
  mailbox #(memory_item) observed_mb;

  bit verbose;
  int unsigned observed_count;
  int unsigned cycle;
  int unsigned words;

  function new(virtual memory_if.monitor vif, mailbox #(memory_item) observed_mb, int unsigned words = 64);
    this.vif = vif;
    this.observed_mb = observed_mb;
    this.words = words;
    this.verbose = 1'b0;
    this.observed_count = 0;
    this.cycle = 0;
  endfunction

  task run();
    memory_item item;

    forever begin
      @(posedge vif.clk);
      cycle++;

      item = new(words);
      item.rst_n = vif.rst_n;
      item.address = vif.address;
      item.word_index = vif.address[31:2];
      item.write_data = vif.write_data;
      item.write_enable = vif.write_enable;
      item.byte_enable = vif.byte_enable;
      item.cycle = cycle;

      if (!vif.rst_n) begin
        item.op = MEM_OP_RESET;
        item.read_data = '0;
      end else if (vif.write_enable) begin
        item.op = MEM_OP_WRITE;
        #1;
        item.read_data = vif.read_data;
      end else if (vif.byte_enable != 4'b0000) begin
        item.op = MEM_OP_WRITE_DISABLED;
        #1;
        item.read_data = vif.read_data;
      end else begin
        item.op = MEM_OP_READ;
        #1;
        item.read_data = vif.read_data;
      end

      observed_mb.put(item);
      observed_count++;

      if (verbose) begin
        $display("[MEM_MONITOR] observed %s", item.sprint());
      end
    end
  endtask
endclass

class memory_scoreboard;
  mailbox #(memory_item) observed_mb;

  logic [31:0] shadow_mem[];

  int unsigned words;
  int unsigned checked_count;
  int unsigned error_count;
  bit verbose;

  function new(mailbox #(memory_item) observed_mb, int unsigned words = 64);
    this.observed_mb = observed_mb;
    this.words = words;
    this.checked_count = 0;
    this.error_count = 0;
    this.verbose = 1'b0;

    shadow_mem = new[words];
    reset_shadow();
  endfunction

  function void reset_shadow();
    foreach (shadow_mem[i]) begin
      shadow_mem[i] = 32'h0000_0000;
    end
  endfunction

  function logic [31:0] apply_byte_enable(
      logic [31:0] old_word,
      logic [31:0] write_data,
      logic [3:0] byte_enable
  );
    logic [31:0] next_word;

    next_word = old_word;
    for (int lane = 0; lane < 4; lane++) begin
      if (byte_enable[lane]) begin
        next_word[8*lane +: 8] = write_data[8*lane +: 8];
      end
    end

    return next_word;
  endfunction

  function void fail(memory_item item, string message);
    error_count++;
    $error("[MEM_SCOREBOARD] %s | %s", message, item.sprint());
  endfunction

  task run();
    memory_item item;
    logic [31:0] expected_word;

    forever begin
      observed_mb.get(item);

      if (item.op == MEM_OP_RESET) begin
        reset_shadow();
        checked_count++;

        if (verbose) begin
          $display("[MEM_SCOREBOARD] reset observed at cycle %0d", item.cycle);
        end

        continue;
      end

      if (item.word_index >= words) begin
        fail(item, $sformatf("Address word index %0d is outside WORDS=%0d", item.word_index, words));
        continue;
      end

      expected_word = shadow_mem[item.word_index];

      case (item.op)
        MEM_OP_READ: begin
          if (item.read_data !== expected_word) begin
            fail(item, $sformatf("Read mismatch expected=0x%08h actual=0x%08h", expected_word, item.read_data));
          end
        end

        MEM_OP_WRITE: begin
          expected_word = apply_byte_enable(expected_word, item.write_data, item.byte_enable);
          shadow_mem[item.word_index] = expected_word;

          if (item.read_data !== expected_word) begin
            fail(item, $sformatf("Write/readback mismatch expected=0x%08h actual=0x%08h", expected_word, item.read_data));
          end
        end

        MEM_OP_WRITE_DISABLED: begin
          if (item.read_data !== expected_word) begin
            fail(item, $sformatf("Write-disabled changed/read mismatch expected=0x%08h actual=0x%08h", expected_word, item.read_data));
          end
        end

        default: begin
          fail(item, "Unknown operation observed");
        end
      endcase

      checked_count++;

      if (verbose) begin
        $display("[MEM_SCOREBOARD] checked %s", item.sprint());
      end
    end
  endtask

  function void report();
    $display("[MEM_SCOREBOARD] checked=%0d errors=%0d", checked_count, error_count);

    if (error_count != 0) begin
      $fatal(1, "[MEM_SCOREBOARD] FAILED with %0d error(s)", error_count);
    end
  endfunction
endclass

module memory_tb;
  localparam int WORDS = 64;
  localparam int CLK_PERIOD_NS = 10;
  logic clk = 1'b0;
  
  mailbox #(memory_item) request_mb;
  mailbox #(memory_item) observed_mb;

  memory_sequence seq;
  memory_driver driver;
  memory_monitor monitor;
  memory_scoreboard scoreboard;

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

  end

endmodule
