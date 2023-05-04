`timescale 1ps / 1ps

module refr_timer (
  input  logic clk, rst,
  // Configuration Register
  input  logic [$bits(cfr_mode_t)-1:0] cfr_mode_p,
  input  logic [$bits(cfr_time_t)-1:0] cfr_time_p,
  // Arbiter Interface
  input  logic bkarb_cmd_valid,                   // Asserted when Bank Arbiter passes packet to the Command Handler
  input  cmd_t bkarb_cmd,                         // Memory command outputted from Bank Arbiter
  // Local Refresh Handler Interface
  input  cmd_t refh_cmd,                          // Command for timing inquiry
  output logic refh_t_pass);                      // Response to the inquiry
  
  // =================================== Internal Signals ===================================
  struct packed {dram_time_t MRS_TEMP, PREAB, REFAB;} delay, delay_nxt;
  logic      cmd_in;                              // Active command is available at the input
  cfr_mode_t cfr_mode;                            // Mode register parameter array
  cfr_time_t cfr_time;                            // Timing parameter array

  // ================================ Command Timing Update =================================
  assign cmd_in = bkarb_cmd_valid;

  assign cfr_mode = CONFIG_TIMING == "TRUE" ? cfr_mode_t'(cfr_mode_p) : cfr_mode_init;
  assign cfr_time = CONFIG_TIMING == "TRUE" ? cfr_time_t'(cfr_time_p) : cfr_time_init;

  always @(posedge clk, posedge rst)
    if (rst) delay <= 0;
    else     delay <= delay_nxt;

  always_comb begin
    delay_nxt.MRS_TEMP = upd_delay(.cur(delay.MRS_TEMP), .wait_t(0), .cmd_in(cmd_in));
    delay_nxt.PREAB    = upd_delay(.cur(delay.PREAB),    .wait_t(0), .cmd_in(cmd_in));
    delay_nxt.REFAB    = upd_delay(.cur(delay.REFAB),    .wait_t(0), .cmd_in(cmd_in));

    case (bkarb_cmd)
      ACT : begin
        delay_nxt.PREAB    = upd_delay(.cur(delay.PREAB),    .wait_t(cfr_time.tRAS),    .cmd_in(cmd_in));
      end
      RD : begin
        delay_nxt.PREAB    = upd_delay(.cur(delay.PREAB),    .wait_t(cfr_time.tRTP),    .cmd_in(cmd_in));
        delay_nxt.REFAB    = upd_delay(.cur(delay.REFAB),    .wait_t(cfr_mode.RL+BL),   .cmd_in(cmd_in));
      end
      WDM : begin
        delay_nxt.PREAB    = upd_delay(.cur(delay.PREAB),    .wait_t(cfr_mode.WL+2+cfr_time.tWR), .cmd_in(cmd_in));
      end
      PREAB : begin
        delay_nxt.REFAB    = upd_delay(.cur(delay.REFAB),    .wait_t(cfr_time.tRP),     .cmd_in(cmd_in));
      end
      REFAB : begin
        delay_nxt.MRS_TEMP = upd_delay(.cur(delay.MRS_TEMP), .wait_t(cfr_time.tKO   ),  .cmd_in(cmd_in));  // Temperature read is allowed tKO following the REFAB command
        delay_nxt.REFAB    = upd_delay(.cur(delay.REFAB),    .wait_t(cfr_time.tRFCab),  .cmd_in(cmd_in));
      end
      PREPB : begin
        delay_nxt.PREAB    = upd_delay(.cur(delay.PREAB),    .wait_t(cfr_time.tRP),     .cmd_in(cmd_in));
        delay_nxt.REFAB    = upd_delay(.cur(delay.REFAB),    .wait_t(cfr_time.tRP),     .cmd_in(cmd_in));
      end
      REFPB : begin
        delay_nxt.PREAB    = upd_delay(.cur(delay.PREAB),    .wait_t(cfr_time.tRFCpb),  .cmd_in(cmd_in));
        delay_nxt.REFAB    = upd_delay(.cur(delay.REFAB),    .wait_t(cfr_time.tRFCpb),  .cmd_in(cmd_in));
      end
      MRS, NDMX : begin
        delay_nxt.PREAB    = upd_delay(.cur(delay.PREAB),    .wait_t(cfr_time.tMOD),    .cmd_in(cmd_in));
        delay_nxt.REFAB    = upd_delay(.cur(delay.REFAB),    .wait_t(cfr_time.tMOD),    .cmd_in(cmd_in));
      end
      MRS_TEMP : begin
        delay_nxt.MRS_TEMP = upd_delay(.cur(delay.MRS_TEMP), .wait_t(cfr_time.tWRIDON), .cmd_in(cmd_in));
      end
    endcase
  end

  // Function for updating timing variables equally for all banks
  function automatic dram_time_t upd_delay;
    input dram_time_t cur;     // Current timer value
    input dram_time_t wait_t;  // Inter-command timing value
    input logic cmd_in;

    dram_time_t tmp1, tmp2;
    begin
      tmp1 = ck_adj(wait_t);
      tmp2 = (cur == 0) ? 0 : cur - 1;
      if (cmd_in) upd_delay = (tmp1 > tmp2) ? tmp1 : tmp2;
      else        upd_delay = tmp2;
    end
  endfunction

  // Function for ajusting timing values to match module specifics
  function automatic dram_time_t ck_adj;
    input dram_time_t t;

    dram_time_t t0;
    begin
      if (SCHED_STYLE == "FRFCFS") begin
        if (t > 2) ck_adj = t - 2;  // In the current desing, there is always at least 2 CK (one NOP) delay between the same bank commands
        else       ck_adj = 0;
      end
      else if (SCHED_STYLE == "FIFO") begin
        if (GLOBAL_CLK == "CK_DIV2") t0 = (t >> 1) + t[0];  // Always rounding up
        else                         t0 = t;

        if   (t0 > 1) ck_adj = t0 - 1;
        else          ck_adj = 0/*t0*/;
      end
    end
  endfunction

  // ================================ Command Timing Inquiry ================================
  always_comb begin
    refh_t_pass = 0;
    case (refh_cmd)
      MRS_TEMP : refh_t_pass = delay_nxt.MRS_TEMP == 0;
      PREAB    : refh_t_pass = delay_nxt.PREAB    == 0;
      REFAB    : refh_t_pass = delay_nxt.REFAB    == 0;
    endcase
  end

  // ==================================== Initialization ====================================
  initial begin
    delay = 0;
  end

endmodule
