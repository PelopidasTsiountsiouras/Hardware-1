`timescale 1ns/1ps

module regfile_tb;

  // Parameters
  localparam DATAWIDTH = 32;

  // DUT inputs
  reg                     clk;
  reg                     resetn;
  reg                     write;

  reg  [3:0]              readReg1;
  reg  [3:0]              readReg2;
  reg  [3:0]              readReg3;
  reg  [3:0]              readReg4;

  reg  [3:0]              writeReg1;
  reg  [3:0]              writeReg2;
  reg  [DATAWIDTH-1:0]    writeData1;
  reg  [DATAWIDTH-1:0]    writeData2;

  // DUT outputs
  wire [DATAWIDTH-1:0]    readData1;
  wire [DATAWIDTH-1:0]    readData2;
  wire [DATAWIDTH-1:0]    readData3;
  wire [DATAWIDTH-1:0]    readData4;

  // Instantiate register file
  regfile #(DATAWIDTH) dut (
    .clk(clk),
    .resetn(resetn),
    .write(write),

    .readReg1(readReg1),
    .readReg2(readReg2),
    .readReg3(readReg3),
    .readReg4(readReg4),

    .writeReg1(writeReg1),
    .writeReg2(writeReg2),
    .writeData1(writeData1),
    .writeData2(writeData2),

    .readData1(readData1),
    .readData2(readData2),
    .readData3(readData3),
    .readData4(readData4)
  );

  // Clock generation (10 ns)
  always #5 clk = ~clk;

  // Waveform dumping
  initial begin
    $dumpfile("regfile.vcd");
    $dumpvars(0, regfile_tb);
  end

  // Test sequence
  initial begin
    // Init
    clk        = 0;
    resetn     = 1;
    write      = 0;

    readReg1   = 0;
    readReg2   = 0;
    readReg3   = 0;
    readReg4   = 0;

    writeReg1  = 0;
    writeReg2  = 0;
    writeData1 = 0;
    writeData2 = 0;

    $display("==== REGFILE TESTBENCH START ====");

    // Asynchronous reset (active-low)
    resetn = 0;
    #10;
    resetn = 1;
    #10;

    readReg1 = 4'd1;
    readReg2 = 4'd2;
    #1;
    $display("After reset: R1=%h R2=%h (expected 0)",
              readData1, readData2);

    // Write two registers
    write      = 1;
    writeReg1  = 4'd1;
    writeData1 = 32'hAAAA_AAAA;
    writeReg2  = 4'd2;
    writeData2 = 32'h5555_5555;

    #10;  // wait for clock edge
    write = 0;

    readReg1 = 4'd1;
    readReg2 = 4'd2;
    #1;
    $display("Write check: R1=%h R2=%h (expected AAAA_AAAA, 5555_5555)",
              readData1, readData2);

    // Read using all 4 read ports
    readReg1 = 4'd1;
    readReg2 = 4'd2;
    readReg3 = 4'd1;
    readReg4 = 4'd2;
    #1;
    $display("4-port read: R1=%h R2=%h R3=%h R4=%h",
              readData1, readData2, readData3, readData4);

    // Write priority over read
    write      = 1;
    writeReg1  = 4'd1;
    writeData1 = 32'hDEAD_BEEF;
    writeReg2  = 4'd3;
    writeData2 = 32'h1234_5678;

    readReg1 = 4'd1;  // conflict with writeReg1
    readReg2 = 4'd3;  // conflict with writeReg2

    #1;
    $display("Write priority: R1=%h R2=%h (expected DEAD_BEEF, 1234_5678)",
              readData1, readData2);

    #10;
    write = 0;

    $display("==== REGFILE TESTBENCH END ====");
    $finish;
  end

endmodule
