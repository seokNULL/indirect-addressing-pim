`timescale 1ps / 1ps

module aim_timer (
  input  logic clk, rst,
  // Configuration Register
  input  logic [$bits(cfr_mode_t)-1:0] cfr_mode_p,
  input  logic [$bits(cfr_time_t)-1:0] cfr_time_p,
  // Arbiter Interface
  input  logic bkarb_cmd_valid,                   // Asserted when Bank Arbiter passes packet to the Command Handler
  input  cmd_t bkarb_cmd,                         // Memory command outputted from Bank Arbiter
  // Bank Engine Interface
  input  cmd_t aime_cmd,                          // Command for timing inquiry
  output logic aime_t_pass);                      // Response to the inquiry
  
  // =================================== Internal Signals ===================================
  struct packed {dram_time_t ACT, MACSB, RDCP, WRCP, PREPB,                                  // Single bank commands
                             ACT16, MACAB, WRBK, EWMUL, ACTAF16, AF, PREAB,                  // All bank commands
                             NDME, NDMX, MRS, WRGB, WRBIAS, RDMAC, RDAF;} delay, delay_nxt;  // NDM based commands
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
    // Single Bank Commands
    delay_nxt.ACT     = upd_delay(.cur(delay.ACT    ), .wait_t(0), .cmd_in(cmd_in));
    delay_nxt.MACSB   = upd_delay(.cur(delay.MACSB  ), .wait_t(0), .cmd_in(cmd_in));
    delay_nxt.RDCP    = upd_delay(.cur(delay.RDCP   ), .wait_t(0), .cmd_in(cmd_in));
    delay_nxt.WRCP    = upd_delay(.cur(delay.WRCP   ), .wait_t(0), .cmd_in(cmd_in));
    delay_nxt.PREPB   = upd_delay(.cur(delay.PREPB  ), .wait_t(0), .cmd_in(cmd_in));
    // All Bank Commands
    delay_nxt.ACT16   = upd_delay(.cur(delay.ACT16  ), .wait_t(0), .cmd_in(cmd_in));
    delay_nxt.MACAB   = upd_delay(.cur(delay.MACAB  ), .wait_t(0), .cmd_in(cmd_in));
    delay_nxt.WRBK    = upd_delay(.cur(delay.WRBK   ), .wait_t(0), .cmd_in(cmd_in));
    delay_nxt.EWMUL   = upd_delay(.cur(delay.EWMUL  ), .wait_t(0), .cmd_in(cmd_in));
    delay_nxt.ACTAF16 = upd_delay(.cur(delay.ACTAF16), .wait_t(0), .cmd_in(cmd_in));
    delay_nxt.AF      = upd_delay(.cur(delay.AF     ), .wait_t(0), .cmd_in(cmd_in));
    delay_nxt.PREAB   = upd_delay(.cur(delay.PREAB  ), .wait_t(0), .cmd_in(cmd_in));
    // NDM Based Commands
    delay_nxt.NDME    = upd_delay(.cur(delay.NDME   ), .wait_t(0), .cmd_in(cmd_in));
    delay_nxt.NDMX    = upd_delay(.cur(delay.NDMX   ), .wait_t(0), .cmd_in(cmd_in));
    delay_nxt.MRS     = upd_delay(.cur(delay.MRS    ), .wait_t(0), .cmd_in(cmd_in));
    delay_nxt.WRGB    = upd_delay(.cur(delay.WRGB   ), .wait_t(0), .cmd_in(cmd_in));
    delay_nxt.WRBIAS  = upd_delay(.cur(delay.WRBIAS ), .wait_t(0), .cmd_in(cmd_in));
    delay_nxt.RDMAC   = upd_delay(.cur(delay.RDMAC  ), .wait_t(0), .cmd_in(cmd_in));
    delay_nxt.RDAF    = upd_delay(.cur(delay.RDAF   ), .wait_t(0), .cmd_in(cmd_in));
    case (bkarb_cmd)
      // Single Bank Commands
      RD : begin
        delay_nxt.PREAB   = upd_delay(.cur(delay.PREAB  ), .wait_t(cfr_time.tRTP  ), .cmd_in(cmd_in));
      end
      WDM : begin
        delay_nxt.PREAB   = upd_delay(.cur(delay.PREAB  ), .wait_t(cfr_mode.WL+BL+cfr_time.tWR), .cmd_in(cmd_in));
      end
      ACT : begin
        delay_nxt.MACSB   = upd_delay(.cur(delay.MACSB  ), .wait_t(cfr_time.tRCDRD), .cmd_in(cmd_in));
        delay_nxt.RDCP    = upd_delay(.cur(delay.RDCP   ), .wait_t(cfr_time.tRCDRD), .cmd_in(cmd_in));
        delay_nxt.WRCP    = upd_delay(.cur(delay.WRCP   ), .wait_t(cfr_time.tRCDWR), .cmd_in(cmd_in));
        delay_nxt.PREPB   = upd_delay(.cur(delay.PREPB  ), .wait_t(cfr_time.tRAS  ), .cmd_in(cmd_in));
        delay_nxt.PREAB   = upd_delay(.cur(delay.PREPB  ), .wait_t(cfr_time.tRAS  ), .cmd_in(cmd_in));
      end
      MACSB : begin
        delay_nxt.MACSB   = upd_delay(.cur(delay.MACSB  ), .wait_t(cfr_time.tCCD  ), .cmd_in(cmd_in));
        delay_nxt.PREPB   = upd_delay(.cur(delay.PREPB  ), .wait_t(cfr_time.tMACD ), .cmd_in(cmd_in));
        delay_nxt.PREAB   = upd_delay(.cur(delay.PREAB  ), .wait_t(cfr_time.tMACD ), .cmd_in(cmd_in));
      end
      RDCP : begin
        delay_nxt.RDCP    = upd_delay(.cur(delay.RDCP   ), .wait_t(cfr_time.tCCD  ), .cmd_in(cmd_in));
        delay_nxt.PREPB   = upd_delay(.cur(delay.PREPB  ), .wait_t(cfr_time.tRDCPD), .cmd_in(cmd_in));
        delay_nxt.PREAB   = upd_delay(.cur(delay.PREAB  ), .wait_t(cfr_time.tRDCPD), .cmd_in(cmd_in));
      end
      WRCP : begin
        delay_nxt.WRCP    = upd_delay(.cur(delay.WRCP   ), .wait_t(cfr_time.tCCD  ), .cmd_in(cmd_in));
        delay_nxt.PREPB   = upd_delay(.cur(delay.PREPB  ), .wait_t(cfr_mode.WL+BL+cfr_time.tWR), .cmd_in(cmd_in));
        delay_nxt.PREAB   = upd_delay(.cur(delay.PREAB  ), .wait_t(cfr_mode.WL+BL+cfr_time.tWR), .cmd_in(cmd_in));
      end
      PREPB, PREAB : begin
        delay_nxt.MRS     = upd_delay(.cur(delay.MRS    ), .wait_t(cfr_time.tRP   ), .cmd_in(cmd_in));
        delay_nxt.NDME    = upd_delay(.cur(delay.NDME   ), .wait_t(cfr_time.tRP   ), .cmd_in(cmd_in));
        delay_nxt.ACT     = upd_delay(.cur(delay.ACT    ), .wait_t(cfr_time.tRP   ), .cmd_in(cmd_in));
        delay_nxt.ACT16   = upd_delay(.cur(delay.ACT16  ), .wait_t(cfr_time.tRP   ), .cmd_in(cmd_in));
        delay_nxt.ACTAF16 = upd_delay(.cur(delay.ACTAF16), .wait_t(cfr_time.tRP   ), .cmd_in(cmd_in));
      end
      // All Bank Commands
      REFPB, REFAB : begin
        delay_nxt.MRS     = upd_delay(.cur(delay.MRS    ), .wait_t(cfr_time.tRFCab), .cmd_in(cmd_in));
        delay_nxt.NDME    = upd_delay(.cur(delay.NDME   ), .wait_t(cfr_time.tRFCab), .cmd_in(cmd_in));
        delay_nxt.ACT     = upd_delay(.cur(delay.ACT    ), .wait_t(cfr_time.tRFCab), .cmd_in(cmd_in));
        delay_nxt.ACT16   = upd_delay(.cur(delay.ACT16  ), .wait_t(cfr_time.tRFCab), .cmd_in(cmd_in));
        delay_nxt.ACTAF16 = upd_delay(.cur(delay.ACTAF16), .wait_t(cfr_time.tRFCab), .cmd_in(cmd_in));
      end
      ACT16 : begin
        delay_nxt.MACAB   = upd_delay(.cur(delay.MACAB  ), .wait_t(cfr_time.tRCDRDL), .cmd_in(cmd_in));
        delay_nxt.WRBK    = upd_delay(.cur(delay.WRBK   ), .wait_t(cfr_time.tRCDWRL), .cmd_in(cmd_in));
        delay_nxt.EWMUL   = upd_delay(.cur(delay.EWMUL  ), .wait_t(cfr_time.tRCDRDL), .cmd_in(cmd_in));
        delay_nxt.PREAB   = upd_delay(.cur(delay.PREAB  ), .wait_t(cfr_time.tRAS  ), .cmd_in(cmd_in));
      end
      MACAB : begin
        delay_nxt.MACAB   = upd_delay(.cur(delay.MACAB  ), .wait_t(cfr_time.tCCD  ), .cmd_in(cmd_in));
        delay_nxt.PREAB   = upd_delay(.cur(delay.PREAB  ), .wait_t(cfr_time.tMACD ), .cmd_in(cmd_in));
      end
      WRBK : begin
        delay_nxt.WRBK    = upd_delay(.cur(delay.WRBK   ), .wait_t(cfr_time.tCCD  ), .cmd_in(cmd_in));
        delay_nxt.PREAB   = upd_delay(.cur(delay.PREAB  ), .wait_t(cfr_mode.WL+BL+cfr_time.tWR), .cmd_in(cmd_in));
      end
      EWMUL : begin
        delay_nxt.EWMUL   = upd_delay(.cur(delay.EWMUL  ), .wait_t(cfr_time.tEED  ), .cmd_in(cmd_in));
        delay_nxt.PREAB   = upd_delay(.cur(delay.PREAB  ), .wait_t(cfr_time.tEWMD ), .cmd_in(cmd_in));
      end
      ACTAF16 : begin
        delay_nxt.WRBK    = upd_delay(.cur(delay.WRBK   ), .wait_t(cfr_time.tRCDWRL), .cmd_in(cmd_in));
        delay_nxt.AF      = upd_delay(.cur(delay.AF     ), .wait_t(cfr_time.tRCDRDL), .cmd_in(cmd_in));
        delay_nxt.PREAB   = upd_delay(.cur(delay.PREAB  ), .wait_t(cfr_time.tRAS  ), .cmd_in(cmd_in));
      end
      AF : begin
        delay_nxt.PREAB   = upd_delay(.cur(delay.PREAB  ), .wait_t(cfr_time.tAFD  ), .cmd_in(cmd_in));
      end
      // NDM Based Commands
      NDME : begin
        delay_nxt.WRGB    = upd_delay(.cur(delay.WRGB   ), .wait_t(cfr_time.tNDMWR), .cmd_in(cmd_in));
        delay_nxt.WRBIAS  = upd_delay(.cur(delay.WRBIAS ), .wait_t(cfr_time.tNDMWR), .cmd_in(cmd_in));
        delay_nxt.RDMAC   = upd_delay(.cur(delay.RDMAC  ), .wait_t(cfr_time.tNDMRD), .cmd_in(cmd_in));
        delay_nxt.RDAF    = upd_delay(.cur(delay.RDAF   ), .wait_t(cfr_time.tNDMRD), .cmd_in(cmd_in));
        // delay_nxt.NDMX    = upd_delay(.cur(delay.NDMX   ), .wait_t(tNDMRD), .cmd_in(cmd_in));
      end
      WRGB : begin
        delay_nxt.WRGB    = upd_delay(.cur(delay.WRGB   ), .wait_t(cfr_time.tWRGBD), .cmd_in(cmd_in));
        delay_nxt.WRBIAS  = upd_delay(.cur(delay.WRBIAS ), .wait_t(cfr_time.tWRGBX), .cmd_in(cmd_in));
        delay_nxt.NDMX    = upd_delay(.cur(delay.NDMX   ), .wait_t(cfr_time.tWRGBX), .cmd_in(cmd_in));
      end
      WRBIAS : begin
        delay_nxt.WRGB    = upd_delay(.cur(delay.WRGB   ), .wait_t(cfr_time.tWRBIASX), .cmd_in(cmd_in));
        delay_nxt.WRBIAS  = upd_delay(.cur(delay.WRBIAS ), .wait_t(cfr_time.tWRBIASD), .cmd_in(cmd_in));
        delay_nxt.NDMX    = upd_delay(.cur(delay.NDMX   ), .wait_t(cfr_time.tWRBIASX), .cmd_in(cmd_in));
      end
      RDMAC : begin
        delay_nxt.NDMX    = upd_delay(.cur(delay.NDMX   ), .wait_t(cfr_time.tRDMACX), .cmd_in(cmd_in));
      end
      RDAF : begin
        delay_nxt.NDMX    = upd_delay(.cur(delay.NDMX   ), .wait_t(cfr_time.tRDAFX), .cmd_in(cmd_in));
      end
      MRS, NDMX : begin
        delay_nxt.MRS     = upd_delay(.cur(delay.MRS    ), .wait_t(cfr_time.tMRD  ), .cmd_in(cmd_in));
        delay_nxt.NDME    = upd_delay(.cur(delay.NDME   ), .wait_t(cfr_time.tMRD  ), .cmd_in(cmd_in));
        delay_nxt.ACT     = upd_delay(.cur(delay.ACT    ), .wait_t(cfr_time.tMOD  ), .cmd_in(cmd_in));
        delay_nxt.ACT16   = upd_delay(.cur(delay.ACT16  ), .wait_t(cfr_time.tMOD  ), .cmd_in(cmd_in));
        delay_nxt.ACTAF16 = upd_delay(.cur(delay.ACTAF16), .wait_t(cfr_time.tMOD  ), .cmd_in(cmd_in));
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
    aime_t_pass = 0;
    case (aime_cmd)
      // Single Bank Commands
      ACT     : aime_t_pass = delay_nxt.ACT     == 0;
      MACSB   : aime_t_pass = delay_nxt.MACSB   == 0;
      RDCP    : aime_t_pass = delay_nxt.RDCP    == 0;
      WRCP    : aime_t_pass = delay_nxt.WRCP    == 0;
      PREPB   : aime_t_pass = delay_nxt.PREPB   == 0;
      // All Bank Commands
      ACT16   : aime_t_pass = delay_nxt.ACT16   == 0;
      MACAB   : aime_t_pass = delay_nxt.MACAB   == 0;
      WRBK    : aime_t_pass = delay_nxt.WRBK    == 0;
      EWMUL   : aime_t_pass = delay_nxt.EWMUL   == 0;
      ACTAF16 : aime_t_pass = delay_nxt.ACTAF16 == 0;
      AF      : aime_t_pass = delay_nxt.AF      == 0;
      PREAB   : aime_t_pass = delay_nxt.PREAB   == 0;
      // NDM Based Commands
      NDME    : aime_t_pass = delay_nxt.NDME    == 0;
      NDMX    : aime_t_pass = delay_nxt.NDMX    == 0;
      MRS     : aime_t_pass = delay_nxt.MRS     == 0;
      WRGB    : aime_t_pass = delay_nxt.WRGB    == 0;
      WRBIAS  : aime_t_pass = delay_nxt.WRBIAS  == 0;
      RDMAC   : aime_t_pass = delay_nxt.RDMAC   == 0;
      RDAF    : aime_t_pass = delay_nxt.RDAF    == 0;
      default : aime_t_pass = 0;
    endcase
  end

  // ==================================== Initialization ====================================
  initial begin
    delay = 0;
  end

endmodule
