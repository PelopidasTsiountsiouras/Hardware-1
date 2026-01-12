`timescale 1ns / 1ps

module tb_nn;

  // Testbench signals
  reg [31:0] input_1;
  reg [31:0] input_2;
  reg clk;
  reg resetn;
  reg enable;
  
  wire [31:0] final_output;
  wire total_ovf;
  wire total_zero;
  wire [2:0] ovf_fsm_stage;
  wire [2:0] zero_fsm_stage;
  
  // Reference output
  reg [31:0] ref_output;
  reg ref_overflow;
  
  // Test counters
  integer pass_count;
  integer total_tests;
  integer i;
  
  // Instantiate the neural network
  nn dut (
    .final_output(final_output),
    .total_ovf(total_ovf),
    .total_zero(total_zero),
    .ovf_fsm_stage(ovf_fsm_stage),
    .zero_fsm_stage(zero_fsm_stage),
    .input_1(input_1),
    .input_2(input_2),
    .clk(clk),
    .resetn(resetn),
    .enable(enable)
  );
  
  // Clock generation: 10ns period, 50% duty cycle
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  
  // Reference model function with overflow detection
  function [32:0] nn_model;  // Returns {overflow, result[31:0]}
    input signed [31:0] in1;
    input signed [31:0] in2;
    reg signed [31:0] shift_bias_1, shift_bias_2, shift_bias_3;
    reg signed [31:0] weight_1, weight_2, weight_3, weight_4;
    reg signed [31:0] bias_1, bias_2, bias_3;
    reg signed [31:0] inter_1, inter_2, inter_3, inter_4, inter_5;
    reg signed [63:0] temp;
    reg ovf;
    begin
      ovf = 0;
      
      // Load weights and biases (matching ROM values in nn.v)
      shift_bias_1 = 32'd2;
      shift_bias_2 = 32'd1;
      weight_1 = 32'd5;
      bias_1 = 32'd3;
      weight_2 = 32'd4;
      bias_2 = 32'd1;
      weight_3 = 32'd6;
      weight_4 = 32'd2;
      bias_3 = 32'd7;
      shift_bias_3 = 32'd3;
      
      // Preprocess layer: arithmetic shift right
      inter_1 = in1 >>> shift_bias_1;
      inter_2 = in2 >>> shift_bias_2;
      
      // Input layer - neuron 1
      temp = inter_1 * weight_1;
      // Check multiplication overflow
      if (temp[63:31] != {33{temp[31]}}) begin
        nn_model = {1'b1, 32'hFFFFFFFF};
      end else begin
        inter_3 = temp[31:0] + bias_1;
        // Check addition overflow
        if ((~(temp[31] ^ bias_1[31])) & (inter_3[31] ^ temp[31])) begin
          nn_model = {1'b1, 32'hFFFFFFFF};
        end else begin
          // Input layer - neuron 2
          temp = inter_2 * weight_2;
          // Check multiplication overflow
          if (temp[63:31] != {33{temp[31]}}) begin
            nn_model = {1'b1, 32'hFFFFFFFF};
          end else begin
            inter_4 = temp[31:0] + bias_2;
            // Check addition overflow
            if ((~(temp[31] ^ bias_2[31])) & (inter_4[31] ^ temp[31])) begin
              nn_model = {1'b1, 32'hFFFFFFFF};
            end else begin
              // Output layer: inter_5 = inter_3*w3 + inter_4*w4 + b3
              // Step 1: inter_3 * weight_3 + bias_3
              temp = inter_3 * weight_3;
              if (temp[63:31] != {33{temp[31]}}) begin
                nn_model = {1'b1, 32'hFFFFFFFF};
              end else begin
                inter_5 = temp[31:0] + bias_3;
                if ((~(temp[31] ^ bias_3[31])) & (inter_5[31] ^ temp[31])) begin
                  nn_model = {1'b1, 32'hFFFFFFFF};
                end else begin
                  // Step 2: inter_4 * weight_4 + inter_5
                  temp = inter_4 * weight_4;
                  if (temp[63:31] != {33{temp[31]}}) begin
                    nn_model = {1'b1, 32'hFFFFFFFF};
                  end else begin
                    inter_5 = temp[31:0] + inter_5;
                    if ((~(temp[31] ^ inter_5[31])) & (inter_5[31] ^ temp[31])) begin
                      nn_model = {1'b1, 32'hFFFFFFFF};
                    end else begin
                      // Postprocess layer: logical shift left
                      nn_model = {1'b0, inter_5 << shift_bias_3};
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  endfunction
  
  // Main test procedure
  initial begin
    // Initialize signals
    input_1 = 0;
    input_2 = 0;
    resetn = 0;
    enable = 0;
    pass_count = 0;
    total_tests = 0;
    
    // Display header
    $display("========================================");
    $display("Neural Network Testbench");
    $display("========================================");
    
    // Reset sequence
    #20;
    resetn = 1;
    #20;
    
    // Enable the neural network to load weights
    enable = 1;
    #10;
    enable = 0;
    
    // Wait for weight loading to complete (11 cycles for 10 weights + 1 transition)
    #120;
    
    // Run 100 iterations, each with 3 test cases
    for (i = 0; i < 100; i = i + 1) begin
      
      // Test 1: Random values in range [-4096, 4095]
      input_1 = $signed($urandom_range(8191)) - 4096;
      input_2 = $signed($urandom_range(8191)) - 4096;
      {ref_overflow, ref_output} = nn_model(input_1, input_2);
      
      enable = 1;
      #10;
      enable = 0;
      
      // Wait for computation through FSM
      // IDLE->PREPROCESS->INPUT->OUTPUT->POST->IDLE = 5 state transitions
      // Need to wait until end of POST state when final_output is updated
      #80;
      
      // Check result
      total_tests = total_tests + 1;
      if (ref_overflow) begin
        if (total_ovf && final_output === 32'hFFFFFFFF) begin
          pass_count = pass_count + 1;
        end else begin
          $display("FAIL at time %0t ns:", $time);
          $display("  Input1 = %h (%0d), Input2 = %h (%0d)", 
                   input_1, $signed(input_1), input_2, $signed(input_2));
          $display("  Expected overflow (-1)");
          $display("  DUT: ovf=%b, output=%h", total_ovf, final_output);
        end
      end else begin
        if (final_output === ref_output && !total_ovf) begin
          pass_count = pass_count + 1;
        end else begin
          $display("FAIL at time %0t ns:", $time);
          $display("  Input1 = %h (%0d), Input2 = %h (%0d)", 
                   input_1, $signed(input_1), input_2, $signed(input_2));
          $display("  DUT Output = %h (%0d), ovf=%b", 
                   final_output, $signed(final_output), total_ovf);
          $display("  Expected   = %h (%0d)", ref_output, $signed(ref_output));
        end
      end
      
      // Test 2: Large positive values (overflow test)
      input_1 = $urandom_range(32'h3FFFFFFF, 32'h7FFFFFFE);
      input_2 = $urandom_range(32'h3FFFFFFF, 32'h7FFFFFFE);
      {ref_overflow, ref_output} = nn_model(input_1, input_2);
      
      enable = 1;
      #10;
      enable = 0;
      #80;
      
      total_tests = total_tests + 1;
      if (ref_overflow) begin
        if (total_ovf && final_output === 32'hFFFFFFFF) begin
          pass_count = pass_count + 1;
        end else begin
          $display("FAIL (overflow case) at time %0t ns:", $time);
          $display("  Input1 = %h, Input2 = %h", input_1, input_2);
          $display("  Expected overflow, got ovf=%b, output=%h", 
                   total_ovf, final_output);
        end
      end else begin
        if (final_output === ref_output && !total_ovf) begin
          pass_count = pass_count + 1;
        end else begin
          $display("FAIL at time %0t ns:", $time);
          $display("  Input1 = %h, Input2 = %h", input_1, input_2);
          $display("  DUT Output = %h, ovf=%b", final_output, total_ovf);
          $display("  Expected   = %h", ref_output);
        end
      end
      
      // Test 3: Large negative values
      input_1 = $urandom_range(32'h80000001, 32'hC0000000);
      input_2 = $urandom_range(32'h80000001, 32'hC0000000);
      {ref_overflow, ref_output} = nn_model(input_1, input_2);
      
      enable = 1;
      #10;
      enable = 0;
      #80;
      
      total_tests = total_tests + 1;
      if (ref_overflow) begin
        if (total_ovf && final_output === 32'hFFFFFFFF) begin
          pass_count = pass_count + 1;
        end else begin
          $display("FAIL (overflow case) at time %0t ns:", $time);
          $display("  Input1 = %h, Input2 = %h", input_1, input_2);
          $display("  Expected overflow, got ovf=%b, output=%h", 
                   total_ovf, final_output);
        end
      end else begin
        if (final_output === ref_output && !total_ovf) begin
          pass_count = pass_count + 1;
        end else begin
          $display("FAIL at time %0t ns:", $time);
          $display("  Input1 = %h, Input2 = %h", input_1, input_2);
          $display("  DUT Output = %h, ovf=%b", final_output, total_ovf);
          $display("  Expected   = %h", ref_output);
        end
      end
    end
    
    // Display final results
    $display("========================================");
    $display("Test Results: %0d PASS / %0d total tests", pass_count, total_tests);
    if (total_tests > 0)
      $display("Pass rate: %0d%%", (pass_count * 100) / total_tests);
    if (pass_count == total_tests)
      $display("*** ALL TESTS PASSED! ***");
    else
      $display("*** %0d test(s) failed ***", total_tests - pass_count);
    $display("========================================");
    
    #100;
    $finish;
  end
  
  // Optional: Waveform dump for debugging
  initial begin
    $dumpfile("tb_nn.vcd");
    $dumpvars(0, tb_nn);
  end

endmodule