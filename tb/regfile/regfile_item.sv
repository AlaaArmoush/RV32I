`timescale 1ns / 1ps

class regfile_item;
  rand bit [4:0]  address1;
  rand bit [4:0]  address2;
  rand bit [4:0]  address3;
  rand bit        write_enable;
  rand bit [31:0] write_data;

  logic        rst_n;
  logic [31:0] read_data1;
  logic [31:0] read_data2;

  string name;

  function new(string name = "regfile_item");
    this.name = name;
  endfunction

  function string sprint();
    return $sformatf(
        "%s rst_n=%0b a1=x%0d rd1=0x%08h a2=x%0d rd2=0x%08h we=%0b a3=x%0d wd=0x%08h",
        name, rst_n, address1, read_data1, address2, read_data2,
        write_enable, address3, write_data
    );
  endfunction
endclass
