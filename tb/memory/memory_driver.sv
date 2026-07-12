`timescale 1ns / 1ps

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
