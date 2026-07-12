`timescale 1ns / 1ps

module regfile_sva(regfile_if.monitor mon);
  property port1_x0_reads_zero;
    @(posedge mon.clk)
      (mon.address1 == 5'd0) |-> (mon.read_data1 == 32'd0);
  endproperty

  property port2_x0_reads_zero;
    @(posedge mon.clk)
      (mon.address2 == 5'd0) |-> (mon.read_data2 == 32'd0);
  endproperty

  property x0_write_port1_stays_zero;
    @(negedge mon.clk) disable iff (!mon.rst_n)
      (mon.write_enable && (mon.address3 == 5'd0) && (mon.address1 == 5'd0))
      |-> (mon.read_data1 == 32'd0);
  endproperty

  property x0_write_port2_stays_zero;
    @(negedge mon.clk) disable iff (!mon.rst_n)
      (mon.write_enable && (mon.address3 == 5'd0) && (mon.address2 == 5'd0))
      |-> (mon.read_data2 == 32'd0);
  endproperty

  assert property (port1_x0_reads_zero)
    else $error("regfile x0 invariant failed on read port 1");

  assert property (port2_x0_reads_zero)
    else $error("regfile x0 invariant failed on read port 2");

  assert property (x0_write_port1_stays_zero)
    else $error("regfile x0 write attempt changed read port 1");

  assert property (x0_write_port2_stays_zero)
    else $error("regfile x0 write attempt changed read port 2");
endmodule
