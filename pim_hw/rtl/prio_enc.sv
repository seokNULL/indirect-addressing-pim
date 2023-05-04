`timescale 1ps / 1ps

module prio_enc #(parameter WIDTH=16) (
  input  logic clk,
  input  logic rst,
  input  logic [WIDTH-1:0]         prioenc_in,
  output logic [$clog2(WIDTH)-1:0] prioenc_out);
  
  logic [$clog2(WIDTH)-1:0] prioenc_out_nxt;

  always_comb begin
    prioenc_out_nxt = 0;
    for (int idx=WIDTH-1; idx>=0; idx--)
      if (prioenc_in[idx]) prioenc_out_nxt = idx;
  end

  always @(posedge clk, posedge rst)
    if (rst) prioenc_out <= 0;
    else     prioenc_out <= prioenc_out_nxt;

  initial prioenc_out = 0;

endmodule