`include "alu.v"
`include "mac_unit.v"
`include "regfile.v"

module nn (
  output reg [31:0] final_output,
  output reg total_ovf,
  output reg total_zero,
  output reg [2:0] ovf_fsm_stage,
  output reg [2:0] zero_fsm_stage,
  input [31:0] input_1,
  input [31:0] input_2,
  input clk,
  input resetn,
  input enable
);

  // FSM state encoding
  localparam [2:0] S_DEACTIVATED = 3'b000;
  localparam [2:0] S_LOAD_WB     = 3'b001;
  localparam [2:0] S_PREPROCESS  = 3'b010;
  localparam [2:0] S_INPUT       = 3'b011;
  localparam [2:0] S_OUTPUT      = 3'b100;
  localparam [2:0] S_POST        = 3'b101;
  localparam [2:0] S_IDLE        = 3'b110;

  reg [2:0] state, next_state;

  // ALU opcodes 
  localparam [3:0] ALU_LOG_SHIFT_L = 4'b0001;
  localparam [3:0] ALU_ARI_SHIFT_R = 4'b0010;

  // Max positive signed 32-bit
  localparam [31:0] MAX_POS = 32'h7FFFFFFF;

  // Weight loading control
  reg        weight_loaded;
  reg [3:0]  load_idx;

  // Regfile interface signals
  reg write;
  reg [3:0] writeReg1, writeReg2;
  reg [31:0] writeData1, writeData2;
  reg [3:0] readReg1, readReg2, readReg3, readReg4;
  wire [31:0] readData1, readData2, readData3, readData4;

  // Regfile instance
  regfile reg_instance (
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

  // Registered intermediate values
  reg [31:0] inter_1_reg, inter_2_reg;  // After preprocess
  reg [31:0] inter_3_reg, inter_4_reg;  // After input layer
  reg [31:0] inter_5_reg;                // After output layer
  reg [31:0] shift_bias_3_reg;           // Stored shift value for post-processing
  
  // Wires for combinational paths
  wire [31:0] inter_1, inter_2;
  wire [31:0] inter_3, inter_4;
  wire [31:0] out_tmp;
  wire [31:0] inter_5;
  wire [31:0] post_out;

  // Shift parameters (read from regfile during appropriate states)
  wire [31:0] shift_bias_1 = readData1;  // Read in PREPROCESS
  wire [31:0] shift_bias_2 = readData2;  // Read in PREPROCESS
  wire [31:0] weight_1 = readData1;      // Read in INPUT
  wire [31:0] bias_1 = readData2;        // Read in INPUT
  wire [31:0] weight_2 = readData3;      // Read in INPUT
  wire [31:0] bias_2 = readData4;        // Read in INPUT
  wire [31:0] weight_3 = readData1;      // Read in OUTPUT
  wire [31:0] weight_4 = readData2;      // Read in OUTPUT
  wire [31:0] bias_3 = readData3;        // Read in OUTPUT

  // ALUs for preprocess shifts
  alu alu_shift_r1 (
    .op1(input_1),
    .op2(shift_bias_1),
    .alu_op(ALU_ARI_SHIFT_R),
    .result(inter_1),
    .zero(),
    .ovf()
  );

  alu alu_shift_r2 (
    .op1(input_2),
    .op2(shift_bias_2),
    .alu_op(ALU_ARI_SHIFT_R),
    .result(inter_2),
    .zero(),
    .ovf()
  );

  // MAC units for INPUT LAYER
  wire zero_mul_in1, zero_add_in1, ovf_mul_in1, ovf_add_in1;
  wire zero_mul_in2, zero_add_in2, ovf_mul_in2, ovf_add_in2;

  mac_unit mac_in1 (
    .op1(inter_1_reg),
    .op2(weight_1),
    .op3(bias_1),
    .total_result(inter_3),
    .zero_mul(zero_mul_in1),
    .zero_add(zero_add_in1),
    .ovf_mul(ovf_mul_in1),
    .ovf_add(ovf_add_in1)
  );

  mac_unit mac_in2 (
    .op1(inter_2_reg),
    .op2(weight_2),
    .op3(bias_2),
    .total_result(inter_4),
    .zero_mul(zero_mul_in2),
    .zero_add(zero_add_in2),
    .ovf_mul(ovf_mul_in2),
    .ovf_add(ovf_add_in2)
  );

  // MAC units for OUTPUT LAYER
  wire zero_mul_o1, zero_add_o1, ovf_mul_o1, ovf_add_o1;
  wire zero_mul_o2, zero_add_o2, ovf_mul_o2, ovf_add_o2;

  mac_unit mac_out1 (
    .op1(inter_3_reg),
    .op2(weight_3),
    .op3(bias_3),
    .total_result(out_tmp),
    .zero_mul(zero_mul_o1),
    .zero_add(zero_add_o1),
    .ovf_mul(ovf_mul_o1),
    .ovf_add(ovf_add_o1)
  );

  mac_unit mac_out2 (
    .op1(inter_4_reg),
    .op2(weight_4),
    .op3(out_tmp),
    .total_result(inter_5),
    .zero_mul(zero_mul_o2),
    .zero_add(zero_add_o2),
    .ovf_mul(ovf_mul_o2),
    .ovf_add(ovf_add_o2)
  );

  // ALU for postprocess shift (uses registered shift_bias_3_reg)
  alu alu_shift_l_out (
    .op1(inter_5_reg),
    .op2(shift_bias_3_reg),
    .alu_op(ALU_LOG_SHIFT_L),
    .result(post_out),
    .zero(),
    .ovf()
  );

  // Stage-specific overflow detection
  wire ovf_input_stage  = ovf_mul_in1 | ovf_add_in1 | ovf_mul_in2 | ovf_add_in2;
  wire ovf_output_stage = ovf_mul_o1  | ovf_add_o1  | ovf_mul_o2  | ovf_add_o2;
  
  wire zero_input_stage  = zero_mul_in1 | zero_add_in1 | zero_mul_in2 | zero_add_in2;
  wire zero_output_stage = zero_mul_o1  | zero_add_o1  | zero_mul_o2  | zero_add_o2;

  // ROM-style loader
  reg [31:0] rom_data;
  reg [3:0]  rom_target_reg;

  always @(*) begin
    case (load_idx)
      4'd0: rom_data = 32'd2;  // shift_bias_1
      4'd1: rom_data = 32'd1;  // shift_bias_2
      4'd2: rom_data = 32'd5;  // weight_1
      4'd3: rom_data = 32'd3;  // bias_1
      4'd4: rom_data = 32'd4;  // weight_2
      4'd5: rom_data = 32'd1;  // bias_2
      4'd6: rom_data = 32'd6;  // weight_3
      4'd7: rom_data = 32'd2;  // weight_4
      4'd8: rom_data = 32'd7;  // bias_3
      4'd9: rom_data = 32'd3;  // shift_bias_3
      default: rom_data = 32'd0;
    endcase
  end

  always @(*) begin
    case (load_idx)
      4'd0: rom_target_reg = 4'h2;
      4'd1: rom_target_reg = 4'h3;
      4'd2: rom_target_reg = 4'h4;
      4'd3: rom_target_reg = 4'h5;
      4'd4: rom_target_reg = 4'h6;
      4'd5: rom_target_reg = 4'h7;
      4'd6: rom_target_reg = 4'h8;
      4'd7: rom_target_reg = 4'h9;
      4'd8: rom_target_reg = 4'hA;
      4'd9: rom_target_reg = 4'hB;
      default: rom_target_reg = 4'h0;
    endcase
  end
  
  // FSM combinational logic
  always @(*) begin
    // DEFAULTS 
    next_state = state;
    write = 1'b0;
    writeReg1 = 4'd0;
    writeReg2 = 4'd0;
    writeData1 = 32'd0;
    writeData2 = 32'd0;
    readReg1 = 4'd0;
    readReg2 = 4'd0;
    readReg3 = 4'd0;
    readReg4 = 4'd0;
    
    case (state)

      S_DEACTIVATED: begin
        if (enable && resetn)
          next_state = S_LOAD_WB;
      end

      S_LOAD_WB: begin
        write = 1'b1;
        writeReg1 = rom_target_reg;
        writeData1 = rom_data;

        if (weight_loaded)
          next_state = S_PREPROCESS;
      end

      S_PREPROCESS: begin
        // Read shift biases
        readReg1 = 4'h2;  // shift_bias_1
        readReg2 = 4'h3;  // shift_bias_2
        next_state = S_INPUT;
      end

      S_INPUT: begin
        // Read weights and biases for input layer
        readReg1 = 4'h4;  // weight_1
        readReg2 = 4'h5;  // bias_1
        readReg3 = 4'h6;  // weight_2
        readReg4 = 4'h7;  // bias_2
        
        // CHECK FOR OVERFLOW - jump to IDLE immediately if detected
        if (ovf_input_stage)
          next_state = S_IDLE;
        else
          next_state = S_OUTPUT;
      end

      S_OUTPUT: begin
        // Read weights and bias for output layer
        readReg1 = 4'h8;  // weight_3
        readReg2 = 4'h9;  // weight_4
        readReg3 = 4'hA;  // bias_3
        readReg4 = 4'hB;  // shift_bias_3 (will be latched for POST)
        
        // CHECK FOR OVERFLOW - jump to IDLE immediately if detected
        if (ovf_output_stage)
          next_state = S_IDLE;
        else
          next_state = S_POST;
      end

      S_POST: begin
        // shift_bias_3_reg already contains the shift value
        next_state = S_IDLE;
      end

      S_IDLE: begin
        if (enable)
          next_state = S_PREPROCESS;
      end

      default: begin
        next_state = S_DEACTIVATED;
      end

    endcase
  end

  // FSM sequential logic
  always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      // RESET
      state <= S_DEACTIVATED;
      load_idx <= 4'd0;
      weight_loaded <= 1'b0;
      final_output <= 32'd0;
      total_ovf <= 1'b0;
      total_zero <= 1'b0;
      ovf_fsm_stage <= 3'b111;
      zero_fsm_stage <= 3'b111;
      
      inter_1_reg <= 32'd0;
      inter_2_reg <= 32'd0;
      inter_3_reg <= 32'd0;
      inter_4_reg <= 32'd0;
      inter_5_reg <= 32'd0;
      shift_bias_3_reg <= 32'd0;
    end
    else begin
      // STATE UPDATE
      state <= next_state;

      // Clear overflow/zero flags when starting new computation
      if (state == S_IDLE && enable) begin
        total_ovf <= 1'b0;
        total_zero <= 1'b0;
        ovf_fsm_stage <= 3'b111;
        zero_fsm_stage <= 3'b111;
      end

      // WEIGHT LOADING COUNTER
      if (state == S_LOAD_WB) begin
        if (load_idx == 4'd9) begin
          load_idx <= 4'd0;
          weight_loaded <= 1'b1;
        end
        else begin
          load_idx <= load_idx + 1'b1;
        end
      end

      // LATCH INTERMEDIATE RESULTS AT END OF EACH STAGE
      if (state == S_PREPROCESS) begin
        inter_1_reg <= inter_1;
        inter_2_reg <= inter_2;
      end

      if (state == S_INPUT) begin
        inter_3_reg <= inter_3;
        inter_4_reg <= inter_4;
        
        // Check for overflow in input stage
        if (ovf_input_stage) begin
          total_ovf <= 1'b1;
          ovf_fsm_stage <= S_INPUT;
          final_output <= MAX_POS;
        end
        
        // Check for zero in input stage
        if (zero_input_stage && !total_zero) begin
          total_zero <= 1'b1;
          zero_fsm_stage <= S_INPUT;
        end
      end

      if (state == S_OUTPUT) begin
        inter_5_reg <= inter_5;
        shift_bias_3_reg <= readData4;  // Latch shift_bias_3 for POST state
        
        // Check for overflow in output stage
        if (ovf_output_stage) begin
          total_ovf <= 1'b1;
          ovf_fsm_stage <= S_OUTPUT;
          final_output <= MAX_POS;
        end
        
        // Check for zero in output stage
        if (zero_output_stage && !total_zero) begin
          total_zero <= 1'b1;
          zero_fsm_stage <= S_OUTPUT;
        end
      end

      if (state == S_POST) begin
        // Update final output at the end of POST state
        // Only if no overflow occurred
        if (!total_ovf) begin
          final_output <= post_out;
        end
      end
    end
  end
  
endmodule