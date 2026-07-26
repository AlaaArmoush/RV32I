import control_pkg::*;

class control_scoreboard;
  int unsigned transactions_checked, total_checks, passed_checks, failed_checks;

  function new();
    reset();
  endfunction

  function reset();
    transactions_checked = 0;
    total_checks = 0;
    passed_checks = 0;
    failed_checks = 0;
  endfunction

  function void check_field(input control_item item, input sring field_name,
                            input logic [3:0] actual, input logic [3:0] expected);
    total_checks++;

    if (actual !== expected) begin
      failed_checks++;

      $error("%s: %s mismatch: expected=%04b actual=%04b", item.inputs_to_string(), field_name,
             expected, actual);
    end else begin
      passed_checks++;
    end
  endfunction

  function string expected_to_string(input control_expected_t expected);
    return $sformatf(
        {
          "imm_type=%03b mem_write=%0b reg_write=%0b ",
          "reg_write_gated=%0b alu_source=%0b result_source=%02b ",
          "pc_src=%0b addr_base_src=%02b alu_control=%04b"
        },
        expected.imm_type,
        expected.mem_write,
        expected.reg_write,
        expected.reg_write_gated,
        expected.alu_source,
        expected.result_source,
        expected.pc_src,
        expected.addr_base_src,
        expected.alu_control
    );
  endfunction

  function void check(input control_item item);
    control_expected_t expected;
    int unsigned       failures_before;

    expected = golden_decode(item.op_code, item.func3, item.func7, item.zero, item.last_bit);

    transactions_checked++;
    failures_before = failed_checks;

    check_field(item, "imm_type", {1'b0, item.imm_type}, {1'b0, expected.imm_type});

    check_field(item, "mem_write", {3'b000, item.mem_write}, {3'b000, expected.mem_write});

    check_field(item, "reg_write", {3'b000, item.reg_write}, {3'b000, expected.reg_write});

    check_field(item, "reg_write_gated", {3'b000, item.reg_write_gated}, {
                3'b000, expected.reg_write_gated});

    check_field(item, "alu_source", {3'b000, item.alu_source}, {3'b000, expected.alu_source});

    check_field(item, "result_source", {2'b00, item.result_source}, {2'b00, expected.result_source
                });

    check_field(item, "pc_src", {3'b000, item.pc_src}, {3'b000, expected.pc_src});

    check_field(item, "addr_base_src", {2'b00, item.addr_base_src}, {2'b00, expected.addr_base_src
                });

    check_field(item, "alu_control", item.alu_control, expected.alu_control);

    if (failed_checks != failures_before) begin
      $display("  Actual outputs  : %s", item.outputs_to_string());
      $display("  Expected outputs: %s", expected_to_string(expected));
    end
  endfunction

  function bit test_passed();
    return failed_checks == 0;
  endfunction

  function void report();
    $display("---------------------------------------");
    $display("Control scoreboard summary");
    $display("  Transactions checked: %0d", transactions_checked);
    $display("  Total field checks  : %0d", total_checks);
    $display("  Passed field checks : %0d", passed_checks);
    $display("  Failed field checks : %0d", failed_checks);
    $display("---------------------------------------");
  endfunction
endclass : control_scoreboard
