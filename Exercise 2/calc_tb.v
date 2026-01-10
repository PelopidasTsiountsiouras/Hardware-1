`timescale 1ns/1ps

module calc_tb;

  // -----------------------------
  // Waveform dumping (MUST be inside module)
  // -----------------------------
  initial begin
    $dumpfile("calc.vcd");
    $dumpvars(0, calc_tb);
  end

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

    // Reset
    btnac = 1; #10;
    btnac = 0; #10;
    $display("Reset -> led = %h (expected 0000)", led);

    btnl = 0; btnr = 1; btnd = 0;
    sw   = 16'h285A;
    press_btnc();
    $display("ADD  -> led = %h (expected 285A)", led);

    btnl = 1; btnr = 1; btnd = 1;
    sw   = 16'h04C8;
    press_btnc();
    $display("XOR  -> led = %h (expected 2C92)", led);

    btnl = 0; btnr = 0; btnd = 0;
    sw   = 16'h0005;
    press_btnc();
    $display("LSR  -> led = %h (expected 0164)", led);

    btnl = 1; btnr = 0; btnd = 1;
    sw   = 16'hA085;
    press_btnc();
    $display("NOR  -> led = %h (expected 5E1A)", led);

    btnl = 1; btnr = 0; btnd = 0;
    sw   = 16'h07FE;
    press_btnc();
    $display("MUL  -> led = %h (expected 13CC)", led);

    btnl = 0; btnr = 0; btnd = 1;
    sw   = 16'h0004;
    press_btnc();
    $display("LSL  -> led = %h (expected 3CC0)", led);

    btnl = 1; btnr = 1; btnd = 0;
    sw   = 16'hFA65;
    press_btnc();
    $display("NAND -> led = %h (expected C7BF)", led);

    btnl = 0; btnr = 1; btnd = 1;
    sw   = 16'hB2E4;
    press_btnc();
    $display("SUB  -> led = %h (expected 14DB)", led);

    $display("==== CALC TESTBENCH END ====");
    $finish;
  end

endmodule
