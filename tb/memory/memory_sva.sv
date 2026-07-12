`timescale 1ns / 1ps

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

  property reset_txn_drives_no_write;
    @(posedge mon.clk) mon.txn_valid && !mon.rst_n |->
        (!mon.write_enable && (mon.byte_enable == 4'b0000));
  endproperty

  property enabled_write_has_byte_lane;
    @(posedge mon.clk) mon.txn_valid && mon.rst_n && mon.write_enable |->
        (mon.byte_enable != 4'b0000);
  endproperty

  property valid_controls_known;
    @(posedge mon.clk) mon.txn_valid |->
        (!$isunknown(mon.rst_n) &&
         !$isunknown(mon.write_enable) &&
         !$isunknown(mon.byte_enable) &&
         !$isunknown(mon.address));
  endproperty

  assert property (txn_address_aligned)
    else $error("[MEM_SVA] Transaction address is not word aligned: addr=0x%08h",
                mon.address);

  assert property (txn_address_in_range)
    else $error("[MEM_SVA] Transaction address outside memory range: addr=0x%08h WORDS=%0d",
                mon.address, WORDS);

  assert property (reset_txn_drives_no_write)
    else $error("[MEM_SVA] Reset transaction drove write controls");

  assert property (enabled_write_has_byte_lane)
    else $error("[MEM_SVA] Enabled write has no byte lanes selected");

  assert property (valid_controls_known)
    else $error("[MEM_SVA] Valid transaction has unknown control/address signals");

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

      assert (!$isunknown(mon.read_data))
        else $error("[MEM_SVA] Read data contains X/Z at addr=0x%08h", address_q);

      assert (mon.read_data === expected_word)
        else $error("[MEM_SVA] Read data mismatch addr=0x%08h expected=0x%08h actual=0x%08h",
                    address_q, expected_word, mon.read_data);
    end
  end
endmodule
