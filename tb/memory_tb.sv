`timescale 1ns/1ps
/* verilator lint_off WIDTHTRUNC */

module memory_tb;
  localparam DATA_WIDTH = 32;
  localparam WORDS = 64;

  //DUT
  logic clk;
  logic rst_en;
  logic write_enable;
  logic [31:0] address;
  logic [DATA_WIDTH-1:0] write_data;
  logic [DATA_WIDTH-1:0] read_data;

  memory #(.WORDS(WORDS)) 
    dut(.clk(clk),
        .rst_en(rst_en),
        .write_enable(write_enable),
        .address(address),
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
    rst_en = 0; //active low 
    write_enable = 0;
    address = 0;
    write_data = 0;
    @(posedge clk);
    rst_en = 1;
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

    $display("\n===================");
    $display("All tests passed!");
    $display("===================");
    $finish;      
  end
endmodule
