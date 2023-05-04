`timescale 1ps / 1ps

import aimc_lib::*;

module clkdiv2_sync (
  input  logic clk,
  input  logic rst,
  // PHY Input Signals
  input  logic cal_done,
  input  logic ck_en,
  input  logic wck_en,
  input  logic pkt_valid,
  input  cmd_t cmd,
  input  pkt_t pkt,
  input  logic [$bits(cfr_mode_t)-1:0] cfr_mode_p,
  input  logic [$bits(cfr_time_t)-1:0] cfr_time_p,
  input  logic [$bits(cfr_schd_t)-1:0] cfr_schd_p,
  // Command/Data Handler Input Signals
  output logic cal_done_sync,
  output logic ck_en_sync,
  output logic wck_en_sync,
  output logic pkt_valid_sync,
  output cmd_t cmd_sync,
  output pkt_t pkt_sync,
  output logic [$bits(cfr_mode_t)-1:0] cfr_mode_p_sync,
  output logic [$bits(cfr_time_t)-1:0] cfr_time_p_sync,
  output logic [$bits(cfr_schd_t)-1:0] cfr_schd_p_sync,
  // Data Handler Output Signals
  input  logic intf_pkt_valid_dh,
  input  logic intf_pkt_retry_dh,
  input  pkt_t intf_pkt_dh,
  input  logic [31:0] intf_edc_dh,
  input  logic temp_valid_dh,
  input  logic [7:0] temp_data_dh,
  // PHY Output Signals
  output logic intf_pkt_valid,
  output logic intf_pkt_retry,
  output pkt_t intf_pkt,
  output logic [31:0] intf_edc,
  output logic temp_valid,
  output logic [7:0] temp_data);
  
  // ============================== Signal Declarations =============================
  logic pkt_valid_buf;
  cmd_t cmd_buf;
  logic skip_cycle;                             // Signal for skipping every second pkt_valid cycle when synchronization from slower to faster clock domain is required
  logic pkt_hold;                               // Signal for holding response packets for two fast clock cycles
  logic temp_hold;                              // Signal for holding temperature data for two fast clock cycles
  // Synchronization Signals
  logic slow_clk_locked;                        // Signal indicating that the slower (system) clock has been corectly replicated by slow_clk_copy
  logic slow_clk_copy;                          // Replica of the slower (system) clock
  logic add_cycle_pkt;                          // Indicator for adding one additional fast cycle to make sure output packet is in sync with positive slow clock edge (need for multicycle_path constraint)
  logic add_cycle_temp;
  logic intf_pkt_valid_d0, intf_pkt_valid_d1;
  logic intf_pkt_retry_d0, intf_pkt_retry_d1;
  pkt_t intf_pkt_d0,       intf_pkt_d1;
  logic [31:0] intf_edc_d0, intf_edc_d1;
  logic temp_valid_d0,     temp_valid_d1;
  logic [7:0]  temp_data_d0, temp_data_d1;

  // ============================= Slow -> Fast CLK Sync ============================
  always @(posedge clk, posedge rst)
    if (rst) begin
      cal_done_sync   <= 0;
      ck_en_sync      <= 0;
      wck_en_sync     <= 0;
      cfr_mode_p_sync <= cfr_mode_init;
      cfr_time_p_sync <= cfr_time_init;
      cfr_schd_p_sync <= cfr_schd_init;
    end
    else if (slow_clk_copy) begin
      cal_done_sync   <= cal_done;
      ck_en_sync      <= ck_en;
      wck_en_sync     <= wck_en;
      cfr_mode_p_sync <= cfr_mode_p;
      cfr_time_p_sync <= cfr_time_p;
      cfr_schd_p_sync <= cfr_schd_p;
    end

  always @(posedge clk)
    if (slow_clk_copy) pkt_sync <= pkt;

  // Buffered command and packet validity values (before additional manipulation)
  always @(posedge clk, posedge rst)
    if (rst) begin
      pkt_valid_buf <= 0;
      cmd_buf       <= NOP1;
    end
    else if (slow_clk_copy) begin
      pkt_valid_buf <= pkt_valid;
      cmd_buf       <= cmd;
    end

  // Additional signal manipulation required for skipping every second command
  always @(posedge clk, posedge rst)
    if      (rst)                         skip_cycle <= 0;
    else if (pkt_valid_buf || skip_cycle) skip_cycle <= !skip_cycle;

  assign pkt_valid_sync = (!skip_cycle || cmd_buf == CONF) ? pkt_valid_buf : 0;   // Continuously apply CONF CA configuration during reset
  assign cmd_sync       = (!skip_cycle || cmd_buf == CONF) ? cmd_buf : NOP1;      // Don't switch to NOP1 during configuration/reset stage

  // ============================= Fast -> Slow CLK Sync ============================
  // Making a copy of the slower (system) clock
  always @(posedge clk, posedge rst)
    if      (rst)       slow_clk_locked <= 0;
    else if (pkt_valid) slow_clk_locked <= 1;

  always @(posedge clk)
    if (!slow_clk_locked) slow_clk_copy <= 0;
    else                  slow_clk_copy <= !slow_clk_copy;

  always @(posedge clk) begin
    intf_pkt_valid_d0 <= intf_pkt_valid_dh;
    intf_pkt_retry_d0 <= intf_pkt_retry_dh;
    temp_valid_d0     <= temp_valid_dh;
  end

  always @(posedge clk) begin
    if (slow_clk_copy) begin
      intf_pkt_valid <= intf_pkt_valid_dh || intf_pkt_valid_d0;  // "||" is to make sure validity holds for 2 clock cycles (it will be only captured once due to slow_clk_copy)
      intf_pkt_retry <= intf_pkt_retry_dh || intf_pkt_retry_d0;
      intf_pkt       <= intf_pkt_dh;
      intf_edc       <= intf_edc_dh;
      temp_valid     <= temp_valid_dh || temp_valid_d0;
      temp_data      <= temp_data_dh;
    end
  end

  // ================================ Initialization ================================
  initial begin
    cal_done_sync     = 0;
    ck_en_sync        = 0;
    wck_en_sync       = 0;
    pkt_sync          = 0;
    cfr_mode_p_sync   = cfr_mode_init;
    cfr_time_p_sync   = cfr_time_init;
    cfr_schd_p_sync   = cfr_schd_init;
    pkt_valid_buf     = 0;
    cmd_buf           = NOP1;
    skip_cycle        = 0;
    slow_clk_locked   = 0;
    slow_clk_copy     = 0;
    intf_pkt_valid_d0 = 0;
    intf_pkt_retry_d0 = 0;
    intf_pkt_d0       = 0;
    intf_edc_d0       = 0;
    temp_valid_d0     = 0;
    temp_data_d0      = 0;
    intf_pkt_valid_d1 = 0;
    intf_pkt_retry_d1 = 0;
    intf_pkt_d1       = 0;
    intf_edc_d1       = 0;
    temp_valid_d1     = 0;
    temp_data_d1      = 0;
    intf_pkt_valid    = 0;
    intf_pkt_retry    = 0;
    intf_pkt          = 0;
    intf_edc          = 0;
    temp_valid        = 0;
    temp_data         = 0;
  end

endmodule