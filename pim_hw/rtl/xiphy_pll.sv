`timescale 1ps/1ps

import aimc_lib::*;

module xiphy_pll #(parameter PLL_WIDTH = 1) (
  input  logic clk_div,
  input  logic rst_div,
  input  logic ub_rst_out,
  input  logic mmcm_lock,
  input  logic pll_gate,
  output logic [PLL_WIDTH-1:0] clk_pll,
  output logic pll_lock);

  // ======================== Internal Variables ========================
  logic                 clkphyout_en;  // PHY clocking enable signal
  logic [PLL_WIDTH-1:0] pll_fb;        // PLL feedback
  logic [PLL_WIDTH-1:0] pll_lock_int;  // PLL locked flag
  logic                 rst_pll;       // PLL reset signal
  logic                 clk_xpll_in;   // Shifted PLL input clock

  // ============================ PLL Blocks ============================
  genvar i;
  generate
    for (i=0; i<PLL_WIDTH; i++) begin : plle_loop
      `ifdef ULTRASCALE_CONFIG
      PLLE4_ADV #(
        .CLKFBOUT_MULT      (CLKFBOUT_MULT_PLL),   // VCO multiplier (VCO = CLKIN_FREQ * CLKFBOUT_MULT_PLL / DIVCLK_DIVIDE_PLL)
        .DIVCLK_DIVIDE      (DIVCLK_DIVIDE_PLL),   // VCO divider
        .CLKIN_PERIOD       (CLKIN_PERIOD_PLL),    // Fabric clock period (nanoseconds)
        .STARTUP_WAIT       ("FALSE"),
        .CLKFBOUT_PHASE     (90.000),
        .COMPENSATION       ("AUTO"),
        .CLKOUTPHY_MODE     (CLKOUTPHY_MODE_PLL))  // CLKOUTPHY multiplier: "VCO_2X", "VCO", "VCO_HALF"
      PLLE4_INST (
        .CLKIN              (clk_div),
        .RST                (rst_pll),
        .PWRDWN             (1'b0),
        .CLKOUT0            (),
        .CLKOUT0B           (),
        .CLKOUT1            (),
        .CLKOUT1B           (),
        .CLKFBOUT           (pll_fb[i]),
        .CLKFBIN            (pll_fb[i]),
        .CLKOUTPHYEN        (clkphyout_en),
        .CLKOUTPHY          (clk_pll[i]),
        .LOCKED             (pll_lock_int[i]),
        .DADDR              (7'b0),
        .DI                 (16'b0),
        .DWE                (1'b0),
        .DEN                (1'b0),
        .DCLK               (1'b0),
        .DO                 (),
        .DRDY               ());
      `elsif VERSAL_CONFIG
      /* Maximum input clock frequency = 1070 MHz (Speed Grade = -2, VCCIO = 0.80 V)
         Minimum input clock frequency = 100 MHz
         Maximum XPLL VCO frequency = 4320 MHz
         Minimum XPLL VCO frequency = 2160 MHz */
      if (INTF_SPEED=="3_2_Gbps" || INTF_SPEED=="3_4_Gbps" || INTF_SPEED=="3_6_Gbps" || INTF_SPEED=="3_8_Gbps") begin
        XPLL #(
          .CLKOUT0_DIVIDE     (8),
          .CLKOUT0_PHASE      (-213.75),             // !!! IMPORTANT !!! Phase needs to be adjusted manually to improve the timing
          .CLKOUT0_PHASE_CTRL (2'b00),
          .DESKEW_DELAY1      (0),
          .DESKEW_DELAY_PATH1 ("FALSE"),
          .DESKEW_DELAY_EN1   ("FALSE"),
          .CLKFBOUT_MULT      (CLKFBOUT_MULT_PLL),   // VCO multiplier (VCO = CLKIN_FREQ * CLKFBOUT_MULT_PLL / DIVCLK_DIVIDE_PLL)
          .DIVCLK_DIVIDE      (DIVCLK_DIVIDE_PLL),   // VCO divider
          .CLKIN_PERIOD       (CLKIN_PERIOD_PLL),    // Fabric clock period (nanoseconds)
          .CLKFBOUT_PHASE     (0.000))
        XPLL_SHIFT_INST (
          .CLKIN              (clk_div),
          .RST                (rst_pll),
          .PWRDWN             (1'b0),
          .CLKOUT0            (clk_xpll_in),
          .CLKOUT1            (),
          .CLKOUT2            (),
          .CLKOUT3            (),
          .CLKIN1_DESKEW      (1'b0),
          .CLKIN2_DESKEW      (1'b0),
          .CLKFB1_DESKEW      (1'b0),
          .CLKFB2_DESKEW      (1'b0),
          .LOCKED1_DESKEW     (),
          .LOCKED2_DESKEW     (),
          .CLKOUTPHYEN        (),
          .CLKOUTPHY          (),
          .LOCKED             (),
          .DADDR              (7'b0),
          .DI                 (16'b0),
          .DWE                (1'b0),
          .DEN                (1'b0),
          .DCLK               (1'b0),
          .DO                 (),
          .DRDY               (),
          .CLKOUTPHY_CASC_OUT (),
          .CLKOUTPHY_CASC_IN  (1'b0),
          .LOCKED_FB          (),
          .PSDONE             (),
          .PSCLK              (1'b0),
          .PSEN               (1'b0),
          .PSINCDEC           (1'b0),
          .RIU_CLK            (1'b0),
          .RIU_ADDR           (8'd0),
          .RIU_NIBBLE_SEL     (1'b0),
          .RIU_WR_DATA        (16'd0),
          .RIU_WR_EN          (1'b0),
          .RIU_RD_DATA        (),
          .RIU_VALID          ());
      end
      else begin
        assign clk_xpll_in = clk_div;
      end

      XPLL #(
        .CLKFBOUT_MULT      (CLKFBOUT_MULT_PLL),     // VCO multiplier (VCO = CLKIN_FREQ * CLKFBOUT_MULT_PLL / DIVCLK_DIVIDE_PLL)
        .DIVCLK_DIVIDE      (DIVCLK_DIVIDE_PLL),     // VCO divider
        .CLKIN_PERIOD       (CLKIN_PERIOD_PLL),      // Fabric clock period (nanoseconds)
        .CLKFBOUT_PHASE     (0.000),
        .CLKOUTPHY_DIVIDE   (CLKOUTPHY_DIVIDE_PLL))  // CLKOUTPHY divider: "DIV1", "DIV2", "DIV4", "DIV8", "DIV16"
      XPLL_INST (
        .CLKIN              (clk_xpll_in),
        .RST                (rst_pll),
        .PWRDWN             (1'b0),
        .CLKOUT0            (),
        .CLKOUT1            (),
        .CLKOUT2            (),
        .CLKOUT3            (),
        .CLKIN1_DESKEW      (1'b0),
        .CLKIN2_DESKEW      (1'b0),
        .CLKFB1_DESKEW      (1'b0),
        .CLKFB2_DESKEW      (1'b0),
        .LOCKED1_DESKEW     (),
        .LOCKED2_DESKEW     (),
        .CLKOUTPHYEN        (clkphyout_en),
        .CLKOUTPHY          (clk_pll[i]),
        .LOCKED             (pll_lock_int[i]),
        .DADDR              (7'b0),
        .DI                 (16'b0),
        .DWE                (1'b0),
        .DEN                (1'b0),
        .DCLK               (1'b0),
        .DO                 (),
        .DRDY               (),
        .CLKOUTPHY_CASC_OUT (),
        .CLKOUTPHY_CASC_IN  (1'b0),
        .LOCKED_FB          (),
        .PSDONE             (),
        .PSCLK              (1'b0),
        .PSEN               (1'b0),
        .PSINCDEC           (1'b0),
        .RIU_CLK            (1'b0),
        .RIU_ADDR           (8'd0),
        .RIU_NIBBLE_SEL     (1'b0),
        .RIU_WR_DATA        (16'd0),
        .RIU_WR_EN          (1'b0),
        .RIU_RD_DATA        (),
        .RIU_VALID          ());
      `endif
    end
  endgenerate

  assign rst_pll = !mmcm_lock || ub_rst_out;

  always @(posedge clk_div) begin
    if      (rst_div)  clkphyout_en <= 1'b0;
    else if (pll_gate) clkphyout_en <= 1'b1;
  end

  initial clkphyout_en = 0;

  // ============================ Output Signals ============================
  assign pll_lock = &pll_lock_int;

endmodule