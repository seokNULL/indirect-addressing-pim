`timescale 1ps / 1ps

module xiphy_vck190 #(parameter CH_IDX=0) (
  input  logic        clk_pll,
  input  logic        clk_div,
  input  logic        rst_div,
  input  logic        clk_riu,
  input  logic        rst_riu,
  input  logic        clk_rx_fifo,
  // Command Input Int   erface
  input  logic [7:0]  intf_ck_t,
  input  logic [7:0]  intf_ca [9:0],
  input  logic [7:0]  intf_cabi_n,
  input  logic [7:0]  intf_wck_t,
  // Data Handler Interface
  input  logic        tbyte_in,
  input  logic        tx_t,
  input  logic [7:0]  intf_dq    [15:0],
  input  logic [7:0]  intf_dbi_n [1:0],
  input  logic [7:0]  init_edc   [1:0],
  input  logic [7:0]  top_cke_n,
  output logic [7:0]  phy_dq     [15:0],
  output logic [7:0]  phy_dbi_n  [1:0],
  output logic [7:0]  phy_edc    [1:0],
  // Calibration Interface
  output logic        phy_rdy,
  input  logic        init_done,
  input  logic        param_smpl_edge,
  input  logic        param_sync_ordr,
  input  logic [71:0] param_io_in_del,
  input  logic [63:0] param_io_out_del,
  // MicroBlaze Interface
  input  logic [7:0]  riu_addr,
  input  logic [15:0] riu_wr_data,
  output logic [15:0] riu_rd_data [8:0],
  output logic [8:0]  riu_valid,
  input  logic        riu_wr_en,
  input  logic [8:0]  riu_nibble_sel,
  // GDDR6 Interface
  output logic        CK_t, CK_c,
  output logic [9:0]  CA,
  output logic        CKE_n,
  output logic        CABI_n,
  output logic        WCK1_t, WCK1_c,
  output logic        WCK0_t, WCK0_c,
  inout  tri   [15:0] DQ,
  inout  tri   [1:0]  EDC);
  
  // ============================= Internal Variables ============================
  /*
  Mapping verified on 2022.03.22

  CHANNEL 2 (CHANNEL A on FMC2, BANK 708)
  NIBBLE8 : X      X      DQ0    DQ2    X      X
  NIBBLE7 : X      X      X      X      X      X
  NIBBLE6 : X      X      X      X      X      X
  NIBBLE5 : CA9    CA0    DQ15   DQ14   CK_c   CK_t
  NIBBLE4 : CA4    CA2    CKE_n  CABI_n X      X
  NIBBLE3 : CA7    CA5    DQ13   DQ11   WCK0_c WCK0_t
  NIBBLE2 : CA1    CA8    EDC0   EDC1   WCK1_c WCK1_t
  NIBBLE1 : DQ4    DQ5    DQ12   DQ10   DQ7    DQ6
  NIBBLE0 : DQ1    DQ3    CA6    CA3    DQ9    DQ8

  CHANNEL 1 (CHANNEL B on FMC1, BANK 707)
  NIBBLE8 : X      X      X      X      X      X
  NIBBLE7 : X      X      X      X      X      X
  NIBBLE6 : X      X      X      X      X      X
  NIBBLE5 : CA2    CA4    EDC1   EDC0   CKE_n  CABI_n
  NIBBLE4 : CA0    CA8    CA5    CA3    X      X
  NIBBLE3 : CA9    CA1    DQ0    DQ3    WCK1_c WCK1_t
  NIBBLE2 : DQ14   DQ15   DQ12   DQ13   WCK0_c WCK0_t
  NIBBLE1 : CA7    CA6    DQ9    DQ10   DQ2    DQ5
  NIBBLE0 : DQ1    DQ4    DQ6    DQ7    DQ11   DQ8

  CHANNEL 0 (CHANNEL A on FMC1, BANK 706)
  NIBBLE8 : X      X      X      X      X      X
  NIBBLE7 : X      X      X      X      X      X
  NIBBLE6 : X      X      X      X      X      X
  NIBBLE5 : DQ9    DQ8    DQ12   DQ10   DQ7    DQ6
  NIBBLE4 : DQ1    DQ3    CA6    CA3    WCK1_c WCK1_t
  NIBBLE3 : DQ4    DQ5    CA4    CA2    CK_c   CK_t
  NIBBLE2 : CA9    CA0    CA7    CA5    WCK0_c WCK0_t
  NIBBLE1 : DQ0    DQ2    EDC0   EDC1   DQ13   DQ11
  NIBBLE0 : DQ15   DQ14   CKE_n  CABI_n CA1    CA8
  */

  // XPHY Nibble Configuration
  localparam [8:0] XPHY_NIBBLE_EN [2:0]          = '{/*XPIO 708*/ 9'b101111111, /*XPIO 707*/ 9'b000111111, /*XPIO 706*/ 9'b000111111};

  localparam [8:0][5:0] TBYTE_CTL [2:0]          = '{{6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b110011, 6'b111111, 6'b111111},   // XPIO 708 (CH2)
                                                     {6'b111111, 6'b111111, 6'b111111, 6'b110011, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111},   // XPIO 707 (CH1)
                                                     {6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b110011, 6'b111111}};  // XPIO 706 (CH0)

  localparam [8:0][5:0] TXRX_LOOPBACK [2:0]      = '{{6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000001, 6'b000000, 6'b000000},   // XPIO 708 (CH2)
                                                     {6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000001, 6'b000000, 6'b000000},   // XPIO 707 (CH1)
                                                     {6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000001, 6'b000000, 6'b000000}};  // XPIO 706 (CH0)

  localparam [8:0] EN_CLK_TO_UPPER [2:0]         = '{/*XPIO 708*/ 9'b000010100, /*XPIO 707*/ 9'b000000100, /*XPIO 706*/ 9'b000000100};
  localparam [8:0] EN_CLK_TO_LOWER [2:0]         = '{/*XPIO 708*/ 9'b001000100, /*XPIO 707*/ 9'b000000100, /*XPIO 706*/ 9'b000000100};
  localparam [8:0] EN_OTHER_CLK    [2:0]         = '{/*XPIO 708*/ 9'b000101010, /*XPIO 707*/ 9'b000101010, /*XPIO 706*/ 9'b000101010};

  localparam [8:0][5:0] TX_INIT [2:0]            = '{{6'b000000, 6'b000000, 6'b000000, 6'b110001, 6'b111101, 6'b110001, 6'b110001, 6'b000000, 6'b001100},   // XPIO 708 (CH2)
                                                     {6'b000000, 6'b000000, 6'b000000, 6'b110011, 6'b111100, 6'b110001, 6'b000001, 6'b110000, 6'b000000},   // XPIO 707 (CH1)
                                                     {6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b001101, 6'b001101, 6'b111101, 6'b000000, 6'b001111}};  // XPIO 706 (CH0)

  // localparam [8:0][5:0] TX_OUTPUT_PHASE_90 [2:0] = '{{6'b000000, 6'b000000, 6'b000000, 6'b110011, 6'b111111, 6'b110011, 6'b110011, 6'b000000, 6'b001100},   // XPIO 708 (CH2)
  //                                                    {6'b000000, 6'b000000, 6'b000000, 6'b110011, 6'b111100, 6'b110011, 6'b000011, 6'b110000, 6'b000000},   // XPIO 707 (CH1)
  //                                                    {6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b001111, 6'b001111, 6'b111111, 6'b001100, 6'b000011}};  // XPIO 706 (CH0)

  // IOB Configuration (0:unused, 1:single-ended out, 2:single-ended in, 3: single-ended io, 4:unused, 5:diff out, 6:diff in, 7:diff io)
  localparam [8:0][5:0][2:0] IOBTYPE [2:0] = '{ // XPIO 708 (CH2)
                                               {{3'd0, 3'd0, 3'd3, 3'd3, 3'd0, 3'd0}, {3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0}, {3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0},
                                                {3'd1, 3'd1, 3'd3, 3'd3, 3'd0, 3'd5}, {3'd1, 3'd1, 3'd1, 3'd1, 3'd0, 3'd0}, {3'd1, 3'd1, 3'd3, 3'd3, 3'd0, 3'd5},
                                                {3'd1, 3'd1, 3'd3, 3'd3, 3'd0, 3'd5}, {3'd3, 3'd3, 3'd3, 3'd3, 3'd3, 3'd3}, {3'd3, 3'd3, 3'd1, 3'd1, 3'd3, 3'd3}},
                                                // XPIO 707 (CH1)
                                               {{3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0}, {3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0}, {3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0},
                                                {3'd1, 3'd1, 3'd3, 3'd3, 3'd1, 3'd1}, {3'd1, 3'd1, 3'd1, 3'd1, 3'd0, 3'd0}, {3'd1, 3'd1, 3'd3, 3'd3, 3'd0, 3'd5},
                                                {3'd3, 3'd3, 3'd3, 3'd3, 3'd0, 3'd5}, {3'd1, 3'd1, 3'd3, 3'd3, 3'd3, 3'd3}, {3'd3, 3'd3, 3'd3, 3'd3, 3'd3, 3'd3}},
                                                // XPIO 706 (CH0)
                                               {{3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0}, {3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0}, {3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0},
                                                {3'd3, 3'd3, 3'd3, 3'd3, 3'd3, 3'd3}, {3'd3, 3'd3, 3'd1, 3'd1, 3'd0, 3'd5}, {3'd3, 3'd3, 3'd1, 3'd1, 3'd0, 3'd5},
                                                {3'd1, 3'd1, 3'd1, 3'd1, 3'd0, 3'd5}, {3'd3, 3'd3, 3'd3, 3'd3, 3'd3, 3'd3}, {3'd3, 3'd3, 3'd1, 3'd1, 3'd1, 3'd1}}};

  localparam [8:0] USE_VREF [2:0]          = '{/*XPIO 708*/ 9'b100101111, /*XPIO 707*/ 9'b000101111, /*XPIO 706*/ 9'b000111011};
            
  // User Logic Interface
  logic [8:0] rx_fifo_rden;        // Read Enable for RX FIFO (one per 6 nibble slices in Versal)
  logic [8:0][5:0][7:0] rx_q_tmp;  // Deserialized RX output data (to PL)
  logic [8:0][5:0][7:0] rx_q;      // rx_q reordered to restore the original captured data sequence (only required in Versal)
  logic [8:0][5:0][7:0] tx_d;      // Parallel TX input data
  logic [8:0] rx_fifo_wrclk;       // Clock used for writing and reading RX FIFO
  logic [8:0] rx_fifo_empty;       // RX FIFO empty flags (one per 6 nibble slices in Versal)
  logic [8:0][5:0][7:0] rx_dout;   // Deserialized RX output data (to PL)
  logic rx_fifo_rdclk;             // Clock used for reading RX FIFO queues
  // IOB Interface
  logic [8:0][5:0] ob_pin;         // Output pin bus (later distributed among output pins)      
  tri   [63:0] nc;                 // Dummy variable for unconnected tri-state pins
  logic [8:0][5:0] dyn_dci;        // Dynamic DCI control from XPHY
  logic [8:0][5:0] ibuf_disable;   // IBUF control from XPHY
  logic [8:0][5:0] rx_d;           // Serial RX input data
  logic [8:0][5:0] tx_o;           // Serialized TX output data (to DRAM)
  logic [8:0][5:0] tx_t_out;       // IOB tristate control
  wire  [8:0][5:0] iob_pin;        // IOB pins
  // XPHY Clock and Reset Signals
  logic [8:0] clk_to_lower;
  logic [8:0] clk_to_upper;
  logic [8:0] pclk_nibble_out;
  logic [8:0] nclk_nibble_out;
  logic [8:0] pclk_nibble_in;
  logic [8:0] nclk_nibble_in;
  logic [8:0] clk_from_other_xphy;
  logic [8:0][5:0] rxtx_rst;
  // XPHY Control and Status Signals
  logic en_vtc_r1, en_vtc_r2;
  logic [8:0] vtc_rdy_r0;
  logic vtc_rdy_r1, vtc_rdy_r2;
  logic [8:0] dly_rdy;
  logic [8:0] vtc_rdy;
  // Simulation-only signals for BISC
  logic [8:0] bisc_start_in;
  logic [8:0] bisc_start_out;
  logic [8:0] bisc_stop_in;
  logic [8:0] bisc_stop_out;
  // RX Delay Signals
  logic [7:0] edc_rx_q [1:0];      // Data from EDC RX FIFO
  logic edc_rx_fifo_rden;          // FIFO read trigger applied to EDC RX FIFO
  logic [7:0]  dq_rx_q [15:0];     // Data from DQ RX FIFO
  logic dq_rx_fifo_rden;           // FIFO read trigger applied to DQ RX FIFO
  logic [16*4-1:0] param_io_in_del_dq;
  logic [2*4-1:0]  param_io_in_del_edc;
  // TX Delay Signals
  logic [7:0] intf_ck_t_d;
  logic [7:0] intf_ca_d [9:0];
  logic [7:0] intf_cabi_n_d;
  logic [7:0] intf_wck_t_d;
  logic tbyte_in_d;
  logic tx_t_d;
  logic [7:0] intf_dq_d [15:0];
  logic [7:0] intf_dbi_n_d [1:0];
  logic [7:0] init_edc_d [1:0];
  logic [7:0] top_cke_n_d;

  // ============================ VTC Initialization =============================
  // Synchronization to RIU clock domain (DLY_RDY is async, but EN_VTC is in RIU_CLK domain)
  always @(posedge clk_riu, posedge rst_riu) begin
    if (rst_riu) begin
      en_vtc_r1 <= 1'b0;
      en_vtc_r2 <= 1'b0;
    end
    else begin
      en_vtc_r1 <= &dly_rdy;
      en_vtc_r2 <= en_vtc_r1;
    end
  end

  // Synchronization to DIV clock domain (VTC_RDY is async)
  always @(posedge clk_div, posedge rst_div) begin
    if (rst_div) begin
      vtc_rdy_r0 <= 1'b0;
      vtc_rdy_r1 <= 1'b0;
      vtc_rdy_r2 <= 1'b0;
    end
    else begin
      vtc_rdy_r0 <= vtc_rdy;
      vtc_rdy_r1 <= &vtc_rdy_r0;
      vtc_rdy_r2 <= vtc_rdy_r1;
    end
  end

  assign phy_rdy = vtc_rdy_r2;

  initial begin
    en_vtc_r1  = 1'b0;
    en_vtc_r2  = 1'b0;
    vtc_rdy_r1 = 1'b0;
    vtc_rdy_r2 = 1'b0;
  end

  // ============================== XPHY TX Inputs ===============================
  generate
    if (CH_IDX == 2) begin  // XPIO 708
      // Inputs to Nibble Slice 8
      assign tx_d[8][5] = 1'b0;
      assign tx_d[8][4] = 1'b0;
      assign tx_d[8][3] = intf_dq_d[0];
      assign tx_d[8][2] = intf_dq_d[2];
      assign tx_d[8][1] = 1'b0;
      assign tx_d[8][0] = 1'b0;
      // Inputs to Nibble Slice 7
      assign tx_d[7][5] = 1'b0;
      assign tx_d[7][4] = 1'b0;
      assign tx_d[7][3] = 1'b0;
      assign tx_d[7][2] = 1'b0;
      assign tx_d[7][1] = 1'b0;
      assign tx_d[7][0] = 1'b0;
      // Inputs to Nibble Slice 6
      assign tx_d[6][5] = 1'b0;
      assign tx_d[6][4] = 1'b0;
      assign tx_d[6][3] = 1'b0;
      assign tx_d[6][2] = 1'b0;
      assign tx_d[6][1] = 1'b0;
      assign tx_d[6][0] = 1'b0;
      // Inputs to Nibble Slice 5
      assign tx_d[5][5] = intf_ca_d[9];
      assign tx_d[5][4] = intf_ca_d[0];
      assign tx_d[5][3] = intf_dq_d[15];
      assign tx_d[5][2] = intf_dq_d[14];
      assign tx_d[5][1] = 1'b0;
      assign tx_d[5][0] = intf_ck_t_d;
      // Inputs to Nibble Slice 4
      assign tx_d[4][5] = intf_ca_d[4];
      assign tx_d[4][4] = intf_ca_d[2];
      assign tx_d[4][3] = {8{top_cke_n_d[0]}};
      assign tx_d[4][2] = intf_cabi_n_d;
      assign tx_d[4][1] = 1'b0;
      assign tx_d[4][0] = 1'b0;
      // Inputs to Nibble Slice 3
      assign tx_d[3][5] = intf_ca_d[7];
      assign tx_d[3][4] = intf_ca_d[5];
      assign tx_d[3][3] = intf_dq_d[13];
      assign tx_d[3][2] = intf_dq_d[11];
      assign tx_d[3][1] = 1'b0;
      assign tx_d[3][0] = intf_wck_t_d;
      // Inputs to Nibble Slice 2
      assign tx_d[2][5] = intf_ca_d[1];
      assign tx_d[2][4] = intf_ca_d[8];
      assign tx_d[2][3] = init_edc_d[0];
      assign tx_d[2][2] = init_edc_d[1];
      assign tx_d[2][1] = 1'b0;
      assign tx_d[2][0] = intf_wck_t_d;
      // Inputs to Nibble Slice 1
      assign tx_d[1][5] = intf_dq_d[4];
      assign tx_d[1][4] = intf_dq_d[5];
      assign tx_d[1][3] = intf_dq_d[12];
      assign tx_d[1][2] = intf_dq_d[10];
      assign tx_d[1][1] = intf_dq_d[7];
      assign tx_d[1][0] = intf_dq_d[6];
      // Inputs to Nibble Slice 0
      assign tx_d[0][5] = intf_dq_d[1];
      assign tx_d[0][4] = intf_dq_d[3];
      assign tx_d[0][3] = intf_ca_d[6];
      assign tx_d[0][2] = intf_ca_d[3];
      assign tx_d[0][1] = intf_dq_d[9];
      assign tx_d[0][0] = intf_dq_d[8];
    end
    else if (CH_IDX == 1) begin  // XPIO 707
      // Inputs to Nibble Slice 8
      assign tx_d[8][5] = 1'b0;
      assign tx_d[8][4] = 1'b0;
      assign tx_d[8][3] = 1'b0;
      assign tx_d[8][2] = 1'b0;
      assign tx_d[8][1] = 1'b0;
      assign tx_d[8][0] = 1'b0;
      // Inputs to Nibble Slice 7
      assign tx_d[7][5] = 1'b0;
      assign tx_d[7][4] = 1'b0;
      assign tx_d[7][3] = 1'b0;
      assign tx_d[7][2] = 1'b0;
      assign tx_d[7][1] = 1'b0;
      assign tx_d[7][0] = 1'b0;
      // Inputs to Nibble Slice 6
      assign tx_d[6][5] = 1'b0;
      assign tx_d[6][4] = 1'b0;
      assign tx_d[6][3] = 1'b0;
      assign tx_d[6][2] = 1'b0;
      assign tx_d[6][1] = 1'b0;
      assign tx_d[6][0] = 1'b0;
      // Inputs to Nibble Slice 5
      assign tx_d[5][5] = intf_ca_d[2];
      assign tx_d[5][4] = intf_ca_d[4];
      assign tx_d[5][3] = init_edc_d[1];
      assign tx_d[5][2] = init_edc_d[0];
      assign tx_d[5][1] = {8{top_cke_n_d[0]}};
      assign tx_d[5][0] = intf_cabi_n_d;
      // Inputs to Nibble Slice 4
      assign tx_d[4][5] = intf_ca_d[0];
      assign tx_d[4][4] = intf_ca_d[8];
      assign tx_d[4][3] = intf_ca_d[5];
      assign tx_d[4][2] = intf_ca_d[3];
      assign tx_d[4][1] = 1'b0;
      assign tx_d[4][0] = 1'b0;
      // Inputs to Nibble Slice 3
      assign tx_d[3][5] = intf_ca_d[9];
      assign tx_d[3][4] = intf_ca_d[1];
      assign tx_d[3][3] = intf_dq_d[0];
      assign tx_d[3][2] = intf_dq_d[3];
      assign tx_d[3][1] = 1'b0;
      assign tx_d[3][0] = intf_wck_t_d;
      // Inputs to Nibble Slice 2
      assign tx_d[2][5] = intf_dq_d[14];
      assign tx_d[2][4] = intf_dq_d[15];
      assign tx_d[2][3] = intf_dq_d[12];
      assign tx_d[2][2] = intf_dq_d[13];
      assign tx_d[2][1] = 1'b0;
      assign tx_d[2][0] = intf_wck_t_d;
      // Inputs to Nibble Slice 1
      assign tx_d[1][5] = intf_ca_d[7];
      assign tx_d[1][4] = intf_ca_d[6];
      assign tx_d[1][3] = intf_dq_d[9];
      assign tx_d[1][2] = intf_dq_d[10];
      assign tx_d[1][1] = intf_dq_d[2];
      assign tx_d[1][0] = intf_dq_d[5];
      // Inputs to Nibble Slice 0
      assign tx_d[0][5] = intf_dq_d[1];
      assign tx_d[0][4] = intf_dq_d[4];
      assign tx_d[0][3] = intf_dq_d[6];
      assign tx_d[0][2] = intf_dq_d[7];
      assign tx_d[0][1] = intf_dq_d[11];
      assign tx_d[0][0] = intf_dq_d[8];
    end
    else if (CH_IDX == 0) begin  // XPIO 706
      // Inputs to Nibble Slice 8
      assign tx_d[8][5] = 1'b0;
      assign tx_d[8][4] = 1'b0;
      assign tx_d[8][3] = 1'b0;
      assign tx_d[8][2] = 1'b0;
      assign tx_d[8][1] = 1'b0;
      assign tx_d[8][0] = 1'b0;
      // Inputs to Nibble Slice 7
      assign tx_d[7][5] = 1'b0;
      assign tx_d[7][4] = 1'b0;
      assign tx_d[7][3] = 1'b0;
      assign tx_d[7][2] = 1'b0;
      assign tx_d[7][1] = 1'b0;
      assign tx_d[7][0] = 1'b0;
      // Inputs to Nibble Slice 6
      assign tx_d[6][5] = 1'b0;
      assign tx_d[6][4] = 1'b0;
      assign tx_d[6][3] = 1'b0;
      assign tx_d[6][2] = 1'b0;
      assign tx_d[6][1] = 1'b0;
      assign tx_d[6][0] = 1'b0;
      // Inputs to Nibble Slice 5
      assign tx_d[5][5] = intf_dq_d[9];
      assign tx_d[5][4] = intf_dq_d[8];
      assign tx_d[5][3] = intf_dq_d[12];
      assign tx_d[5][2] = intf_dq_d[10];
      assign tx_d[5][1] = intf_dq_d[7];
      assign tx_d[5][0] = intf_dq_d[6];
      // Inputs to Nibble Slice 4
      assign tx_d[4][5] = intf_dq_d[1];
      assign tx_d[4][4] = intf_dq_d[3];
      assign tx_d[4][3] = intf_ca_d[6];
      assign tx_d[4][2] = intf_ca_d[3];
      assign tx_d[4][1] = 1'b0;
      assign tx_d[4][0] = intf_wck_t_d;
      // Inputs to Nibble Slice 3
      assign tx_d[3][5] = intf_dq_d[4];
      assign tx_d[3][4] = intf_dq_d[5];
      assign tx_d[3][3] = intf_ca_d[4];
      assign tx_d[3][2] = intf_ca_d[2];
      assign tx_d[3][1] = 1'b0;
      assign tx_d[3][0] = intf_ck_t_d;
      // Inputs to Nibble Slice 2
      assign tx_d[2][5] = intf_ca_d[9];
      assign tx_d[2][4] = intf_ca_d[0];
      assign tx_d[2][3] = intf_ca_d[7];
      assign tx_d[2][2] = intf_ca_d[5];
      assign tx_d[2][1] = 1'b0;
      assign tx_d[2][0] = intf_wck_t_d;
      // Inputs to Nibble Slice 1
      assign tx_d[1][5] = intf_dq_d[0];
      assign tx_d[1][4] = intf_dq_d[2];
      assign tx_d[1][3] = init_edc_d[0];
      assign tx_d[1][2] = init_edc_d[1];
      assign tx_d[1][1] = intf_dq_d[13];
      assign tx_d[1][0] = intf_dq_d[11];
      // Inputs to Nibble Slice 0
      assign tx_d[0][5] = intf_dq_d[15];
      assign tx_d[0][4] = intf_dq_d[14];
      assign tx_d[0][3] = {8{top_cke_n_d[0]}};
      assign tx_d[0][2] = intf_cabi_n_d;
      assign tx_d[0][1] = intf_ca_d[1];
      assign tx_d[0][0] = intf_ca_d[8];
    end
  endgenerate

  // ============================ IO Buffer Outputs ==============================
  generate
    if (CH_IDX == 2) begin  // XPIO 708
      assign CK_c   = ob_pin[5][1];
      assign CK_t   = ob_pin[5][0];
      assign CA[9]  = ob_pin[5][5];
      assign CA[8]  = ob_pin[2][4];
      assign CA[7]  = ob_pin[3][5];
      assign CA[6]  = ob_pin[0][3];
      assign CA[5]  = ob_pin[3][4];
      assign CA[4]  = ob_pin[4][5];
      assign CA[3]  = ob_pin[0][2];
      assign CA[2]  = ob_pin[4][4];
      assign CA[1]  = ob_pin[2][5];
      assign CA[0]  = ob_pin[5][4];
      assign CKE_n  = ob_pin[4][3];
      assign CABI_n = ob_pin[4][2];
      assign WCK1_c = ob_pin[2][1];
      assign WCK1_t = ob_pin[2][0];
      assign WCK0_c = ob_pin[3][1];
      assign WCK0_t = ob_pin[3][0];
    end
    else if (CH_IDX == 1) begin  // XPIO 707
      assign CK_c   = 1'b0;
      assign CK_t   = 1'b0;
      assign CA[9]  = ob_pin[3][5];
      assign CA[8]  = ob_pin[4][4];
      assign CA[7]  = ob_pin[1][5];
      assign CA[6]  = ob_pin[1][4];
      assign CA[5]  = ob_pin[4][3];
      assign CA[4]  = ob_pin[5][4];
      assign CA[3]  = ob_pin[4][2];
      assign CA[2]  = ob_pin[5][5];
      assign CA[1]  = ob_pin[3][4];
      assign CA[0]  = ob_pin[4][5];
      assign CKE_n  = ob_pin[5][1];
      assign CABI_n = ob_pin[5][0];
      assign WCK1_c = ob_pin[3][1];
      assign WCK1_t = ob_pin[3][0];
      assign WCK0_c = ob_pin[2][1];
      assign WCK0_t = ob_pin[2][0];
    end
    else if (CH_IDX == 0) begin  // XPIO 706
      assign CK_c   = ob_pin[3][1];
      assign CK_t   = ob_pin[3][0];
      assign CA[9]  = ob_pin[2][5];
      assign CA[8]  = ob_pin[0][0];
      assign CA[7]  = ob_pin[2][3];
      assign CA[6]  = ob_pin[4][3];
      assign CA[5]  = ob_pin[2][2];
      assign CA[4]  = ob_pin[3][3];
      assign CA[3]  = ob_pin[4][2];
      assign CA[2]  = ob_pin[3][2];
      assign CA[1]  = ob_pin[0][1];
      assign CA[0]  = ob_pin[2][4];
      assign CKE_n  = ob_pin[0][3];
      assign CABI_n = ob_pin[0][2];
      assign WCK1_c = ob_pin[4][1];
      assign WCK1_t = ob_pin[4][0];
      assign WCK0_c = ob_pin[2][1];
      assign WCK0_t = ob_pin[2][0];
    end
  endgenerate

  // ============================== XPHY RX Outputs ==============================
  always @(posedge rx_fifo_rdclk) rx_fifo_rden <= ~rx_fifo_empty;

  always_comb begin                        // Reordering deserialized data bits to restore the original input data order (see Versal SelectIO documentation for more info)
    for (int x=0; x<9; x++) begin
      for (int y=0; y<6; y++) begin
        rx_q[x][y][7:0] = {rx_q_tmp[x][y][4], rx_q_tmp[x][y][0], rx_q_tmp[x][y][5], rx_q_tmp[x][y][1], rx_q_tmp[x][y][6], rx_q_tmp[x][y][2], rx_q_tmp[x][y][7], rx_q_tmp[x][y][3]};
      end
    end
  end

  generate
    if (CH_IDX == 2) begin
      // EDC Signals
      assign edc_rx_q[1] = rx_q[2][2];
      assign edc_rx_q[0] = rx_q[2][3];
      // DQ Signals
      assign dq_rx_q[15] = rx_q[5][3];
      assign dq_rx_q[14] = rx_q[5][2];
      assign dq_rx_q[13] = rx_q[3][3];
      assign dq_rx_q[12] = rx_q[1][3];
      assign dq_rx_q[11] = rx_q[3][2];
      assign dq_rx_q[10] = rx_q[1][2];
      assign dq_rx_q[9]  = rx_q[0][1];
      assign dq_rx_q[8]  = rx_q[0][0];
      assign dq_rx_q[7]  = rx_q[1][1];
      assign dq_rx_q[6]  = rx_q[1][0];
      assign dq_rx_q[5]  = rx_q[1][4];
      assign dq_rx_q[4]  = rx_q[1][5];
      assign dq_rx_q[3]  = rx_q[0][4];
      assign dq_rx_q[2]  = rx_q[8][2];
      assign dq_rx_q[1]  = rx_q[0][5];
      assign dq_rx_q[0]  = rx_q[8][3];
    end
    else if (CH_IDX == 1) begin
      // EDC Signals
      assign edc_rx_q[1] = rx_q[5][3];
      assign edc_rx_q[0] = rx_q[5][2];
      // DQ Signals
      assign dq_rx_q[15] = rx_q[2][4];
      assign dq_rx_q[14] = rx_q[2][5];
      assign dq_rx_q[13] = rx_q[2][2];
      assign dq_rx_q[12] = rx_q[2][3];
      assign dq_rx_q[11] = rx_q[0][1];
      assign dq_rx_q[10] = rx_q[1][2];
      assign dq_rx_q[9]  = rx_q[1][3];
      assign dq_rx_q[8]  = rx_q[0][0];
      assign dq_rx_q[7]  = rx_q[0][2];
      assign dq_rx_q[6]  = rx_q[0][3];
      assign dq_rx_q[5]  = rx_q[1][0];
      assign dq_rx_q[4]  = rx_q[0][4];
      assign dq_rx_q[3]  = rx_q[3][2];
      assign dq_rx_q[2]  = rx_q[1][1];
      assign dq_rx_q[1]  = rx_q[0][5];
      assign dq_rx_q[0]  = rx_q[3][3];
    end
    else if (CH_IDX == 0) begin
      // EDC Signals
      assign edc_rx_q[1] = rx_q[1][2];
      assign edc_rx_q[0] = rx_q[1][3];
      // DQ Signals
      assign dq_rx_q[15] = rx_q[0][5];
      assign dq_rx_q[14] = rx_q[0][4];
      assign dq_rx_q[13] = rx_q[1][1];
      assign dq_rx_q[12] = rx_q[5][3];
      assign dq_rx_q[11] = rx_q[1][0];
      assign dq_rx_q[10] = rx_q[5][2];
      assign dq_rx_q[9]  = rx_q[5][5];
      assign dq_rx_q[8]  = rx_q[5][4];
      assign dq_rx_q[7]  = rx_q[5][1];
      assign dq_rx_q[6]  = rx_q[5][0];
      assign dq_rx_q[5]  = rx_q[3][4];
      assign dq_rx_q[4]  = rx_q[3][5];
      assign dq_rx_q[3]  = rx_q[4][4];
      assign dq_rx_q[2]  = rx_q[1][4];
      assign dq_rx_q[1]  = rx_q[4][5];
      assign dq_rx_q[0]  = rx_q[1][5];
    end
  endgenerate

  // ================================ XPHY Nibbles ===============================
  // RX FIFO Clocking
  assign rx_fifo_rdclk = clk_div;  // In Versal, using system clock to read-out data from RX FIFOs

  // Inter-Byte Clocking
  always_comb begin
    clk_from_other_xphy = 9'b000000000;
    clk_from_other_xphy[0] = clk_to_lower[2];
    clk_from_other_xphy[2] = 1'b1;
    clk_from_other_xphy[4] = clk_to_upper[2];
    clk_from_other_xphy[6] = clk_to_upper[4];
    clk_from_other_xphy[8] = clk_to_lower[6];
  end

  // Inter-Nibble Clocking
  always_comb begin
    pclk_nibble_in = 9'b000000000;
    nclk_nibble_in = 9'b111111111;
    pclk_nibble_in[1] = pclk_nibble_out[0];
    nclk_nibble_in[1] = nclk_nibble_out[0];
    pclk_nibble_in[3] = pclk_nibble_out[2];
    nclk_nibble_in[3] = nclk_nibble_out[2];
    pclk_nibble_in[5] = pclk_nibble_out[4];
    nclk_nibble_in[5] = nclk_nibble_out[4];
    // pclk_nibble_in[7] = pclk_nibble_out[6];
    // nclk_nibble_in[7] = nclk_nibble_out[6];
  end

  // BISC Simulation
  always_comb begin
    bisc_start_in = 9'b000000000;
    bisc_stop_in  = 9'b000000000;
    case (CH_IDX)
      0 : begin
        bisc_start_in = {1'b0, 1'b0, 1'b0, bisc_stop_out[5], bisc_start_out[5], bisc_start_out[4], bisc_start_out[3], bisc_start_out[2], bisc_start_out[1]};
        bisc_stop_in  = {1'b0, 1'b0, 1'b0, bisc_stop_out[4], bisc_stop_out[3],  bisc_stop_out[2],  bisc_stop_out[1],  bisc_stop_out[0],  1'b1};
      end
      1 : begin
        bisc_start_in = {1'b0, 1'b0, 1'b0, bisc_stop_out[5], bisc_start_out[5], bisc_start_out[4], bisc_start_out[3], bisc_start_out[2], bisc_start_out[1]};
        bisc_stop_in  = {1'b0, 1'b0, 1'b0, bisc_stop_out[4], bisc_stop_out[3],  bisc_stop_out[2],  bisc_stop_out[1],  bisc_stop_out[0],  1'b1};
      end
      2 : begin
        bisc_start_in = {bisc_stop_out[8], 1'b0, bisc_start_out[8], bisc_start_out[6], bisc_start_out[5], bisc_start_out[4], bisc_start_out[3], bisc_start_out[2], bisc_start_out[1]};
        bisc_stop_in  = {bisc_stop_out[6], 1'b0, bisc_stop_out[5], bisc_stop_out[4],  bisc_stop_out[3],  bisc_stop_out[2],  bisc_stop_out[1],  bisc_stop_out[0],  1'b1};
      end
    endcase
  end

  // RX TX Reset
  always_comb begin
    rxtx_rst = {9{6'b000000}};
    case (CH_IDX)
      0 : rxtx_rst = {{6{1'b0}}, {6{1'b0}}, {6{1'b0}}, {6{rst_div}}, {{4{rst_div}}, 1'b0, rst_div}, {{4{rst_div}}, 1'b0, rst_div}, {{4{rst_div}}, 1'b0, rst_div}, {6{rst_div}}, {6{rst_div}}};
      1 : rxtx_rst = {{6{1'b0}}, {6{1'b0}}, {6{1'b0}}, {6{rst_div}}, {{4{rst_div}}, 2'b00}, {{4{rst_div}}, 1'b0, rst_div}, {{4{rst_div}}, 1'b0, rst_div}, {6{rst_div}}, {6{rst_div}}};
      2 : rxtx_rst = {{2'b00, {2{rst_div}}, 2'b00}, {6{1'b0}}, {6{1'b0}}, {{4{rst_div}}, 1'b0, rst_div}, {{4{rst_div}}, 2'b00}, {{4{rst_div}}, 1'b0, rst_div}, {{4{rst_div}}, 1'b0, rst_div}, {6{rst_div}}, {6{rst_div}}};
    endcase
  end

  // XPHY Instantiation
  genvar i;
  generate
    for (i=0; i<9; i++) begin : xphyNibble
      if (XPHY_NIBBLE_EN[CH_IDX][i]) begin
        XPHY #(
          .CASCADE_0              ("FALSE"),                                               // Delay cascading within the nibble
          .CASCADE_1              ("FALSE"),
          .CASCADE_2              ("FALSE"),
          .CASCADE_3              ("FALSE"),
          .CASCADE_4              ("FALSE"),
          .CASCADE_5              ("FALSE"),
          .CONTINUOUS_DQS         ("TRUE"),                                                // Used to gate DQS with RX_GATING attribute and PHY_RDEN signal
          .CRSE_DLY_EN            ("FALSE"),                                               // Coarse delay used for slow interfaces (PLL_CLK 200 MHz - 1 GHz)
          .DELAY_VALUE_0          (0),                                                     // Delays used for both RX and TX parts of nibble slices
          .DELAY_VALUE_1          (0),
          .DELAY_VALUE_2          (0),
          .DELAY_VALUE_3          (0),
          .DELAY_VALUE_4          (0),
          .DELAY_VALUE_5          (0),
          .DIS_IDLY_VT_TRACK      ("FALSE"),
          .DIS_ODLY_VT_TRACK      ("FALSE"),
          .DIS_QDLY_VT_TRACK      ("FALSE"),
          .DQS_MODE               ("DDR4_1TCK"),                                              // ??
          .DQS_SRC                ((i==0 || i==4 || i==6 || i==8) ? "EXTERN" : "LOCAL"),   // Sets DQS source, must be "LOCAL" for SERIAL_MODE, TXRX_LOOPBACK, and inter-nibble clocking
          .EN_CLK_TO_LOWER        (EN_CLK_TO_LOWER[CH_IDX][i] ? "ENABLE" : "DISABLE"),     // Enables inter-byte clocking to a numerically lower nibble
          .EN_CLK_TO_UPPER        (EN_CLK_TO_UPPER[CH_IDX][i] ? "ENABLE" : "DISABLE"),     // Enables inter-byte clocking to a numerically upper nibble
          .EN_DYN_DLY_MODE        ("FALSE"),                                               // ??
          .EN_OTHER_NCLK          (EN_OTHER_CLK[CH_IDX][i] ? "TRUE" : "FALSE"),            // Set to receive strobe from inter-nibble clocking
          .EN_OTHER_PCLK          (EN_OTHER_CLK[CH_IDX][i] ? "TRUE" : "FALSE"),
          .FAST_CK                ("FALSE"),                                               // ??
          .FIFO_MODE_0            ("ASYNC"),                                               // RX FIFO read and write clocks are of the same frequency, but have different phases
          .FIFO_MODE_1            ("ASYNC"),
          .FIFO_MODE_2            ("ASYNC"),
          .FIFO_MODE_3            ("ASYNC"),
          .FIFO_MODE_4            ("ASYNC"),
          .FIFO_MODE_5            ("ASYNC"),
          .IBUF_DIS_SRC_0         ("INTERNAL"),                                            // IBUF_DISABLE for IOB is controller from NIBBLE state machine ("INTERNAL")
          .IBUF_DIS_SRC_1         ("INTERNAL"),
          .IBUF_DIS_SRC_2         ("INTERNAL"),
          .IBUF_DIS_SRC_3         ("INTERNAL"),
          .IBUF_DIS_SRC_4         ("INTERNAL"),
          .IBUF_DIS_SRC_5         ("INTERNAL"),
          .INV_RXCLK              ("FALSE"),                                               // Inverts input strobe on NIBBLESLICE[0], only affects n-clk
          .LP4_DQS                ("FALSE"),                                               // ??
          .ODELAY_BYPASS_0        ("FALSE"),                                               // ??
          .ODELAY_BYPASS_1        ("FALSE"),
          .ODELAY_BYPASS_2        ("FALSE"),
          .ODELAY_BYPASS_3        ("FALSE"),
          .ODELAY_BYPASS_4        ("FALSE"),
          .ODELAY_BYPASS_5        ("FALSE"),
          .ODT_SRC_0              ("INTERNAL"),                                            // DYN_DCI for IOB is controller from NIBBLE state machine ("INTERNAL")
          .ODT_SRC_1              ("INTERNAL"),
          .ODT_SRC_2              ("INTERNAL"),
          .ODT_SRC_3              ("INTERNAL"),
          .ODT_SRC_4              ("INTERNAL"),
          .ODT_SRC_5              ("INTERNAL"),
          .PRIME_VAL              (1'b0),                                                  // ??
          .REFCLK_FREQUENCY       (REFCLK_FREQ),
          .RX_CLK_PHASE_N         ("SHIFT_0"),                                             // Sets positive 90-degree shift to n-clk strobe
          .RX_CLK_PHASE_P         ("SHIFT_0"),
          .RX_DATA_WIDTH          (8),                                                     // Sets deserialization to 1:2, 1:4, or 1:8
          .RX_GATING              ("DISABLE"),                                             // Used to gate input DQS with PHY_RD_EN signal (used for bidirectional strobes)
          `ifdef XILINX_SIMULATOR
          .SELF_CALIBRATE         ("DISABLE"),                                             // Calibration can take up to 1.3 ms, so it's better to disable it for simulations, unless it's specifically needed
          `else
          .SELF_CALIBRATE         ("ENABLE"),                                              // Enables BISC (also requires setting ..._VT_TRACK attributes)
          `endif
          .SERIAL_MODE            ("FALSE"),                                               // When "TRUE", uses PLL_CLK in DDR mode to capture input data, otherwise uses DQS
          .TBYTE_CTL_0            (TBYTE_CTL[CH_IDX][i][0] ? "PHY_WREN" : "T"),            // Sets tristate control to PHY_WREN signal or external logic
          .TBYTE_CTL_1            (TBYTE_CTL[CH_IDX][i][1] ? "PHY_WREN" : "T"),
          .TBYTE_CTL_2            (TBYTE_CTL[CH_IDX][i][2] ? "PHY_WREN" : "T"),
          .TBYTE_CTL_3            (TBYTE_CTL[CH_IDX][i][3] ? "PHY_WREN" : "T"),
          .TBYTE_CTL_4            (TBYTE_CTL[CH_IDX][i][4] ? "PHY_WREN" : "T"),
          .TBYTE_CTL_5            (TBYTE_CTL[CH_IDX][i][5] ? "PHY_WREN" : "T"),
          .TXRX_LOOPBACK_0        (TXRX_LOOPBACK[CH_IDX][i][0] ? "TRUE" : "FALSE"),        // Sends TX signal back to RX (could be useful for using WCK as an input strobe)
          .TXRX_LOOPBACK_1        (TXRX_LOOPBACK[CH_IDX][i][1] ? "TRUE" : "FALSE"),
          .TXRX_LOOPBACK_2        (TXRX_LOOPBACK[CH_IDX][i][2] ? "TRUE" : "FALSE"),
          .TXRX_LOOPBACK_3        (TXRX_LOOPBACK[CH_IDX][i][3] ? "TRUE" : "FALSE"),
          .TXRX_LOOPBACK_4        (TXRX_LOOPBACK[CH_IDX][i][4] ? "TRUE" : "FALSE"),
          .TXRX_LOOPBACK_5        (TXRX_LOOPBACK[CH_IDX][i][5] ? "TRUE" : "FALSE"),
          .TX_DATA_WIDTH          (8),                                                     // Sets serialization to 2:1, 4:1, or 8:1
          .TX_GATING              ("DISABLE"),                                             // If enabled, uses PHY_WREN to gate TX datapath
          .TX_INIT_0              (TX_INIT[CH_IDX][i][0]),                                 // Initial values for TX
          .TX_INIT_1              (TX_INIT[CH_IDX][i][1]),
          .TX_INIT_2              (TX_INIT[CH_IDX][i][2]),
          .TX_INIT_3              (TX_INIT[CH_IDX][i][3]),
          .TX_INIT_4              (TX_INIT[CH_IDX][i][4]),     
          .TX_INIT_5              (TX_INIT[CH_IDX][i][5]),
          .TX_INIT_TRI            (1'b1),
          .TX_OUTPUT_PHASE_90_0   ("FALSE"),                                               // Used to implement 90-degree shifts (relative to clock) between signals
          .TX_OUTPUT_PHASE_90_1   ("FALSE"),
          .TX_OUTPUT_PHASE_90_2   ("FALSE"),
          .TX_OUTPUT_PHASE_90_3   ("FALSE"),
          .TX_OUTPUT_PHASE_90_4   ("FALSE"),
          .TX_OUTPUT_PHASE_90_5   ("FALSE"),
          .TX_OUTPUT_PHASE_90_TRI ("FALSE"),
          .WRITE_LEVELING         ("FALSE"))                                               // ??
        xphy_nibble (
          // Clocking and Reset
          .PLL_CLK                (clk_pll),
          .CTRL_CLK               (clk_riu),
          .FIFO_RD_CLK            (rx_fifo_rdclk),
          .FIFO_WR_CLK            (rx_fifo_wrclk[i]),
          .CLK_TO_UPPER           (clk_to_upper[i]),    
          .CLK_TO_LOWER           (clk_to_lower[i]),    
          .NCLK_NIBBLE_OUT        (nclk_nibble_out[i]),
          .PCLK_NIBBLE_OUT        (pclk_nibble_out[i]),
          .NCLK_NIBBLE_IN         (nclk_nibble_in[i]),
          .PCLK_NIBBLE_IN         (pclk_nibble_in[i]),
          .CLK_FROM_OTHER_XPHY    (clk_from_other_xphy[i]),
          .RST                    (rst_div),
          .RX_RST                 (rxtx_rst[i]),
          .TX_RST                 (rxtx_rst[i]),
          // BISC Signals
          .DLY_RDY                (dly_rdy[i]),
          .EN_VTC                 (en_vtc_r2),
          .RX_EN_VTC              (6'b111111),
          .TX_EN_VTC              (6'b111111),
          .PHY_RDY                (vtc_rdy[i]),
          // BISC Simulation Signals
          .BISC_START_IN          (bisc_start_in[i]),
          .BISC_START_OUT         (bisc_start_out[i]),
          .BISC_STOP_IN           (bisc_stop_in[i]),
          .BISC_STOP_OUT          (bisc_stop_out[i]),
          // RX Signals
          .PHY_RDEN               (4'b1111),           // !! Not implemented; to use this, pass cmd from cmd_handler and assert PHY_RDEN for RD commands (see RD_IDLE_COUNT RIU) !!
          .FIFO_RDEN              (rx_fifo_rden[i]),
          .FIFO_EMPTY             (rx_fifo_empty[i]),
          .DATAIN                 (rx_d[i]),
          .Q0                     (rx_q_tmp[i][0]),
          .Q1                     (rx_q_tmp[i][1]),
          .Q2                     (rx_q_tmp[i][2]),
          .Q3                     (rx_q_tmp[i][3]),
          .Q4                     (rx_q_tmp[i][4]),
          .Q5                     (rx_q_tmp[i][5]),
          // TX Signals
          .PHY_WREN               ({4{tbyte_in_d}}),    // "tbyte_in_d" is used for DQ TRI control (coming from Data Handler)
          .D0                     (tx_d[i][0]),
          .D1                     (tx_d[i][1]),
          .D2                     (tx_d[i][2]),
          .D3                     (tx_d[i][3]),
          .D4                     (tx_d[i][4]),
          .D5                     (tx_d[i][5]),
          .T                      ({6{tx_t_d}}),        // "tx_t_d" is used for EDC TRI crontrol (coming from Initialization Handler)
          .O0                     (tx_o[i]),
          .T_OUT                  (tx_t_out[i]),
          // IOB Control Signals
          .DYN_DCI                (dyn_dci[i]),
          .IBUF_DISABLE           (ibuf_disable[i]),
          // "Memory-ralted Use" Signals
          .GT_STATUS              (),
          .PHY_RDCS0              (4'd0),
          .PHY_RDCS1              (4'd0),
          .PHY_WRCS0              (4'd0),
          .PHY_WRCS1              (4'd0),
          // PL Delay Programming Interface
          .RXTX_SEL               (6'd0),
          .CE                     (6'd0),
          .INC                    (6'd0),
          .LD                     (6'd0),
          .CNTVALUEIN             (54'd0),
          .CNTVALUEOUT            (),
          // RIU Signals
          .RIU_RD_DATA            (riu_rd_data[i]),
          .RIU_RD_VALID           (riu_valid[i]),
          .RIU_ADDR               (riu_addr),
          .RIU_NIBBLE_SEL         (riu_nibble_sel[i]),
          .RIU_WR_DATA            (riu_wr_data),
          .RIU_WR_EN              (riu_wr_en));
      end
      else begin
        assign rx_d[i]            = 6'd0;
        assign riu_rd_data[i]     = 8'd0;
        assign rx_fifo_wrclk[i]   = 1'b0;
        assign rx_fifo_empty[i]   = 1'b1;
        assign rx_q_tmp[i]        = {6{8'd0}};
        assign dly_rdy[i]         = 1'b1;
        assign vtc_rdy[i]         = 1'b1;
        assign clk_to_lower[i]    = 1'b0;
        assign clk_to_upper[i]    = 1'b0;
        assign bisc_start_out[i]  = 1'b0;
        assign bisc_stop_out[i]   = 1'b0;
        assign pclk_nibble_out[i] = 1'b0;
        assign nclk_nibble_out[i] = 1'b1;
        assign riu_valid[i]       = 1'b1;
        assign dyn_dci[i]         = 6'd0;
        assign ibuf_disable[i]    = 6'd0;
      end
    end
  endgenerate

  // =============================== TX Data Delay ===============================
  odel_block odel_all (
    .clk_div,
    .rst_div,
    // Calibration Interface
    .param_io_out_del,
    // Command Input Interface
    .intf_ck_t,
    .intf_ca,
    .intf_cabi_n,
    .intf_wck_t,
    // Data Handler Interface
    .tbyte_in,
    .tx_t,
    .intf_dq,
    .intf_dbi_n,
    .init_edc,
    .top_cke_n,
    // Delayed Command Input Signals
    .intf_ck_t_d,
    .intf_ca_d,
    .intf_cabi_n_d,
    .intf_wck_t_d,
    // Delayed Data Handler Signals
    .tbyte_in_d,
    .tx_t_d,
    .intf_dq_d,
    .intf_dbi_n_d,
    .init_edc_d,
    .top_cke_n_d);

  // ========================== RX Data Delay and Sync =========================
  assign param_io_in_del_dq  = param_io_in_del[0+:16*4];
  assign param_io_in_del_edc = param_io_in_del[16*4+:2*4];

  idel_block #(.LINES(2)) idel_edc (
    .clk_rx_fifo     (rx_fifo_rdclk),
    .clk_div         (1'b0),
    .rst_div         (1'b0),
    // Capture/Delay Parameters
    .param_smpl_edge (param_smpl_edge),
    .param_sync_ordr (param_sync_ordr),
    .param_io_in_del (param_io_in_del_edc),
    // Byte Group Interface
    .rx_fifo_empty   (2'd0),
    .rx_q            (edc_rx_q),
    .rx_fifo_rden    (),
    // Memory Controller Interface
    .sync_en         (1'b1),
    .phy_dout        (phy_edc));

  idel_block #(.LINES(16)) idel_dq (
    .clk_rx_fifo     (rx_fifo_rdclk),
    .clk_div         (1'b0),
    .rst_div         (1'b0),
    // Capture/Delay Parameters
    .param_smpl_edge (param_smpl_edge),
    .param_sync_ordr (param_sync_ordr),
    .param_io_in_del (param_io_in_del_dq),
    // Byte Group Interface
    .rx_fifo_empty   (16'd0),
    .rx_q            (dq_rx_q),
    .rx_fifo_rden    (),
    // Memory Controller Interface
    .sync_en         (1'b1),
    .phy_dout        (phy_dq));


  assign phy_dbi_n = '{2{8'b1111_1111}};  // DBI_n is unused

  // ================================ IO Buffers ===============================
  generate
    if (CH_IDX == 2) begin  // XPIO 708
      iob_nibble #(
        .NIBBLE_EN       (XPHY_NIBBLE_EN [CH_IDX]),
        .IOBTYPE         (IOBTYPE        [CH_IDX]),
        .USE_VREF        (USE_VREF       [CH_IDX]),
        .USE_DYN_DCI     ("TRUE"),
        .USE_IBUFDISABLE ("FALSE"))
      iob_nibble (
        .tx_o            (tx_o),
        .tx_t_out        (tx_t_out),
        .rx_d            (rx_d),
        .ib_pin          ({9{6'd0}}),
        .ob_pin          (ob_pin),
        .iob_pin         ({{nc[17], nc[16], DQ[0],  DQ[2],  nc[15], nc[14]},
                           {nc[30+:6]},
                           {nc[24+:6]},
                           {nc[13], nc[12], DQ[15], DQ[14], nc[11], nc[10]},
                           {nc[18+:6]},
                           {nc[9],  nc[8],  DQ[13], DQ[11], nc[7],  nc[6]},
                           {nc[5],  nc[4],  EDC[0], EDC[1], nc[3],  nc[2]},
                           {DQ[4],  DQ[5],  DQ[12], DQ[10], DQ[7],  DQ[6]},
                           {DQ[1],  DQ[3],  nc[1],  nc[0],  DQ[9],  DQ[8]}}),
        .dyn_dci         (dyn_dci),
        .ibuf_disable    (ibuf_disable));
    end
    else if (CH_IDX == 1) begin  // XPIO 707
      iob_nibble #(
        .NIBBLE_EN       (XPHY_NIBBLE_EN [CH_IDX]),
        .IOBTYPE         (IOBTYPE        [CH_IDX]),
        .USE_VREF        (USE_VREF       [CH_IDX]),
        .USE_DYN_DCI     ("TRUE"),
        .USE_IBUFDISABLE ("FALSE"))
      iob_nibble (
        .tx_o            (tx_o),
        .tx_t_out        (tx_t_out),
        .rx_d            (rx_d),
        .ib_pin          ({9{6'd0}}),
        .ob_pin          (ob_pin),
        .iob_pin         ({{nc[30+:6]},
                           {nc[24+:6]},
                           {nc[18+:6]},
                           {nc[11], nc[10], EDC[1], EDC[0], nc[9],  nc[8]},
                           {nc[12+:6]},
                           {nc[7],  nc[6],  DQ[0],  DQ[3],  nc[5],  nc[4]},
                           {DQ[14], DQ[15], DQ[12], DQ[13], nc[3],  nc[2]},
                           {nc[1],  nc[0],  DQ[9],  DQ[10], DQ[2],  DQ[5]},
                           {DQ[1],  DQ[4],  DQ[6],  DQ[7],  DQ[11], DQ[8]}}),
        .dyn_dci         (dyn_dci),
        .ibuf_disable    (ibuf_disable));
    end
    else if (CH_IDX == 0) begin  // XPIO 706
      iob_nibble #(
        .NIBBLE_EN       (XPHY_NIBBLE_EN [CH_IDX]),
        .IOBTYPE         (IOBTYPE        [CH_IDX]),
        .USE_VREF        (USE_VREF       [CH_IDX]),
        .USE_DYN_DCI     ("TRUE"),
        .USE_IBUFDISABLE ("FALSE"))
      iob_nibble (
        .tx_o            (tx_o),
        .tx_t_out        (tx_t_out),
        .rx_d            (rx_d),
        .ib_pin          ({9{6'd0}}),
        .ob_pin          (ob_pin),
        .iob_pin         ({{nc[30+:6]},
                           {nc[24+:6]},
                           {nc[18+:6]},
                           {DQ[9],  DQ[8],  DQ[12], DQ[10], DQ[7],  DQ[6]},
                           {DQ[1],  DQ[3],  nc[11], nc[10], nc[9],  nc[8]},
                           {DQ[4],  DQ[5],  nc[7],  nc[6],  nc[5],  nc[4]},
                           {nc[12+:6]},
                           {DQ[0],  DQ[2], EDC[0], EDC[1], DQ[13], DQ[11]},
                           {DQ[15], DQ[14], nc[3],  nc[2], nc[1],  nc[0]}}),
        .dyn_dci           (dyn_dci),
        .ibuf_disable      (ibuf_disable));
    end
  endgenerate



//  (* keep = "true", mark_debug = "true" *) reg [8:0]  debug_vtc_rdy;
//  (* keep = "true", mark_debug = "true" *) reg [7:0]  debug_riu_addr;
//  (* keep = "true", mark_debug = "true" *) reg [15:0] debug_riu_wr_data;
//  (* keep = "true", mark_debug = "true" *) reg [8:0]  debug_riu_valid;
//  (* keep = "true", mark_debug = "true" *) reg        debug_riu_wr_en;
//  (* keep = "true", mark_debug = "true" *) reg [8:0]  debug_riu_nibble_sel;
//  (* keep = "true", mark_debug = "true" *) reg [15:0] debug_riu_rd_data [8:0],

  //  always @(posedge clk_div, posedge rst_div)
  //  if (rst_div) begin
  //             debug_vtc_rdy                       <='b0;   
  //  end
  //  else begin
  //             debug_vtc_rdy                       <=vtc_rdy;
  //  end

  //  always @(posedge clk_riu, posedge rst_riu)
  //  if (rst_riu) begin
  //             debug_riu_addr                      <='b0;  
  //             debug_riu_wr_data                   <='b0;    
  //             debug_riu_valid                     <='b0;  
  //             debug_riu_wr_en                     <='b0;  
  //             debug_riu_nibble_sel                <='b0;        
  //  end
  //  else begin
  //             debug_riu_addr                      <=riu_addr;
  //             debug_riu_wr_data                   <=riu_wr_data;
  //             debug_riu_valid                     <=riu_valid;
  //             debug_riu_wr_en                     <=riu_wr_en;
  //             debug_riu_nibble_sel                <=riu_nibble_sel;
  //  end

endmodule