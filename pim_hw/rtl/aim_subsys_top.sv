`timescale 1ps / 1ps

// !! IMPORTANT !! Below, define interfaces that are required for the selected design configuration !!

// `define USE_QDRII  // Required for N1ZYNQ configuration
// `define USE_FX3    // Required for N1ZYNQ configuration
// `define USE_DBI    // Required for N1ZYNQ and ZCU102 configurations

import axi_lib::*;
import aimc_lib::*;

module aim_subsys (
  input  logic                        sys_clk_n,
  input  logic                        sys_clk_p,
  input  logic                        sys_rst,
  output logic                        aclk,
  output logic                        clk_mcs,
  output logic                        rst_mcs,
  // AXI4: Write Address Channel
  input  logic [AXI_ID_WIDTH-1:0]     s_axi_awid,
  input  logic [AXI_ADDR_WIDTH-1:0]   s_axi_awaddr,
  input  logic [7:0]                  s_axi_awlen,
  input  logic [2:0]                  s_axi_awsize,
  input  logic [1:0]                  s_axi_awburst,
  input  logic                        s_axi_awlock,
  input  logic [3:0]                  s_axi_awcache,
  input  logic [2:0]                  s_axi_awprot,
  input  logic [3:0]                  s_axi_awqos,
  input  logic [3:0]                  s_axi_awregion,
  input  logic                        s_axi_awvalid,
  output logic                        s_axi_awready,
  // AXI4: Write Data Channel
  input  logic [AXI_DATA_WIDTH-1:0]   s_axi_wdata,
  input  logic [AXI_DATA_WIDTH/8-1:0] s_axi_wstrb,
  input  logic                        s_axi_wlast,
  input  logic                        s_axi_wvalid,
  output logic                        s_axi_wready,
  // AXI4: Write Response Channel
  output logic [AXI_ID_WIDTH-1:0]     s_axi_bid,
  output logic [1:0]                  s_axi_bresp,
  output logic                        s_axi_bvalid,
  input  logic                        s_axi_bready,
  // AXI4: Read Address Channel
  input  logic [AXI_ID_WIDTH-1:0]     s_axi_arid,
  input  logic [AXI_ADDR_WIDTH-1:0]   s_axi_araddr,
  input  logic [7:0]                  s_axi_arlen,
  input  logic [2:0]                  s_axi_arsize,
  input  logic [1:0]                  s_axi_arburst,
  input  logic                        s_axi_arlock,
  input  logic [3:0]                  s_axi_arcache,
  input  logic [2:0]                  s_axi_arprot,
  input  logic [3:0]                  s_axi_arqos,
  input  logic [3:0]                  s_axi_arregion,
  input  logic                        s_axi_arvalid,
  output logic                        s_axi_arready,
  // AXI4: Read Data Channel
  output logic [AXI_ID_WIDTH-1:0]     s_axi_rid,
  output logic [AXI_DATA_WIDTH-1:0]   s_axi_rdata,
  output logic [1:0]                  s_axi_rresp,
  output logic                        s_axi_rlast,
  output logic                        s_axi_rvalid,
  input  logic                        s_axi_rready,
  // MCS IO Interface
  input logic                         IO_addr_strobe,
  input logic                         IO_read_strobe,
  input logic                         IO_write_strobe,
  input logic  [31:0]                 IO_address,
  input logic  [3:0]                  IO_byte_enable,
  input logic  [31:0]                 IO_write_data,
  output logic [31:0]                 IO_read_data,
  output logic                        IO_ready,
  // LED Interface
  output logic [CH_NUM-1:0]           led,
  `ifdef USE_QDRII
  // QDR II+ Clocks and Interface
  input  logic                        qdrii_clk_n,
  input  logic                        qdrii_clk_p,
  output logic [17:0]                 qdrii_D,
  output logic                        qdrii_K_p,
  output logic                        qdrii_K_n,
  output logic [1:0]                  qdrii_BW_n,
  output logic                        qdrii_RPS_n,
  output logic                        qdrii_WPS_n,
  output logic                        qdrii_DOFF_n,
  output logic [20:0]                 qdrii_SA,
  input  logic [17:0]                 qdrii_Q,
  input  logic                        qdrii_CQ_p,
  input  logic                        qdrii_CQ_n,
  `endif
  `ifdef USE_FX3
  // FX3 Interface
  output logic                        PCLK,
  input  logic                        FLAGA,
  input  logic                        FLAGC,
  output logic                        PKTEND_N,
  output logic                        SLWR_N,
  output logic                        SLRD_N,
  output logic                        SLOE_N,
  output logic [1:0]                  FX3_A,
  inout  logic [FX3_WIDTH-1:0]        FX3_DQ,
  `endif
  // AiM (GDDR6) Interface
  output logic [((CH_NUM-1)>>1):0]    CK_t, 
  output logic [((CH_NUM-1)>>1):0]    CK_c,
  output logic [((CH_NUM-1)>>1):0]    RESET_n,
  output logic [CH_NUM-1:0] [9:0]     CA,
  output logic [CH_NUM-1:0]           CABI_n,
  output logic [CH_NUM-1:0]           CKE_n,
  output logic [CH_NUM-1:0]           WCK1_t,
  output logic [CH_NUM-1:0]           WCK1_c,
  output logic [CH_NUM-1:0]           WCK0_t,
  output logic [CH_NUM-1:0]           WCK0_c,
  inout  tri   [CH_NUM-1:0] [15:0]    DQ,
  `ifdef USE_DBI
  inout  tri   [CH_NUM-1:0] [1:0]     DBI_n,
  `endif
  inout  tri   [CH_NUM-1:0] [1:0]     EDC);

  // =============================== Signal Declarations ==============================
  // Clocking and Reset Signals
  logic [CH_NUM-1:0]            CK_t_loc;                     // Clock signals from both channels A and B (latter to be discarded)
  logic [CH_NUM-1:0]            CK_c_loc;
  logic [CH_NUM-1:0]            RESET_n_loc;                  // Reset signals from both channels A and B (latter to be discarded)
  logic [CH_NUM-1:0]            pll_lock;
  logic                         mmcm_lock;
  logic                         clk_div, clk_riu;
  logic                         rst_div, rst_riu;
  logic                         rst_ub_riu;
  logic                         ub_rst_out;                   // Soft reset issued by MCS firmware (used for IO Bank PLL)
  logic                         clk_100;
  logic                         rst_100;
  logic                         clk_rx_fifo;
  logic                         pll_gate;
  logic                         arst;
  `ifndef USE_QDRII
  // QDR II+ Dummy Signals
  logic                         qdrii_clk_n;
  logic                         qdrii_clk_p;
  logic [17:0]                  qdrii_D;
  logic                         qdrii_K_p;
  logic                         qdrii_K_n;
  logic [1:0]                   qdrii_BW_n;
  logic                         qdrii_RPS_n;
  logic                         qdrii_WPS_n;
  logic                         qdrii_DOFF_n;
  logic [20:0]                  qdrii_SA;
  logic [17:0]                  qdrii_Q;
  logic                         qdrii_CQ_p;
  logic                         qdrii_CQ_n;
  `endif
  // Calibration Handler Signals
  logic [$clog2(CH_NUM)-1:0]    cal_ch_idx;                   // Index of the channel (controller) currently selected by MCS
  logic [CH_NUM-1:0]            cal_done;
  logic [CH_NUM-1:0]            cal_ref_stop;                 // Calibration Handler request to stop refresh in a given controller
  logic [CH_NUM-1:0]            ref_idle;                     // Refresh status from each controller
  logic [CH_NUM-1:0]            init_done;
  logic [31:0]                  cal_addr;                     // Address data passed from MCS
  logic [31:0]                  cal_rd_data;                  // Read data bus to MCS
  logic                         cal_rd_strobe_lvl;            // Read command strobe from MCS
  logic [31:0]                  cal_wr_data;                  // Write data bus from MCS
  logic                         cal_wr_strobe_lvl;            // Write command strobe from MCS
  logic                         cal_rdy_lvl;                  // Write/Read command acknowledgement to MCS
  // logic                        cal_ui_ctrl;                // When asserted Interconnect is driven by Calibration Handler packets
  // pkt_t                        pgen_pkt;                   // Packet from the Pattern Generator
  // logic                        pgen_pkt_valid;             // Validity signal for the Patter Generator packet
  logic [CH_NUM-1:0][3:0][6:0]  param_vref_tune;
  logic [CH_NUM-1:0]            param_smpl_edge;              // Selects PLL clock edge for data capture (0:Rising, 1:Falling)
  logic [CH_NUM-1:0]            param_sync_ordr;              // Selects which synchronization FIFO or pipe is written first when crossing data from PHY to the controller
  logic [CH_NUM-1:0][18*4-1:0]  param_io_in_del;              // Adds 0-15 WCK half-cycle delays during data capture (per DQ/EDC line)
  logic [CH_NUM-1:0][16*4-1:0]  param_io_out_del;             // Adds 0-15  WCK half-cycle delays during output capture (per DQ line)
  logic [CH_NUM-1:0][2:0]       param_rl_del;                 // Adds 0-7 clock cycle delay for expected data in Data Handler
  logic [CH_NUM-1:0]            cal_ck_en;
  logic [CH_NUM-1:0]            cal_wck_en;
  pkt_t                         cal_pkt;                      // Calibration Handler packet
  cmd_t                         cal_cmd;                      // Calibration Handler command
  logic [CH_NUM-1:0]            cal_pkt_valid;                // Calibration Handler packet valid
  logic [CH_NUM-1:0]            aimc_cal_rdy;
  pkt_t                         aimc_cal_pkt [CH_NUM-1:0];
  logic [CH_NUM-1:0][31:0]      aimc_cal_edc;
  logic [CH_NUM-1:0]            aimc_cal_pkt_valid;
  logic [CH_NUM-1:0]            aimc_temp_valid;
  logic [CH_NUM-1:0][7:0]       aimc_temp_data;
  // MCS Signals
  logic [3:0]                   riu_nibble;                   // Nibble select (addressing a single HPIO/XPIO bank, so 8 nibbles in UltraScale+ and 9 nibbles in Versal)
  logic [7:0]                   riu_addr;                     // RIU register address (e.g. OELAY control register, etc.); 6-bit in UltraScale+ and 8-bit in Versal
  logic [CH_NUM-1:0][15:0]      riu_rd_data;                  // Data read from RIU for each channel
  logic [CH_NUM-1:0]            riu_rd_strobe;
  logic [15:0]                  riu_wr_data;                  // Data to be written to RIU
  logic [CH_NUM-1:0]            riu_wr_strobe;
  logic [CH_NUM-1:0]            riu_valid;                    // Combined (&-ed) RIU_RD_VALID responses from Byte Groups (UltraScal+) or XPHY Nibbles (Versal) for each channel
  // Diagnostic Monitor Signals
  logic                         mon_upd;
  logic [CH_NUM-1:0][7:0][5:0]  aimc_ca_util;                 // AiM Controller CA utilization (eight 6-bit values per controller)
  logic [CH_NUM-1:0][3:0][23:0] aimc_que_ocup;                // AiM Controller queue occupancy
  logic [3:0][23:0]             aims_que_ocup;
  logic [31:0]                  pkt_latency;                  // Latency data: 8-bit min latency, 8-bit max latency, 16-bit packet count for recording latency
  // DMA and Interconnect Signals
  logic [$bits(cfr_mode_t)-1:0] cfr_mode_p;
  logic [$bits(cfr_time_t)-1:0] cfr_time_p;
  logic [$bits(cfr_refr_t)-1:0] cfr_refr_p;
  logic [$bits(cfr_schd_t)-1:0] cfr_schd_p;
  logic                         icnt_rdy;
  logic                         dma_rdy;
  pkt_t                         dma_pkt;
  logic [CH_NUM-1:0]            dma_pkt_ch_mask;
  logic                         dma_pkt_valid;
  pkt_t                         icnt_dma_pkt;
  logic [$clog2(CH_NUM)-1:0]    icnt_dma_pkt_ch_addr;
  logic                         icnt_dma_pkt_valid;
  logic [CH_NUM-1:0]            icnt_aimc_pkt_valid;
  pkt_t                         icnt_aimc_pkt;
  logic [CH_NUM-1:0]            aimc_rdy;
  logic [CH_NUM-1:0]            aimc_pkt_valid;
  pkt_t                         aimc_pkt [CH_NUM-1:0];
  // AiM Controllers Signals
  logic [7:0]                   phy_rdy_o;                    // PHY ready output signal from AiM controller (8 bits required for synchronizing with non-existing channels)
  logic [CH_NUM-1:0]            phy_rdy_i;                    // PHY ready input signal to AiM controller
  // Other
  tri   [CH_NUM-1:0][1:0]       dummy_dbi;

  // ==================================== Clocking ====================================
  logic sys_rst_ibuf;

  global_infra #(
    .CLKIN_PERIOD_MMCM   (CLKIN_PERIOD_MMCM),
    .CLKFBOUT_MULT_MMCM  (CLKFBOUT_MULT_MMCM),
    .DIVCLK_DIVIDE_MMCM  (DIVCLK_DIVIDE_MMCM),
    .CLKOUT0_DIVIDE_MMCM (CLKDIV_DIVIDE_MMCM),  
    .CLKOUT1_DIVIDE_MMCM (CLKRX_DIVIDE_MMCM),
    .CLKOUT2_DIVIDE_MMCM (CLK100_DIVIDE_MMCM),
    .CLKOUT3_DIVIDE_MMCM (CLK100_DIVIDE_MMCM),
    .CLKOUT4_DIVIDE_MMCM (CLK100_DIVIDE_MMCM),
    .CLKOUT6_DIVIDE_MMCM (CLKRIU_DIVIDE_MMCM),
    .TCQ                 (100))
  global_infra (
    .sys_clk_n           (sys_clk_n), 
    .sys_clk_p           (sys_clk_p),
    .sys_rst             (sys_rst_ibuf),
    .pll_lock            (&pll_lock),
    .mmcm_lock           (mmcm_lock),
    .div_clk             (clk_div),
    .riu_clk             (clk_riu),
    .ui_clkout1          (clk_rx_fifo),
    .ui_clkout2          (clk_100),
    .ui_clkout3          (),
    .ui_clkout4          (),
    .dbg_clk             (),
    .rstdiv0             (rst_div),
    .rstdiv1             (rst_riu),
    .rstout2             (rst_100),
    .reset_ub            (rst_ub_riu),
    .pllgate             (pll_gate));

  generate
    if (GLOBAL_CLK == "CK_DIV1") begin
      assign aclk = clk_div;
      assign arst = rst_div;      
    end 
    else if (GLOBAL_CLK == "CK_DIV2") begin
      assign aclk = clk_riu;
      assign arst = rst_riu;
    end
    else begin 
      assign aclk = 0;
      assign arst = 0;
    end    
  endgenerate
  
  IBUF IBUF_sys_rst (
    .O (sys_rst_ibuf),
    .I (sys_rst));

  assign clk_mcs = clk_riu;
  assign rst_mcs = rst_ub_riu;

  // =================================== DMA Engine ===================================
  `ifndef USE_QDRII
  assign qdrii_clk_n = 1'b0;
  assign qdrii_clk_p = 1'b0;
  assign qdrii_Q     = 18'd0;
  assign qdrii_CQ_p  = 1'b0;
  assign qdrii_CQ_n  = 1'b0;
  `endif

  aim_dma aim_dma (
    .clk          (aclk),
    .rst          (arst),
    // QDR II+ Clocks and Interface (unavailable on VCU118/ZCU102/VCK190)
    .qdrii_clk_n,
    .qdrii_clk_p,
    .sys_rst      (sys_rst_ibuf),
    .qdrii_D,
    .qdrii_K_p,
    .qdrii_K_n,
    .qdrii_BW_n,
    .qdrii_RPS_n,
    .qdrii_WPS_n,
    .qdrii_DOFF_n,
    .qdrii_SA,
    .qdrii_Q,
    .qdrii_CQ_p,
    .qdrii_CQ_n,
    // Diagnostic Monitor (unsupported on VCU118/ZCU102/VCK190)
    .mon_upd,
    .pkt_latency,
    // Configuration Register
    .cfr_mode_p,
    .cfr_time_p,
    .cfr_refr_p,
    .cfr_schd_p,
    // AXI4: Write Address Channel
    .s_axi_awid,
    .s_axi_awaddr,
    .s_axi_awlen,
    .s_axi_awsize,
    .s_axi_awburst,
    .s_axi_awlock,
    .s_axi_awcache,
    .s_axi_awprot,
    .s_axi_awqos,
    .s_axi_awregion,
    .s_axi_awvalid,
    .s_axi_awready,
    // AXI4: Write Data Channel
    .s_axi_wdata,
    .s_axi_wstrb,
    .s_axi_wlast,
    .s_axi_wvalid,
    .s_axi_wready,
    // AXI4: Write Response Channel
    .s_axi_bid,
    .s_axi_bresp,
    .s_axi_bvalid,
    .s_axi_bready,
    // AXI4: Read Address Channel
    .s_axi_arid,
    .s_axi_araddr,
    .s_axi_arlen,
    .s_axi_arsize,
    .s_axi_arburst,
    .s_axi_arlock,
    .s_axi_arcache,
    .s_axi_arprot,
    .s_axi_arqos,
    .s_axi_arregion,
    .s_axi_arvalid,
    .s_axi_arready,
    // AXI4: Read Data Channel
    .s_axi_rid,
    .s_axi_rdata,
    .s_axi_rresp,
    .s_axi_rlast,
    .s_axi_rvalid,
    .s_axi_rready,
  // AiM Interconnect Interface
    .icnt_rdy,
    .dma_pkt_valid,
    .dma_pkt,
    .dma_pkt_ch_mask,
    .dma_rdy,
    .icnt_dma_pkt_valid,
    .icnt_dma_pkt,
    .icnt_dma_pkt_ch_addr);

  // ================================= Calibration MUX ================================
  calib_mux #(
    .CLK_SPEED_MHZ (SYS_CLK_SPEED/2),
    .CH_NUM        (CH_NUM)) 
  calib_mux (
    .clk           (clk_riu),
    .rst           (rst_riu),
    // UART Interface
    .uart_rx       (),
    .uart_tx       (),
    .uart_rxd      (),
    .uart_txd      (),
    // AIMC Interface
    .cal_done,
    .ch_idx        (cal_ch_idx),
    // Button/LED Interface
    .btn_up        (),  // Manual channel select is not used anymore
    .btn_down      (),
    .led);
    
  // OBUF OBUF_uart_tx (
  //   .O (uart_tx),
  //   .I (uart_tx_obuf));

  // IBUF IBUF_uart_rx (
  //   .O (uart_rx_ibuf),
  //   .I (uart_rx));

  // =============================== Multicast Interconnect ===========================
  bcast_icnt bcast_icnt (
    .clk (aclk),
    .rst (arst),
    // DMA Interface
    .dma_rdy,
    .dma_pkt_valid,
    .dma_pkt,
    .dma_pkt_ch_mask,
    .icnt_rdy,
    .icnt_dma_pkt_valid,
    .icnt_dma_pkt,
    .icnt_dma_pkt_ch_addr,
    // AiM Controller Interface
    .icnt_aimc_pkt_valid,
    .icnt_aimc_pkt,
    .aimc_rdy,
    .aimc_pkt_valid,
    .aimc_pkt);


  // =============================== Calibration Handler ==============================
  gddr6_calib aimc_calib (
    .clk            (aclk),
    .rst            (arst),
    .cal_done,
    .cal_ref_stop,
    .ref_idle,
    // Initialization Handler Interface
    .init_done,
    // Interconnect Interface (for Pattern Generator)
    .cal_ui_ctrl    (),
    .icnt_rdy       (1'b0),
    .pgen_pkt_valid (),
    .pgen_pkt       (),
    // MCS Interface
    .cal_ch_idx,
    .cal_addr,
    .cal_rd_data,
    .cal_rd_strobe_lvl,
    .cal_wr_data,
    .cal_wr_strobe_lvl,
    .cal_rdy_lvl,
    // Parameter Interface
    .param_vref_tune,
    .param_smpl_edge,
    .param_sync_ordr,
    .param_io_in_del,
    .param_io_out_del,
    .param_rl_del,
    // Command Handler Interface
    .cal_ck_en,
    .cal_wck_en,
    .cal_pkt,
    .cal_cmd,
    .cal_pkt_valid,
    .aimc_cal_rdy,
    // Data Handler Interface
    .aimc_cal_pkt,
    .aimc_cal_edc,
    .aimc_cal_pkt_valid,
    .aimc_temp_valid,
    .aimc_temp_data);

  // =============================== MCS Infrastructure ===============================
  microblaze_mcs aimc_mcs (
    .clk_div (aclk),
    .rst_div (arst),
    .clk_riu,
    .rst_riu,
    .rst_ub_riu,
    .ub_rst_out,
    // MCS IO Interface
    .IO_addr_strobe,
    .IO_read_strobe,
    .IO_write_strobe,
    .IO_address,
    .IO_byte_enable,
    .IO_write_data,
    .IO_read_data,
    .IO_ready,
    // RIU Interface
    .riu_nibble,
    .riu_addr,
    .riu_rd_data,
    .riu_rd_strobe,
    .riu_wr_data,
    .riu_wr_strobe,
    .riu_valid,
    // Calibration Handler Interface
    .cal_ch_idx,
    .cal_addr,
    .cal_rd_data,
    .cal_rd_strobe_lvl,
    .cal_wr_data,
    .cal_wr_strobe_lvl,
    .cal_rdy_lvl);

  // ================================= AiM Controllers ================================
  genvar i;
  generate
    for (i=0; i<8; i++) begin : aimcCh
      if (i<CH_NUM) begin
        // Generating clock and reset signals for even channels (GDDR6 uses one CK_t/c pair and one RESET_n per two channels)
        if (i[0] == 1'b0) begin
          assign CK_t[i>>1] = CK_t_loc[i];
          assign CK_c[i>>1] = CK_c_loc[i];

          OBUF OBUF_RESET_n (
            .O (RESET_n     [i>>1]),
            .I (RESET_n_loc [i]));
        end

        // Syncrhonizing initialization sequences between channels A and B
        if (i[0] == 1'b0) begin  // Channel A
          always @(posedge aclk, posedge arst)
            if (arst) phy_rdy_i[i] <= 0;
            else      phy_rdy_i[i] <= phy_rdy_o[i] && phy_rdy_o[i+1];
        end
        else begin               // Channel B
          always @(posedge aclk, posedge arst)
            if (arst) phy_rdy_i[i] <= 0;
            else      phy_rdy_i[i] <= phy_rdy_o[i] && phy_rdy_o[i-1];
        end

        initial phy_rdy_i[i] = 0;
        aimc_top #(.CH_IDX (i)) aimc (
          .clk_div,
          .rst_div,
          .clk_riu,
          .rst_riu,
          .ub_rst_out,
          .clk_rx_fifo,
          .mmcm_lock,
          .pll_gate,
          .pll_lock           (pll_lock            [i]),
          .phy_rdy_o          (phy_rdy_o           [i]),
          .phy_rdy_i          (phy_rdy_i           [i]),
          // Calibration Handler Interface
          .cal_done           (cal_done            [i]),
          .cal_ref_stop       (cal_ref_stop        [i]),
          .ref_idle           (ref_idle            [i]),
          .init_done          (init_done           [i]),
          .cal_ck_en          (cal_ck_en           [i]),
          .cal_wck_en         (cal_wck_en          [i]),
          .cal_pkt,
          .cal_cmd,
          .cal_pkt_valid      (cal_pkt_valid       [i]),
          .aimc_cal_rdy       (aimc_cal_rdy        [i]),
          .param_vref_tune    (param_vref_tune     [i]),
          .param_smpl_edge    (param_smpl_edge     [i]),
          .param_sync_ordr    (param_sync_ordr     [i]),
          .param_io_in_del    (param_io_in_del     [i]),
          .param_io_out_del   (param_io_out_del    [i]),
          .param_rl_del       (param_rl_del        [i]),
          .aimc_cal_pkt_valid (aimc_cal_pkt_valid  [i]),
          .aimc_cal_pkt       (aimc_cal_pkt        [i]),
          .aimc_cal_edc       (aimc_cal_edc        [i]),
          .aimc_temp_valid    (aimc_temp_valid     [i]),
          .aimc_temp_data     (aimc_temp_data      [i]),
          // MCS-RIU Interface
          .riu_nibble,
          .riu_addr,
          .riu_rd_data        (riu_rd_data         [i]),
          .riu_rd_strobe      (riu_rd_strobe       [i]),
          .riu_wr_data,
          .riu_wr_strobe      (riu_wr_strobe       [i]),
          .riu_valid          (riu_valid           [i]),
          // Diagnostic Monitor Interface
          .mon_upd,
          .aimc_ca_util       (aimc_ca_util        [i]),
          // Configuration Register Interface
          .cfr_mode_p,
          .cfr_time_p,
          .cfr_refr_p,
          .cfr_schd_p,
          // Interconnect Interface
          .ui_pkt             (icnt_aimc_pkt),
          .ui_pkt_valid       (icnt_aimc_pkt_valid [i]),
          .aimc_rdy           (aimc_rdy            [i]),
          .aimc_pkt           (aimc_pkt            [i]),
          .aimc_pkt_valid     (aimc_pkt_valid      [i]),
          // GDDR6 Interface
          .CK_t               (CK_t_loc            [i]), 
          .CK_c               (CK_c_loc            [i]),
          .RESET_n            (RESET_n_loc         [i]),
          .CA                 (CA                  [i]),
          .CABI_n             (CABI_n              [i]),
          .CKE_n              (CKE_n               [i]),
          .WCK1_t             (WCK1_t              [i]),
          .WCK1_c             (WCK1_c              [i]),
          .WCK0_t             (WCK0_t              [i]),
          .WCK0_c             (WCK0_c              [i]),
          .DQ                 (DQ                  [i]),
          `ifdef USE_DBI
          .DBI_n              (DBI_n               [i]),
          `else
          .DBI_n              (dummy_dbi           [i]),
          `endif
          .EDC                (EDC                 [i]));
      end
      else begin
        assign phy_rdy_o[i] = 1;
      end
    end
  endgenerate

  // =============================== Diagnostic Monitor ===============================
  `ifdef USE_FX3
  generate
    if (DIAG_MON_EN == "TRUE") begin
      diag_mon_top diag_mon_top (
        .clk     (aclk),
        .rst     (arst),
        .clk_100 (clk_100),
        .rst_100 (rst_100),
        // System Interface
        .mon_upd,
        .aimc_ca_util,      // CA bus utilization (eight 6-bit values per channel, one for each command type)
        .aimc_que_ocup,     // Concatenated queue occupancy array from AiM controllers
        .aims_que_ocup,     // Concatenated queue occupancy array from AiM DMA and Interconnect
        .pkt_latency,       // Packet latency data (8-bit min, 8-bit max, 16-bit pkt count)
        // FX3 Interface
        .PCLK,
        .FLAGA,
        .FLAGC,
        // .SLCS_N,
        .PKTEND_N,
        .SLWR_N,
        .SLRD_N,
        .SLOE_N,
        .A  (FX3_A),
        .DQ (FX3_DQ));
    end
    else begin
      assign mon_upd = 1'b0;

      OBUF OBUF_PCLK     (.O (PCLK),     .I (0));
      // OBUF OBUF_SLCS_N   (.O (SLCS_N),   .I (0));
      OBUF OBUF_PKTEND_N (.O (PKTEND_N), .I (0));
      OBUF OBUF_SLWR_N   (.O (SLWR_N),   .I (0));
      OBUF OBUF_SLRD_N   (.O (SLRD_N),   .I (0));
      OBUF OBUF_SLOE_N   (.O (SLOE_N),   .I (0));
      for (i=0; i<2; i++)
        OBUF OBUF_SOC_A (.O (FX3_A[i]), .I (0));
      for (i=0; i<FX3_WIDTH; i++)
        IOBUF IOBUF_DQ (.O  (), .I  (0), .IO (FX3_DQ[i]), .T  (1));
    end
  endgenerate
  `else
  assign mon_upd = 1'b0;
  `endif

endmodule
