`timescale 1ps / 1ps

import aimc_lib::*;

module bank_engine #(parameter BANK_INDEX = 0) (  // Bank Address corresponding to the current bank engine
  input  logic  clk, rst,
  // Configuration Register
  input  logic [$bits(cfr_mode_t)-1:0] cfr_mode_p,
  input  logic [$bits(cfr_time_t)-1:0] cfr_time_p,
  // AiM Engine and Refresh Handler Interface
  input  logic refpb_req,
  output logic refpb_ack,
  output logic bke_pause_aime,
  input  logic aime_is_idle,
  // Bank Engine Flushing
  input  logic flush,
  // Row Arbiter Interface
  input  pkt_meta_t rowarb_pkt,
  input  logic rowarb_pkt_req,
  output logic bke_pkt_ack,
  // Bank Arbiter Interface (Individual)
  output pkt_meta_t bke_pkt,
  output cmd_t bke_cmd,
  output logic bke_pkt_req,
  input  logic bkarb_pkt_ack,
  // Bank Arbiter Interface (Broadcasted)
  input  cmd_t bkarb_cmd,
  input  logic [BK_ADDR_WIDTH-1:0] bkarb_cmd_bk,
  input  logic [ROW_ADDR_WIDTH-1:0] bkarb_cmd_row,
  input  logic bkarb_cmd_valid);
  
  // ============================= Signal Declarations ===============================
  // Bank and Page State Variables
  typedef enum logic [1:0] {BANK_IDLE=0, BANK_ACTIVE}                        bank_st_t;
  typedef enum logic [1:0] {BKE_IDLE=0, BKE_DRAM_ACC, BKE_REFR}              engine_st_t;
  typedef enum logic [1:0] {PAGE_UNKNOWN=0, PAGE_EMPTY, PAGE_HIT, PAGE_MISS} page_st_t;
  bank_st_t   bank_state,  bank_state_nxt;
  engine_st_t engine_sate, engine_state_nxt;
  page_st_t   page_state;
  // Request Packet Signals
  logic bke_t_pass;                                           // Timing pass flag for the current command in the queue
  logic [ROW_ADDR_WIDTH-1:0] act_row_addr, act_row_addr_nxt;  // Address of the currently activated row
  pkt_meta_t bke_pkt_nxt;                                     // Next state for the bke_pkt register (packet at the Bank Arbiter interface)
  cmd_t bke_cmd_nxt;
  logic bke_pkt_req_nxt;                                      // Next state for the bke_pkt_req register (request to the Bank Arbiter)
  logic bke_pkt_ack_nxt;                                      // Next state for the bke_pkt_ack register (acknowledgement signal to the Row Arbiter)
  // Refresh and AiM Signals
  logic refpb_ack_nxt;                                        // Per-Bank Refresh Acknowledgement to the Refresh Handler
  logic bke_pause_aime_nxt;                                   // Request to pause AiM Engine (for aim_is_idle to be asserted)

  // =========================== Bank Engine Command Timer ===========================
  bank_timer #(.BANK_INDEX(BANK_INDEX)) bank_timer (
    .clk,
    .rst,
    // Configuration Register
    .cfr_mode_p,
    .cfr_time_p,
    // Bank Arbiter Interface (Broadcasted)
    .bkarb_cmd_valid,
    .bkarb_cmd,
    .bkarb_cmd_bk,
    // Local Interface
    .bke_cmd (bke_cmd_nxt),
    .bke_t_pass);

  // ================================ Bank Engine FSM ================================
  // Assigning "next" states to all FSM registers
  always @(posedge clk, posedge rst)
    if (rst) begin
      engine_sate    <= BKE_IDLE;
      // Request Packet Signals
      bke_pkt_req    <= 0;
      bke_pkt        <= 0;
      bke_cmd        <= NOP1;
      bke_pkt_ack    <= 0;
      // Refresh and AiM Signals
      refpb_ack      <= 0;
      bke_pause_aime <= 0;
    end
    else begin
      engine_sate    <= engine_state_nxt;
      // Request Packet Signals
      bke_pkt_req    <= bke_pkt_req_nxt;
      bke_pkt        <= bke_pkt_nxt;
      bke_cmd        <= bke_cmd_nxt;
      bke_pkt_ack    <= bke_pkt_ack_nxt;
      // Refresh and AiM Signals
      refpb_ack      <= refpb_ack_nxt;
      bke_pause_aime <= bke_pause_aime_nxt;
    end

  always_comb begin
    engine_state_nxt   = engine_sate;
    page_state         = PAGE_MISS;
    // Request Packet Signals
    bke_pkt_nxt        = bke_pkt;
    bke_cmd_nxt        = bke_cmd;
    bke_pkt_nxt.prio   = flush ? (PRIO-2) : bke_pkt.prio;
    bke_pkt_req_nxt    = bke_t_pass && aime_is_idle;       // AiM Engine must be idle for Bank Engine commands to be issued
    bke_pkt_ack_nxt    = 0;
    // Refresh and AiM Signals
    refpb_ack_nxt      = 0;
    bke_pause_aime_nxt = (bke_pkt.prio > 1);               // Request AiM pause when priority of the current packet is above 1 (AiM packet priority is fixed to 1)

    case (engine_sate)
      BKE_IDLE : begin
        if (refpb_req) begin                               // Refresh Request Packet
          refpb_ack_nxt    = 1'b1;
          bke_pkt_nxt.prio = PRIO-1;                       // Setting the highest priority to pause AiM packets
          engine_state_nxt = BKE_REFR;
        end
        else if (rowarb_pkt_req) begin                     // RD/WR Request Packet
          bke_pkt_ack_nxt  = 1'b1;
          bke_pkt_nxt      = rowarb_pkt;
          engine_state_nxt = BKE_DRAM_ACC;
        end
      end

      BKE_DRAM_ACC : begin
        // Checking page status (hit or miss) based on the bank state and the request packet row address
        if      (bank_state_nxt   == BANK_IDLE)        page_state = PAGE_EMPTY;
        else if (act_row_addr_nxt == bke_pkt.row_addr) page_state = PAGE_HIT;

        case (page_state)
          PAGE_EMPTY : bke_cmd_nxt = ACT;
          PAGE_HIT   : bke_cmd_nxt = (bke_pkt_nxt.req_type == WRITE) ? WDM : RD;  // All Bank Engine requests MUST be READ or WRITE (non-AiM)
          PAGE_MISS  : bke_cmd_nxt = PREPB;
        endcase

        // If a follow-up request of the same type to the same row is available, stay in the BKE_DRAM_ACC state, otherwise go back to BKE_IDLE
        if (bkarb_pkt_ack && (bke_cmd == RD || bke_cmd == WDM)) begin
          if (rowarb_pkt_req && (rowarb_pkt.row_addr == act_row_addr) && (rowarb_pkt.req_type == bke_pkt.req_type) && !refpb_req) begin
            bke_pkt_ack_nxt  = 1'b1;
            bke_pkt_nxt      = rowarb_pkt;
          end
          else begin
            bke_cmd_nxt      = NOP1;
            bke_pkt_nxt.prio = 0;         // Setting priority to 0 to make way for AiM packets
            engine_state_nxt = BKE_IDLE;
          end
        end
      end

      BKE_REFR : begin
        bke_pkt_nxt.bk_addr = BANK_INDEX;
        if (bank_state_nxt == BANK_IDLE) bke_cmd_nxt = REFPB;
        else                             bke_cmd_nxt = PREPB;

        if (bkarb_pkt_ack && bke_cmd == REFPB) begin
          bke_cmd_nxt      = NOP1;
          bke_pkt_nxt.prio = 0;           // Setting priority to 0 to make way for AiM packets
          engine_state_nxt = BKE_IDLE;
        end
      end
    endcase
  end

  // =============================== Bank State Update ===============================
  always @(posedge clk, posedge rst)
    if (rst) begin
      bank_state   <= BANK_IDLE;
      act_row_addr <= 0;
    end
    else begin
      bank_state   <= bank_state_nxt;
      act_row_addr <= act_row_addr_nxt;
    end

  always_comb begin
    bank_state_nxt   = bank_state;
    act_row_addr_nxt = act_row_addr;

    if (bkarb_cmd_valid) begin
      case (bkarb_cmd)
        ACT : begin
          if (BANK_INDEX == bkarb_cmd_bk) begin
            act_row_addr_nxt = bkarb_cmd_row;
            bank_state_nxt   = BANK_ACTIVE;
          end
        end
        PREPB : begin
          if (BANK_INDEX == bkarb_cmd_bk) begin
            bank_state_nxt = BANK_IDLE;
          end
        end
        PREAB : begin
          bank_state_nxt = BANK_IDLE;
        end
      endcase
    end
  end

  // ================================= Initialization ================================
  initial begin
    engine_sate    = BKE_IDLE;
    bank_state     = BANK_IDLE;
    // Request Packet Signals
    act_row_addr   = 0;
    bke_pkt_req    = 0;
    bke_pkt        = 0;
    bke_pkt_ack    = 0;
    // Refresh and AiM Signals
    refpb_ack      = 0;
    bke_pause_aime = 0;
  end

endmodule