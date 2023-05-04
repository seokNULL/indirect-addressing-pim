`timescale 1ps / 1ps
import aimc_lib::*;

module aim_engine (
  input  logic  clk, rst,
  // Configuration Register
  input  logic [$bits(cfr_mode_t)-1:0] cfr_mode_p,
  input  logic [$bits(cfr_time_t)-1:0] cfr_time_p,
  input  logic [$bits(cfr_schd_t)-1:0] cfr_schd_p,
  // Bank Engine and Refresh Handler Interface
  input  logic [2**BK_ADDR_WIDTH-1:0] bke_pause_aime,
  input  logic refh_pause_aime,
  output logic aime_is_idle,
  // Row Arbiter Interface
  input  pkt_meta_t rowarb_pkt,
  input  logic rowarb_pkt_req,
  output logic aime_pkt_ack,
  // Bank Arbiter Interface (Individual)
  output pkt_meta_t aime_pkt,
  output cmd_t aime_cmd,
  output logic aime_pkt_req,
  input  logic bkarb_pkt_ack,
  // Bank Arbiter Interface (Broadcasted)
  input  cmd_t bkarb_cmd,
  input  logic [BK_ADDR_WIDTH-1:0]  bkarb_cmd_bk,
  input  logic [ROW_ADDR_WIDTH-1:0] bkarb_cmd_row,
  input  logic bkarb_cmd_valid);

  // ============================== Signal Declarations ==============================
  // Configuration Register
  cfr_schd_t cfr_schd;                                  // Scheduler parameter array
  cfr_mode_t cfr_mode;                                  // Mode Register parameter array
  // State Variables
  typedef enum logic [2:0] {AIME_IDLE=0, AIME_PREP, AIME_WAIT, AIME_NDM, AIME_SBK, AIME_ABK, AIME_AF, AIME_MRS} aime_st_t;
  aime_st_t   aime_state, aime_state_nxt;               // Main AiM engine state indicating the type of operations currently being executed
  logic       pause_req;                                // Combined pause request from Bank Engines and Refresh Handler
  logic       aime_is_idle_nxt;                         // AiM Engine idle flag
  logic [1:0] step, step_nxt;                           // Auxiliary state variables for maintaining sequences
  bit   [2**BK_ADDR_WIDTH-1:0] bk_state, bk_state_nxt;  // Bank state register (ACT or IDLE)
  logic       loop, loop_nxt;                           // Flag indicating that the module is currently in a loop issuing consecutive commands
  logic       restore_bk, restore_bk_nxt;               // Flag for restoring old bank address after switching to a different one during MACSB with bank broadcast OFF
  // Request Packet Signals
  logic       aime_t_pass;                              // Timing pass flag for the current command in the queue
  pkt_meta_t  aime_pkt_nxt;                             // Packet to the Bank Arbiter
  cmd_t       aime_cmd_nxt;                             // Command to the Bank Arbiter
  logic       aime_pkt_req_nxt;                         // Request to the Bank Arbiter
  logic       aime_pkt_ack_nxt;                         // Acknowledgement to the Row Arbiter

  // ============================ Configuration Register =============================
  assign cfr_schd = cfr_schd_t'(cfr_schd_p);
  assign cfr_mode = cfr_mode_t'(cfr_mode_p);

  // =========================== AiM Engine Command Timer ============================
  aim_timer aim_timer (
    .clk,
    .rst,
    // Configuration Register
    .cfr_mode_p,
    .cfr_time_p,
    // Bank Arbiter Interface (Broadcasted)
    .bkarb_cmd_valid,
    .bkarb_cmd,
    // Local Interface
    .aime_cmd (aime_cmd_nxt),
    .aime_t_pass);

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

  // ================================ AiM Engine FSM =================================
  assign pause_req = |bke_pause_aime || refh_pause_aime;

  // Assigning "next" states to all FSM registers
  always @(posedge clk, posedge rst)
    if (rst) begin
      // State Variables
      aime_state   <= AIME_IDLE;
      aime_is_idle <= 1'b1;
      step         <= 0;
      loop         <= 0;
      restore_bk   <= 0;
      // Request Packet Signals
      aime_pkt_req <= 0;
      aime_pkt     <= 0;
      aime_cmd     <= NOP1;
    end
    else begin
      // State Variables
      aime_state   <= aime_state_nxt;
      aime_is_idle <= aime_is_idle_nxt;
      step         <= step_nxt;
      loop         <= loop_nxt;
      restore_bk   <= restore_bk_nxt;
      // Request Packet Signals
      aime_pkt_req <= aime_pkt_req_nxt;
      aime_pkt     <= aime_pkt_nxt;
      aime_cmd     <= aime_cmd_nxt;
    end

  generate
    if (SCHED_STYLE == "FIFO") begin  // Due to Bank Arbiter responding at the same clock cycles, AiM Engine also has to respond quicker
      assign aime_pkt_ack = aime_pkt_ack_nxt;
    end
    else if (SCHED_STYLE == "FRFCFS") begin
      always @(posedge clk, posedge rst)
        if (rst) aime_pkt_ack <= 0;
        else     aime_pkt_ack <= aime_pkt_ack_nxt;

      initial aime_pkt_ack = 0;
    end
  endgenerate

  always_comb begin
    // State Variables
    aime_state_nxt   = aime_state;
    aime_is_idle_nxt = aime_is_idle;
    step_nxt         = step;
    loop_nxt         = loop;
    restore_bk_nxt   = restore_bk;
    // Request Packet Signals
    aime_pkt_req_nxt = aime_t_pass;
    aime_pkt_nxt     = aime_pkt;
    aime_cmd_nxt     = aime_cmd;
    aime_pkt_ack_nxt = 0;

    case (aime_state)
      AIME_IDLE : begin
        if ((loop || rowarb_pkt_req) && !pause_req) begin
          aime_is_idle_nxt = 0;
          aime_state_nxt   = AIME_PREP;  // Switching to an intermediate "prepare" state to let "aime_is_idle = 0" to switch and propagate to Bank Engines
          aime_cmd_nxt     = NOP1;
          aime_pkt_nxt     = loop ? aime_pkt : rowarb_pkt;
          aime_pkt_ack_nxt = !loop;      // Don't acknowledge a new packet when in a loop - first need to finish the current one
          step_nxt         = 0;
        end
      end

      AIME_PREP : begin
        case (step)
          0, 1 : begin  // Using two additional clk cycle delay to make sure no requests from Bank Engines sneak in before AiM Engine starts issuing requests
            if (pause_req) begin
              aime_state_nxt   = AIME_IDLE;
              aime_is_idle_nxt = 1'b1;
              loop_nxt         = 1'b1;  // This is "fake" loop flag used to NOT issue aime_pkt_ack when leaving AIME_IDLE after the interrupt (pause_req source) is taken care of
            end
            else begin
              step_nxt = step + 1'b1;
              loop_nxt = 0;  // Resetting the loop to remove the "fake" loop flag (see loop_nxt description above), the real one will still be asserted again later
            end
          end
          2 : begin  // Finally issuing AiM Engine requests
            if (aime_pkt.req_type == DO_MACSB && !cfr_mode.BK_BCAST) begin
              aime_pkt_nxt.bk_addr = aime_pkt.bk_addr + 1'b1;  // If bank braodcast is OFF, first, activate vetor bank, then return to the weight bank address
              restore_bk_nxt = 1;                               // Indicator that we need to restore the original bank address (weight)
            end

            case (aime_pkt.req_type)
              WRITE_GB, WRITE_BIAS, READ_MAC, READ_AF : begin
                aime_state_nxt = AIME_NDM;
                step_nxt       = |bk_state ? 0 : 1;
                aime_cmd_nxt   = |bk_state ? PREAB : NDME;
              end
              DO_MACSB, DO_RDCP, DO_WRCP : begin
                aime_state_nxt   = AIME_SBK;
                step_nxt         = |bk_state ? 0 : cfr_mode.BK_BCAST;
                aime_cmd_nxt     = |bk_state ? PREAB : ACT;
                aime_pkt_req_nxt = aime_cmd_nxt == NOP1;
              end
              WRITE_ABK, DO_MACAB, DO_EWMUL : begin
                aime_state_nxt = AIME_ABK;
                step_nxt       = |bk_state ? 0 : 1;
                aime_cmd_nxt   = |bk_state ? PREAB : ACT16;
              end
              WRITE_AF, DO_AF : begin
                aime_state_nxt = AIME_AF;
                step_nxt       = |bk_state ? 0 : 1;
                aime_cmd_nxt   = |bk_state ? PREAB : ACTAF16;
              end
              DO_MRS : begin
                aime_state_nxt = |bk_state ? AIME_MRS : AIME_WAIT;
                aime_cmd_nxt   = |bk_state ? PREAB : MRS;
              end
            endcase
          end
        endcase
      end

      AIME_WAIT : begin  // State for waiting until the last AiM command is accepted by Bank Arbiter
        if (bkarb_pkt_ack) begin
          aime_cmd_nxt     = NOP1;
          aime_state_nxt   = AIME_IDLE;
          aime_is_idle_nxt = 1'b1;
        end
      end

      AIME_NDM : begin
        if (bkarb_pkt_ack) begin
          case (step)
            0 : begin
              aime_cmd_nxt = NDME;
              step_nxt = 1;
            end
            1 : begin
              case (aime_pkt.req_type)
                WRITE_GB   : begin
                  aime_cmd_nxt = WRGB;
                  step_nxt     = 2;     // "step=2" allows command sequences (WRGB, WRBIAS)
                end
                WRITE_BIAS : begin
                  aime_cmd_nxt = WRBIAS;
                  step_nxt     = 2;
                end
                READ_MAC   : begin
                  aime_cmd_nxt = RDMAC;
                  step_nxt     = 3;     // "step=3" goes straight to NDMX (no sequences of RDMAC or RDAF are allowed)
                end
                READ_AF    : begin
                  aime_cmd_nxt = RDAF;
                  step_nxt     = 3;
                end
              endcase
            end
            2 : begin
              if (rowarb_pkt_req && (rowarb_pkt.req_type == WRITE_GB || rowarb_pkt.req_type == WRITE_BIAS) && !pause_req) begin  // Multiple WRBG and WRBIAS commands and their mixing is allowed - accept the req without going back to IDLE
                aime_pkt_ack_nxt = 1'b1;
                aime_pkt_nxt     = rowarb_pkt;
                aime_cmd_nxt     = (aime_pkt_nxt.req_type == WRITE_GB) ? WRGB : WRBIAS;
                step_nxt         = 2;
              end
              else begin
                aime_cmd_nxt   = NDMX;
                aime_state_nxt = AIME_WAIT;
              end
            end
            3 : begin
              aime_cmd_nxt   = NDMX;
              aime_state_nxt = AIME_WAIT;
            end
          endcase
        end
      end

      AIME_SBK : begin
        if (bkarb_pkt_ack) begin
          case (step)
            0 : begin
              aime_cmd_nxt = ACT;
              if (restore_bk) begin
                aime_pkt_nxt.bk_addr = aime_pkt.bk_addr - 1'b1;                // Restore bank address and issue one more ACT
                restore_bk_nxt = 0;
              end
              else begin
                step_nxt = 1;
              end
            end
            1 : begin
                case (aime_pkt.req_type)
                  DO_MACSB : aime_cmd_nxt = MACSB;
                  DO_RDCP  : aime_cmd_nxt = RDCP;
                  DO_WRCP  : aime_cmd_nxt = WRCP;
                endcase
                step_nxt = 2;
                loop_nxt = cfr_schd.LOOP_EN && aime_pkt.col_addr != 0;          // If looping is on, only exit the looping state when the request for COL=0 is issued
            end
            2 : begin
              if (cfr_schd.LOOP_EN && aime_pkt.col_addr != 0) aime_pkt_nxt.col_addr = aime_pkt.col_addr - 1'b1;  // Keep decrementing column addresses when in a loop

              if (pause_req) begin                                            // Upon pause request, go back to IDLE
                aime_cmd_nxt   = PREAB;
                aime_state_nxt = AIME_WAIT;
                loop_nxt       = cfr_schd.LOOP_EN && aime_pkt.col_addr != 0;  // If pause_req happens at the end of the loop, exit it at the same time
              end
              else if (cfr_schd.LOOP_EN && aime_pkt.col_addr != 0) begin      // Loop with the same command if enabled and COL>0
                /*DO NOTHING*/
              end
              else if (rowarb_pkt_req && rowarb_pkt.req_type == aime_pkt.req_type && rowarb_pkt.row_addr == aime_pkt.row_addr && rowarb_pkt.bk_addr == aime_pkt.bk_addr) begin  // Sequences of packets of the same type are allowed - accept without going to IDLE
                aime_pkt_ack_nxt = 1'b1;
                aime_pkt_nxt     = rowarb_pkt;
                loop_nxt         = cfr_schd.LOOP_EN && rowarb_pkt.col_addr != 0;
              end
              else begin
                aime_cmd_nxt = PREAB;
                aime_state_nxt = AIME_WAIT;
                loop_nxt       = 0;
              end
            end
          endcase
        end
      end

      AIME_ABK : begin
        if (bkarb_pkt_ack) begin
          case (step)
            0 : begin
              aime_cmd_nxt = ACT16;
              step_nxt = 1;
            end
            1 : begin
              case (aime_pkt.req_type)
                DO_MACAB  : begin
                  aime_cmd_nxt = MACAB;
                  loop_nxt     = cfr_schd.LOOP_EN && aime_pkt.col_addr != 0;  // If looping is on, only exit the looping state when the request for COL=0 is issued
                end
                WRITE_ABK : begin
                  aime_cmd_nxt = WRBK;
                end
                DO_EWMUL  : begin
                  aime_cmd_nxt = EWMUL;
                  loop_nxt     = cfr_schd.LOOP_EN && aime_pkt.col_addr != 0;  // If looping is on, only exit the looping state when the request for COL=0 is issued
                end
              endcase
              step_nxt = 2;
            end
            2 : begin
              if (cfr_schd.LOOP_EN && aime_pkt.col_addr != 0) aime_pkt_nxt.col_addr = aime_pkt.col_addr - 1'b1;  // Keep decrementing column addresses when in a loop

              if (pause_req) begin                                            // Upon pause request, go back to IDLE
                aime_cmd_nxt   = PREAB;
                aime_state_nxt = AIME_WAIT;
                loop_nxt       = cfr_schd.LOOP_EN && aime_pkt.col_addr != 0;  // If pause_req happens at the end of the loop, exit it at the same time
              end
              else if (cfr_schd.LOOP_EN && aime_pkt.col_addr != 0) begin      // Loop with the same command if enabled and COL>0
                /*DO NOTHING*/
              end
              else if (rowarb_pkt_req && rowarb_pkt.req_type == aime_pkt.req_type && rowarb_pkt.row_addr == aime_pkt.row_addr) begin  // Sequences of packets of the same type are allowed - accept without going to IDLE
                aime_pkt_ack_nxt = 1'b1;
                aime_pkt_nxt     = rowarb_pkt;
                loop_nxt         = cfr_schd.LOOP_EN && rowarb_pkt.col_addr != 0;
              end
              else begin
                aime_cmd_nxt   = PREAB;
                aime_state_nxt = AIME_WAIT;
                loop_nxt       = 0;
                loop_nxt       = 0;
              end
            end
          endcase
        end
      end

      AIME_AF : begin
        if (bkarb_pkt_ack) begin
          case (step)
            0 : begin
              aime_cmd_nxt = ACTAF16;
              step_nxt = 1;
            end
            1 : begin
              case (aime_pkt.req_type)
                WRITE_AF : begin
                  aime_cmd_nxt = WRBK;
                  step_nxt     = 2;     // "step=2" allows WRBK command sequences
                end
                DO_AF     : begin
                  aime_cmd_nxt = AF;
                  step_nxt     = 3;     // "step=3" goes straight to PREAB (AF command sequences are not allowed)
                end
              endcase
            end
            2 : begin
              if (rowarb_pkt_req && rowarb_pkt.req_type == WRITE_AF && !pause_req) begin  // WRBK packet sequences are allowed - accept without going to IDLE
                aime_pkt_ack_nxt = 1'b1;
                aime_pkt_nxt     = rowarb_pkt;
              end
              else begin
                aime_cmd_nxt   = PREAB;
                aime_state_nxt = AIME_WAIT;
              end
            end
            3 : begin
              aime_cmd_nxt   = PREAB;
              aime_state_nxt = AIME_WAIT;
            end
          endcase
        end
      end

      AIME_MRS : begin
        if (bkarb_pkt_ack) begin
          aime_cmd_nxt   = MRS;
          aime_state_nxt = AIME_WAIT;
        end
      end
    endcase
  end

  // ================================= Initialization ================================
  initial begin
    // State Variables
    aime_state   = AIME_IDLE;
    aime_is_idle = 1'b1;
    step         = 0;
    bk_state     = 0;
    loop         = 0;
    restore_bk   = 0;
    // Request Packet Signals
    aime_pkt_req = 0;
    aime_pkt     = 0;
    aime_cmd     = NOP1;
  end

endmodule
