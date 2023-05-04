`timescale 1ns / 1ps

module round_robin #(parameter DEPTH = 16) (
  input  logic clk,
  input  logic rst,
  input  logic rr_add,
  input  logic [$clog2(DEPTH)-1:0] rr_add_val,
  input  logic rr_rmv,
  input  logic rr_nxt,
  output logic [$clog2(DEPTH)-1:0] rr_idx);
  
  // ============================= Local Declarations =============================
  // General Signals
  logic [$clog2(DEPTH):0] occup;                 // Number of occupied round-robin slots
  logic rot_en;                                  // Signal enabling slot rotation between two FIFO registers
  logic add_loc;                                 // Local rr_add signal that accounts for occupancy
  logic rmv_loc;                                 // Local rr_rmv signal that accounts for occupancy
  // Slot Tracking Signals
  logic [DEPTH-1:0] idx_in_rot, idx_in_rot_nxt;  // 1-bit array for tracking indexes that are in rotation
  // FIFO Signals
  logic wr_en [1:0];                             // FIFO write enable
  logic rd_en [1:0];                             // FIFO read enable
  logic empty [1:0];                             // FIFO empty
  logic [$clog2(DEPTH)-1:0] din  [1:0];          // FIFO data input
  logic [$clog2(DEPTH)-1:0] dout [1:0];          // FIFO data output

  // ============================== General Signals ===============================
  assign add_loc = rr_add && (!(occup==DEPTH || idx_in_rot[rr_add_val]) || (rr_rmv && (rr_idx==rr_add_val)));  // Ignore input if occupany is max, or the index is in rotation, or currently removing the same index
  assign rmv_loc = rr_rmv && !(occup==0);        // Ignore remove requests if occupancy is zero
  assign rot_en  = occup > 1;                    // If occupancy is one, no rotation is needed
  assign rr_idx  = dout[0];

  always @(posedge clk, posedge rst)
    if      (rst)              occup <= 0;
    else if (add_loc||rmv_loc) occup <= occup + add_loc - rmv_loc;

  initial occup = 0;

  // =============================== FIFO Registers ===============================
  genvar i;
  generate
    for (i=0; i<2; i++) begin : rrFifo
      xvk_fifo #(
        .WIDTH     ($clog2(DEPTH)),
        .DEPTH     (DEPTH),
        .PROG_FULL (),
        .RAM_TYPE  ("DISTRIBUTED"))
      rr_fifo (
        .clk,
        .rst,
        .wr_en     (wr_en[i]),
        .rd_en     (rd_en[i]),
        .din       (din[i]),
        .full      (),
        .empty     (empty[i]),
        .last      (),
        .prog_full (),
        .dout      (dout[i]));
    end
  endgenerate

  assign din[0] = add_loc ? rr_add_val : dout[1];  // Hold dout[1] when adding new entries
  assign din[1] = dout[0];

  assign wr_en[0] = (rmv_loc && !empty[1]) || add_loc || (rr_nxt && rot_en && !empty[1]);
  assign rd_en[0] = rmv_loc || (rr_nxt && rot_en);
  assign wr_en[1] = (rr_nxt && rot_en && !rmv_loc);
  assign rd_en[1] = (rr_nxt && rot_en || rmv_loc) && !add_loc && !empty[1];

  // ======================== Tracking Indexes in Rotation ========================
  always_comb begin
    idx_in_rot_nxt = idx_in_rot;
    if (rmv_loc) idx_in_rot_nxt [rr_idx]     = 0;
    if (add_loc) idx_in_rot_nxt [rr_add_val] = 1;
  end

  always @(posedge clk, posedge rst)
    if (rst) idx_in_rot <= 0;
    else     idx_in_rot <= idx_in_rot_nxt;

  initial idx_in_rot = 0;

endmodule
