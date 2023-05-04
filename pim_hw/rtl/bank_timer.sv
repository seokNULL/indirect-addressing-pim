`timescale 1ps / 1ps

import aimc_lib::*;

module bank_timer #(parameter BANK_INDEX = 0) (
  input  logic clk, rst,
  // Configuration Register
  input  logic [$bits(cfr_mode_t)-1:0] cfr_mode_p,
  input  logic [$bits(cfr_time_t)-1:0] cfr_time_p,
  // Arbiter Interface
  input  logic bkarb_cmd_valid,                   // Asserted when Bank Arbiter passes packet to the Command Handler
  input  cmd_t bkarb_cmd,                         // Memory command outputted from Bank Arbiter
  input  logic [BK_ADDR_WIDTH-1:0] bkarb_cmd_bk,  // Target bank address for the memory command
  // Bank Engine Interface
  input  cmd_t bke_cmd,                           // Command for timing inquiry
  output logic bke_t_pass);                       // Response to the inquiry
  
  // =================================== Internal Signals ===================================
  struct packed {dram_time_t ACT, PREPB, RD, WDM, REFPB;} delay, delay_nxt;
  logic      same_bk;                             // Indicates whether the command selected by the arbiter belongs to the same bank as the bank_engine
  logic      cmd_in;                              // Active command is available at the input
  cfr_mode_t cfr_mode;                            // Mode register parameter array
  cfr_time_t cfr_time;                            // Timing parameter array

  // ================================ Command Timing Update =================================
  assign same_bk = bkarb_cmd_bk == BANK_INDEX[3:0];
  assign cmd_in  = bkarb_cmd_valid;

  assign cfr_mode = CONFIG_TIMING == "TRUE" ? cfr_mode_t'(cfr_mode_p) : cfr_mode_init;
  assign cfr_time = CONFIG_TIMING == "TRUE" ? cfr_time_t'(cfr_time_p) : cfr_time_init;

  always @(posedge clk, posedge rst)
    if (rst) delay <= 0;
    else     delay <= delay_nxt;

  always_comb begin
    delay_nxt.ACT   = upd_delay (.cur(delay.ACT  ), .wait_t(0), .cmd_in(cmd_in));
    delay_nxt.PREPB = upd_delay (.cur(delay.PREPB), .wait_t(0), .cmd_in(cmd_in));
    delay_nxt.RD    = upd_delay (.cur(delay.RD   ), .wait_t(0), .cmd_in(cmd_in));
    delay_nxt.WDM   = upd_delay (.cur(delay.WDM  ), .wait_t(0), .cmd_in(cmd_in));
    delay_nxt.REFPB = upd_delay (.cur(delay.REFPB), .wait_t(0), .cmd_in(cmd_in));

    case (bkarb_cmd)
      ACT : begin
        delay_nxt.ACT   = upd_delay    (.cur(delay.ACT  ), .wait_t(cfr_time.tRRD  ),                                               .cmd_in(cmd_in));
        delay_nxt.PREPB = upd_delay_bk (.cur(delay.PREPB), .same_t(cfr_time.tRAS  ), .other_t(0              ), .same_bk(same_bk), .cmd_in(cmd_in));
        delay_nxt.RD    = upd_delay_bk (.cur(delay.RD   ), .same_t(cfr_time.tRCDRD), .other_t(0              ), .same_bk(same_bk), .cmd_in(cmd_in));
        delay_nxt.WDM   = upd_delay_bk (.cur(delay.WDM  ), .same_t(cfr_time.tRCDWR), .other_t(0              ), .same_bk(same_bk), .cmd_in(cmd_in));
        delay_nxt.REFPB = upd_delay_bk (.cur(delay.REFPB), .same_t(cfr_time.tRC   ), .other_t(cfr_time.tRRD  ), .same_bk(same_bk), .cmd_in(cmd_in));
      end
      PREPB : begin
        delay_nxt.ACT   = upd_delay_bk (.cur(delay.ACT  ), .same_t(cfr_time.tRP   ), .other_t(0              ), .same_bk(same_bk), .cmd_in(cmd_in));
        delay_nxt.PREPB = upd_delay    (.cur(delay.PREPB), .wait_t(cfr_time.tPPD  ),                                               .cmd_in(cmd_in));
        delay_nxt.RD    = upd_delay    (.cur(delay.RD   ), .wait_t(0              ),                                               .cmd_in(cmd_in));
        delay_nxt.WDM   = upd_delay    (.cur(delay.WDM  ), .wait_t(0              ),                                               .cmd_in(cmd_in));
        delay_nxt.REFPB = upd_delay_bk (.cur(delay.REFPB), .same_t(cfr_time.tRP   ), .other_t(0              ), .same_bk(same_bk), .cmd_in(cmd_in));
      end
      PREAB : begin
        delay_nxt.ACT   = upd_delay    (.cur(delay.ACT  ), .wait_t(cfr_time.tRP   ),                                               .cmd_in(cmd_in));
        delay_nxt.REFPB = upd_delay    (.cur(delay.WDM  ), .wait_t(cfr_time.tRP   ),                                               .cmd_in(cmd_in));
      end
      RD : begin
        delay_nxt.ACT   = upd_delay    (.cur(delay.ACT  ), .wait_t(0              ),                                               .cmd_in(cmd_in));
        delay_nxt.PREPB = upd_delay_bk (.cur(delay.PREPB), .same_t(cfr_time.tRTP  ), .other_t(0              ), .same_bk(same_bk), .cmd_in(cmd_in));
        delay_nxt.RD    = upd_delay    (.cur(delay.RD   ), .wait_t(cfr_time.tCCD  ),                                               .cmd_in(cmd_in));
        delay_nxt.WDM   = upd_delay    (.cur(delay.WDM  ), .wait_t(cfr_time.tRTW  ),                                               .cmd_in(cmd_in));
        delay_nxt.REFPB = upd_delay    (.cur(delay.REFPB), .wait_t(0              ),                                               .cmd_in(cmd_in));
      end
      WDM : begin
        delay_nxt.ACT   = upd_delay    (.cur(delay.ACT  ), .wait_t(0              ),                                               .cmd_in(cmd_in));
        delay_nxt.PREPB = upd_delay_bk (.cur(delay.PREPB), .same_t(cfr_mode.WL+BL+cfr_time.tWR ), .other_t(0 ), .same_bk(same_bk), .cmd_in(cmd_in));
        delay_nxt.RD    = upd_delay    (.cur(delay.RD   ), .wait_t(cfr_mode.WL+BL+cfr_time.tWTR),                                  .cmd_in(cmd_in));
        delay_nxt.WDM   = upd_delay    (.cur(delay.WDM  ), .wait_t(cfr_time.tCCD  ),                                               .cmd_in(cmd_in));
        delay_nxt.REFPB = upd_delay    (.cur(delay.REFPB), .wait_t(0              ),                                               .cmd_in(cmd_in));
      end
      REFPB : begin
        delay_nxt.ACT   = upd_delay_bk (.cur(delay.ACT  ), .same_t(cfr_time.tRFCpb), .other_t(cfr_time.tRREFD), .same_bk(same_bk), .cmd_in(cmd_in));
        delay_nxt.PREPB = upd_delay    (.cur(delay.PREPB), .wait_t(0              ),                                               .cmd_in(cmd_in));
        delay_nxt.RD    = upd_delay    (.cur(delay.RD   ), .wait_t(0              ),                                               .cmd_in(cmd_in));
        delay_nxt.WDM   = upd_delay    (.cur(delay.WDM  ), .wait_t(0              ),                                               .cmd_in(cmd_in));
        delay_nxt.REFPB = upd_delay    (.cur(delay.REFPB), .wait_t(cfr_time.tRFCpb),                                               .cmd_in(cmd_in));
      end
      REFAB : begin
        delay_nxt.ACT   = upd_delay    (.cur(delay.ACT  ), .wait_t(cfr_time.tRFCab),                                               .cmd_in(cmd_in));
        delay_nxt.REFPB = upd_delay    (.cur(delay.REFPB), .wait_t(cfr_time.tRFCab),                                               .cmd_in(cmd_in));
      end
       MRS, NDMX : begin
        delay_nxt.ACT   = upd_delay    (.cur(delay.ACT  ), .wait_t(cfr_time.tMOD  ),                                               .cmd_in(cmd_in));
        delay_nxt.REFPB = upd_delay    (.cur(delay.REFPB), .wait_t(cfr_time.tMOD  ),                                               .cmd_in(cmd_in));
      end
    endcase
  end

  // Function for updating timing variables (different timings for the same and different banks)
  function automatic dram_time_t upd_delay_bk;
    input dram_time_t cur;              // Current timer value
    input dram_time_t same_t, other_t;  // Command timing values for the same and different banks
    input logic same_bk;
    input logic cmd_in;

    dram_time_t tmp1, tmp2;
    begin
      if (same_bk) tmp1 = ck_adj(same_t);
      else         tmp1 = ck_adj(other_t);
      tmp2 = (cur == 0) ? 0 : cur - 1;
      if (cmd_in) upd_delay_bk = (tmp1 > tmp2) ? tmp1 : tmp2;
      else        upd_delay_bk = tmp2;
    end
  endfunction

  // Function for updating timing variables (same timings for the same and different banks)
  function automatic dram_time_t upd_delay;
    input dram_time_t cur;     // Current timer value
    input dram_time_t wait_t;  // Command timing value
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
    bke_t_pass = 0;
    case (bke_cmd)
      ACT     : bke_t_pass = delay_nxt.ACT   == 0;
      PREPB   : bke_t_pass = delay_nxt.PREPB == 0;
      RD      : bke_t_pass = delay_nxt.RD    == 0;
      WDM     : bke_t_pass = delay_nxt.WDM   == 0;
      REFPB   : bke_t_pass = delay_nxt.REFPB == 0;
    endcase
  end

  // ==================================== Initialization ====================================
  initial begin
    delay = 0;
  end

endmodule
