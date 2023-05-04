`timescale 1ns / 1ps

module calib_mux # (parameter CLK_SPEED_MHZ = 250, CH_NUM = 8) (
  input  logic clk,
  input  logic rst,
  // UART Interface
  input  logic uart_rx,
  output logic uart_tx,
  output logic [CH_NUM-1:0] uart_rxd,
  input  logic [CH_NUM-1:0] uart_txd,
  // AIMC Interface
  input  logic [CH_NUM-1:0] cal_done,
  input  logic [$clog2(CH_NUM)-1:0] ch_idx,
  // Button/LED Interface
  input  logic btn_up,
  input  logic btn_down,
  output logic [CH_NUM-1:0] led);
  
  // ======================== Signal Declarations =========================
  // Button Input
  logic btn_up_p;                        // Up button signal converted to pulse
  logic btn_down_p;                      // Down button signal converted to pulse
  // Channel Selector
  logic [CH_NUM-1:0] ch_sel;             // Channel select signal (one-hot encoded)
  logic [$clog2(CH_NUM)-1:0] ch_idx_r1;  // Selected channel index
  // UART Multiplexer
  logic [CH_NUM-1:0] uart_rx_ch_us;      // Controller UART RX signals before being synchronized to target clock domain
  logic [CH_NUM-1:0] uart_tx_ch_s;       // Controller UART TX signals synchronized to target clock domain

  // ============================ Button Input ============================
  // async_pulse_cnv #(
  //   .CLK_SPEED_MHZ    (CLK_SPEED_MHZ),
  //   .FILTER_WINDOW_US (1000))
  // btn_up_pulse (
  //   .clk,
  //   .rst,
  //   .din  (btn_up),
  //   .dout (btn_up_p));

  // async_pulse_cnv #(
  //   .CLK_SPEED_MHZ    (CLK_SPEED_MHZ),
  //   .FILTER_WINDOW_US (1000))
  // btn_down_pulse (
  //   .clk,
  //   .rst,
  //   .din  (btn_down),
  //   .dout (btn_down_p));

  // ========================== Channel Selector ==========================
  // Channel Index Counter (Button Controlled)
  // always @(posedge clk, posedge rst)
  //   if      (rst)                 ch_idx_r1 <= 0;
  //   else if (btn_up_p^btn_down_p) ch_idx_r1 <= ch_idx_r1 + btn_up_p - btn_down_p;
  // initial ch_idx_r1 = 0;

  // Channel Indicator (Auto Controlled)
  sync #(
    .SYNC_FF (2),
    .WIDTH   ($clog2(CH_NUM)))
  ch_idx_sync (
    .dest_clk (clk),
    .din      (ch_idx),
    .dout     (ch_idx_r1));

  // ========================== UART Multiplexer ==========================
  // UART TX (FPGA output)
  xpm_cdc_array_single #(
    .DEST_SYNC_FF   (2),
    .INIT_SYNC_FF   (1),
    .SIM_ASSERT_CHK (1),
    .SRC_INPUT_REG  (0),
    .WIDTH          (CH_NUM))
  uart_tx_sync (
    .dest_out (uart_tx_ch_s),
    .dest_clk (clk),
    .src_clk  (1'b0),
    .src_in   (uart_txd));

  assign uart_tx = uart_tx_ch_s[ch_idx_r1];

  // UART RX (FPGA input)
  always_comb begin
    uart_rx_ch_us = {CH_NUM{1'b1}};
    uart_rx_ch_us[ch_idx_r1] = uart_rx;
  end

  xpm_cdc_array_single #(
    .DEST_SYNC_FF   (2),
    .INIT_SYNC_FF   (1),
    .SIM_ASSERT_CHK (1),
    .SRC_INPUT_REG  (0),
    .WIDTH          (CH_NUM))
  uart_rx_sync (
    .dest_out (uart_rxd),
    .dest_clk (clk),
    .src_clk  (),
    .src_in   (uart_rx_ch_us));

  // =========================== LED PWM Drivers ==========================
  led_pwm #(
    .CLK_SPEED_MHZ (CLK_SPEED_MHZ),
    .PWM_PER_US    (1000),
    .PWM_DUTY      (2),
    .BLINK_PER_MS  (250),
    .LED_NUM       (CH_NUM))
  led_pwm (
    .clk,
    .rst,
    .led_idx  (ch_idx_r1),
    .cal_done (cal_done),
    .led      (led));

endmodule
