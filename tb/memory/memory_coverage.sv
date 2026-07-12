`timescale 1ns / 1ps

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
    RAW_NOT_READ,
    RAW_NO_PRIOR,
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
      bins not_read = {RAW_NOT_READ};
      bins no_prior_write = {RAW_NO_PRIOR};
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

    if (item.op != MEM_OP_READ) begin
      return RAW_NOT_READ;
    end

    if (item.word_index >= words) begin
      return RAW_NO_PRIOR;
    end

    if (last_write_txn_by_word[item.word_index] >= 0) begin
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
