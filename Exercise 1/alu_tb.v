`timescale 1ns/1ps

module alu_tb;

  reg [31:0] op1, op2;
  reg [3:0]  alu_op;
  wire [31:0] result;
  wire zero, ovf;

  alu dut (
    .op1(op1),
    .op2(op2),
    .alu_op(alu_op),
    .result(result),
    .zero(zero),
    .ovf(ovf)
  );

  localparam ALU_AND = 4'b1000;
  localparam ALU_OR  = 4'b1001;
  localparam ALU_NOR = 4'b1010;
  localparam ALU_NAND = 4'b1011;
  localparam ALU_XOR = 4'b1100;
  localparam ALU_ADD = 4'b0100;
  localparam ALU_SUB = 4'b0101;
  localparam ALU_MUL = 4'b0110;
  localparam ALU_LOG_SHIFT_R = 4'b0000;
  localparam ALU_LOG_SHIFT_L = 4'b0001;
  localparam ALU_ARI_SHIFT_R = 4'b0010;
  localparam ALU_ARI_SHIFT_L = 4'b0011;

  task check;
    input [31:0] exp_result;
    input exp_zero;
    input exp_ovf;
    begin
      #1;
      if (result !== exp_result || zero !== exp_zero || ovf !== exp_ovf)
        $display("FAIL | op=%b res=%h z=%b ovf=%b (exp %h %b %b)",
                  alu_op, result, zero, ovf, exp_result, exp_zero, exp_ovf);
      else
        $display("PASS | op=%b res=%h z=%b ovf=%b",
                  alu_op, result, zero, ovf);
    end
  endtask

  initial begin
    $display("=== ALU TESTS START ===");

    op1=32'hA5A5A5A5; op2=32'h0F0F0F0F; alu_op=ALU_AND;
    check(32'h05050505,0,0);

    alu_op=ALU_OR;
    check(32'hAFAFAFAF,0,0);

    alu_op=ALU_XOR;
    check(32'hAAAAAAAA,0,0);

    op1=100; op2=50; alu_op=ALU_ADD;
    check(150,0,0);

    op1=32'h7FFFFFFF; op2=1; alu_op=ALU_ADD;
    check(32'h80000000,0,1);

    op1=50; op2=20; alu_op=ALU_SUB;
    check(30,0,0);

    op1=32'h80000000; op2=1; alu_op=ALU_SUB;
    check(32'h7FFFFFFF,0,1);

    op1=10; op2=20; alu_op=ALU_MUL;
    check(200,0,0);

    op1=32'h40000000; op2=4; alu_op=ALU_MUL;
    check(32'h00000000,1,1);

    op1=32'h00000100; op2=2; alu_op=ALU_LOG_SHIFT_R;
    check(32'h00000040,0,0);

    alu_op=ALU_LOG_SHIFT_L;
    check(32'h00000400,0,0);

    op1=32'hFFFFFF00; op2=4; alu_op=ALU_ARI_SHIFT_R;
    check(32'hFFFFFFF0,0,0);

    alu_op=ALU_ARI_SHIFT_L;
    check(32'hFFFFF000,0,0);

    op1=0; op2=0; alu_op=ALU_ADD;
    check(0,1,0);

    $display("=== ALU TESTS END ===");
    $finish;
  end

endmodule
