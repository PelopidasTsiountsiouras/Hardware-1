`timescale 1ns/1ps

module nn_tb;

  // DUT inputs
  reg  clk;
  reg  resetn;
  reg  enable;
  reg  [31:0] input_1;
  reg  [31:0] input_2;

  // DUT outputs
  wire [31:0] final_output;
  wire total_ovf;
  wire total_zero;
  wire [2:0] ovf_fsm_stage;
  wire [2:0] zero_fsm_stage;

  // Instantiate DUT
  nn dut (
    .clk(clk),
    .resetn(resetn),
    .enable(enable),
    .input_1(input_1),
    .input_2(input_2),
    .final_output(final_output),
    .total_ovf(total_ovf),
    .total_zero(total_zero),
    .ovf_fsm_stage(ovf_fsm_stage),
    .zero_fsm_stage(zero_fsm_stage)
  );

  // Clock generation (10 ns)
  always #5 clk = ~clk;

  // Waveform dump
  initial begin
    $dumpfile("nn.vcd");
    $dumpvars(0, nn_tb);
  end

  // Test sequence
  initial begin
    // Initial values
    clk      = 0;
    resetn  = 0;
    enable  = 0;
    input_1 = 0;
    input_2 = 0;

    $display("==== NN TESTBENCH START ====");

    // Hold reset
    #20;
    resetn = 1;
    $display("Reset released");

    // Give time for LOAD_WB FSM state
    #100;

    // Apply inputs
    input_1 = 32'd10;
    input_2 = 32'd4;

    // Start computation
    enable = 1;
    #10;
    enable = 0;

    // Wait long enough for FSM to finish
    #200;

    // Observe result
    $display("Final output = %d (0x%h)", final_output, final_output);
    $display("Overflow     = %b", total_ovf);
    $display("Zero         = %b", total_zero);
    $display("OVF stage    = %b", ovf_fsm_stage);
    $display("ZERO stage   = %b", zero_fsm_stage);

    $display("==== NN TESTBENCH END ====");
    $finish;
  end

endmodule
