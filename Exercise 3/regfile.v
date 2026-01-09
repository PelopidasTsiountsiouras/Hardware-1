module regfile #(parameter DATAWIDTH = 32) (
  input clk,
  input resetn,     // active-low async reset
  input write,
  input [3:0] readReg1,
  input [3:0] readReg2,
  input [3:0] readReg3,
  input [3:0] readReg4,
  input [3:0] writeReg1,
  input [3:0] writeReg2,
  input [DATAWIDTH-1:0] writeData1,
  input [DATAWIDTH-1:0] writeData2,
  output reg [DATAWIDTH-1:0] readData1,
  output reg [DATAWIDTH-1:0] readData2,
  output reg [DATAWIDTH-1:0] readData3,
  output reg [DATAWIDTH-1:0] readData4
);

  // 16 registers of DATAWIDTH bits
  reg [DATAWIDTH-1:0] regs [0:15];
  integer i;

  // Asynchronous reset + write logic
  always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      // async active-low reset
      for (i = 0; i < 16; i = i + 1)
        regs[i] <= {DATAWIDTH{1'b0}};
    end
    else if (write) begin
      regs[writeReg1] <= writeData1;
      regs[writeReg2] <= writeData2;
    end
  end

  // Read logic (combinational)
  always @(*) begin
    readData1 = regs[readReg1];
    readData2 = regs[readReg2];
    readData3 = regs[readReg3];
    readData4 = regs[readReg4];

    // Write-forwarding priority
    if (write) begin
      if (readReg1 == writeReg1) readData1 = writeData1;
      else if (readReg1 == writeReg2) readData1 = writeData2;

      if (readReg2 == writeReg1) readData2 = writeData1;
      else if (readReg2 == writeReg2) readData2 = writeData2;

      if (readReg3 == writeReg1) readData3 = writeData1;
      else if (readReg3 == writeReg2) readData3 = writeData2;

      if (readReg4 == writeReg1) readData4 = writeData1;
      else if (readReg4 == writeReg2) readData4 = writeData2;
    end
  end

endmodule
