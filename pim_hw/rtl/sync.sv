`timescale 1ps/1ps

module sync #(parameter
  SYNC_FF = 2,
  WIDTH   = 8)
(
   input  logic dest_clk,
   input  logic [WIDTH-1:0] din,
   output logic [WIDTH-1:0] dout);
  
  (*DONT_TOUCH="TRUE"*) (*ASYNC_REG="TRUE"*) logic [WIDTH-1:0][SYNC_FF-1:0] sync_reg;

  genvar i;
  generate
    for (i=0; i<WIDTH; i++) begin : SYNC
      assign dout[i] = sync_reg[i][SYNC_FF-1];

      always @(posedge dest_clk) begin
        sync_reg[i] <= {sync_reg[i][0+:SYNC_FF-1], din[i]};
      end
    end
  endgenerate

endmodule