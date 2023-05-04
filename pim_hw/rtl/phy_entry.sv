`timescale 1ps / 1ps

module phy_entry (
  input  logic clk_div,
  input  logic rst_div,
  input  logic aclk,
  // Configuration Register
  input  logic [$bits(cfr_mode_t)-1:0] cfr_mode_p,
  input  logic [$bits(cfr_time_t)-1:0] cfr_time_p,
  input  logic [$bits(cfr_schd_t)-1:0] cfr_schd_p,
  // Scheduler Interface
  input  pkt_t sched_pkt,
  input  cmd_t sched_cmd,
  input  logic sched_pkt_valid,
  output logic intf_rdy,
  output logic intf_pkt_retry,
  output logic temp_valid,
  output logic [7:0] temp_data,
  // User Interface
  output pkt_t intf_pkt,
  output logic [31:0] intf_edc,
  output logic intf_pkt_valid,
  // Initializer Interface
  input  logic init_done,
  input  logic init_ck_en,
  input  logic init_wck_en,
  input  pkt_t init_pkt,
  input  cmd_t init_cmd,
  input  logic init_pkt_valid,
  // Calibration Handler Interface
  input  logic cal_done,
  input  logic cal_ck_en,
  input  logic cal_wck_en,
  input  pkt_t cal_pkt,
  input  cmd_t cal_cmd,
  input  logic cal_pkt_valid,
  input  logic [2:0] param_rl_del,
  // Command Interface
  output logic [7:0] intf_ck_t,
  output logic [7:0] intf_cke_n,
  output logic [7:0] intf_ca [9:0],
  output logic [7:0] intf_cabi_n,
  // Data Interface
  output logic [7:0] intf_wck_t,
  output logic dq_tri,
  output logic [7:0] intf_dq    [15:0],
  output logic [7:0] intf_dbi_n [1:0],
  input  logic [7:0] phy_dq     [15:0],
  input  logic [7:0] phy_dbi_n  [1:0],
  input  logic [7:0] phy_edc    [1:0]);

  // ================================ Internal Signals =================================
  // Command/Data Handlers
  pkt_t pkt;                  // Packet received from Initializer, Scheduler, or Calibration Handler
  cmd_t cmd;
  logic pkt_valid;            // Packet valid signal
  logic ck_en;                // CK_t/CK_c enable signal
  logic wck_en;               // WCK_t/WCK_c enable signal
  // Data Handler Interface Signals (required for inserting clkdiv2_sync module)
  logic intf_pkt_valid_dh;
  logic intf_pkt_retry_dh;
  pkt_t intf_pkt_dh;
  logic [31:0] intf_edc_dh;
  logic temp_valid_dh;
  logic [7:0] temp_data_dh;
  logic pkt_valid_dh;
  pkt_t pkt_dh;
  cmd_t cmd_dh;
  // Input Signal Syncrhonized to CKDIV2 Domain
  logic cal_done_sync;
  logic ck_en_sync;
  logic wck_en_sync;
  logic pkt_valid_sync;
  cmd_t cmd_sync;
  pkt_t pkt_sync;
  logic [$bits(cfr_mode_t)-1:0] cfr_mode_p_sync;
  logic [$bits(cfr_time_t)-1:0] cfr_time_p_sync;
  logic [$bits(cfr_schd_t)-1:0] cfr_schd_p_sync;

  // =================================== Packet MUX ====================================
  always @(posedge aclk) pkt       <= init_done ? (cal_done ? sched_pkt       : cal_pkt  )     : init_pkt;
  always @(posedge aclk) cmd       <= init_done ? (cal_done ? sched_cmd       : cal_cmd  )     : init_cmd;
  always @(posedge aclk) pkt_valid <= init_done ? (cal_done ? sched_pkt_valid : cal_pkt_valid) : init_pkt_valid;
  always @(posedge aclk) ck_en     <= init_done ? cal_ck_en  : init_ck_en;   // After initialization the control over the clocks is passed to the calibration handler
  always @(posedge aclk) wck_en    <= init_done ? cal_wck_en : init_wck_en;

  initial begin
    pkt       = 0;
    cmd       = cmd_t'(0);
    pkt_valid = 0;
    ck_en     = 0;
    wck_en    = 0;
  end

  // ================================ Command Handler ==================================
  cmd_handler cmd_handler (
    .clk        (clk_div),
    .rst        (rst_div),
    // Configuration Register
    .cfr_mode_p (cfr_mode_p_sync),
    // Initializer/Scheduler/Calibration Interface
    .pkt        (pkt_sync),
    .cmd        (cmd_sync),
    .pkt_valid  (pkt_valid_sync),
    .ck_en      (ck_en_sync), 
    .wck_en     (wck_en_sync),
    .intf_rdy,
    // PHY Interface
    .intf_ck_t,
    .intf_wck_t,
    .intf_cke_n,
    .intf_ca,
    .intf_cabi_n);

  // ================================== Data Handler ===================================
  data_handler data_handler (
    .clk            (clk_div),
    .rst            (rst_div),
    .cal_done       (cal_done_sync),
    // Configuration Register
    .cfr_mode_p     (cfr_mode_p_sync),
    .cfr_time_p     (cfr_time_p_sync),
    .cfr_schd_p     (cfr_schd_p_sync),
    // Initializer/Scheduler/Calibration Interface
    .pkt            (pkt_sync),
    .cmd            (cmd_sync),
    .pkt_valid      (pkt_valid_sync),
    .intf_pkt_retry (intf_pkt_retry_dh),
    .param_rl_del,
    .temp_valid     (temp_valid_dh),
    .temp_data      (temp_data_dh),
    // UI Interface
    .intf_pkt_valid (intf_pkt_valid_dh),
    .intf_pkt       (intf_pkt_dh),
    .intf_edc       (intf_edc_dh),
    // PHY Interface
    .dq_tri,
    .intf_dq,
    .intf_dbi_n,
    .phy_dq,
    .phy_dbi_n,
    .phy_edc);

  generate
    if (GLOBAL_CLK == "CK_DIV2") begin
      clkdiv2_sync clkdiv2_sync (
        .clk (clk_div),
        .rst (rst_div),
        // PHY Input Signals
        .cal_done,
        .ck_en,
        .wck_en,
        .pkt_valid,
        .cmd,
        .pkt,
        .cfr_mode_p,
        .cfr_time_p,
        .cfr_schd_p,
        // Command/Data Handler Input Signals
        .cal_done_sync,
        .ck_en_sync,
        .wck_en_sync,
        .pkt_valid_sync,
        .cmd_sync,
        .pkt_sync,
        .cfr_mode_p_sync,
        .cfr_time_p_sync,
        .cfr_schd_p_sync,
        // Data Handler Output Signals
        .intf_pkt_valid_dh,
        .intf_pkt_retry_dh,
        .intf_pkt_dh,
        .intf_edc_dh,
        .temp_valid_dh,
        .temp_data_dh,
        // PHY Output Signals
        .intf_pkt_valid,
        .intf_pkt_retry,
        .intf_pkt,
        .intf_edc,
        .temp_valid,
        .temp_data);
    end
    else if (GLOBAL_CLK == "CK_DIV1") begin
      assign intf_pkt_valid  = intf_pkt_valid_dh;
      assign intf_pkt_retry  = intf_pkt_retry_dh;
      assign intf_pkt        = intf_pkt_dh;
      assign intf_edc        = intf_edc_dh;
      assign temp_valid      = temp_valid_dh;
      assign temp_data       = temp_data_dh;
      assign cal_done_sync   = cal_done;
      assign ck_en_sync      = ck_en;
      assign wck_en_sync     = wck_en;
      assign pkt_valid_sync  = pkt_valid;
      assign cmd_sync        = cmd;
      assign pkt_sync        = pkt;
      assign cfr_mode_p_sync = cfr_mode_p;
      assign cfr_time_p_sync = cfr_time_p;
      assign cfr_schd_p_sync = cfr_schd_p;
    end
  endgenerate

endmodule
