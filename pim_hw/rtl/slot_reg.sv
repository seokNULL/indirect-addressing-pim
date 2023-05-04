`timescale 1ps / 1ps

module slot_reg #(parameter DEPTH = 1024) (
  input  logic clk,
  input  logic rst,
  input  logic slot_set,
  output logic [$clog2(DEPTH)-1:0] slot_nxt_addr,
  input  logic slot_clr,
  input  logic [$clog2(DEPTH)-1:0] slot_clr_addr,
  output logic [$clog2(DEPTH):0]   slot_cnt,
  output logic slot_full);

  // =============================== Signal Definitions ================================
  // Initial Address Generator Sigals
  logic slot_init_done;                     // Flag indicating that all slot addresses have been initialized and put into rotation
  logic [$clog2(DEPTH)-1:0] init_addr;      // A counter generating initial slot addresses
  // Slot Queue Signals
  logic slot_que_wr;                        // Write enable signal for Slot Queue
  logic slot_que_rd;                        // Read enable signal for Slot Queue
  logic [$clog2(DEPTH)-1:0] slot_que_din;   // Data input bus to Slot Queue
  logic [$clog2(DEPTH)-1:0] slot_que_dout;  // Data output bus from Slot Queue
  logic slot_que_empty;                     // Empty flag for Slot Queue

  // ============================ Initial Address Generator ============================
  always @(posedge clk, posedge rst)
    if (rst) init_addr <= 0;
    else     init_addr <= init_addr + slot_set;

  always @(posedge clk, posedge rst)
    if (rst) slot_init_done <= 0;
    else     slot_init_done <= slot_init_done || (init_addr == DEPTH-1 && slot_set);  // All slot addresses are initialized when the last one is used (slot_set asserted)

  // =================================== Slot Queue ====================================
  xvk_fifo #(
    .WIDTH     ($clog2(DEPTH)),
    .DEPTH     (DEPTH),
    .PROG_FULL (),
    .RAM_TYPE  ("BLOCK"))
  slot_que (
    .clk,
    .rst,
    .wr_en     (slot_que_wr),
    .rd_en     (slot_que_rd),
    .din       (slot_que_din),
    .full      (),
    .empty     (slot_que_empty),
    .last      (),
    .prog_full (),
    .dout      (slot_que_dout));

  assign slot_que_wr = slot_clr;                                      // Returning emtpy slot addresses to rotation with each "clear" assertion
  assign slot_que_rd = slot_init_done && slot_set;                    // Taking slot addresses from rotation with each "set" (after initialization is done)
  assign slot_que_din = slot_clr_addr;

  assign slot_nxt_addr = slot_init_done ? slot_que_dout : init_addr;  // Taking slot addresses from the initialization counter until all of them are initialized
  assign slot_full = slot_init_done && slot_que_empty;                // If there are no empty slots in rotation left, the slot register is full

  always @(posedge clk, posedge rst)
    if (rst) slot_cnt <= 0;
    else     slot_cnt <= slot_cnt + (!slot_full ? slot_set : 0) - ((slot_cnt == 0) ? 0 : slot_clr);

  // ================================= Initialization ==================================
  initial begin
    // Initial Address Generator Signals
    init_addr = 0;
    slot_init_done = 0;
    // Slot Queue Signals
    slot_cnt = 0;
  end

endmodule
