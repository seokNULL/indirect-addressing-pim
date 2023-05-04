`timescale 1ps / 1ps

import aimc_lib::*;

module aimc_top #(parameter CH_IDX = 0) (
  input  logic            clk_div,
  input  logic            rst_div,
  input  logic            clk_riu,
  input  logic            rst_riu,
  input  logic            ub_rst_out,
  input  logic            clk_rx_fifo,
  input  logic            mmcm_lock,
  input  logic            pll_gate,
  output logic            pll_lock,
  output logic            phy_rdy_o,
  input  logic            phy_rdy_i,
  // Calibration Handler Interface
  input  logic            cal_done,
  input  logic            cal_ref_stop,
  output logic            ref_idle,
  output logic            init_done,
  input  logic            cal_ck_en,
  input  logic            cal_wck_en,
  input  pkt_t            cal_pkt,
  input  cmd_t            cal_cmd,
  input  logic            cal_pkt_valid,
  output logic            aimc_cal_rdy,
  input  logic [3:0][6:0] param_vref_tune,
  input  logic            param_smpl_edge,
  input  logic            param_sync_ordr,
  input  logic [18*4-1:0] param_io_in_del,
  input  logic [16*4-1:0] param_io_out_del,
  input  logic [2:0]      param_rl_del,
  output logic            aimc_cal_pkt_valid,
  output pkt_t            aimc_cal_pkt,
  output logic [31:0]     aimc_cal_edc,
  output logic            aimc_temp_valid,
  output logic [7:0]      aimc_temp_data,
  // MCS-RIU Interface
  input  logic [3:0]      riu_nibble,              // Nibble select index (UltraScale+: 3-bit nibble index; Versal: 4-bit nibble index)
  input  logic [7:0]      riu_addr,                // RIU_ADDR input (UltraScal+: 6-bit address; Versal: 8-bit address)
  output logic [15:0]     riu_rd_data,
  input  logic            riu_rd_strobe,
  input  logic [15:0]     riu_wr_data,
  input  logic            riu_wr_strobe,
  output logic            riu_valid,  
  // Diagnostic Monitor Interface
  input  logic            mon_upd,
  output logic [7:0][5:0] aimc_ca_util,
  // Configuration Register Interface
  input  logic [$bits(cfr_mode_t)-1:0] cfr_mode_p,
  input  logic [$bits(cfr_time_t)-1:0] cfr_time_p,
  input  logic [$bits(cfr_refr_t)-1:0] cfr_refr_p,
  input  logic [$bits(cfr_schd_t)-1:0] cfr_schd_p,
  // Interconnect Interface
  input  pkt_t            ui_pkt,
  input  logic            ui_pkt_valid,
  output logic            aimc_rdy,
  output pkt_t            aimc_pkt,
  output logic            aimc_pkt_valid,
  // GDDR6 Interface
  output logic            RESET_n,
  output logic            CK_t, CK_c,
  output logic [9:0]      CA,
  output logic            CABI_n,
  output logic            CKE_n,
  output logic            WCK1_t, WCK1_c,
  output logic            WCK0_t, WCK0_c,
  inout  tri   [15:0]     DQ,
  inout  tri   [1:0]      DBI_n,
  inout  tri   [1:0]      EDC);

  // ============================== Signal Declarations ================================
  // Clocking
  logic        aclk;
  logic        arst;
  // Scheduler Signals
  pkt_t        sched_pkt;                  // Scheduler packet
  cmd_t        sched_cmd;                  // Scheduler command
  logic        sched_pkt_valid;            // Scheduler packet valid
  logic        sched_rdy;                  // Scheduler ready signal
  // Interface Block Signals
  logic        intf_rdy;                   // Interface Block ready for input packets
  pkt_t        intf_pkt;                   // Interface Block output packet
  logic [31:0] intf_edc;                   // Interface Block EDC data
  logic        intf_pkt_valid;             // Interface Block packet valid
  logic        intf_pkt_retry;             // CRC fail signal (asserted together with intf_pkt_valid)
  logic        temp_valid;                 // Temperature data valid
  logic [7:0]  temp_data;                  // Temperature data
  // Initialization Block Signals
  pkt_t        init_pkt;                   // Initialization Block packet
  cmd_t        init_cmd;                   // Initialization Block comand
  logic        init_pkt_valid;             // Initialization Block packet valid
  logic        init_ck_en;                 // CK_t/CK_c enable signal
  logic        init_wck_en;                // WCK_t/WCK_c enable signal
  // PHY Inputs
  logic [7:0]  intf_ck_t;
  logic [7:0]  intf_cabi_n;
  logic [7:0]  intf_ca    [9:0];
  logic [7:0]  intf_wck_t;
  logic [7:0]  intf_dq    [15:0];
  logic [7:0]  intf_dbi_n [1:0];
  logic [7:0]  intf_cke_n;
  logic [7:0]  init_edc   [1:0];
  logic [7:0]  init_cke_n;
  // PHY Outputs
  logic [7:0]  phy_dq     [15:0];
  logic [7:0]  phy_dbi_n  [1:0];
  logic [7:0]  phy_edc    [1:0];
  logic        phy_rdy;
  // DQ/EDC Tristate Control Signals
  logic dq_tri;
  logic edc_tri;

  // ==================================== Clocking =====================================
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

  // ============================== Configuration Buffers ==============================
  logic [$bits(cfr_mode_t)-1:0] cfr_mode_p_d;
  logic [$bits(cfr_time_t)-1:0] cfr_time_p_d;
  logic [$bits(cfr_refr_t)-1:0] cfr_refr_p_d;
  logic [$bits(cfr_schd_t)-1:0] cfr_schd_p_d;

  always @(posedge clk_div, posedge rst_div)
    if (rst_div) begin
      cfr_mode_p_d <= cfr_mode_init;
      cfr_time_p_d <= cfr_time_init;
      cfr_refr_p_d <= cfr_refr_init;
      cfr_schd_p_d <= cfr_schd_init;
    end
    else begin
      cfr_mode_p_d <= cfr_mode_p;
      cfr_time_p_d <= cfr_time_p;
      cfr_refr_p_d <= cfr_refr_p;
      cfr_schd_p_d <= cfr_schd_p;
    end

  initial begin
    cfr_mode_p_d = cfr_mode_init;
    cfr_time_p_d = cfr_time_init;
    cfr_refr_p_d = cfr_refr_init;
    cfr_schd_p_d = cfr_schd_init;
  end

  // =================================== Scheduler =====================================
  aimc_sched aimc_sched (
    .clk        (aclk),
    .rst        (arst),
    // Configuration Register
    .cfr_mode_p (cfr_mode_p_d),
    .cfr_time_p (cfr_time_p_d),
    .cfr_refr_p (cfr_refr_p_d),
    .cfr_schd_p (cfr_schd_p_d),
    // User Interface
    .ui_pkt,
    .ui_pkt_valid,
    .sched_rdy,
    // Data Handler Interface
    .intf_pkt,
    .intf_pkt_retry,
    // Calibration Interface
    .cal_done,
    .cal_ref_stop,
    .ref_idle,
    // Command/Data Handler Interface
    .sched_pkt,
    .sched_cmd,
    .sched_pkt_valid,
    .intf_rdy,
    .temp_valid,
    .temp_data);

  // ============================= Bus Utilization Monitor =============================
  generate
    if (UTIL_MON_EN == "TRUE") begin
      util_mon util_mon (
        .clk       (aclk),
        .rst       (arst),
        .cmd       (sched_cmd),
        .cmd_valid (sched_pkt_valid),
        .mon_upd,
        .aimc_ca_util);
    end
    else begin
      assign aimc_ca_util = 0;
    end
  endgenerate

  // ============================ Initialization Handler ===============================
  gddr6_init aimc_init (
    .clk (aclk),
    .rst (arst),
    // Command Handler Interface
    .init_done,
    .init_ck_en,
    .init_wck_en,
    .init_pkt,
    .init_cmd,
    .init_pkt_valid,
    .intf_rdy,
    // PHY Interface
    .phy_rdy (phy_rdy_i),
    .edc_tri,
    .init_edc,
    .init_cke_n,
    // GDDR6 Interface
    .RESET_n);

  // ================================= PHY Entry Block =================================
  phy_entry aimc_phy_entry (
    .clk_div, 
    .rst_div,
    .aclk       (aclk),
    // Configuration Register
    .cfr_mode_p (cfr_mode_p_d),
    .cfr_time_p (cfr_time_p_d),
    .cfr_schd_p (cfr_schd_p_d),
    // Scheduler Interface
    .sched_pkt,
    .sched_cmd,
    .sched_pkt_valid,
    .intf_rdy,
    .intf_pkt_retry,
    .temp_valid,
    .temp_data,
    // UI Interface
    .intf_pkt,
    .intf_edc,
    .intf_pkt_valid,
    // Initializer Interface
    .init_done,
    .init_ck_en,
    .init_wck_en,
    .init_pkt,
    .init_cmd,
    .init_pkt_valid,
    // Calibration Handler Interface
    .cal_done,
    .cal_ck_en,
    .cal_wck_en,
    .cal_pkt,
    .cal_cmd,
    .cal_pkt_valid,
    .param_rl_del,
    // PHY Interface
    .intf_ck_t, 
    .intf_cke_n,
    .intf_ca,
    .intf_cabi_n,
    .intf_wck_t,
    .dq_tri,
    .intf_dq,
    .intf_dbi_n,
    .phy_dq,
    .phy_dbi_n,
    .phy_edc);

  // ==================================== XIPHY ========================================
  xiphy_wrapper #(.CH_IDX (CH_IDX)) aimc_phy (
    .clk_div,
    .rst_div,
    .clk_rx_fifo,
    .ub_rst_out,
    .mmcm_lock,
    .pll_gate,
    .pll_lock,
    .clk_riu,
    .rst_riu,
    // Command Handler Interface
    .intf_ck_t,
    .intf_ca,
    .intf_cabi_n,
    .intf_wck_t,
    // Data Handler Interface
    .tx_t      (edc_tri),
    .tbyte_in  (dq_tri),
    .intf_dq,
    .intf_dbi_n,
    .init_edc,
    .top_cke_n (init_done ? intf_cke_n : init_cke_n),
    .phy_dq,
    .phy_dbi_n,
    .phy_edc,
    // Calibration Interface
    .init_done,
    .phy_rdy,
    .param_vref_tune,
    .param_smpl_edge,
    .param_sync_ordr,
    .param_io_in_del,
    .param_io_out_del,
    // MCS-RIU Interface
    .riu_nibble,
    .riu_addr,
    .riu_rd_data,
    .riu_rd_strobe,
    .riu_wr_data,
    .riu_wr_strobe,
    .riu_valid,
    // GDDR6 Interface
    .CK_t,
    .CK_c,
    .CA,
    .CKE_n,
    .CABI_n,
    .WCK1_t,
    .WCK1_c,
    .WCK0_t,
    .WCK0_c,
    .DQ,
    .DBI_n,
    .EDC);

  // =============================== AIMC Output Signals ===============================
  assign aimc_pkt           = intf_pkt;
  assign aimc_rdy           = sched_rdy;
  assign aimc_pkt_valid     = intf_pkt_valid && cal_done && !intf_pkt_retry;
  // Calibration Handler Interface
  assign phy_rdy_o          = phy_rdy;
  assign aimc_cal_pkt       = intf_pkt;
  assign aimc_cal_edc       = intf_edc;
  assign aimc_cal_pkt_valid = intf_pkt_valid;
  assign aimc_temp_data     = temp_data;
  assign aimc_temp_valid    = temp_valid;
  assign aimc_cal_rdy       = intf_rdy;


endmodule
