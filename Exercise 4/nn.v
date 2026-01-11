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

  // Preprocess results
  wire [31:0] inter_1, inter_2;

  // Input layer results
  wire [31:0] inter_3, inter_4;

  // Output layer results
  wire [31:0] inter_5;
  wire [31:0] out_tmp;     // intermediate for output-layer two-MAC chain

  // Postprocess result (wire), then you can latch to final_output in FSM if you want
  wire [31:0] post_out;

  // FSM state encoding
  localparam [2:0] S_DEACTIVATED = 3'b000;
  localparam [2:0] S_LOAD_WB = 3'b001;
  localparam [2:0] S_PREPROCESS = 3'b010;
  localparam [2:0] S_INPUT = 3'b011;
  localparam [2:0] S_OUTPUT = 3'b100;
  localparam [2:0] S_POST = 3'b101;
  localparam [2:0] S_IDLE = 3'b110;

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

  // READ ADDRESSES MUST BE REGS (FSM-driven)
  reg [3:0] readReg1, readReg2, readReg3, readReg4;

  // READ DATA are WIRES (regfile-driven)
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

  // In PREPROCESS state you will set:
  //   readReg1=0x2 (shift_bias_1), readReg2=0x3 (shift_bias_2)
  wire [31:0] shift_bias_1 = readData1;
  wire [31:0] shift_bias_2 = readData2;

  // In INPUT state you will set:
  //   readReg1=0x4 (w1), readReg2=0x5 (b1), readReg3=0x6 (w2), readReg4=0x7 (b2)
  wire [31:0] weight_1 = readData1;
  wire [31:0] bias_1 = readData2;
  wire [31:0] weight_2 = readData3;
  wire [31:0] bias_2 = readData4;

  // In OUTPUT state you will set:
  //   readReg1=0x8 (w3), readReg2=0x9 (w4), readReg3=0xA (b3)
  wire [31:0] weight_3 = readData1;
  wire [31:0] weight_4 = readData2;
  wire [31:0] bias_3 = readData3;

  // In POST state you will set:
  //   readReg1=0xB (shift_bias_3)
  wire [31:0] shift_bias_3 = readData1;

  // ALUs for preprocess/postprocess shifts
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

  alu alu_shift_l_out (
    .op1(inter_5),
    .op2(shift_bias_3),
    .alu_op(ALU_LOG_SHIFT_L),
    .result(post_out),
    .zero(),
    .ovf()
  );

  // ----------------------------
  // MAC units
  // INPUT LAYER: two neurons in parallel
  // inter_3 = inter_1*w1 + b1
  // inter_4 = inter_2*w2 + b2
  // ----------------------------
  wire zero_mul_in1, zero_add_in1, ovf_mul_in1, ovf_add_in1;
  wire zero_mul_in2, zero_add_in2, ovf_mul_in2, ovf_add_in2;

  mac_unit mac_in1 (
    .op1(inter_1),
    .op2(weight_1),
    .op3(bias_1),
    .total_result(inter_3),
    .zero_mul(zero_mul_in1),
    .zero_add(zero_add_in1),
    .ovf_mul(ovf_mul_in1),
    .ovf_add(ovf_add_in1)
  );

  mac_unit mac_in2 (
    .op1(inter_2),
    .op2(weight_2),
    .op3(bias_2),
    .total_result(inter_4),
    .zero_mul(zero_mul_in2),
    .zero_add(zero_add_in2),
    .ovf_mul(ovf_mul_in2),
    .ovf_add(ovf_add_in2)
  );

  // ----------------------------
  // OUTPUT LAYER: two MACs in series to match the PDF:
  // inter_5 = inter_3*w3 + inter_4*w4 + b3
  //
  // Step A: out_tmp = inter_3*w3 + b3
  // Step B: inter_5 = inter_4*w4 + out_tmp
  // ----------------------------
  wire zero_mul_o1, zero_add_o1, ovf_mul_o1, ovf_add_o1;
  wire zero_mul_o2, zero_add_o2, ovf_mul_o2, ovf_add_o2;

  mac_unit mac_out1 (
    .op1(inter_3),
    .op2(weight_3),
    .op3(bias_3),
    .total_result(out_tmp),
    .zero_mul(zero_mul_o1),
    .zero_add(zero_add_o1),
    .ovf_mul(ovf_mul_o1),
    .ovf_add(ovf_add_o1)
  );

  mac_unit mac_out2 (
    .op1(inter_4),
    .op2(weight_4),
    .op3(out_tmp),
    .total_result(inter_5),
    .zero_mul(zero_mul_o2),
    .zero_add(zero_add_o2),
    .ovf_mul(ovf_mul_o2),
    .ovf_add(ovf_add_o2)
  );

  // Overflow / zero aggregation wires (FSM will use these)
  wire any_ovf =
      ovf_mul_in1 | ovf_add_in1 |
      ovf_mul_in2 | ovf_add_in2 |
      ovf_mul_o1  | ovf_add_o1  |
      ovf_mul_o2  | ovf_add_o2;

  wire any_zero =
      zero_mul_in1 | zero_add_in1 |
      zero_mul_in2 | zero_add_in2 |
      zero_mul_o1  | zero_add_o1  |
      zero_mul_o2  | zero_add_o2;

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
    
    // FSM LOGIC
    case (state)

      S_DEACTIVATED: begin
        if (enable)
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
        // read shift_bias_1, shift_bias_2
        readReg1 = 4'h2;
        readReg2 = 4'h3;
        next_state = S_INPUT;
      end

      S_INPUT: begin
        // read weight_1, bias_1, weight_2, bias_2
        readReg1 = 4'h4;
        readReg2 = 4'h5;
        readReg3 = 4'h6;
        readReg4 = 4'h7;

        if (any_ovf)
          next_state = S_IDLE;
        else
          next_state = S_OUTPUT;
      end

      S_OUTPUT: begin
        // read weight_3, weight_4, bias_3
        readReg1 = 4'h8;
        readReg2 = 4'h9;
        readReg3 = 4'hA;

        if (any_ovf)
          next_state = S_IDLE;
        else
          next_state = S_POST;
      end

      S_POST: begin
        // read shift_bias_3
        readReg1 = 4'hB;

        if (any_ovf)
          next_state = S_IDLE;
        else
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

  always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      // RESET
      state <= S_DEACTIVATED;
      load_idx <= 4'd0;
      weight_loaded <= 1'b0;
      final_output <= 32'd0;
      total_ovf <= 1'b0;
      total_zero <= 1'b0;
      ovf_fsm_stage <= 3'd0;
      zero_fsm_stage <= 3'd0;
    end
    else begin
      // STATE UPDATE
      state <= next_state;

      // WEIGHT LOADING COUNTER
      if (state == S_LOAD_WB) begin
        if (load_idx == 4'd9) begin
          load_idx      <= 4'd0;
          weight_loaded <= 1'b1;
        end
        else begin
          load_idx <= load_idx + 1'b1;
        end
      end

      // OUTPUT LATCHING
      if (state == S_POST && !any_ovf) begin
        final_output <= post_out;
      end

      // OVERFLOW / ZERO TRACKING
      if (any_ovf) begin
        total_ovf     <= 1'b1;
        ovf_fsm_stage <= state;
        final_output  <= MAX_POS;
      end

      if (any_zero) begin
        total_zero      <= 1'b1;
        zero_fsm_stage  <= state;
      end
    end
  end
  
endmodule