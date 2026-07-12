`timescale 1ns / 1ps

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
