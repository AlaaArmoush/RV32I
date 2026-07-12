`timescale 1ns / 1ps

class regfile_monitor;
  virtual regfile_if.monitor vif;

  function new(virtual regfile_if.monitor vif);
    this.vif = vif;
  endfunction

  task sample_item(
      output regfile_item item,
      input string name = "monitored_item"
  );
    #1ps;

    item = new(name);
    item.rst_n        = vif.rst_n;
    item.address1     = vif.address1;
    item.address2     = vif.address2;
    item.address3     = vif.address3;
    item.write_enable = vif.write_enable;
    item.write_data   = vif.write_data;
    item.read_data1   = vif.read_data1;
    item.read_data2   = vif.read_data2;
  endtask
endclass
