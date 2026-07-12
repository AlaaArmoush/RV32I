`timescale 1ns / 1ps

class memory_scoreboard;
  mailbox #(memory_item) observed_mb;

  logic [31:0] shadow_mem[];

  int unsigned words;
  int unsigned checked_count;
  int unsigned error_count;
  memory_coverage coverage;
  bit verbose;

  function new(mailbox #(memory_item) observed_mb, int unsigned words = 64, memory_coverage coverage = null);
    this.observed_mb = observed_mb;
    this.words = words;
    this.checked_count = 0;
    this.error_count = 0;
    this.verbose = 1'b0;
    this.coverage = coverage;

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

        if (coverage != null) begin
          coverage.sample(item);
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

      if (coverage != null) begin
        coverage.sample(item);
      end

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
endclass : memory_scoreboard
