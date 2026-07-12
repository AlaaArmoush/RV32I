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
  logic txn_valid;

  modport driver (
      input  clk,
      input  read_data,
      output rst_n,
      output address,
      output write_data,
      output write_enable,
      output byte_enable,
      output txn_valid
  );

  modport monitor (
      input clk,
      input rst_n,
      input address,
      input write_data,
      input write_enable,
      input byte_enable,
      input read_data,
      input txn_valid
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
    vif.txn_valid <= 1'b0;
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
        vif.txn_valid <= 1'b1;

        @(posedge vif.clk);
        #1;
        vif.txn_valid <= 1'b0;

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
        vif.txn_valid <= 1'b1;

        @(posedge vif.clk);
        #1;
        vif.txn_valid <= 1'b0;
      end

      MEM_OP_WRITE: begin
        @(negedge vif.clk);
        vif.rst_n <= 1'b1;
        vif.address <= item.address;
        vif.write_data <= item.write_data;
        vif.write_enable <= 1'b1;
        vif.byte_enable <= item.byte_enable;
        vif.txn_valid <= 1'b1;

        @(posedge vif.clk);
        #1;
        vif.txn_valid <= 1'b0;
      end

      MEM_OP_WRITE_DISABLED: begin
        @(negedge vif.clk);
        vif.rst_n <= 1'b1;
        vif.address <= item.address;
        vif.write_data <= item.write_data;
        vif.write_enable <= 1'b0;
        vif.byte_enable <= item.byte_enable;
        vif.txn_valid <= 1'b1;

        @(posedge vif.clk);
        #1;
        vif.txn_valid <= 1'b0;
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

      if (!vif.txn_valid) begin
        continue;
      end

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
endclass : memory_monitor

class memory_coverage;
  typedef enum int {
    ADDR_FIRST,
    ADDR_LAST,
    ADDR_MIDDLE
  } address_class_e;

  typedef enum int {
    BE_ZERO,
    BE_SINGLE,
    BE_LOW_HALF,
    BE_HIGH_HALF,
    BE_FULL,
    BE_MIXED
  } byte_enable_class_e;

  typedef enum int {
    DATA_NOT_WRITE,
    DATA_ZERO,
    DATA_ALL_ONES,
    DATA_WALKING_BYTE,
    DATA_RANDOM
  } data_class_e;

  typedef enum int {
    RAW_NO_PRIOR,
    RAW_WRITE_READBACK,
    RAW_ONE_TXN_LATER,
    RAW_MANY_TXNS_LATER
  } raw_distance_e;

  int unsigned words;
  int signed last_write_txn_by_word[];
  int unsigned observed_count;
  int unsigned last_word_index;
  bit have_last_word_index;

  covergroup memory_cg with function sample(
      memory_op_e op,
      address_class_e addr_class,
      byte_enable_class_e be_class,
      data_class_e data_class,
      bit reset_active,
      bit repeated_address,
      raw_distance_e raw_distance
  );
    cp_op: coverpoint op {
      bins reset = {MEM_OP_RESET};
      bins read = {MEM_OP_READ};
      bins write = {MEM_OP_WRITE};
      bins write_disabled = {MEM_OP_WRITE_DISABLED};
    }

    cp_addr_class: coverpoint addr_class {
      bins first_word = {ADDR_FIRST};
      bins last_word = {ADDR_LAST};
      bins middle = {ADDR_MIDDLE};
    }

    cp_byte_enable_class: coverpoint be_class {
      bins zero = {BE_ZERO};
      bins single_lane = {BE_SINGLE};
      bins low_half = {BE_LOW_HALF};
      bins high_half = {BE_HIGH_HALF};
      bins full_word = {BE_FULL};
      bins mixed_lanes = {BE_MIXED};
    }

    cp_data_class: coverpoint data_class {
      bins not_write = {DATA_NOT_WRITE};
      bins zero = {DATA_ZERO};
      bins all_ones = {DATA_ALL_ONES};
      bins walking_byte = {DATA_WALKING_BYTE};
      bins random = {DATA_RANDOM};
    }

    cp_reset_phase: coverpoint reset_active {
      bins reset_active = {1};
      bins reset_inactive = {0};
    }

    cp_repeated_address: coverpoint repeated_address {
      bins not_repeated = {0};
      bins repeated = {1};
    }

    cp_raw_distance: coverpoint raw_distance {
      bins no_prior_write = {RAW_NO_PRIOR};
      bins write_readback = {RAW_WRITE_READBACK};
      bins one_txn_later = {RAW_ONE_TXN_LATER};
      bins many_txns_later = {RAW_MANY_TXNS_LATER};
    }

    cross cp_byte_enable_class, cp_addr_class;
    cross cp_byte_enable_class, cp_data_class;
    cross cp_op, cp_reset_phase;
    cross cp_repeated_address, cp_byte_enable_class;
  endgroup

  function new(int unsigned words = 64);
    this.words = words;
    this.observed_count = 0;
    this.last_word_index = 0;
    this.have_last_word_index = 1'b0;

    last_write_txn_by_word = new[words];
    reset_history();

    memory_cg = new();
  endfunction

  function void reset_history ();
    foreach (last_write_txn_by_word[i]) begin
      last_write_txn_by_word[i] = -1;
    end
  endfunction

  function address_class_e classify_address(int unsigned word_index);
    if (word_index == 0) begin
      return ADDR_FIRST;
    end

    if (word_index == words - 1) begin
      return ADDR_LAST;
    end

    return ADDR_MIDDLE;
  endfunction

  function byte_enable_class_e classify_byte_enable(logic [3:0] byte_enable);
    case (byte_enable)
      4'b0000: return BE_ZERO;
      4'b0001,
      4'b0010,
      4'b0100,
      4'b1000: return BE_SINGLE;
      4'b0011: return BE_LOW_HALF;
      4'b1100: return BE_HIGH_HALF;
      4'b1111: return BE_FULL;
      default: return BE_MIXED;
    endcase
  endfunction

  function data_class_e classify_data(memory_item item);
    if (!((item.op == MEM_OP_WRITE) || (item.op == MEM_OP_WRITE_DISABLED))) begin
      return DATA_NOT_WRITE;
    end

    case (item.write_data)
      32'h0000_0000: return DATA_ZERO;
      32'hffff_ffff: return DATA_ALL_ONES;
      32'h0000_00ff,
      32'h0000_ff00,
      32'h00ff_0000,
      32'hff00_0000: return DATA_WALKING_BYTE;
      default: return DATA_RANDOM;
    endcase
  endfunction

  function raw_distance_e classify_raw_distance(memory_item item);
    int unsigned distance;

    if (item.word_index >= words) begin
      return RAW_NO_PRIOR;
    end

    if (item.op == MEM_OP_WRITE) begin
      return RAW_WRITE_READBACK;
    end

    if ((item.op == MEM_OP_READ) && (last_write_txn_by_word[item.word_index] >= 0)) begin
      distance = observed_count - last_write_txn_by_word[item.word_index];

      if (distance == 1) begin
        return RAW_ONE_TXN_LATER;
      end

      return RAW_MANY_TXNS_LATER;
    end

    return RAW_NO_PRIOR;
  endfunction

  function void sample(memory_item item);
    bit repeated_address;
    raw_distance_e raw_distance;

    repeated_address = have_last_word_index && (item.word_index == last_word_index);
    raw_distance = classify_raw_distance(item);

    memory_cg.sample(
        item.op,
        classify_address(item.word_index),
        classify_byte_enable(item.byte_enable),
        classify_data(item),
        !item.rst_n,
        repeated_address,
        raw_distance
    );

    if (item.op == MEM_OP_RESET) begin
      reset_history();
    end else if (item.op == MEM_OP_WRITE) begin
      last_write_txn_by_word[item.word_index] = observed_count;
    end

    last_word_index = item.word_index;
    have_last_word_index = 1'b1;
    observed_count++;
  endfunction

  function void report();
    $display("[MEM_COVERAGE] instance coverage = %.2f%%", memory_cg.get_inst_coverage());
  endfunction
endclass : memory_coverage

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

module memory_sva #(parameter int WORDS = 64) (
    memory_if.monitor mon
);
  logic [31:0] model_mem[WORDS];

  function automatic logic [31:0] apply_byte_enable(
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

  property txn_address_aligned;
    @(posedge mon.clk) mon.txn_valid |-> (mon.address[1:0] == 2'b00);
  endproperty

  property txn_address_in_range;
    @(posedge mon.clk) mon.txn_valid |-> (mon.address[31:2] < WORDS);
  endproperty

  assert property (txn_address_aligned)
    else $error("[MEM_SVA] Transaction address is not word aligned: addr=0x%08h",
                mon.address);

  assert property (txn_address_in_range)
    else $error("[MEM_SVA] Transaction address outside memory range: addr=0x%08h WORDS=%0d",
                mon.address, WORDS);

  initial begin
    foreach (model_mem[i]) begin
      model_mem[i] = 32'h0000_0000;
    end
  end

  always @(posedge mon.clk) begin
    bit txn_valid_q;
    bit rst_n_q;
    bit write_enable_q;
    logic [31:0] address_q;
    logic [31:0] write_data_q;
    logic [3:0] byte_enable_q;
    int unsigned word_index_q;
    logic [31:0] old_word;
    logic [31:0] expected_word;

    txn_valid_q = mon.txn_valid;
    rst_n_q = mon.rst_n;
    address_q = mon.address;
    write_data_q = mon.write_data;
    write_enable_q = mon.write_enable;
    byte_enable_q = mon.byte_enable;
    word_index_q = mon.address[31:2];

    if (txn_valid_q && (word_index_q < WORDS)) begin
      old_word = model_mem[word_index_q];
      expected_word = old_word;

      if (!rst_n_q) begin
        foreach (model_mem[i]) begin
          model_mem[i] = 32'h0000_0000;
        end
        expected_word = 32'h0000_0000;
      end else if (write_enable_q) begin
        expected_word = apply_byte_enable(old_word, write_data_q, byte_enable_q);
        model_mem[word_index_q] = expected_word;

        for (int lane = 0; lane < 4; lane++) begin
          if (!byte_enable_q[lane]) begin
            assert (expected_word[8*lane +: 8] == old_word[8*lane +: 8])
              else $error("[MEM_SVA] Disabled byte lane %0d changed at addr=0x%08h",
                          lane, address_q);
          end
        end
      end

      #1;

      assert (mon.read_data === expected_word)
        else $error("[MEM_SVA] Read data mismatch addr=0x%08h expected=0x%08h actual=0x%08h",
                    address_q, expected_word, mon.read_data);
    end
  end
endmodule

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
  memory_coverage coverage;

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

  memory_sva #(
      .WORDS(WORDS)
  ) sva_i (
      .mon(mem_vif)
  );

  task automatic init_bus();
    mem_vif.rst_n = 1'b1;
    mem_vif.address = '0;
    mem_vif.write_data = '0;
    mem_vif.write_enable = 1'b0;
    mem_vif.byte_enable = 4'b0000;
    mem_vif.txn_valid = 1'b0;
  endtask

  task automatic reset_dut();
    mem_vif.rst_n = 1'b0;
    repeat (2) @(posedge clk);
    mem_vif.rst_n = 1'b1;
    @(posedge clk);
  endtask

  initial begin
    int unsigned expected_item_count;
    int unsigned timeout_cycles;
    int unsigned random_tests;
    int unsigned seed;

    seed = 32'h2026_0712;
    random_tests = 500;

    if ($value$plusargs("SEED=%d", seed)) begin
      $display("[MEM_TB] Using plusarg SEED=%0d", seed);
    end else begin
      $display("[MEM_TB] Using default SEED=%0d", seed);
    end

    if ($value$plusargs("RANDOM_TESTS=%d", random_tests)) begin
      $display("[MEM_TB] Using plusarg RANDOM_TESTS=%0d", random_tests);
    end else begin
      $display("[MEM_TB] Using default RANDOM_TESTS=%0d", random_tests);
    end

    void'($urandom(seed));

    $display("[MEM_TB] Starting memory DV environment");

    request_mb = new();
    observed_mb = new();

    seq = new(request_mb, WORDS);
    driver = new(mem_vif.driver, request_mb);
    monitor = new(mem_vif.monitor, observed_mb, WORDS);
    coverage = new(WORDS);
    scoreboard = new(observed_mb, WORDS, coverage);

    driver.verbose = 1'b0;
    monitor.verbose = 1'b0;
    scoreboard.verbose = 1'b0;

    init_bus();

    fork : env_threads
      driver.run();
      monitor.run();
      scoreboard.run();
    join_none

    seq.run_directed_smoke();
    seq.run_random(random_tests);

    expected_item_count = seq.generated_count;
    timeout_cycles = 200 + (expected_item_count * 4);

    fork : completion_or_timeout
      begin
        wait (scoreboard.checked_count >= expected_item_count);
      end

      begin
        repeat (timeout_cycles) @(posedge clk);
        $fatal(1,
               "[MEM_TB] Timeout waiting for scoreboard: checked=%0d expected=%0d",
               scoreboard.checked_count,
               expected_item_count);
      end
    join_any

    disable completion_or_timeout;

    scoreboard.report();
    coverage.report();

    $display("[MEM_TB] PASS checked=%0d random_tests=%0d seed=%0d",
             scoreboard.checked_count,
             random_tests,
             seed);
    disable env_threads;
    $finish;
  end
endmodule
