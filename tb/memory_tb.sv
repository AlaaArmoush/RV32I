`timescale 1ns/1ps
/* verilator lint_off WIDTHTRUNC */

module memory_tb;
  localparam DATA_WIDTH = 32;
  localparam WORDS = 64;

  //DUT
  logic clk;
  logic rst_n;
  logic write_enable;
  logic [31:0] address;
  logic [DATA_WIDTH-1:0] write_data;
  logic [DATA_WIDTH-1:0] read_data;
  logic [3:0] byte_enable;

  memory #(.WORDS(WORDS)) 
    dut(.clk(clk),
        .rst_n(rst_n),
        .write_enable(write_enable),
        .address(address),
        .byte_enable(byte_enable),
        .write_data(write_data),
        .read_data(read_data)
        );

  initial clk = 0;
  always #0.5 clk = ~clk;

  typedef struct{
    int addr;
    int data;
  } test_data_t;
  
  test_data_t test_data[4];
  
  initial begin
    // test 1: reset 
    rst_n = 0; //active low 
    write_enable = 0;
    byte_enable = 4'b1111;
    address = 0;
    write_data = 0;
    @(posedge clk);
    rst_n = 1;
    @(posedge clk);

    for(int i = 0; i < WORDS; i++) begin
      address = i;
      if(read_data != 0) $fatal("Memory not zero at address %0d, got value = ", address, read_data);
    end
    $display("Test 1 passed: Memory cleared after reset");

    //test 2 write/read_data
    test_data[0] = '{0, 32'hDEADBEEF};   
    test_data[1] = '{4, 32'hCAFEBABE};   
    test_data[2] = '{8, 32'h12345678};   
    test_data[3] = '{12, 32'hA5A5A5A5};  

    for(int i = 0; i < 4; i++) begin
    address = test_data[i].addr;
    write_data = test_data[i].data;
    write_enable = 1;
    @(posedge clk);
    //single cycle write 
    write_enable = 0;
    @(posedge clk);

    if(read_data != test_data[i].data)
      $fatal("readback missmatch at addr %0d: expected %h, got %h", test_data[i].addr, test_data[i].data, read_data);  
    end
    $display("Test 2 passed: single write/read operation");


    //test 3 burst write/read
    for(int i = 0; i < WORDS; i++) begin
    address = i << 2;
    write_data = i*100;
    write_enable = 1;
    @(posedge clk);
    end

    write_enable = 0;
    for(int i = 0; i < WORDS; i++) begin
    address = i << 2;
    @(posedge clk);
    if(read_data != i*100) $fatal("readback missmatch at addr %0d: expected %h, got %h", test_data[i].addr, test_data[i].data, read_data);  
    end
    $display("Test 3 passed: Burst write/read operations");

    // test 4 byte-enable partial writes
    // Setup: write a known full word at address 0
    address = 32'd0;
    write_data = 32'h11223344;
    byte_enable = 4'b1111;
    write_enable = 1;
    @(posedge clk);

    write_enable = 0;
    @(posedge clk);

    if (read_data !== 32'h11223344)
      $fatal("Test 4 setup failed: expected 11223344, got %h", read_data);

    // Write only byte 0: changes 0x44 into 0xAA
    address = 32'd0;
    write_data = 32'h000000AA;
    byte_enable = 4'b0001;
    write_enable = 1;
    @(posedge clk);

    write_enable = 0;
    @(posedge clk);

    if (read_data !== 32'h112233AA)
      $fatal("Byte lane 0 failed: expected 112233AA, got %h", read_data);

    // Write only byte 1: changes 0x33 into 0xBB
    write_data = 32'h0000BB00;
    byte_enable = 4'b0010;
    write_enable = 1;
    @(posedge clk);

    write_enable = 0;
    @(posedge clk);

    if (read_data !== 32'h1122BBAA)
      $fatal("Byte lane 1 failed: expected 1122BBAA, got %h", read_data);

    // Write upper halfword: changes 0x1122 into 0xCCDD
    write_data = 32'hCCDD0000;
    byte_enable = 4'b1100;
    write_enable = 1;
    @(posedge clk);

    write_enable = 0;
    @(posedge clk);

    if (read_data !== 32'hCCDDBBAA)
      $fatal("Upper halfword failed: expected CCDDBBAA, got %h", read_data);

    $display("Test 4 passed: byte_enable partial writes");


    $display("\n===================");
    $display("All tests passed!");
    $display("===================");
    $finish;      
  end
endmodule
