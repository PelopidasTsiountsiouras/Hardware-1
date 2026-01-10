`include "alu.v"

module mac_unit (
  output [31:0] total_result,
  output zero_mul,
  output zero_add,
  output ovf_mul,
  output ovf_add,
  input [31:0] op1,
  input [31:0] op2,
  input [31:0] op3
);
  
  wire [31:0] mul_result;
  
  alu mul (
    .op1(op1),
    .op2(op2),
    .alu_op(4'b0110),
    .result(mul_result),
    .zero(zero_mul),
    .ovf(ovf_mul)
  );

  alu add (
    .op1(mul_result),
    .op2(op3),
    .alu_op(4'b0100),
    .result(total_result),
    .zero(zero_add),
    .ovf(ovf_add)
  );
  
endmodule
