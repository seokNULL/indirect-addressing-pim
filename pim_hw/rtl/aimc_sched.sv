`timescale 1ps / 1ps

import aimc_lib::*;

module aimc_sched (
  input  logic clk, rst,
  // Configuration Register
  input  logic [$bits(cfr_mode_t)-1:0] cfr_mode_p,
  input  logic [$bits(cfr_time_t)-1:0] cfr_time_p,
  input  logic [$bits(cfr_refr_t)-1:0] cfr_refr_p,
  input  logic [$bits(cfr_schd_t)-1:0] cfr_schd_p,
  // User Interface
  input  pkt_t ui_pkt,
  input  logic ui_pkt_valid,
  output logic sched_rdy,
  // Data Handler Interface
  input  pkt_t intf_pkt,
  input  logic intf_pkt_retry,
  // Calibration Interface
  input  logic cal_done,
  input  logic cal_ref_stop,
  output logic ref_idle,
  // Command and Data Handler Interface
  output pkt_t sched_pkt,
  output cmd_t sched_cmd,
  output logic sched_pkt_valid,
  input  logic intf_rdy,
  input  logic temp_valid,
  input  logic [7:0] temp_data);
  
  // =============================== Signal Declarations ===============================
  // Row Arbiter Signals
  logic      rowarb_rdy;                             // Flag indicating that Row Arbiter is ready to accept input packets
  pkt_meta_t rowarb_pkt [2**BK_ADDR_WIDTH:0];        // Packet at the Row Arbiter output
  logic      [2**BK_ADDR_WIDTH:0] rowarb_pkt_valid;  // Flag indicating that a valid packet is available at the Row Arbiter output
  logic      [MASK_WIDTH-1:0]     rowarb_mask;       // Write data mask passed to Bank Arbiter when a packet is selected
  logic      [DATA_WIDTH-1:0]     rowarb_data;       // Write data passed to Bank Arbiter when a packet is selected
  // Bank Engine Signals
  pkt_meta_t [2**BK_ADDR_WIDTH-1:0] bke_pkt;         // Packets at the Bank Engine outputs
  cmd_t      [2**BK_ADDR_WIDTH-1:0] bke_cmd;         // Commands at Bank Engine outputs (in sync with packets)
  logic      [2**BK_ADDR_WIDTH-1:0] bke_pkt_req;     // Bank Engine requests to Bank Arbiter
  logic      [2**BK_ADDR_WIDTH-1:0] bke_rdy;         // Flags indicating that Bank Engines are ready to accept packets from Row Arbiter
  logic      [2**BK_ADDR_WIDTH-1:0] flush;           // Bank Engine input signals for maximizing the priority of the packets they're currently holding
  logic      [2**BK_ADDR_WIDTH-1:0] bke_pause_aime;  // AiM Engine pause requests from bank Engines
  // AiM Engine Signals
  pkt_meta_t aime_pkt;                               // Packet at the AiM Engine output
  cmd_t      aime_cmd;                               // Command at AiM Engine output
  logic      aime_pkt_req;                           // AiM engine request to Bank Arbiter
  logic      aime_rdy;                               // Flag indicating that AiM Engine is ready to accept packets from Row Arbiter
  logic      aime_is_idle;                           // AiM Engine pause signal giving way to Bank Engines and Refresh Handler
  // Refresh Handler Signals
  pkt_meta_t refh_pkt;                               // Packet at the Refresh Handler output
  cmd_t      refh_cmd;                               // Command at the Refresh Handler output
  logic      refh_pkt_req;                           // Refresh Handler REFAB request to Bank Arbiter
  logic      [2**BK_ADDR_WIDTH-1:0] refpb_req;       // Refresh Handler REFPB requests to Bank Engines
  logic      [2**BK_ADDR_WIDTH-1:0] refpb_ack;       // Bank Engine REFPB acknowledgements to Refresh Handler
  logic      refh_pause_aime;                        // AiM Engine pause request from Refresh Handler
  // Bank Arbiter Signals
  pkt_meta_t bkarb_pkt, bkarb_pkt_d;                 // Packet at the Bank Arbiter output
  cmd_t      bkarb_cmd;                              // Command at the Bank Arbiter output
  logic      bkarb_pkt_valid;                        // Flag indicating that a valid packet is available at the Bank Arbiter output
  logic      bkarb_pkt_ignore;                       // Ignore flag for not pulling data during the command looping
  logic      [2**BK_ADDR_WIDTH+1:0] bkarb_pkt_ack;   // Bank Arbiter acknowledgements to 16 Bank Engines + 1 AiM Engine + 1 Refresh Handler

  genvar i;
  generate
    if (SCHED_STYLE == "FRFCFS") begin
      // ================================== Row Arbiter ==================================
      frfcfs_arbiter frfcfs_arbiter (
        .clk,
        .rst,
        // Configuration Register
        .cfr_schd_p,
        // UI Interface
        .ui_pkt,
        .ui_pkt_valid,
        .rowarb_rdy,
        // Data Handler Interface
        .intf_pkt,
        .intf_pkt_retry,
        // Bank Engine Interface
        .rowarb_pkt,
        .rowarb_pkt_valid,
        .bke_rdy        ({aime_rdy, bke_rdy}),
        // Bank Arbiter Interface
        .bkarb_pkt_valid,
        .bkarb_pkt_ignore,
        .bkarb_cmd,
        .bkarb_data_ptr (bkarb_pkt.data_ptr),
        .rowarb_mask,
        .rowarb_data);

      // ================================= Bank Engines ==================================
      for (i=0; i<2**BK_ADDR_WIDTH; i++) begin : bkEng
        bank_engine #(.BANK_INDEX(i)) bank_engine (
          .clk,
          .rst,
          // Configuration Register
          .cfr_mode_p,
          .cfr_time_p,
          // Refresh Handler and AiM Engine Interface
          .refpb_req       (refpb_req      [i]),
          .refpb_ack       (refpb_ack      [i]),
          .bke_pause_aime  (bke_pause_aime [i]),
          .aime_is_idle,
          // Priority Injection
          .flush           (flush          [i]),  
          // Row Arbiter Interface
          .rowarb_pkt      (rowarb_pkt     [i]),
          .rowarb_pkt_req  (rowarb_pkt_valid [i]),
          .bke_pkt_ack     (bke_rdy        [i]),
          // Bank Arbiter Interface (Individual)
          .bke_pkt         (bke_pkt        [i]),
          .bke_cmd         (bke_cmd        [i]),
          .bke_pkt_req     (bke_pkt_req    [i]),
          .bkarb_pkt_ack   (bkarb_pkt_ack  [i]),
          // Bank Arbiter Interface (Broadcasted)
          .bkarb_cmd,
          .bkarb_cmd_bk    (bkarb_pkt.bk_addr),
          .bkarb_cmd_row   (bkarb_pkt.row_addr),
          .bkarb_cmd_valid (bkarb_pkt_valid));

        // Giving the highest priority to the current Bank Engine requests when high-priority inputs are pending
        assign flush[i] = refpb_req[i] || (rowarb_pkt_valid[i] && rowarb_pkt[i].prio > 1);  
      end

      aim_engine aim_engine (
        .clk,
        .rst,
        // Configuration Register
        .cfr_mode_p,
        .cfr_time_p,
        .cfr_schd_p,
        // Bank Engine and Refresh Handler Interface
        .refh_pause_aime,
        .bke_pause_aime,
        .aime_is_idle,
        // Row Arbiter Interface
        .rowarb_pkt      (rowarb_pkt       [2**BK_ADDR_WIDTH]),
        .rowarb_pkt_req  (rowarb_pkt_valid [2**BK_ADDR_WIDTH]),
        .aime_pkt_ack    (aime_rdy),
        // Bank Arbiter Interface (Individual)
        .aime_pkt,
        .aime_cmd,
        .aime_pkt_req,
        .bkarb_pkt_ack   (bkarb_pkt_ack [2**BK_ADDR_WIDTH]),
        // Bank Arbiter Interface (Broadcasted)
        .bkarb_cmd,
        .bkarb_cmd_bk    (bkarb_pkt.bk_addr),
        .bkarb_cmd_row   (bkarb_pkt.row_addr),
        .bkarb_cmd_valid (bkarb_pkt_valid));

      // ================================ Refresh Handler ================================
      refr_handler refr_handler (
        .clk,
        .rst,
        .cal_done,
        .cal_ref_stop,
        .ref_idle,
        // Configuration Register
        .cfr_mode_p,
        .cfr_time_p,
        .cfr_refr_p,
        // Bank Engine and AiM Engine Interface
        .refpb_req,
        .refpb_ack,
        .refh_pause_aime,
        .aime_is_idle,
        // Bank Arbiter Interface (Individual)
        .refh_pkt_req,
        .refh_pkt,
        .refh_cmd,
        .bkarb_pkt_ack   (bkarb_pkt_ack [2**BK_ADDR_WIDTH+1]),
        // Bank Arbiter Interface (Broadcast)
        .bkarb_cmd_valid (bkarb_pkt_valid),
        .bkarb_cmd,
        .bkarb_cmd_bk    (bkarb_pkt.bk_addr),
        // Data Handler Interface
        .temp_valid,
        .temp_data);

      // ================================= Bank Arbiter ==================================
      bank_arbiter bank_arbiter (
        .clk,
        .rst,
        // Configuration Register
        .cfr_schd_p,
        // Bank Engine Interface
        .bke_pkt     ({refh_pkt,     aime_pkt,     bke_pkt    }),
        .bke_cmd     ({refh_cmd,     aime_cmd,     bke_cmd    }),
        .bke_pkt_req ({refh_pkt_req, aime_pkt_req, bke_pkt_req}),
        .bkarb_pkt_ack,
        // Command/Data Handler Interface
        .bkarb_en    (cal_done && intf_rdy),
        .bkarb_pkt,
        .bkarb_cmd,
        .bkarb_pkt_valid,
        .bkarb_pkt_ignore);
    end

    else if (SCHED_STYLE == "FIFO") begin
      // ================================== Row Arbiter ==================================
      fifo_arbiter fifo_arbiter (
        .clk,
        .rst,
        // Configuration Register
        .cfr_schd_p,
        // UI Interface
        .ui_pkt,
        .ui_pkt_valid,
        .rowarb_rdy,
        // Data Handler Interface
        .intf_pkt,
        .intf_pkt_retry,
        // Bank Engine Interface
        .rowarb_pkt       (rowarb_pkt       [1:0]),
        .rowarb_pkt_valid (rowarb_pkt_valid [1:0]),
        .bke_rdy          ({aime_rdy, bke_rdy[0]}),
        // Bank Arbiter Interface
        .bkarb_pkt_valid,
        .bkarb_pkt_ignore,
        .bkarb_cmd,
        .bkarb_data_ptr (bkarb_pkt.data_ptr),
        .rowarb_mask,
        .rowarb_data);

      // ================================= Bank Engines ==================================
      bank_engine_fifo bank_engine_fifo (
        .clk,
        .rst,
        // Configuration Register
        .cfr_mode_p,
        .cfr_time_p,
        // Refresh Handler and AiM Engine Interface
        .refpb_req       (refpb_req),
        .refpb_ack       (refpb_ack),
        .bke_pause_aime  (bke_pause_aime   [0]),
        .aime_is_idle,
        // Priority Injection
        .flush           (flush            [0]),  
        // Row Arbiter Interface
        .rowarb_pkt      (rowarb_pkt       [0]),
        .rowarb_pkt_req  (rowarb_pkt_valid [0]),
        .bke_pkt_ack     (bke_rdy          [0]),
        // Bank Arbiter Interface (Individual)
        .bke_pkt         (bke_pkt          [0]),
        .bke_cmd         (bke_cmd          [0]),
        .bke_pkt_req     (bke_pkt_req      [0]),
        .bkarb_pkt_ack   (bkarb_pkt_ack    [0]),
        // Bank Arbiter Interface (Broadcasted)
        .bkarb_cmd,
        .bkarb_cmd_bk    (bkarb_pkt.bk_addr),
        .bkarb_cmd_row   (bkarb_pkt.row_addr),
        .bkarb_cmd_valid (bkarb_pkt_valid));

      // Giving the highest priority to the current Bank Engine requests when high-priority inputs are pending
      assign flush[0] = |refpb_req || (rowarb_pkt_valid[0] && rowarb_pkt[0].prio > 1);  

      aim_engine aim_engine (
        .clk,
        .rst,
        // Configuration Register
        .cfr_mode_p,
        .cfr_time_p,
        .cfr_schd_p,
        // Bank Engine and Refresh Handler Interface
        .refh_pause_aime,
        .bke_pause_aime  ({2**BK_ADDR_WIDTH{bke_pause_aime[0]}}),
        .aime_is_idle,
        // Row Arbiter Interface
        .rowarb_pkt      (rowarb_pkt       [1]),
        .rowarb_pkt_req  (rowarb_pkt_valid [1]),
        .aime_pkt_ack    (aime_rdy),
        // Bank Arbiter Interface (Individual)
        .aime_pkt,
        .aime_cmd,
        .aime_pkt_req,
        .bkarb_pkt_ack   (bkarb_pkt_ack [1]),
        // Bank Arbiter Interface (Broadcasted)
        .bkarb_cmd,
        .bkarb_cmd_bk    (bkarb_pkt.bk_addr),
        .bkarb_cmd_row   (bkarb_pkt.row_addr),
        .bkarb_cmd_valid (bkarb_pkt_valid));

      // ================================ Refresh Handler ================================
      refr_handler refr_handler (
        .clk,
        .rst,
        .cal_done,
        .cal_ref_stop,
        .ref_idle,        
        // Configuration Register
        .cfr_mode_p,
        .cfr_time_p,
        .cfr_refr_p,
        // Bank Engine and AiM Engine Interface
        .refpb_req,
        .refpb_ack,
        .refh_pause_aime,
        .aime_is_idle,
        // Bank Arbiter Interface (Individual)
        .refh_pkt_req,
        .refh_pkt,
        .refh_cmd,
        .bkarb_pkt_ack   (bkarb_pkt_ack [2]),
        // Bank Arbiter Interface (Broadcast)
        .bkarb_cmd_valid (bkarb_pkt_valid),
        .bkarb_cmd,
        .bkarb_cmd_bk    (bkarb_pkt.bk_addr),
        // Data Handler Interface
        .temp_valid,
        .temp_data);

      // ================================= Bank Arbiter ==================================
      bank_arbiter_fifo bank_arbiter_fifo (
        .clk,
        .rst,
        // Configuration Register
        .cfr_schd_p,
        // Bank Engine Interface
        .bke_pkt       ({refh_pkt,     aime_pkt,     bke_pkt     [0]}),
        .bke_cmd       ({refh_cmd,     aime_cmd,     bke_cmd     [0]}),
        .bke_pkt_req   ({refh_pkt_req, aime_pkt_req, aime_is_idle && bke_pkt_req [0]}),
        .bkarb_pkt_ack (bkarb_pkt_ack [2:0]),
        // Command/Data Handler Interface
        .bkarb_en      (cal_done && intf_rdy),
        .bkarb_pkt,
        .bkarb_cmd,
        .bkarb_pkt_valid,
        .bkarb_pkt_ignore);
    end
  endgenerate

  // ============================= Scheduler Output Signals ============================
  assign sched_rdy = rowarb_rdy;
  
  always @(posedge clk, posedge rst)
    if (rst) sched_pkt_valid <= 0;
    else     sched_pkt_valid <= bkarb_pkt_valid;   // Delaying bkarb_pkt_valid one clock cycle for the rowarb_data to arrive from the URAM

  always @(posedge clk) bkarb_pkt_d <= bkarb_pkt;  // Delaying all packet meta data one cycle for the rowarb_data to arrive

  // Composing output packet from the delayed metadata and rowarb_data from the URAM
  always_comb begin
    sched_pkt.marker   = bkarb_pkt_d.marker;
    sched_pkt.bcast    = bkarb_pkt_d.bcast;
    sched_pkt.prio     = bkarb_pkt_d.prio;
    sched_pkt.req_type = bkarb_pkt_d.req_type;
    sched_pkt.row_addr = bkarb_pkt_d.row_addr;
    sched_pkt.col_addr = bkarb_pkt_d.col_addr;
    sched_pkt.bk_addr  = bkarb_pkt_d.bk_addr;
    sched_pkt.mask     = rowarb_mask;
    sched_pkt.data     = rowarb_data;
  end

  always @(posedge clk)
    sched_cmd <= bkarb_cmd;

  // ================================== Debug Counters =================================
  // logic [31:0] sched_cnt [2:0];

  // always @(posedge clk, posedge rst)
  //   if (rst) sched_cnt[0] <= 0;
  //   else if (sched_pkt_valid && (sched_cmd == RD || sched_cmd == WDM)) sched_cnt[0] <= sched_cnt[0] + 1;

  // always @(posedge clk, posedge rst)
  //   if (rst) sched_cnt[1] <= 0;
  //   else if (rowarb_pkt_valid[0] && bke_rdy[0]) sched_cnt[1] <= sched_cnt[1] + 1;

  // always @(posedge clk, posedge rst)
  //   if (rst) sched_cnt[2] <= 0;
  //   else if (ui_pkt_valid && sched_rdy) sched_cnt[2] <= sched_cnt[2] + 1;

  // initial sched_cnt = '{0, 0, 0};

  // ================================== Initialization =================================
  initial begin
    sched_pkt_valid = 0;
    bkarb_pkt_d = 0;
    sched_cmd = NOP1;
  end

endmodule
