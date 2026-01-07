`timescale 1ns/1ps

module calc_tb;

  // DUT inputs
  reg        clk;
  reg        btnc;
  reg        btnac;
  reg        btnl;
  reg        btnr;
  reg        btnd;
  reg [15:0] sw;

  // DUT output
  wire [15:0] led;

  // Instantiate calculator
  calc dut (
    .clk(clk),
    .btnc(btnc),
    .btnac(btnac),
    .btnl(btnl),
    .btnr(btnr),
    .btnd(btnd),
    .sw(sw),
    .led(led)
  );

  // -----------------------------
  // Clock generation (10 ns)
  // -----------------------------
  always #5 clk = ~clk;

  // -----------------------------
  // Helper task: press btnc
  // -----------------------------
  task press_btnc;
    begin
      btnc = 1;
      #10;
      btnc = 0;
      #10;
    end
  endtask

  // -----------------------------
  // Test sequence
  // -----------------------------
  initial begin
    // Init
    clk   = 0;
    btnc  = 0;
    btnac = 0;
    btnl  = 0;
    btnr  = 0;
    btnd  = 0;
    sw    = 0;

    $display("==== CALC TESTBENCH START ====");

    // --------------------------------
    // Reset (btnac)
    // --------------------------------
    btnac = 1;
    #10;
    btnac = 0;
    #10;
    $display("Reset -> led = %h (expected 0000)", led);

    // --------------------------------
    // 0,1,0  ADD   acc=0x0000 sw=0x285a
    // --------------------------------
    btnl = 0; btnr = 1; btnd = 0;
    sw   = 16'h285A;
    press_btnc();
    $display("ADD  -> led = %h (expected 285A)", led);

    // --------------------------------
    // 1,1,1  XOR   acc=0x285A sw=0x04C8
    // --------------------------------
    btnl = 1; btnr = 1; btnd = 1;
    sw   = 16'h04C8;
    press_btnc();
    $display("XOR  -> led = %h (expected 2C92)", led);

    // --------------------------------
    // 0,0,0  LSR   acc=0x2C92 sw=0x0005
    // --------------------------------
    btnl = 0; btnr = 0; btnd = 0;
    sw   = 16'h0005;
    press_btnc();
    $display("LSR  -> led = %h (expected 0164)", led);

    // --------------------------------
    // 1,0,1  NOR   acc=0x0164 sw=0xA085
    // --------------------------------
    btnl = 1; btnr = 0; btnd = 1;
    sw   = 16'hA085;
    press_btnc();
    $display("NOR  -> led = %h (expected 5E1A)", led);

    // --------------------------------
    // 1,0,0  MUL   acc=0x5E1A sw=0x07FE
    // --------------------------------
    btnl = 1; btnr = 0; btnd = 0;
    sw   = 16'h07FE;
    press_btnc();
    $display("MUL  -> led = %h (expected 13CC)", led);

    // --------------------------------
    // 0,0,1  LSL   acc=0x13CC sw=0x0004
    // --------------------------------
    btnl = 0; btnr = 0; btnd = 1;
    sw   = 16'h0004;
    press_btnc();
    $display("LSL  -> led = %h (expected 3CC0)", led);

    // --------------------------------
    // 1,1,0  NAND  acc=0x3CC0 sw=0xFA65
    // --------------------------------
    btnl = 1; btnr = 1; btnd = 0;
    sw   = 16'hFA65;
    press_btnc();
    $display("NAND -> led = %h (expected C7BF)", led);

    // --------------------------------
    // 0,1,1  SUB   acc=0xC7BF sw=0xB2E4
    // --------------------------------
    btnl = 0; btnr = 1; btnd = 1;
    sw   = 16'hB2E4;
    press_btnc();
    $display("SUB  -> led = %h (expected 14DB)", led);

    $display("==== CALC TESTBENCH END ====");
    $finish;
  end

endmodule
