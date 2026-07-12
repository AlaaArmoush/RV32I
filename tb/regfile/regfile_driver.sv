`timescale 1ns / 1ps

class regfile_driver;
  virtual regfile_if.driver vif;

  function new(virtual regfile_if.driver vif);
    this.vif = vif;  
  endfunction

  task reset();
    vif.rst_n        <= 1'b0;
    vif.address1     <= 5'd0;
    vif.address2     <= 5'd0;
    vif.address3     <= 5'd0;
    vif.write_enable <= 1'b0;
    vif.write_data   <= 32'd0;
    repeat (2) @(posedge vif.clk);

    vif.rst_n <= 1'b1;
    @(posedge vif.clk);
  endtask

  task drive_item(regfile_item item);
    @(negedge vif.clk);

    vif.address1     <= item.address1;
    vif.address2     <= item.address2;
    vif.address3     <= item.address3;
    vif.write_enable <= item.write_enable;
    vif.write_data   <= item.write_data;

    @(posedge vif.clk);
  endtask
endclass
