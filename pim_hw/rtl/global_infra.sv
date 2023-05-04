`timescale 1ps / 1ps

module global_infra #(
  parameter real CLKIN_PERIOD_MMCM   = 3.750,                  // Input clock period
  parameter int  CLKFBOUT_MULT_MMCM  = 4,                      // write MMCM VCO multiplier
  parameter int  DIVCLK_DIVIDE_MMCM  = 1,                      // write MMCM VCO divisor
  parameter int  CLKOUT0_DIVIDE_MMCM = 4,                      // VCO output divisor for MMCM clkout0 (div_clk)
  parameter int  CLKOUT1_DIVIDE_MMCM = 4,                      // VCO output divisor for MMCM clkout1 (ui_clkout1)
  parameter int  CLKOUT2_DIVIDE_MMCM = 4,                      // VCO output divisor for MMCM clkout2 (ui_clkout2)
  parameter int  CLKOUT3_DIVIDE_MMCM = 4,                      // VCO output divisor for MMCM clkout3 (ui_clkout3)
  parameter int  CLKOUT4_DIVIDE_MMCM = 4,                      // VCO output divisor for MMCM clkout4 (ui_clkout4)
  parameter int  CLKOUT6_DIVIDE_MMCM = 2*CLKOUT0_DIVIDE_MMCM,  // VCO output divisor for MMCM clkout6 (riu_clk)
  parameter TCQ                      = 100)                    // clk->out delay (sim only)
(
  input  logic sys_clk_n, sys_clk_p,
  input  logic sys_rst,                                        // core reset from user application
  input  logic pll_lock,
  output logic mmcm_lock,
  output logic div_clk,
  output logic riu_clk,
  output logic ui_clkout1,
  output logic ui_clkout2,
  output logic ui_clkout3,
  output logic ui_clkout4,
  output logic dbg_clk,
  // Reset outputs
  output logic rstdiv0,
  output logic rstdiv1,
  output logic rstout2,
  output logic reset_ub,
  output logic pllgate);

  // # of clock cycles to delay deassertion of reset. Needs to be a fairly
  // high number not so much for metastability protection, but to give time
  // for reset (i.e. stable clock cycles) to propagate through all state
  // machines and to all control signals (i.e. not all control signals have
  // resets, instead they rely on base state logic being reset, and the effect
  // of that reset propagating through the logic). Need this because we may not
  // be getting stable clock cycles while reset asserted (i.e. since reset
  // depends on DCM lock status)
  localparam RST_SYNC_NUM = 24;

  // Round up for clk reset delay to ensure that CLKDIV reset deassertion
  // occurs at same time or after CLK reset deassertion
  localparam RST_DIV_SYNC_NUM  = RST_SYNC_NUM;        // Counter For Stretching DIV Reset
  localparam RST_RIU_SYNC_NUM  = RST_SYNC_NUM/2;      // Counter For Stretching RIU Reset  
  localparam RST_OUT2_SYNC_NUM = RST_SYNC_NUM;
  localparam INPUT_RST_STRETCH = 50;                  // Counter For Stretching Input Reset

  // # of clock cycles to wait before we enable the PLL clock
  localparam PLL_GATE_CNT_LIMIT = 64;
  
  logic sys_clk_in;

  logic mmcm_clkout0;
  logic mmcm_clkout1;
  logic mmcm_clkout2;
  logic mmcm_clkout3;
  logic mmcm_clkout4;
  logic mmcm_clkout5;
  logic mmcm_clkout6;

  (* keep = "TRUE" , ASYNC_REG = "TRUE" *) logic [3:0] rst_input_sync_r;
  (* keep = "TRUE" , ASYNC_REG = "TRUE" *) logic [1:0] rst_input_async;
  (* keep = "TRUE" , ASYNC_REG = "TRUE" *) logic       rst_async_riu_div;
  (* keep = "TRUE" , ASYNC_REG = "TRUE" *) logic       rst_async_mb;

  (* keep = "TRUE" , ASYNC_REG = "TRUE" *) logic [1:0] rst_riu_sync_r;  // RIU Clock Domain RST Sync
  (* keep = "TRUE" , ASYNC_REG = "TRUE" *) logic [1:0] rst_div_sync_r;  // DIV Clock Domain RST Sync
  (* keep = "TRUE" , ASYNC_REG = "TRUE" *) logic [1:0] rst_out2_sync_r; // UI_CLKOUT2 Clock Domain RST Sync
  (* keep = "TRUE" , ASYNC_REG = "TRUE" *) logic [1:0] rst_mb_sync_r;   // MB RST Sync

  logic [6:0] counter_input_rst;  // counter for input reset stretch
  logic [6:0] counter_riu_rst;    // counter for riu reset synchronous deassertion 
  logic [6:0] counter_div_rst;    // counter for fabric reset synchronous deassertion
  logic [6:0] counter_out2_rst;   // counter for ui_clkout2 reset synchronous deassertion
  logic [6:0] counter_mb_rst;     // counter for mb reset synchronous deassertion
  logic       rst_div_logic;      // Fabric reset
  logic       rst_out2_logic;     // ui_clkout2 reset
  logic       rst_riu_logic;      // RIU Reset
   logic       rst_mb_logic;       // MB Reset

  (* keep = "TRUE" , ASYNC_REG = "TRUE" *) logic [2:0] rst_div_logic_r;  // Reset synchronizer for Fabric Domain
  (* keep = "TRUE" , ASYNC_REG = "TRUE" *) logic [2:0] rst_out2_logic_r; // Reset synchronizer for ui_clkout2 Domain
  (* keep = "TRUE" , ASYNC_REG = "TRUE" *) logic [2:0] rst_riu_logic_r;  // Reset synchronizer for RIU Domain
  (* keep = "TRUE" , ASYNC_REG = "TRUE" *) logic [2:0] rst_mb_logic_r;   // Reset synchronizer for MB

  logic rst_div_logic_r1;  // Final Reset going for Fabric
  logic rst_out2_logic_r1; // Final Reset going for ui_clkout2 domain
  logic rst_riu_logic_r1;  // FInal Reset Going for RIU
  logic rst_mb_logic_r1;   // Final Reset going for MB

  logic [6:0] pll_gate_cnt;

                      logic input_rst_mmcm;
  (* keep = "TRUE" *) logic input_rst_design;
                      logic sys_clk_in_bufg;

  initial begin
    rst_input_sync_r  = 0;
    rst_input_async   = 0;
    rst_async_riu_div = 0;
    rst_async_mb      = 0;

    rst_riu_sync_r    = 0;  // RIU Clock Domain RST Sync
    rst_div_sync_r    = 0;  // DIV Clock Domain RST Sync
    rst_out2_sync_r   = 0;  // UI_CLKOUT2 Domain RST Sync
    rst_mb_sync_r     = 0;  // MB RST Sync

    counter_input_rst = INPUT_RST_STRETCH;  // counter for input reset stretch
    counter_riu_rst   = RST_RIU_SYNC_NUM;   // counter for riu reset synchronous deassertion 
    counter_div_rst   = RST_DIV_SYNC_NUM;   // counter for fabric reset synchronous deassertion
    counter_out2_rst  = RST_OUT2_SYNC_NUM;  // counter for ui_clkout2 reset synchronous deassertion
    counter_mb_rst    = RST_DIV_SYNC_NUM;   // counter for mb reset synchronous deassertion
    rst_div_logic     = 1'b1;               // Fabric reset
    rst_out2_logic    = 1'b1;               // ui_clkout2 reset
    rst_riu_logic     = 1'b1;               // RIU Reset
    rst_mb_logic      = 1'b1;               // MB Reset

    rst_div_logic_r   = {3{1'b1}};  // Reset synchronizer for Fabric Domain
    rst_out2_logic_r  = {3{1'b1}};  // Reset synchronizer for ui_clkout2 Domain
    rst_riu_logic_r   = {3{1'b1}};  // Reset synchronizer for RIU Domain
    rst_mb_logic_r    = {3{1'b1}};  // Reset synchronizer for MB

    rst_div_logic_r1  = 1'b1;   // Final Reset going for Fabric
    rst_out2_logic_r1 = 1'b1;   // Final Reset going for ui_clkout2 domain
    rst_riu_logic_r1  = 1'b1;   // FInal Reset GOing for RIu
    rst_mb_logic_r1   = 1'b1;   // Final Reset going for MB

    input_rst_mmcm    = 0;
    input_rst_design  = 0;

    pllgate           = 0;
  end

  // =============================== Input Clock Buffers ===============================
  IBUFDS #(.IBUF_LOW_PWR ("FALSE")) u_ibufg_sys_clk (
   .I  (sys_clk_p),
   .IB (sys_clk_n),
   .O  (sys_clk_in));

  BUFG  u_bufg_inst (
    .I(sys_clk_in),       // 1-bit input: Primary clock
    .O(sys_clk_in_bufg)); // 1-bit output: Clock output

  BUFG u_bufg_backbone (
    .I (sys_clk_in),
    .O (mmcm_clk_in));  

  // =================== Reset Generation Loigc For MMCM And Design ===================
  // Reset synchorinizer
  always @(posedge sys_clk_in_bufg or posedge sys_rst) begin
    if (sys_rst) begin
      rst_input_async[0]   <= #TCQ  1;
      rst_input_async[1]   <= #TCQ  1;
    end else begin
      rst_input_async[0]   <= #TCQ  0;
      rst_input_async[1]   <= #TCQ  rst_input_async[0];
    end
  end

  always @(posedge sys_clk_in_bufg) begin
    rst_input_sync_r[0]     <= #TCQ   rst_input_async[1];
    rst_input_sync_r[3:1]   <= #TCQ   rst_input_sync_r[2:0];
  end

 //Counter For Reset Stretching  
  always @(posedge sys_clk_in_bufg) begin
      if (rst_input_sync_r[3])
          counter_input_rst    <= #TCQ  INPUT_RST_STRETCH;
      else if (counter_input_rst != 0) 
          counter_input_rst    <= #TCQ  counter_input_rst - 1'b1 ;
      else 
          counter_input_rst    <= #TCQ  counter_input_rst ;
  end

  always @(posedge sys_clk_in_bufg) begin
      if (counter_input_rst != 0) 
         input_rst_design <= #TCQ  1'b1;
      else 
         input_rst_design <= #TCQ  1'b0;
  end

  always @(posedge sys_clk_in_bufg) begin
      if ((counter_input_rst <= 'd10) && (counter_input_rst != 0)) 
         input_rst_mmcm <= #TCQ  1'b1;
      else 
         input_rst_mmcm <= #TCQ  1'b0;
  end

  // ============================= MMCM and Clock Buffers ============================
  `ifdef ULTRASCALE_CONFIG
  MMCME4_ADV #(
    .BANDWIDTH            ("OPTIMIZED"),
    .CLKOUT4_CASCADE      ("FALSE"),
    .COMPENSATION         ("INTERNAL"),
    .STARTUP_WAIT         ("FALSE"),
    .DIVCLK_DIVIDE        (DIVCLK_DIVIDE_MMCM),
    .CLKFBOUT_MULT_F      (CLKFBOUT_MULT_MMCM),
    .CLKFBOUT_PHASE       (0.000),
    .CLKFBOUT_USE_FINE_PS ("FALSE"),
    .CLKOUT0_DIVIDE_F     (CLKOUT0_DIVIDE_MMCM),
    .CLKOUT0_PHASE        (0.000),
    .CLKOUT0_DUTY_CYCLE   (0.500),
    .CLKOUT0_USE_FINE_PS  ("FALSE"),
    .CLKOUT1_DIVIDE       (CLKOUT1_DIVIDE_MMCM),
    .CLKOUT1_PHASE        (0.000),
    .CLKOUT1_DUTY_CYCLE   (0.500),
    .CLKOUT1_USE_FINE_PS  ("FALSE"),
    .CLKOUT2_DIVIDE       (CLKOUT2_DIVIDE_MMCM),
    .CLKOUT2_PHASE        (0.000),
    .CLKOUT2_DUTY_CYCLE   (0.500),
    .CLKOUT2_USE_FINE_PS  ("FALSE"),
    .CLKOUT3_DIVIDE       (CLKOUT3_DIVIDE_MMCM),
    .CLKOUT3_PHASE        (0.000),
    .CLKOUT3_DUTY_CYCLE   (0.500),
    .CLKOUT3_USE_FINE_PS  ("FALSE"),
    .CLKOUT4_DIVIDE       (CLKOUT4_DIVIDE_MMCM),
    .CLKOUT4_PHASE        (0.000),
    .CLKOUT4_DUTY_CYCLE   (0.500),
    .CLKOUT4_USE_FINE_PS  ("FALSE"),
    .CLKOUT5_DIVIDE       (CLKOUT0_DIVIDE_MMCM*4),
    .CLKOUT5_PHASE        (0.000),
    .CLKOUT5_DUTY_CYCLE   (0.500),
    .CLKOUT5_USE_FINE_PS  ("FALSE"),
    .CLKOUT6_DIVIDE       (CLKOUT6_DIVIDE_MMCM),
    .CLKOUT6_PHASE        (0.000),
    .CLKOUT6_DUTY_CYCLE   (0.500),
    .CLKOUT6_USE_FINE_PS  ("FALSE"),  
    .CLKIN1_PERIOD        (CLKIN_PERIOD_MMCM),
    .REF_JITTER1          (0.010))
  u_mmcme_adv_inst (
    // Output Clocks
    .CLKFBOUT             (),
    .CLKFBOUTB            (),
    .CLKOUT0              (mmcm_clkout0),
    .CLKOUT0B             (),
    .CLKOUT1              (mmcm_clkout1),
    .CLKOUT1B             (),
    .CLKOUT2              (mmcm_clkout2),
    .CLKOUT2B             (),
    .CLKOUT3              (mmcm_clkout3),
    .CLKOUT3B             (),
    .CLKOUT4              (mmcm_clkout4),
    .CLKOUT5              (mmcm_clkout5),
    .CLKOUT6              (mmcm_clkout6),
    // Input Clocks
    .CLKFBIN              (),
    .CLKIN1               (mmcm_clk_in),
    .CLKIN2               (),
    .CLKINSEL             (1'b1),
    // Control and Status Signals
    .LOCKED               (mmcm_lock),
    .PWRDWN               (1'b0),
    .RST                  (input_rst_mmcm),
    .CDDCDONE             (),
    .CLKFBSTOPPED         (),
    .CLKINSTOPPED         (),
    .DO                   (),
    .DRDY                 (),
    .PSDONE               (),
    .CDDCREQ              (1'b0),
    .DADDR                (7'd0),
    .DCLK                 (1'b0),
    .DEN                  (1'b0),
    .DI                   (16'd0),
    .DWE                  (1'b0),
    .PSCLK                (1'b0),
    .PSEN                 (1'b0),
    .PSINCDEC             (1'b0));

  `elsif VERSAL_CONFIG
  logic mmcm_clkfb;
  logic mmcm_clkfb_bufg;

  MMCME5 #(
    .BANDWIDTH            ("OPTIMIZED"),            // HIGH, LOW, OPTIMIZED
    .COMPENSATION         ("AUTO"),                 // Clock input compensation
    .DIVCLK_DIVIDE        (DIVCLK_DIVIDE_MMCM),     // Master division value
    .CLKFBOUT_MULT        (CLKFBOUT_MULT_MMCM),     // Multiply value for all CLKOUT, (4-432)
    .CLKFBOUT_PHASE       (0.0),                    // Phase offset in degrees of CLKFB
    .CLKIN1_PERIOD        (CLKIN_PERIOD_MMCM),      // Input clock period in ns to ps resolution (i.e., 33.333 is 30 MHz).
    .IS_CLKFBIN_INVERTED  (1'b0),                   // Optional inversion for CLKFBIN
    .IS_CLKIN1_INVERTED   (1'b0),                   // Optional inversion for CLKIN1
    .IS_CLKINSEL_INVERTED (1'b0),                   // Optional inversion for CLKINSEL
    .IS_RST_INVERTED      (1'b0),                   // Optional inversion for RST
    .CLKOUT0_DIVIDE       (CLKOUT0_DIVIDE_MMCM),    // Divide amount for CLKOUT0 (2-511)
    .CLKOUT0_DUTY_CYCLE   (0.5),                    // Duty cycle for CLKOUT0
    .CLKOUT0_PHASE        (0.0),                    // Phase offset for CLKOUT0
    .CLKOUT1_DIVIDE       (CLKOUT1_DIVIDE_MMCM),    // Divide amount for CLKOUT1 (2-511)
    .CLKOUT1_DUTY_CYCLE   (0.5),                    // Duty cycle for CLKOUT1
    .CLKOUT1_PHASE        (0.0),                    // Phase offset for CLKOUT1
    .CLKOUT2_DIVIDE       (CLKOUT2_DIVIDE_MMCM),    // Divide amount for CLKOUT2 (2-511)
    .CLKOUT2_DUTY_CYCLE   (0.5),                    // Duty cycle for CLKOUT2
    .CLKOUT2_PHASE        (0.0),                    // Phase offset for CLKOUT2
    .CLKOUT3_DIVIDE       (CLKOUT3_DIVIDE_MMCM),    // Divide amount for CLKOUT3 (2-511)
    .CLKOUT3_DUTY_CYCLE   (0.5),                    // Duty cycle for CLKOUT3
    .CLKOUT3_PHASE        (0.0),                    // Phase offset for CLKOUT3
    .CLKOUT4_DIVIDE       (CLKOUT4_DIVIDE_MMCM),    // Divide amount for CLKOUT4 (2-511)
    .CLKOUT4_DUTY_CYCLE   (0.5),                    // Duty cycle for CLKOUT4
    .CLKOUT4_PHASE        (0.0),                    // Phase offset for CLKOUT4
    .CLKOUT5_DIVIDE       (CLKOUT0_DIVIDE_MMCM*4),  // Divide amount for CLKOUT5 (2-511)
    .CLKOUT5_DUTY_CYCLE   (0.5),                    // Duty cycle for CLKOUT5
    .CLKOUT5_PHASE        (0.0),                    // Phase offset for CLKOUT5
    .CLKOUT6_DIVIDE       (CLKOUT6_DIVIDE_MMCM),    // Divide amount for CLKOUT6 (2-511)
    .CLKOUT6_DUTY_CYCLE   (0.5),                    // Duty cycle for CLKOUT6
    .CLKOUT6_PHASE        (0.0),                    // Phase offset for CLKOUT6
    .LOCK_WAIT            ("FALSE"),                // Lock wait
    .REF_JITTER1          (0.01))                   // Reference input jitter in UI (0.000-0.200).
  MMCME5_inst (
    // Output Clocks
    .CLKFBOUT             (mmcm_clkfb),             // 1-bit output: Feedback clock
    .CLKOUT0              (mmcm_clkout0),           // 1-bit output: CLKOUT0
    .CLKOUT1              (mmcm_clkout1),           // 1-bit output: CLKOUT1
    .CLKOUT2              (mmcm_clkout2),           // 1-bit output: CLKOUT2
    .CLKOUT3              (mmcm_clkout3),           // 1-bit output: CLKOUT3
    .CLKOUT4              (mmcm_clkout4),           // 1-bit output: CLKOUT4
    .CLKOUT5              (mmcm_clkout5),           // 1-bit output: CLKOUT5
    .CLKOUT6              (mmcm_clkout6),           // 1-bit output: CLKOUT6
    // Input Clocks
    .CLKFBIN              (mmcm_clkfb_bufg),        // 1-bit input: Feedback clock
    .CLKIN1_DESKEW        (),                       // 1-bit input: Primary clock input to PD1
    .CLKFB1_DESKEW        (),                       // 1-bit input: Secondary clock input to PD1
    .CLKIN2_DESKEW        (),                       // 1-bit input: Primary clock input to PD2
    .CLKFB2_DESKEW        (),                       // 1-bit input: Secondary clock input to PD2
    .CLKIN1               (mmcm_clk_in),            // 1-bit input: Primary clock
    .CLKIN2               (1'b0),                   // 1-bit input: Secondary clock
    .CLKINSEL             (1'b1),                   // 1-bit input: Clock select, High=CLKIN1 Low=CLKIN2
    // Control and Status Signals
    .LOCKED               (mmcm_lock),              // 1-bit output: LOCK
    .LOCKED1_DESKEW       (),                       // 1-bit output: LOCK DESKEW PD1
    .LOCKED2_DESKEW       (),                       // 1-bit output: LOCK DESKEW PD2
    .LOCKED_FB            (),                       // 1-bit output: LOCK FEEDBACK
    .PWRDWN               (1'b0),                   // 1-bit input: Power-down
    .RST                  (),                       // 1-bit input: Reset
    .CLKFBSTOPPED         (),                       // 1-bit output: Feedback clock stopped
    .CLKINSTOPPED         (),                       // 1-bit output: Input clock stopped
    .DO                   (),                       // 16-bit output: DRP data output
    .DRDY                 (),                       // 1-bit output: DRP ready
    .PSDONE               (),                       // 1-bit output: Phase shift done
    .DADDR                (7'd0),                   // 7-bit input: DRP address
    .DCLK                 (1'b0),                   // 1-bit input: DRP clock
    .DEN                  (1'b0),                   // 1-bit input: DRP enable
    .DI                   (16'd0),                  // 16-bit input: DRP data input
    .DWE                  (1'b0),                   // 1-bit input: DRP write enable
    .PSCLK                (1'b0),                   // 1-bit input: Phase shift clock
    .PSEN                 (1'b0),                   // 1-bit input: Phase shift enable
    .PSINCDEC             (1'b0));                  // 1-bit input: Phase shift increment/decrement

  BUFG u_bufg_mmcm_fb (
    .I (mmcm_clkfb),
    .O (mmcm_clkfb_bufg));
  `endif

  BUFG u_bufg_addn_ui_clk_1 (
    .I (mmcm_clkout1),
    .O (ui_clkout1));

  BUFG u_bufg_addn_ui_clk_2 (
    .I (mmcm_clkout2),
    .O (ui_clkout2));

  BUFG u_bufg_addn_ui_clk_3 (
    .I (mmcm_clkout3),
    .O (ui_clkout3));

  BUFG u_bufg_addn_ui_clk_4 (
    .I (mmcm_clkout4),
    .O (ui_clkout4));

  BUFG u_bufg_dbg_clk (
    .I (mmcm_clkout5),
    .O (dbg_clk));

  BUFG u_bufg_divClk (
    .I (mmcm_clkout0),
    .O (div_clk));
     
  BUFG u_bufg_riuClk (
    .I (mmcm_clkout6),
    .O (riu_clk));

  always @(posedge sys_clk_in_bufg) begin
    rst_async_riu_div <= #TCQ input_rst_design | ~(&pll_lock) | ~mmcm_lock;
    rst_async_mb      <= #TCQ input_rst_design | ~mmcm_lock;
  end    

  // =========================== Reset for RIU Clock Domain ============================
  // Reset synchorinizer
  always @(posedge riu_clk) begin
    rst_riu_sync_r[0] <= #TCQ  rst_async_riu_div;
    rst_riu_sync_r[1] <= #TCQ  rst_riu_sync_r[0];
  end

 //Counter For Reset Stretching  
  always @(posedge riu_clk) begin
    if (rst_riu_sync_r[1])
      counter_riu_rst    <= #TCQ   RST_RIU_SYNC_NUM;
    else if (counter_riu_rst != 0) 
      counter_riu_rst    <= #TCQ  counter_riu_rst - 1'b1;
    else
      counter_riu_rst    <= #TCQ  counter_riu_rst;
  end

  always @(posedge riu_clk) begin
    if (counter_riu_rst != 0) 
      rst_riu_logic <= #TCQ  1'b1;
    else 
      rst_riu_logic <= #TCQ  1'b0;
  end
  
  always @(posedge riu_clk) begin
    rst_riu_logic_r[0]   <= #TCQ rst_riu_logic;
    rst_riu_logic_r[2:1] <= #TCQ rst_riu_logic_r[1:0];
    rst_riu_logic_r1     <= #TCQ rst_riu_logic_r[2];
  end

  // =========================== Reset for DIV Clock Domain ============================
  // Reset synchorinizer
  always @(posedge div_clk) begin
    rst_div_sync_r[0]   <= #TCQ  rst_async_riu_div;
    rst_div_sync_r[1]   <= #TCQ  rst_div_sync_r[0];
  end

 //Counter For Reset Stretching  
  always @(posedge div_clk) begin
    if (rst_div_sync_r[1])
      counter_div_rst    <= #TCQ   RST_DIV_SYNC_NUM;
    else if (counter_div_rst != 0) 
      counter_div_rst    <= #TCQ  counter_div_rst - 1'b1;
    else 
      counter_div_rst    <= #TCQ  counter_div_rst;
  end

  always @(posedge div_clk) begin
    if (counter_div_rst != 0) 
      rst_div_logic <= #TCQ  1'b1;
    else 
      rst_div_logic <= #TCQ  1'b0;
  end

  always @(posedge div_clk) begin
    rst_div_logic_r[0]   <= #TCQ rst_div_logic;
    rst_div_logic_r[2:1] <= #TCQ rst_div_logic_r[1:0]; 
    rst_div_logic_r1     <= #TCQ rst_div_logic_r[2];
  end

  // ======================= Reset for UI_CLKOUT2 Clock Domain =======================
  // Reset synchorinizer
  always @(posedge ui_clkout2) begin
    rst_out2_sync_r[0]   <= #TCQ  rst_async_riu_div;
    rst_out2_sync_r[1]   <= #TCQ  rst_out2_sync_r[0];
  end

 //Counter For Reset Stretching  
  always @(posedge ui_clkout2) begin
    if (rst_out2_sync_r[1])
      counter_out2_rst    <= #TCQ  RST_OUT2_SYNC_NUM;
    else if (counter_out2_rst != 0) 
      counter_out2_rst    <= #TCQ  counter_out2_rst - 1'b1;
    else 
      counter_out2_rst    <= #TCQ  counter_out2_rst;
  end

  always @(posedge ui_clkout2) begin
    if (counter_out2_rst != 0) 
      rst_out2_logic <= #TCQ  1'b1;
    else 
      rst_out2_logic <= #TCQ  1'b0;
  end

  always @(posedge ui_clkout2) begin
    rst_out2_logic_r[0]   <= #TCQ rst_out2_logic;
    rst_out2_logic_r[2:1] <= #TCQ rst_out2_logic_r[1:0]; 
    rst_out2_logic_r1     <= #TCQ rst_out2_logic_r[2];
  end
  // ============================= Reset for MicroBlaze ==============================
  // Reset synchorinizer
  always @(posedge riu_clk) begin
    rst_mb_sync_r[0]   <= #TCQ rst_async_mb ;
    rst_mb_sync_r[1]   <= #TCQ rst_mb_sync_r[0];
  end

 //Counter For Reset Stretching  
  always @(posedge riu_clk) begin
    if (rst_mb_sync_r[1])
      counter_mb_rst    <= #TCQ   RST_DIV_SYNC_NUM;
    else if (counter_mb_rst != 0) 
      counter_mb_rst    <= #TCQ  counter_mb_rst - 1'b1;
    else 
      counter_mb_rst    <= #TCQ  counter_mb_rst;
  end

  always @(posedge riu_clk) begin
    if (counter_mb_rst != 0) 
      rst_mb_logic <= #TCQ  1'b1;
    else 
      rst_mb_logic <= #TCQ  1'b0;
  end
  
  always @(posedge riu_clk) begin
    rst_mb_logic_r[0]   <= #TCQ rst_mb_logic;
    rst_mb_logic_r[2:1] <= #TCQ rst_mb_logic_r[1:0]; 
    rst_mb_logic_r1     <= #TCQ rst_mb_logic_r[2];
  end
  ////////////////END of Reset Block for MB////////////////////

  assign rstdiv0  = rst_div_logic_r1;   // Reset For Fabric Div clk  Domain
  assign rstdiv1  = rst_riu_logic_r1;   // Reset For RIU Clock Domain
  assign rstout2  = rst_out2_logic_r1;  // Reset for ui_clkout2 domain
  assign reset_ub = rst_mb_logic_r1;    // Reset for MicroBlaze 

  always @(posedge div_clk) begin
    if (rst_div_logic_r1)
      pll_gate_cnt <= #TCQ 7'h0;
    else if (pll_gate_cnt < PLL_GATE_CNT_LIMIT)
      pll_gate_cnt <= #TCQ pll_gate_cnt + 7'h1;
  end

  always @ (posedge div_clk)
  begin
    if (rst_div_logic_r1) begin
      pllgate <= #TCQ 1'b0;
    end else if (pll_gate_cnt == PLL_GATE_CNT_LIMIT) begin
      pllgate <= #TCQ 1'b1;
    end
  end

endmodule


