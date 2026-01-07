`include "alu.v"
`include "calc_enc.v"

module calc (
  output [15:0] led,
  input clk,
  input btnc,
  input btnac,
  input btnl,
  input btnr,
  input btnd,
  input [15:0] sw
);
  
  reg signed [15:0] accumulator;
  
  wire [31:0] alu_op1, alu_op2;
  
  assign alu_op1 = {{16{accumulator[15]}}, accumulator};
  assign alu_op2 = {{16{sw[15]}}, sw};
  
  wire [3:0] alu_op;
  
  wire [31:0] alu_result;
  wire alu_zero;
  wire alu_ovf;
  
  calc_enc enc (
    .btnl(btnl),
    .btnr(btnr),
    .btnd(btnd),
    .alu_op(alu_op)
  );
  
  alu alu_inst (
    .op1(alu_op1),
    .op2(alu_op2),
    .alu_op(alu_op),
    .result(alu_result),
    .zero(alu_zero),
    .ovf(alu_ovf)
  );
  
  always @(posedge clk) begin
    if (btnac) begin
      accumulator <= 16'b0;
    end
    else if (btnc) begin
      accumulator <= alu_result[15:0];
    end
  end
  
  assign led = accumulator;
  
endmodule