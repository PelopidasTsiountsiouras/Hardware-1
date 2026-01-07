module calc_enc (
  output [3:0] alu_op,
  input btnl,
  input btnr,
  input btnd
);
  
  // Intermediate wires for alu_op[0]
  wire a00, a01, a02;
  wire n00, n01;
  
  // Intermediate wires for alu_op[1]
  wire n10, n11;
  wire o10;
  
  // Intermediate wires for alu_op[2]
  wire n20, n21;
  wire a20, a21;
  wire xo20;
  
  // Intermediate wires for alu_op[3]
  wire a30, a31;
  
  // alu_op[0]
  not (n00, btnl);
  not (n01, btnd);
  and (a00, n00, btnd);
  and (a01, btnl, btnr);
  and (a02, a01, n01);
  or (alu_op[0], a00, a02);
  
  // alu_op[1]
  not (n10, btnr);
  not (n11, btnd);
  or (o10, n10, n11);
  and (alu_op[1], btnl, o10);
  
  // alu_op[2]
  not (n20, btnl);
  xor (xo20, btnr, btnd);
  not (n21, xo20);
  and (a20, n20, btnr);
  and (a21, btnl, n21);
  or (alu_op[2], a20, a21);
  
  // alu_op[3]
  and (a30, btnl, btnr);
  and (a31, btnl, btnd);
  or (alu_op[3], a30, a31);
  
endmodule