module alu (
  output reg        zero,
  output reg [31:0] result,
  output reg        ovf,
  input  [31:0]     op1,
  input  [31:0]     op2,
  input  [3:0]      alu_op
);

  // ALU operation codes
  parameter [3:0] ALU_AND          = 4'b1000;
  parameter [3:0] ALU_OR           = 4'b1001;
  parameter [3:0] ALU_NOR          = 4'b1010;
  parameter [3:0] ALU_NAND         = 4'b1011;
  parameter [3:0] ALU_XOR          = 4'b1100;
  parameter [3:0] ALU_ADD          = 4'b0100;
  parameter [3:0] ALU_SUB          = 4'b0101;
  parameter [3:0] ALU_MUL          = 4'b0110;
  parameter [3:0] ALU_LOG_SHIFT_R  = 4'b0000;
  parameter [3:0] ALU_LOG_SHIFT_L  = 4'b0001;
  parameter [3:0] ALU_ARI_SHIFT_R  = 4'b0010;
  parameter [3:0] ALU_ARI_SHIFT_L  = 4'b0011;

  // Signed versions for arithmetic
  wire signed [31:0] sop1 = op1;
  wire signed [31:0] sop2 = op2;
  reg  signed [63:0] wide_result;

  always @(*) begin
    // defaults
    result = 32'b0;
    ovf    = 1'b0;

    case (alu_op)

      ALU_AND:  result = op1 & op2;
      ALU_OR:   result = op1 | op2;
      ALU_NOR:  result = ~(op1 | op2);
      ALU_NAND: result = ~(op1 & op2);
      ALU_XOR:  result = op1 ^ op2;

      ALU_ADD: begin
        result = sop1 + sop2;
        ovf = (~(sop1[31] ^ sop2[31])) & (result[31] ^ sop1[31]);
      end

      ALU_SUB: begin
        result = sop1 - sop2;
        ovf = ((sop1[31] ^ sop2[31])) & (result[31] ^ sop1[31]);
      end

      ALU_MUL: begin
        wide_result = sop1 * sop2;
        result = wide_result[31:0];
        ovf = (wide_result[63:32] != {32{wide_result[31]}});
      end

      ALU_LOG_SHIFT_R: result = op1 >> op2;
      ALU_LOG_SHIFT_L: result = op1 << op2;
      ALU_ARI_SHIFT_R: result = sop1 >>> op2;
      ALU_ARI_SHIFT_L: result = sop1 <<< op2;

      default: result = 32'b0;
    endcase

    zero = (result == 32'b0);

  end

endmodule
