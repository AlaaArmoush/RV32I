`timescale 1ns / 1ps

class memory_sequence;
  mailbox #(memory_item) request_mb;
  int unsigned words;
  int unsigned generated_count;

  function new (mailbox #(memory_item) request_mb, int unsigned words = 64);
    this.request_mb = request_mb;
    this.words = words;
    this.generated_count = 0;
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

  task send_item(memory_item item);
    request_mb.put(item);
    generated_count++;
  endtask

  task send_reset();
    send_item(make_item(MEM_OP_RESET, 0));
  endtask

  task send_read(int unsigned word_index);
    send_item(make_item(MEM_OP_READ, word_index));
  endtask

  task send_write(int unsigned word_index, logic [31:0] write_data, logic [3:0] byte_enable = 4'hF);
    send_item(make_item(MEM_OP_WRITE, word_index, write_data, byte_enable));
  endtask

  task send_write_disabled(int unsigned word_index, logic [31:0] write_data, logic [3:0] byte_enable = 4'hF);
    send_item(make_item(MEM_OP_WRITE_DISABLED, word_index, write_data, byte_enable));
  endtask

  task run_directed_smoke();
    send_reset();

    send_read(4);

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

    run_coverage_targets();
  endtask

  task run_coverage_targets();
    send_write(5, 32'h0000_0000, 4'b0001);
    send_write(6, 32'h0000_0000, 4'b0011);
    send_write(7, 32'h0000_0000, 4'b1100);
    send_write(8, 32'h0000_0000, 4'b1111);
    send_write(9, 32'h0000_0000, 4'b0101);

    send_write(10, 32'hffff_ffff, 4'b0001);
    send_write(11, 32'hffff_ffff, 4'b0011);
    send_write(12, 32'hffff_ffff, 4'b1100);
    send_write(13, 32'hffff_ffff, 4'b1111);
    send_write(14, 32'hffff_ffff, 4'b1010);

    send_write(15, 32'h0000_00ff, 4'b0011);
    send_write(16, 32'h0000_ff00, 4'b1100);
    send_write(17, 32'h00ff_0000, 4'b1111);
    send_write(18, 32'hff00_0000, 4'b0101);
  endtask

  task run_random(int unsigned count);
    memory_item item;
    int unsigned last_word_index;
    bit have_last_word_index;

    last_word_index = 0;
    have_last_word_index = 1'b0;

    for (int unsigned i = 0; i < count; i++) begin
      item = new(words);

      if (!item.randomize()) begin
        $fatal(1, "[MEM_SEQUENCE] Failed to randomize item %0d", i);
      end

      case (i % 16)
        0: begin
          item.op = MEM_OP_WRITE;
          item.word_index = 0;
          item.byte_enable = 4'b1111;
        end

        1: begin
          item.op = MEM_OP_READ;
          item.word_index = 0;
          item.byte_enable = 4'b0000;
        end

        2: begin
          item.op = MEM_OP_WRITE;
          item.word_index = words - 1;
          item.byte_enable = 4'b1111;
        end

        3: begin
          item.op = MEM_OP_READ;
          item.word_index = words - 1;
          item.byte_enable = 4'b0000;
        end

        4: begin
          item.op = MEM_OP_WRITE;
          item.byte_enable = 4'b0001;
        end

        5: begin
          item.op = MEM_OP_WRITE;
          item.byte_enable = 4'b0010;
        end

        6: begin
          item.op = MEM_OP_WRITE;
          item.byte_enable = 4'b0100;
        end

        7: begin
          item.op = MEM_OP_WRITE;
          item.byte_enable = 4'b1000;
        end

        8: begin
          item.op = MEM_OP_WRITE_DISABLED;
          item.byte_enable = 4'b1111;
        end

        9: begin
          if (have_last_word_index) begin
            item.word_index = last_word_index;
          end
        end

        default: begin
        end
      endcase

      item.address = item.word_index << 2;
      last_word_index = item.word_index;
      have_last_word_index = 1'b1;

      send_item(item);
    end
  endtask
endclass : memory_sequence
