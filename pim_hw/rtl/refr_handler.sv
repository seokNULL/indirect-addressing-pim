`timescale 1ps / 1ps

module refr_handler (
  input  logic clk, rst,
  input  logic cal_done,
  input  logic cal_ref_stop,
  output logic ref_idle,
  // Configuration Register
  input  logic [$bits(cfr_mode_t)-1:0] cfr_mode_p,
  input  logic [$bits(cfr_time_t)-1:0] cfr_time_p,
  input  logic [$bits(cfr_refr_t)-1:0] cfr_refr_p,
  // Bank Engine and AiM Engine Interface
  output logic [2**BK_ADDR_WIDTH-1:0] refpb_req,
  input  logic [2**BK_ADDR_WIDTH-1:0] refpb_ack,
  output logic refh_pause_aime,
  input  logic aime_is_idle,
  // Bank Arbiter Interface (Individual)
  output logic refh_pkt_req,
  output pkt_meta_t refh_pkt,
  output cmd_t refh_cmd,
  input  logic bkarb_pkt_ack,
  // Bank Arbiter Interface (Broadcasted)
  input  logic bkarb_cmd_valid,
  input  cmd_t bkarb_cmd,
  input  logic [BK_ADDR_WIDTH-1:0] bkarb_cmd_bk,
  // Data Handler Interface
  input  logic temp_valid,
  input  logic [7:0] temp_data);
  
  // =============================== Signal Definitions ===============================
  // Configuration Register
  cfr_time_t   cfr_time;                         // DRAM timing parameter array
  cfr_refr_t   cfr_refr;                         // Refresh parameter array
  // Main FSM Signals and Variables
  typedef enum logic [3:0] {REFR_IDLE=0, REFR_AB, REFR_PB, REFR_P2B, REFR_ERROR} refh_state_t;
  refh_state_t refh_state, refh_state_nxt;
  logic [3:0]  step, step_nxt;
  logic [2**BK_ADDR_WIDTH-1:0] bk_state, bk_state_nxt;
  logic        rtn_prepb, rtn_prepb_nxt;         // Indicator for pending return to the REFR_PB state
  logic        rtn_prep2b, rtn_prep2b_nxt;       // Indicator for pending return to the REFR_P2B state
  logic        go_idle;                          // Forces FSM to change state to REFR_IDLE (required to switch between refresh policies)
  logic        ref_idle_r0;                      // Register chain for refresh idle siglan (for easier place-and-route)
  logic        ref_idle_r1;
  logic        ref_idle_r2;
  // Output Request Signals
  logic        refh_pkt_req_nxt;
  pkt_meta_t   pkt_empty;                        // Empty packet with only the priority set to max
  pkt_meta_t   refh_pkt_int;                     // Internal packet copy which never goes to NOP (refh_pkt is often set to NOP to occupy the Bank Arbiter with empty commands)
  cmd_t        refh_cmd_int;                     // Internal command copy which never goes to NOP (refh_pkt is often set to NOP to occupy the Bank Arbiter with empty commands)
  pkt_meta_t   refh_pkt_nxt;
  cmd_t        refh_cmd_nxt;
  logic [2**BK_ADDR_WIDTH-1:0] refpb_req_nxt;
  logic        refh_pause_aime_nxt;
  // Command Timer Signals
  logic        refh_t_pass;                      // Timing Pass flag for the queued command
  logic        ref_done;                         // Indicates that the current refresh command sequence is completed
  // Refresh Counters
  logic [31:0] ref_cnt, ref_cnt_nxt;             // The main counter for keeping track of refhesh interval
  logic [31:0] refab_cnt, refab_cnt_nxt;         // Counter for enforcing REFAB commands every 1 ms
  logic [31:0] temp_cnt, temp_cnt_nxt;           // Counter for periodic temperature reads
  logic [6:0]  ref_pending, ref_pending_nxt;     // Pending refresh counter for postponing refresh commands
  logic [BK_ADDR_WIDTH-1:0] bk_cnt, bk_cnt_nxt;  // Bank counter for keeping track of REFPB and REFP2B commands

  // ============================= Configuration Register =============================
  assign cfr_time = cfr_time_t'(cfr_time_p);
  assign cfr_refr = cfr_refr_t'(cfr_refr_p);

  // ========================= Refresh Handler Command Timer ==========================
  refr_timer refr_timer (
    .clk,
    .rst,
    // Configuration Register
    .cfr_mode_p,
    .cfr_time_p,
    // Bank Arbiter Interface
    .bkarb_cmd_valid,
    .bkarb_cmd,
    // Local Interface
    .refh_cmd (refh_cmd_nxt),
    .refh_t_pass);

  // ============================== Bank State Tracking ===============================
  always @(posedge clk, posedge rst)
    if      (rst)             bk_state <= 0;
    else if (bkarb_cmd_valid) bk_state <= bk_state_nxt;

  always_comb begin
    bk_state_nxt = bk_state;
    case (bkarb_cmd)
      ACT   : bk_state_nxt[bkarb_cmd_bk] = 1;
      PREPB : bk_state_nxt[bkarb_cmd_bk] = 0;
      PREAB : bk_state_nxt = 0;
    endcase
  end

  // =============================== Refresh Handler FSM ==============================
  always_comb begin
    pkt_empty = 0;
    pkt_empty.prio = REF_PRIO;
  end

  always @(posedge clk) begin
    refh_pkt     <= refh_t_pass ? refh_pkt_nxt : pkt_empty;
    refh_pkt_int <= refh_pkt_nxt;

    refh_cmd     <= refh_t_pass ? refh_cmd_nxt : NOP1;
    refh_cmd_int <= refh_cmd_nxt;
  end

  // Assigning "next" states to all FSM registers
  always @(posedge clk, posedge rst)
    if (rst) begin
      refh_state      <= REFR_IDLE;
      step            <= 0;
      rtn_prepb       <= 0;
      rtn_prep2b      <= 0;
      ref_idle_r0     <= 1;
      ref_idle_r1     <= 1;
      ref_idle_r2     <= 1;
      ref_idle        <= 1;
      // Refresh Requests
      refh_pkt_req    <= 0;
      refpb_req       <= 0;
      refh_pause_aime <= 0;
      // Counters
      ref_cnt         <= 0;
      refab_cnt       <= ck_adj(cfr_refr_init.REFAB_PER);
      temp_cnt        <= 0;
      ref_pending     <= 0;
      bk_cnt          <= 0;
    end
    else begin
      refh_state      <= refh_state_nxt;
      step            <= step_nxt;
      rtn_prepb       <= rtn_prepb_nxt;
      rtn_prep2b      <= rtn_prep2b_nxt;
      ref_idle_r0     <= refh_state == REFR_IDLE;
      ref_idle_r1     <= ref_idle_r0;
      ref_idle_r2     <= ref_idle_r1;
      ref_idle        <= ref_idle_r2;
      // Refresh Requests
      refh_pkt_req    <= refh_pkt_req_nxt;
      refpb_req       <= refpb_req_nxt;
      refh_pause_aime <= refh_pause_aime_nxt;
      // Counters
      ref_cnt         <= ref_cnt_nxt;
      refab_cnt       <= refab_cnt_nxt;
      temp_cnt        <= temp_cnt_nxt;
      ref_pending     <= ref_pending_nxt;
      bk_cnt          <= bk_cnt_nxt;
    end

  always_comb begin
    refh_state_nxt    = refh_state;
    step_nxt          = step;
    rtn_prepb_nxt     = rtn_prepb;
    rtn_prep2b_nxt    = rtn_prep2b;
    go_idle           = 0;
    // Refresh Requests
    ref_done          = 0;
    refh_pkt_req_nxt  = 0;
    refh_pkt_nxt      = refh_pkt_int;
    refh_cmd_nxt      = refh_cmd_int;
    refh_pkt_nxt.prio = REF_PRIO;
    refpb_req_nxt     = refpb_req;
    refh_pause_aime_nxt = 0;
    // Counters
    ref_cnt_nxt       = 0;
    refab_cnt_nxt     = refab_cnt;
    temp_cnt_nxt      = (temp_cnt == 0) ? 0 : temp_cnt - 1'b1;
    ref_pending_nxt   = ref_pending;
    bk_cnt_nxt        = bk_cnt;

    case (refh_state)
      REFR_IDLE : begin
        if (cal_done && !cal_ref_stop) begin
          case (cfr_refr.REF_POLICY)
            POL_REFAB : refh_state_nxt = REFR_AB;
            POL_REFPB : refh_state_nxt = REFR_PB;
            POL_NOREF : refh_state_nxt = REFR_IDLE;
            default   : refh_state_nxt = REFR_IDLE;
          endcase
        end
      end

      REFR_AB : begin
        go_idle         = cfr_refr.REF_POLICY != POL_REFAB || cal_ref_stop;   // Go to IDLE state when policy changes
        ref_cnt_nxt     = (ref_cnt == 0) ? ck_adj(cfr_time.tREFIab) - 1'b1 : ref_cnt - 1'b1;
        ref_pending_nxt = ref_pending + (ref_cnt == 0);
        if (ref_pending == 9 && ref_cnt == 0) refh_state_nxt = REFR_ERROR;    // Maximum number of postponed REFAB commands is 9

        refab();

        if (ref_done && ref_pending == 0) begin     
          if (go_idle) begin
            refh_state_nxt  = REFR_IDLE;
          end
          else if (rtn_prepb||rtn_prep2b) begin                               // If a return to REFR_PB or REFR_P2B is pending, issue the return
            refh_state_nxt  = rtn_prepb ? REFR_PB : REFR_P2B;
            ref_cnt_nxt     = rtn_prepb ? ck_adj(cfr_time.tREFIpb) : ck_adj(2*cfr_time.tREFIpb);
            rtn_prepb_nxt   = 0;
            rtn_prep2b_nxt  = 0;
          end
        end
      end

      REFR_PB : begin
        go_idle         = cfr_refr.REF_POLICY != POL_REFPB || cal_ref_stop;   // Go to IDLE state when policy changes
        ref_cnt_nxt     = (ref_cnt == 0) ? ck_adj(cfr_time.tREFIpb) - 1'b1 : ref_cnt - 1'b1;
        ref_pending_nxt = ref_pending + (ref_cnt == 0);
        refab_cnt_nxt   = (refab_cnt == 0) ? 0 : refab_cnt - 1'b1;            // Hold "0" until the next refresh is pending to let the system know it must issue REFAB
        if (ref_pending == 144 && ref_cnt == 0) refh_state_nxt = REFR_ERROR;  // Maximum number of postponed REFPB commands is 16*9

        refpb();

        if (ref_done) begin
          if (go_idle && ref_pending == 0) begin                              // Allowing to change policies only when all pending refresh requests have been satisfied
            refh_state_nxt  = REFR_IDLE;
          end
          else if (refab_cnt == 0) begin                                      // Force REFAB every 1 ms even if there are pending REFPB present (unlikely to happen though)
            refh_state_nxt  = REFR_AB;
            rtn_prepb_nxt   = 1;                                              // Setting a pending return to the REFR_PB state
            refab_cnt_nxt   = ck_adj(cfr_refr.REFAB_PER);                     // Resetting the REFAB period counter
            ref_cnt_nxt     = 0;                                              // Setting refresh counter to "0" so that a pending request appears immediately after switching to to a new policy
            ref_pending_nxt = 0;                                              // Setting pending requests to "0" to prevent falling into REFR_ERROR state
          end
        end
      end

      REFR_P2B : begin
        // ref_cnt_nxt     = (ref_cnt == 0) ? 2*tREFIpb - 1'b1 : ref_cnt - 1'b1;
        // ref_pending_nxt = ref_pending + (ref_cnt == 0);
        // refab_cnt_nxt   = (refab_cnt == 0) ? 0 : refab_cnt - 1'b1;            // Hold "0" until the next refresh is pending to let the system know it must issue REFAB

        // refp2b();

        // if (ref_done) begin
        //   if (go_idle && ref_pending == 0) begin                              // Allowing to change policies only when all pending refresh requests have been satisfied
        //     refh_state_nxt  = REFR_IDLE;
        //   end
        //   else if (refab_cnt == 0) begin                                      // Force REFAB every 1 ms even if there are pending REFPB present (unlikely to happen though)
        //     refh_state_nxt  = REFR_AB;
        //     rtn_prep2b_nxt  = 1;                                              // Setting a pending return to the REFR_PB state
        //     refab_cnt_nxt   = cfr_refr.REFAB_PER;                             // Resetting the REFAB period counter
        //     ref_cnt_nxt     = 0;                                              // Setting refresh counter to "0" so that a pending request appears immediately after switching to REFR_AB
        //     ref_pending_nxt = 0;                                              // Setting pending requests to "0" to prevent falling into REFR_ERROR state
        //   end
        // end
      end

      REFR_ERROR : begin
        /*Error state, should never occur*/
      end
    endcase
  end

  // ================================== Local Tasks ===================================
  task refab;
    begin
      case (step)
        0 : begin
          refh_pkt_req_nxt    = refh_t_pass && aime_is_idle;
          refh_pause_aime_nxt = ref_pending;                  // When refresh is ready, request AiM Engine to pause its activity and issue a PREPB, PREAB, or NDMX command
        end
        default: begin
          refh_pkt_req_nxt    = 1;                            // Occupying Bank Arbiter with empty high priority requests until refresh sequence is complete (PREAB + REFAB + MRSx2)
          refh_pause_aime_nxt = 1;                            // Keep AiM Engine paused until the end of the refresh
        end
      endcase

      case (step)
        0 : begin
          if (ref_pending != 0) begin
            // refh_pkt_req_nxt = 1;
            refh_pkt_req_nxt = aime_is_idle;                  // If AiM Engine is paused, issue refresh requests as normal
            if (bkarb_pkt_ack && (bkarb_cmd == NOP1)) begin   // Waiting until the first empty response to make sure there are no lingering requests from other blocks
              bk_cnt_nxt       = 0;                           // Resetting bank counter to "0" with each REFAB command
              step_nxt         = |bk_state ? 1     : 2;
              refh_cmd_nxt     = |bk_state ? PREAB : REFAB;
            end
          end
        end
        // Precharging all banks before the refresh
        1 : begin
          if (bkarb_pkt_ack && (bkarb_cmd != NOP1)) begin     // "&& (bkarb_cmd != NOP1)" is required for distinguishing between bkarb_pkt_ack to empty and non-empty requests
            step_nxt     = 2;
            refh_cmd_nxt = REFAB;
          end
        end
        // Refreshing all banks
        2 : begin
          if (bkarb_pkt_ack && (bkarb_cmd != NOP1)) begin
            step_nxt              = (temp_cnt == 0) ? 3        : 0;
            refh_cmd_nxt          = (temp_cnt == 0) ? MRS_TEMP : NOP1;
            ref_done              = !(temp_cnt == 0);
            refh_pkt_nxt.bk_addr  = 4'h3;
            refh_pkt_nxt.row_addr = {BGmr3, 2'b00, 2'b10, 3'b000, 3'b000};
            ref_pending_nxt       = ref_pending + (ref_cnt == 0) - 1'b1;
          end
        end
        // Reading-out the temperature
        3 : begin
          if (bkarb_pkt_ack && (bkarb_cmd != NOP1)) begin
            step_nxt              = 4;
            refh_cmd_nxt          = MRS_TEMP;
            refh_pkt_nxt.bk_addr  = 4'h3;
            refh_pkt_nxt.row_addr = {BGmr3, 2'b00, 2'b00, 3'b000, 3'b000};
          end
        end
        4 : begin
          if (bkarb_pkt_ack && (bkarb_cmd != NOP1)) begin
            step_nxt     = 0;
            refh_cmd_nxt = NOP1;
            temp_cnt_nxt = cfr_refr.TEMP_RD_PER;
            ref_done     = 1;
          end
        end
      endcase
    end
  endtask

  task refpb;
    begin
      case (step)
        0 : begin
          if (ref_pending != 0) begin
            refpb_req_nxt[bk_cnt] = 1;
            step_nxt              = 1;
          end
        end
        // Refreshing a single bank
        1 : begin
          if (bkarb_cmd_valid && bkarb_cmd == REFPB && bkarb_cmd_bk == bk_cnt) begin
            refpb_req_nxt[bk_cnt] = 0;
            step_nxt              = 0;
            ref_done              = 1;
            ref_pending_nxt       = ref_pending + (ref_cnt == 0) - 1'b1;
            bk_cnt_nxt            = bk_cnt + 1'b1;
          end
        end
      endcase
    end
  endtask

  task refp2b;
    begin
      /* Placeholder */
    end
  endtask

  function automatic logic [31:0] ck_adj;
    input logic [31:0] t;
    begin
      if (GLOBAL_CLK == "CK_DIV2") ck_adj = (t >> 1) + t[0];  // Rounding up
      else                         ck_adj = t;
    end
  endfunction

  // ================================= Initialization =================================
  initial begin
      refh_state      = REFR_IDLE;
      step            = 0;
      rtn_prepb       = 0;
      rtn_prep2b      = 0;
      ref_idle_r0     = 1;
      ref_idle_r1     = 1;
      ref_idle_r2     = 1;
      ref_idle        = 1;
      // Refresh Requests
      refh_pkt_req    = 0;
      refh_pkt        = 0;
      refh_cmd        = NOP1;
      refh_pkt_int    = 0;
      refh_cmd_int    = NOP1;
      refpb_req       = 0;
      refh_pause_aime = 0;
      // Counters
      ref_cnt         = 0;
      refab_cnt       = ck_adj(cfr_refr_init.REFAB_PER);
      temp_cnt        = 0;
      ref_pending     = 0;
      bk_cnt          = 0;
  end

endmodule
