`timescale 1ps / 1ps

import aimc_lib::*;

module bcast_icnt (
  input logic clk,
  input logic rst,
  // DMA Interface
  input  logic dma_rdy,
  input  logic dma_pkt_valid,
  input  pkt_t dma_pkt,
  input  logic [CH_NUM-1:0] dma_pkt_ch_mask,
  output logic icnt_rdy,
  output logic icnt_dma_pkt_valid,
  output pkt_t icnt_dma_pkt,
  output logic [$clog2(CH_NUM)-1:0] icnt_dma_pkt_ch_addr,
  // AiM Controller Interface
  output logic [CH_NUM-1:0] icnt_aimc_pkt_valid,
  output pkt_t icnt_aimc_pkt,
  input  logic [CH_NUM-1:0] aimc_rdy,
  input  logic [CH_NUM-1:0] aimc_pkt_valid,
  input  pkt_t aimc_pkt [CH_NUM-1:0]);

  // ============================= Signal Declarations =============================
  // Entry Queue
  pkt_t entry_que_din;                              // Entry packet queue data in
  pkt_t entry_que_dout;                             // Entry packet queue data out
  logic entry_que_wr;                               // Entry packet queue write enable signal
  logic entry_que_rd;                               // Entry packet queue read enable signal
  logic entry_que_empty;                            // Entry packet queue empty flag
  logic entry_que_full;                             // Entry packet queue full flag
  logic [CH_NUM-1:0] entry_ch_que_din;              // Entry packet channel index/mask queue data in
  logic [CH_NUM-1:0] entry_ch_que_dout;             // Entry packet channel index/mask queue data out
  logic entry_ch_que_wr;                            // Entry packet channel index/mask queue write enable signal
  logic entry_ch_que_rd;                            // Entry packet channel index/mask queue read enable signal
  logic [$clog2(CH_NUM)-1:0] ucast_ch_addr;         // Unicast channel address derived from entry_ch_que_dout
  // Exit Multiplexer
  logic [7:0] rr_req_list;                          // Request list to the 8-channel round-robin arbiter
  logic [2:0] rr_base_idx;                          // Rotating round-robin index (! WARNING: Hard-coded to 8 channels !)
  logic [2:0] ucast_resp_que_idx;                   // Index of the selected unicast response queue (! WARNING: Hard-coded to 8 channels !)
  logic ucast_pull;                                 // Signal for pulling unicast response from the queue
  pkt_t bcast_resp_pkt;                             // Broadcast response packet
  pkt_t ucast_resp_pkt;                             // Unicast response packet
  logic [$clog2(CH_NUM)-1:0] icnt_pkt_ch_addr_nxt;  // Next state for the outbound icnt_dma_pkt_ch_addr signal to the DMA
  pkt_t icnt_dma_pkt_nxt;                           // Next state for the outbound packet register
  // Broadcast Resposne Queue
  logic bcast_add;                                  // Signal for announcing broadcast requests to the collector
  logic [CH_NUM-1:0] bcast_mask;                    // Broadcasting mask indicating channels that are involved in broadcasting
  logic bcast_pull;                                 // Signal for pulling broadcast responses from the collector
  logic bcast_pipe_full;                            // Flag indicating that no more in-flight broadcast packets are allowed
  logic [CH_NUM-1:0] aimc_bcast_resp;               // Indicator that controller's response is to broadcasted request
  logic bcast_resp;                                 // Combined response to a broadcast request (after responses from all channels have been gathered)
  pkt_meta_t bcast_resp_que_din;                    // Broadcast response packet queue data in
  pkt_meta_t bcast_resp_que_dout;                   // Broadcast response packet queue data out
  logic bcast_resp_que_wr;                          // Broadcast response packet queue write enable signal
  logic bcast_resp_que_rd;                          // Broadcast response packet queue read enable signal
  // Unicast Response Queues
  pkt_t ucast_resp_que_din  [CH_NUM-1:0];           // Response queue data in
  pkt_t ucast_resp_que_dout [CH_NUM-1:0];           // Response queue data out
  logic [CH_NUM-1:0] ucast_resp_que_wr;             // Response queue write enable signal
  logic [CH_NUM-1:0] ucast_resp_que_rd;             // Response queue read enable signal
  logic [CH_NUM-1:0] ucast_resp_que_empty;          // Response queue empty flag
  logic [CH_NUM-1:0] ucast_resp_que_pfull;          // Response queue programmable full flag
  logic ucast_resp_que_pfull_d;                     // Single full flag derived from all ucast_resp queues

  genvar i;
  // ================================= Entry Queue =================================
  // Wide queue for storing entry packets, implemented in block RAM
  xpm_fifo_sync #(
    .DOUT_RESET_VALUE    ("0"),
    .ECC_MODE            ("no_ecc"),
    .FIFO_MEMORY_TYPE    ("block"),
    .FIFO_READ_LATENCY   (0),
    .FIFO_WRITE_DEPTH    (16),
    .FULL_RESET_VALUE    (0),
    .PROG_EMPTY_THRESH   (5),
    .PROG_FULL_THRESH    (5),
    .RD_DATA_COUNT_WIDTH (5),
    .READ_DATA_WIDTH     ($bits(pkt_t)),
    .READ_MODE           ("fwft"),
    .SIM_ASSERT_CHK      (0),
    .USE_ADV_FEATURES    ("0000"),
    .WAKEUP_TIME         (0),
    .WR_DATA_COUNT_WIDTH (5),
    .WRITE_DATA_WIDTH    ($bits(pkt_t)))
  entry_que (
    .almost_empty        (),
    .almost_full         (),
    .data_valid          (),
    .dbiterr             (),
    .dout                (entry_que_dout),
    .empty               (entry_que_empty),
    .full                (entry_que_full),
    .overflow            (),
    .prog_empty          (),
    .prog_full           (),
    .rd_data_count       (),
    .rd_rst_busy         (),
    .sbiterr             (),
    .underflow           (),
    .wr_ack              (),
    .wr_data_count       (),
    .wr_rst_busy         (),
    .din                 (entry_que_din),
    .injectdbiterr       (1'b0),
    .injectsbiterr       (1'b0),
    .rd_en               (entry_que_rd),
    .rst                 (rst),
    .sleep               (1'b0),
    .wr_clk              (clk),
    .wr_en               (entry_que_wr));

  assign entry_que_wr  = icnt_rdy && dma_pkt_valid;
  assign entry_que_din = dma_pkt;
  assign icnt_rdy      = !entry_que_full || ucast_resp_que_pfull_d;
  assign icnt_aimc_pkt = entry_que_dout;

  always_comb begin
    icnt_aimc_pkt_valid = 0;
    if (entry_que_dout.bcast) begin
      entry_que_rd        = !entry_que_empty && !bcast_pipe_full && &(~bcast_mask | (aimc_rdy & bcast_mask));
      icnt_aimc_pkt_valid = {CH_NUM{entry_que_rd}} & bcast_mask;
      // icnt_aimc_pkt_valid = {CH_NUM{!entry_que_empty && !bcast_pipe_full && &(~(aimc_rdy^bcast_mask))}} & bcast_mask;  // Asserting valid only when all bcast targets are ready (to avoid duplicating packets while waiting for some channels)
    end
    else begin
      entry_que_rd                       = aimc_rdy[ucast_ch_addr];
      icnt_aimc_pkt_valid[ucast_ch_addr] = !entry_que_empty;         // When request is unicast, only generate "valid" for one channel selected from the channel address queue
    end
  end

  // Narrow queue for storing channel address (in case of ucast) or mask (in case of bcast), implemented in distributed RAM
  xpm_fifo_sync #(
    .DOUT_RESET_VALUE    ("0"),
    .ECC_MODE            ("no_ecc"),
    .FIFO_MEMORY_TYPE    ("distributed"),
    .FIFO_READ_LATENCY   (0),
    .FIFO_WRITE_DEPTH    (16),
    .FULL_RESET_VALUE    (0),
    .PROG_EMPTY_THRESH   (5),
    .PROG_FULL_THRESH    (5),
    .RD_DATA_COUNT_WIDTH (5),
    .READ_DATA_WIDTH     (CH_NUM),
    .READ_MODE           ("fwft"),
    .SIM_ASSERT_CHK      (0),
    .USE_ADV_FEATURES    ("0000"),
    .WAKEUP_TIME         (0),
    .WR_DATA_COUNT_WIDTH (5),
    .WRITE_DATA_WIDTH    (CH_NUM))
  entry_ch_que (
    .almost_empty        (),
    .almost_full         (),
    .data_valid          (),
    .dbiterr             (),
    .dout                (entry_ch_que_dout),
    .empty               (),
    .full                (),
    .overflow            (),
    .prog_empty          (),
    .prog_full           (),
    .rd_data_count       (),
    .rd_rst_busy         (),
    .sbiterr             (),
    .underflow           (),
    .wr_ack              (),
    .wr_data_count       (),
    .wr_rst_busy         (),
    .din                 (entry_ch_que_din),
    .injectdbiterr       (1'b0),
    .injectsbiterr       (1'b0),
    .rd_en               (entry_ch_que_rd),
    .rst                 (rst),
    .sleep               (1'b0),
    .wr_clk              (clk),
    .wr_en               (entry_ch_que_wr));

  assign entry_ch_que_wr  = entry_que_wr;
  assign entry_ch_que_rd  = entry_que_rd;
  assign entry_ch_que_din = dma_pkt_ch_mask;//dma_pkt.bcast ? dma_pkt_ch_mask : dma_pkt_ch_addr;
  assign ucast_ch_addr    = entry_ch_que_dout[CH_ADDR_WIDTH-1:0];  // Used only with ucast packets
  assign bcast_mask       = entry_ch_que_dout;                     // Used only with bcast packets

  // ============================== Exit Multiplexer ===============================
  // Round-robin module for scrolling accross unicast response queues (! WARNING: Hard-coded to 8 channels !)
  rrarb_8 rrarb_8 (
    .rr_req_list (rr_req_list),
    .rr_base_idx (rr_base_idx),
    .rr_sel_idx  (ucast_resp_que_idx));

  always_comb begin
    rr_req_list = 0;  
    rr_req_list[CH_NUM-1:0] = ~ucast_resp_que_empty[CH_NUM-1:0];
  end

  always @(posedge clk, posedge rst)
    if      (rst)        rr_base_idx <= 0;
    else if (ucast_pull) rr_base_idx <= ucast_resp_que_idx + 1'b1;  // Setting next round-robin index to the channel that we currently read from

  assign ucast_pull = |ucast_resp_que_rd;                           // Updating round-robin counter each time a unicast response queue is read

  // Constructing and buffering the outbound packet to DMA
  always @(posedge clk) begin
    if (bcast_pull || ucast_pull) begin
      icnt_dma_pkt         <= icnt_dma_pkt_nxt;
      icnt_dma_pkt_ch_addr <= icnt_pkt_ch_addr_nxt;                            
    end
  end
  assign icnt_dma_pkt_nxt     = bcast_pull ? bcast_resp_pkt : ucast_resp_pkt;
  assign icnt_pkt_ch_addr_nxt = bcast_pull ? 0 : ucast_resp_que_idx;   // Defaulting to "0" channel address for broadcast responses

  always_comb begin
    bcast_resp_pkt = 0;
    bcast_resp_pkt.marker   = bcast_resp_que_dout.marker;
    bcast_resp_pkt.bcast    = bcast_resp_que_dout.bcast;
    bcast_resp_pkt.prio     = bcast_resp_que_dout.prio;
    bcast_resp_pkt.req_type = bcast_resp_que_dout.req_type;
    bcast_resp_pkt.bk_addr  = bcast_resp_que_dout.bk_addr;
    bcast_resp_pkt.row_addr = bcast_resp_que_dout.row_addr;
    bcast_resp_pkt.col_addr = bcast_resp_que_dout.col_addr;
  end
  assign ucast_resp_pkt = ucast_resp_que_dout[ucast_resp_que_idx];

  // Outbound packet validity signal
  always @(posedge clk, posedge rst)
    if      (rst)                            icnt_dma_pkt_valid <= 0;
    else if (!icnt_dma_pkt_valid || dma_rdy) icnt_dma_pkt_valid <= (bcast_pull || ucast_pull);

  // =========================== Broadcast Response Queue ==========================
  // Broadcast response collector
  resp_collector resp_collector (
    .clk,
    .rst,
    .bcast_add,
    .bcast_mask,
    .bcast_pull,
    .bcast_pipe_full,
    .aimc_bcast_resp,
    .bcast_resp);

  always_comb begin
    for (int idx=0; idx<CH_NUM; idx++) begin
      aimc_bcast_resp[idx] = aimc_pkt_valid[idx] && aimc_pkt[idx].bcast;
    end
  end
  assign bcast_add  = bcast_resp_que_wr;
  assign bcast_pull = bcast_resp && (!icnt_dma_pkt_valid || dma_rdy);  // Pull the request when the interconnect output buffer is free or DMA is pulling the response from it

  // Broadcast response queue (stores responses right after requests are issued and waits for collector's commands to pull them out)
  xpm_fifo_sync #(
    .DOUT_RESET_VALUE    ("0"),
    .ECC_MODE            ("no_ecc"),
    .FIFO_MEMORY_TYPE    ("block"),
    .FIFO_READ_LATENCY   (0),
    .FIFO_WRITE_DEPTH    (BCAST_PIPE_LENGTH),
    .FULL_RESET_VALUE    (0),
    .PROG_EMPTY_THRESH   (),
    .PROG_FULL_THRESH    (),
    .RD_DATA_COUNT_WIDTH (),
    .READ_DATA_WIDTH     ($bits(pkt_meta_t)),
    .READ_MODE           ("fwft"),
    .SIM_ASSERT_CHK      (0),
    .USE_ADV_FEATURES    ("0000"),
    .WAKEUP_TIME         (0),
    .WR_DATA_COUNT_WIDTH (),
    .WRITE_DATA_WIDTH    ($bits(pkt_meta_t)))
  bcast_resp_que (
    .almost_empty        (),
    .almost_full         (),
    .data_valid          (),
    .dbiterr             (),
    .dout                (bcast_resp_que_dout),
    .empty               (),
    .full                (),
    .overflow            (),
    .prog_empty          (),
    .prog_full           (),
    .rd_data_count       (),
    .rd_rst_busy         (),
    .sbiterr             (),
    .underflow           (),
    .wr_ack              (),
    .wr_data_count       (),
    .wr_rst_busy         (),
    .din                 (bcast_resp_que_din),
    .injectdbiterr       (1'b0),
    .injectsbiterr       (1'b0),
    .rd_en               (bcast_resp_que_rd),
    .rst                 (rst),
    .sleep               (1'b0),
    .wr_clk              (clk),
    .wr_en               (bcast_resp_que_wr));

  always_comb begin
    bcast_resp_que_din = 0;
    bcast_resp_que_din.marker   = entry_que_dout.marker;
    bcast_resp_que_din.bcast    = entry_que_dout.bcast;
    bcast_resp_que_din.prio     = entry_que_dout.prio;
    bcast_resp_que_din.req_type = entry_que_dout.req_type;
    bcast_resp_que_din.bk_addr  = entry_que_dout.bk_addr;
    bcast_resp_que_din.row_addr = entry_que_dout.row_addr;
    bcast_resp_que_din.col_addr = entry_que_dout.col_addr;
  end
  assign bcast_resp_que_wr = entry_que_rd && entry_que_dout.bcast;
  assign bcast_resp_que_rd = bcast_pull;

  // =========================== Unicast Response Queues ===========================
  generate
    for (i=0; i<CH_NUM; i++) begin : ucastRespQue
      xpm_fifo_sync #(
        .DOUT_RESET_VALUE    ("0"),
        .ECC_MODE            ("no_ecc"),
        .FIFO_MEMORY_TYPE    ("block"),
        .FIFO_READ_LATENCY   (0),
        .FIFO_WRITE_DEPTH    (512),           // Max depth for 36b-wide BRAM block is 512
        .FULL_RESET_VALUE    (0),
        .PROG_EMPTY_THRESH   (5),
        .PROG_FULL_THRESH    (256),           // Each controller can hold over 256 in-flight request packets, so leaving enough space for responses if DMA stalls
        .RD_DATA_COUNT_WIDTH (),              // Must be log2(FIFO_WRITE_DEPTH)+1
        .READ_DATA_WIDTH     ($bits(pkt_t)),
        .READ_MODE           ("fwft"),
        .SIM_ASSERT_CHK      (0),
        .USE_ADV_FEATURES    ("0002"),        // USE_AD_FEATURES[1] enables programmable full threshold
        .WAKEUP_TIME         (0),
        .WR_DATA_COUNT_WIDTH (),              // Must be log2(FIFO_WRITE_DEPTH)+1
        .WRITE_DATA_WIDTH    ($bits(pkt_t)))
      ucast_resp_que (
        .almost_empty        (),
        .almost_full         (),
        .data_valid          (),
        .dbiterr             (),
        .dout                (ucast_resp_que_dout[i]),
        .empty               (ucast_resp_que_empty[i]),
        .full                (),
        .overflow            (),
        .prog_empty          (),
        .prog_full           (ucast_resp_que_pfull[i]),
        .rd_data_count       (),
        .rd_rst_busy         (),
        .sbiterr             (),
        .underflow           (),
        .wr_ack              (),
        .wr_data_count       (),
        .wr_rst_busy         (),
        .din                 (ucast_resp_que_din[i]),
        .injectdbiterr       (1'b0),
        .injectsbiterr       (1'b0),
        .rd_en               (ucast_resp_que_rd[i]),
        .rst                 (rst),
        .sleep               (1'b0),
        .wr_clk              (clk),
        .wr_en               (ucast_resp_que_wr[i]));

      assign ucast_resp_que_wr[i]  = aimc_pkt_valid[i] && !aimc_pkt[i].bcast;   // Ignoring broadcast packets at the unicast response queues
      assign ucast_resp_que_rd[i]  = (!icnt_dma_pkt_valid || dma_rdy) && (ucast_resp_que_idx == i) && !ucast_resp_que_empty[i] && !bcast_resp;  // Only pulling unicast responses when there are no broadcast responses
      assign ucast_resp_que_din[i] = aimc_pkt[i];
    end
  endgenerate

  always @(posedge clk, posedge rst)
    if (rst) ucast_resp_que_pfull_d <= 0;
    else     ucast_resp_que_pfull_d <= |ucast_resp_que_pfull;  // If at least one response queue is full, asserting the flag to block the input

  // ================================ Initialization ===============================
  initial begin
    // Exit Multiplexer
    rr_base_idx = 0;
    icnt_dma_pkt = 0;
    icnt_dma_pkt_ch_addr = 0;
    icnt_dma_pkt_valid = 0;
    ucast_resp_que_pfull_d = 0;
  end


  //debug
/*
  (* dont_touch = "true", mark_debug = "true" *) reg                      dma_rdy_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg                      dma_pkt_valid_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [CH_NUM-1:0]         dma_pkt_ch_mask_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg                      icnt_rdy_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg                      icnt_dma_pkt_valid_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [$clog2(CH_NUM)-1:0] icnt_dma_pkt_ch_addr_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [CH_NUM-1:0]         icnt_aimc_pkt_valid_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [CH_NUM-1:0]         aimc_rdy_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [CH_NUM-1:0]         aimc_pkt_valid_debug;

  (* dont_touch = "true", mark_debug = "true" *) reg entry_que_wr_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg entry_que_rd_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg entry_que_empty_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg entry_que_full_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [CH_NUM-1:0] entry_ch_que_din_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [CH_NUM-1:0] entry_ch_que_dout_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg entry_ch_que_wr_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg entry_ch_que_rd_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [$clog2(CH_NUM)-1:0] ucast_ch_addr_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [7:0] rr_req_list_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [2:0] rr_base_idx_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [2:0] ucast_resp_que_idx_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg ucast_pull_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [$clog2(CH_NUM)-1:0] icnt_pkt_ch_addr_nxt_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg bcast_add_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [CH_NUM-1:0] bcast_mask_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg bcast_pull_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg bcast_pipe_full_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [CH_NUM-1:0] aimc_bcast_resp_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg bcast_resp_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg bcast_resp_que_wr_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg bcast_resp_que_rd_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [CH_NUM-1:0] ucast_resp_que_wr_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [CH_NUM-1:0] ucast_resp_que_rd_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [CH_NUM-1:0] ucast_resp_que_empty_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [CH_NUM-1:0] ucast_resp_que_pfull_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg ucast_resp_que_pfull_d_debug;




  always @(posedge clk, posedge rst)
    if (rst) begin
      dma_rdy_debug <= 'b0;
      dma_pkt_valid_debug <= 'b0;
      dma_pkt_ch_mask_debug <= 'b0;
      icnt_rdy_debug <= 'b0;
      icnt_dma_pkt_valid_debug <= 'b0;
      icnt_dma_pkt_ch_addr_debug <= 'b0;
      icnt_aimc_pkt_valid_debug <= 'b0;
      aimc_rdy_debug <= 'b0;
      aimc_pkt_valid_debug <= 'b0;

      entry_que_wr_debug <= 'b0;
      entry_que_rd_debug <= 'b0;
      entry_que_empty_debug <= 'b0;
      entry_que_full_debug <= 'b0;
      entry_ch_que_din_debug <= 'b0;
      entry_ch_que_dout_debug <= 'b0;
      entry_ch_que_wr_debug <= 'b0;
      entry_ch_que_rd_debug <= 'b0;
      ucast_ch_addr_debug <= 'b0;
      rr_req_list_debug <= 'b0;
      rr_base_idx_debug <= 'b0;
      ucast_resp_que_idx_debug <= 'b0;
      ucast_pull_debug <= 'b0;
      icnt_pkt_ch_addr_nxt_debug <= 'b0;
      bcast_add_debug <= 'b0;
      bcast_mask_debug <= 'b0;
      bcast_pull_debug <= 'b0;
      bcast_pipe_full_debug <= 'b0;
      aimc_bcast_resp_debug <= 'b0;
      bcast_resp_debug <= 'b0;
      bcast_resp_que_wr_debug <= 'b0;
      bcast_resp_que_rd_debug <= 'b0;
      ucast_resp_que_wr_debug <= 'b0;
      ucast_resp_que_rd_debug <= 'b0;
      ucast_resp_que_empty_debug <= 'b0;
      ucast_resp_que_pfull_debug <= 'b0;
      ucast_resp_que_pfull_d_debug <= 'b0;
    end
    else begin
      dma_rdy_debug <= dma_rdy;
      dma_pkt_valid_debug <= dma_pkt_valid;
      dma_pkt_ch_mask_debug <= dma_pkt_ch_mask;
      icnt_rdy_debug <= icnt_rdy;
      icnt_dma_pkt_valid_debug <= icnt_dma_pkt_valid;
      icnt_dma_pkt_ch_addr_debug <= icnt_dma_pkt_ch_addr;
      icnt_aimc_pkt_valid_debug <= icnt_aimc_pkt_valid;
      aimc_rdy_debug <= aimc_rdy;
      aimc_pkt_valid_debug <= aimc_pkt_valid;

      entry_que_wr_debug <= entry_que_wr;
      entry_que_rd_debug <= entry_que_rd;
      entry_que_empty_debug <= entry_que_empty;
      entry_que_full_debug <= entry_que_full;
      entry_ch_que_din_debug <= entry_ch_que_din;
      entry_ch_que_dout_debug <= entry_ch_que_dout;
      entry_ch_que_wr_debug <= entry_ch_que_wr;
      entry_ch_que_rd_debug <= entry_ch_que_rd;
      ucast_ch_addr_debug <= ucast_ch_addr;
      rr_req_list_debug <= rr_req_list;
      rr_base_idx_debug <= rr_base_idx;
      ucast_resp_que_idx_debug <= ucast_resp_que_idx;
      ucast_pull_debug <= ucast_pull;
      icnt_pkt_ch_addr_nxt_debug <= icnt_pkt_ch_addr_nxt;
      bcast_add_debug <= bcast_add;
      bcast_mask_debug <= bcast_mask;
      bcast_pull_debug <= bcast_pull;
      bcast_pipe_full_debug <= bcast_pipe_full;
      aimc_bcast_resp_debug <= aimc_bcast_resp;
      bcast_resp_debug <= bcast_resp;
      bcast_resp_que_wr_debug <= bcast_resp_que_wr;
      bcast_resp_que_rd_debug <= bcast_resp_que_rd;
      ucast_resp_que_wr_debug <= ucast_resp_que_wr;
      ucast_resp_que_rd_debug <= ucast_resp_que_rd;
      ucast_resp_que_empty_debug <= ucast_resp_que_empty;
      ucast_resp_que_pfull_debug <= ucast_resp_que_pfull;
      ucast_resp_que_pfull_d_debug <= ucast_resp_que_pfull_d;
    end
*/
endmodule
