`timescale 1ps / 1ps

import aimc_lib::*;

module idel_block #(parameter LINES = 16) (    // Number of 8-bit FIFO lines from PHY, e.g. DQ0-DQ15 corresponds to 16 lines
  input  logic clk_rx_fifo,
  input  logic clk_div,
  input  logic rst_div,
  // Capture/Delay Parameters
  input  logic param_smpl_edge,
  input  logic param_sync_ordr,
  input  logic [LINES*4-1:0] param_io_in_del,
  // Byte Group Interface
  input  logic [LINES-1:0] rx_fifo_empty,
  input  logic [7:0] rx_q [LINES-1:0],
  output logic rx_fifo_rden,
  // Memory Controller Interface
  input  logic sync_en,
  output logic [7:0] phy_dout [LINES-1:0]);
  
  // =============================== Internal Signals ===============================
  `ifdef ULTRASCALE_CONFIG
  localparam DW = 4*LINES;                         // Combined data width; UltraScale+ uses 4 bits/line instead of 8 since half of the data is discarded as duplicates
  `elsif VERSAL_CONFIG
  localparam DW = 8*LINES;
  `endif
  // Input Data Signals
  logic [LINES-1:0][7:0]      rx_q_r1;             // Buffered rx_q line data (to relax timing)
  // PHY Data Synchronizer Signals
  logic                       sync_idx;            // Counter for toggling between two (upper and lower) syncronizer registers
  logic [1:0]                 sync_din_we;         // Write enable signals for syncronizer input registers
  logic [1:0][DW-1:0]         sync_din;            // Input data buffered at clk_rx_fifo domain
  logic [1:0][DW-1:0]         sync_dout;           // Syncronized output data
  // Input Sampling and Coarse Delay Signals
  logic [LINES-1:0][3:0]      param_io_in_del_r1;  // IO input delay values for each line snchronized to clk_rx_fifo domain
  logic                       param_smpl_edge_r1;  // param_smpl_edge synchronized to clk_rx_fifo domain
  logic                       param_sync_ordr_r1;  // param_sync_ordr synchronized to clk_rx_fufo domain
  logic [DW-1:0]              din_clean;           // Delayed input data with duplicate bits removed (UltraScale+)
  `ifdef ULTRASCALE_CONFIG
  logic [LINES-1:0][4:0][3:0] rx_q_pipe;           // Data pipe for implementing coarse delays
  logic [LINES-1:0][19:0]     rx_q_array;          // Data pipe concatenated into a single packed array, used for taking a 4-bit part based on the dalay value
  `elsif VERSAL_CONFIG
  logic [LINES-1:0][2:0][7:0] rx_q_pipe;
  logic [LINES-1:0][23:0]     rx_q_array;
  `endif

  // ================================ Module Outputs ================================
  always_comb begin
    for (int idx=0; idx<LINES; idx++) begin : idelOut
  `ifdef ULTRASCALE_CONFIG
      phy_dout[idx] = {sync_dout[1][4*idx+:4], sync_dout[0][4*idx+:4]};
  `elsif VERSAL_CONFIG
      phy_dout[idx] = din_clean[8*idx+:8];
  `endif
    end
  end

  // ========================= Input Sampling and Coarse Delay =======================
  // Data Capture Parameters (UltraScale+ Only)
  `ifdef ULTRASCALE_CONFIG
  xpm_cdc_single #(
    .DEST_SYNC_FF   (2),
    .INIT_SYNC_FF   (0),
    .SIM_ASSERT_CHK (0),
    .SRC_INPUT_REG  (0))
  smpl_edge_sync (
    .src_clk        (),                                             // Don't need src_clk if SRC_INPUT_REG = 0
    .dest_clk       (clk_rx_fifo),
    .src_in         (param_smpl_edge),
    .dest_out       (param_smpl_edge_r1));

  xpm_cdc_single #(
    .DEST_SYNC_FF   (2),
    .INIT_SYNC_FF   (0),
    .SIM_ASSERT_CHK (0),
    .SRC_INPUT_REG  (0))
  sync_ordr_sync (
    .src_clk        (),                                             // Don't need src_clk if SRC_INPUT_REG = 0
    .dest_clk       (clk_rx_fifo),
    .src_in         (param_sync_ordr),
    .dest_out       (param_sync_ordr_r1));
  `endif

  // Reading when data is present in all RX FIFOs
  always @(posedge clk_rx_fifo) rx_fifo_rden <= &(~rx_fifo_empty);
  
  // Coarse Delay Implementation
  genvar l, i;
  generate
    for (l=0; l<LINES; l++) begin : lineFamily
      xpm_cdc_array_single #(                                       // With this syncronizer, PHY will return "garbage" during parameter transition period, but it should't hurt the operation
        .DEST_SYNC_FF   (2),
        .INIT_SYNC_FF   (0),
        .SIM_ASSERT_CHK (0),
        .SRC_INPUT_REG  (0),
        .WIDTH          (4))
      io_in_del_sync (
        .src_clk        (),                                         // Don't need src_clk if SRC_INPUT_REG = 0
        .dest_clk       (clk_rx_fifo),
        .src_in         (param_io_in_del[l*4+:4]),
        .dest_out       (param_io_in_del_r1[l]));

      always @(posedge clk_rx_fifo) rx_q_r1[l] <= rx_q[l];           // Buffering input data
      
  `ifdef ULTRASCALE_CONFIG
      // Inputs to the data delay pipe
      assign rx_q_pipe[l][0][0] = rx_q_r1[l][0+param_smpl_edge_r1];  // "Cleaning" the data by discarding the duplicates; depending on the sampling delay, either early or late bits are discarded
      assign rx_q_pipe[l][0][1] = rx_q_r1[l][2+param_smpl_edge_r1];
      assign rx_q_pipe[l][0][2] = rx_q_r1[l][4+param_smpl_edge_r1];
      assign rx_q_pipe[l][0][3] = rx_q_r1[l][6+param_smpl_edge_r1];
      // Data delay pipe
      for (i=1; i<5; i++) begin : rxPipe
        always @(posedge clk_rx_fifo) rx_q_pipe[l][i] <= rx_q_pipe[l][i-1];
      end
      for (i=0; i<5; i++) assign rx_q_array[l][i*4+:4] = rx_q_pipe[l][4-i];
      // Selecting data from pipe
      always @(posedge clk_rx_fifo)
        if (rx_fifo_rden && sync_en) din_clean[l*4+:4] <= rx_q_array[l][(16-param_io_in_del_r1[l])+:4];
      initial din_clean = '0;
      // assign din_clean[l*4+:4] = rx_q_array[l][(16-param_io_in_del_r1[l])+:4];

  `elsif VERSAL_CONFIG
      // Inputs to the data delay pipe
      assign rx_q_pipe[l][0] = {<<{rx_q_r1[l]}};  // Data in Versal RX FIFO is stored in the opposite order from UltraScale+, so need to reverse bits
      // Data delay pipe
      for (i=1; i<3; i++) begin : rxPipe
        always @(posedge clk_rx_fifo) rx_q_pipe[l][i] <= rx_q_pipe[l][i-1];
      end
      for (i=0; i<3; i++) assign rx_q_array[l][i*8+:8] = rx_q_pipe[l][2-i];
      // Selecting data from pipe
      always @(posedge clk_rx_fifo)
        if (rx_fifo_rden) din_clean[l*8+:8] <= rx_q_array[l][(16-param_io_in_del_r1[l])+:8];
      initial din_clean = '0;
  `endif
    end
  endgenerate

  // ============================ PHY Data Synchronizers ============================
  `ifdef ULTRASCALE_CONFIG
  // Toggling between two synchronizers to fill each with half of data at twice the system clock speed
  always @(posedge clk_rx_fifo)
    if (!rx_fifo_rden || !sync_en) sync_idx <= 1;
    else                           sync_idx <= ~sync_idx;

  assign sync_din_we[1] = rx_fifo_rden && sync_en && (sync_idx == param_sync_ordr_r1);   // "param_sync_ordr" parameter defines which sync register is filled "first"
  assign sync_din_we[0] = rx_fifo_rden && sync_en && (sync_idx == !param_sync_ordr_r1);

  always @(posedge clk_rx_fifo)
    if      (sync_din_we[0]) sync_din[0] <= din_clean; 
    else if (sync_din_we[1]) sync_din[1] <= din_clean;

  // Crossing to the system clock
  sync #(
    .SYNC_FF  (2),
    .WIDTH    (DW))
  phy_sync_lower (
    .dest_clk (clk_div),
    .din      (sync_din[0]),
    .dout     (sync_dout[0]));

  sync #(
    .SYNC_FF  (2),
    .WIDTH    (DW))
  phy_sync_upper (
    .dest_clk (clk_div),
    .din      (sync_din[1]),
    .dout     (sync_dout[1]));
  `endif

  // No need to syncrhonize data in Versal, since RX_FIFO is operating at the system clock speed (SERIAL_MODE="FALSE")

  // ================================ Initialization ================================
  initial begin
    sync_din     = '0;
    rx_fifo_rden = '0;
    sync_idx     = '0;
    rx_q_r1      = '0;
    rx_q_pipe    = '0;
  end
endmodule
