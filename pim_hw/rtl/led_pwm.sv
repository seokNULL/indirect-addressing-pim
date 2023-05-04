`timescale 1ns / 1ps

module led_pwm #(parameter 
  CLK_SPEED_MHZ = 250,   // Clock speed in MHz
  PWM_PER_US    = 1000,
  PWM_DUTY      = 1,     // Duty cycle in %
  BLINK_PER_MS  = 500,
  LED_NUM       = 8)     // Number of LED used
(
  input  logic clk,
  input  logic rst,
  input  logic [$clog2(LED_NUM)-1:0] led_idx,
  input  logic [LED_NUM-1:0] cal_done,
  output logic [LED_NUM-1:0] led);

  // ======================= Signal Declarations ========================
  localparam PWM_PER_1 = $rtoi(PWM_PER_US*CLK_SPEED_MHZ * 0.01*PWM_DUTY);
  localparam PWM_PER_0 = PWM_PER_US*CLK_SPEED_MHZ - PWM_PER_1;
  localparam BLINK_PER = 1000*BLINK_PER_MS*CLK_SPEED_MHZ;

  logic [31:0] pwm_cnt;
  logic pwm_phase;
  logic [31:0] blink_cnt;
  logic blink_phase;
  logic [LED_NUM-1:0] led_obuf;    // LED output before being applied to the output buffer
  logic [LED_NUM-1:0] cal_done_s;  // Calibration done flag synchronized to local clock domain

  // =========================== Synchronizers ==========================
  genvar i;
  generate
    for (i=0; i<LED_NUM; i++) begin : calSync
      xpm_cdc_array_single #(
        .DEST_SYNC_FF   (2),
        .INIT_SYNC_FF   (0),
        .SIM_ASSERT_CHK (1),
        .SRC_INPUT_REG  (0),
        .WIDTH          (1))
      cal_done_sync (
        .dest_out (cal_done_s[i]),
        .dest_clk (clk),
        .src_clk  (1'b0),
        .src_in   (cal_done[i]));
    end
  endgenerate

  // =========================== LED Counters ===========================
  // LED PWM Counter
  always @(posedge clk, posedge rst)
    if (rst) begin
      pwm_cnt   <= 0;
      pwm_phase <= 0;
    end
    else begin
      if (pwm_phase == 0) begin
        pwm_cnt   <= (pwm_cnt == PWM_PER_0) ? 0 : pwm_cnt + 1'b1;
        pwm_phase <= (pwm_cnt == PWM_PER_0) ? !pwm_phase : pwm_phase;
      end
      else begin
        pwm_cnt   <= (pwm_cnt == PWM_PER_1) ? 0 : pwm_cnt + 1'b1;
        pwm_phase <= (pwm_cnt == PWM_PER_1) ? !pwm_phase : pwm_phase;
      end
    end

  // LED Blinking Counter
  always @(posedge clk, posedge rst)
    if (rst) begin
      blink_cnt   <= 0;
      blink_phase <= 0;
    end
    else begin
      blink_cnt   <= (blink_cnt == BLINK_PER) ? 0 : blink_cnt + 1'b1;
      blink_phase <= (blink_cnt == BLINK_PER) ? !blink_phase : blink_phase;
    end

  // ======================== LED Output Control ========================
  generate
    for (i=0; i<LED_NUM; i++) begin : ledOut
      always @(posedge clk, posedge rst)
        if (rst) led_obuf[i] <= 0;
        // else     led_obuf[i] <= (pwm_phase || cal_done_s[i]) && (blink_phase || !(led_idx == i));
        else     led_obuf[i] <= (pwm_phase && cal_done_s[i]) && (blink_phase);

      OBUF OBUF_led (
        .O (led[i]),
        .I (led_obuf[i]));
    end
  endgenerate

  // ========================== Initialization ==========================
  initial begin
    pwm_cnt     = 0;
    pwm_phase   = 0;
    blink_cnt   = 0;
    blink_phase = 0;
    led_obuf    = 0;
  end

 //debug
//  (* keep = "true", mark_debug = "true" *) reg [31:0]        debug_pwm_cnt;
//  (* keep = "true", mark_debug = "true" *) reg               debug_pwm_phase;
//  (* keep = "true", mark_debug = "true" *) reg [31:0]        debug_blink_cnt;
//  (* keep = "true", mark_debug = "true" *) reg               debug_blink_phase;
//  (* keep = "true", mark_debug = "true" *) reg [LED_NUM-1:0] debug_led_obuf;
//  (* keep = "true", mark_debug = "true" *) reg [LED_NUM-1:0] debug_cal_done_s;
//  (* keep = "true", mark_debug = "true" *) reg [$clog2(LED_NUM)-1:0] debug_led_idx;

  //  always @(posedge clk, posedge rst)
  //  if (rst) begin
  //                      debug_pwm_cnt     <= 'b0;
  //                      debug_pwm_phase   <= 'b0;
  //                      debug_blink_cnt   <= 'b0;
  //                      debug_blink_phase <= 'b0;
  //                      debug_led_obuf    <= 'b0;
  //                      debug_cal_done_s  <= 'b0;
  //                      debug_led_idx     <= 'b0;
  //  end
  //  else begin
  //                      debug_pwm_cnt     <= pwm_cnt;
  //                      debug_pwm_phase   <= pwm_phase;
  //                      debug_blink_cnt   <= blink_cnt;
  //                      debug_blink_phase <= blink_phase;
  //                      debug_led_obuf    <= led_obuf;
  //                      debug_cal_done_s  <= cal_done_s;
  //                      debug_led_idx     <= led_idx;
  //  end


endmodule
