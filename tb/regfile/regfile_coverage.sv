`timescale 1ns / 1ps

class regfile_coverage;
  covergroup regfile_cg with function sample(
      bit        reset_active,
      bit [4:0]  address1,
      bit [4:0]  address2,
      bit [4:0]  address3,
      bit        write_enable,
      bit [31:0] write_data,
      bit        raw_port1,
      bit        raw_port2,
      bit        same_read_address,
      bit        x0_write_readback
  );
    option.per_instance = 1;

    cp_reset: coverpoint reset_active {
      bins reset = {1};
      bins normal = {0};
    }

    cp_read_port1: coverpoint address1 {
      bins x0 = {0};
      bins low_regs = {[1:15]};
      bins high_regs = {[16:31]};
    }

    cp_read_port2: coverpoint address2 {
      bins x0 = {0};
      bins low_regs = {[1:15]};
      bins high_regs = {[16:31]};
    }

    cp_write_addr: coverpoint address3 {
      bins x0 = {0};
      bins low_regs = {[1:15]};
      bins high_regs = {[16:31]};
    }

    cp_write_enable: coverpoint write_enable {
      bins disabled = {0};
      bins enabled = {1};
    }

    cp_write_data: coverpoint write_data {
      bins zero = {32'h0000_0000};
      bins all_ones = {32'hFFFF_FFFF};
      bins sign_bit_set = {[32'h8000_0000:32'hFFFF_FFFE]};
      bins walking_bits[] = {
        32'h0000_0001,
        32'h0000_0002,
        32'h0000_0004,
        32'h0000_0008,
        32'h0000_0010,
        32'h0000_0080,
        32'h0000_8000,
        32'h8000_0000
      };
      bins other = default;
    }

    cp_raw_port1: coverpoint raw_port1 {
      bins no_raw = {0};
      bins raw = {1};
    }

    cp_raw_port2: coverpoint raw_port2 {
      bins no_raw = {0};
      bins raw = {1};
    }

    cp_same_read_address: coverpoint same_read_address {
      bins different = {0};
      bins same = {1};
    }

    cp_x0_write_readback: coverpoint x0_write_readback {
      bins no_attempt = {0};
      bins attempted = {1};
    }

    cross cp_write_addr, cp_write_enable;
    cross cp_read_port1, cp_write_addr;
    cross cp_read_port2, cp_write_addr;
    cross cp_raw_port1, cp_write_enable;
    cross cp_raw_port2, cp_write_enable;
    cross cp_x0_write_readback, cp_write_enable;
  endgroup

  function new();
    regfile_cg = new();
  endfunction

  function void sample(input regfile_item item);
    regfile_cg.sample(
        !item.rst_n,
        item.address1,
        item.address2,
        item.address3,
        item.write_enable,
        item.write_data,
        item.address1 == item.address3,
        item.address2 == item.address3,
        item.address1 == item.address2,
        (item.address3 == 5'd0) &&
            ((item.address1 == 5'd0) || (item.address2 == 5'd0))
    );
  endfunction
endclass
