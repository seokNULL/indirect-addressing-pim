`timescale 1ps / 1ps
// WARNING : This module is NOT PARAMETRIZED. It is hand-crafted for one unified Bank Engine, one AiM Engine, and one Refresh Handler.

module bank_arbiter_fifo (
  input  logic clk,
  input  logic rst,
  // Configuration Register
  input  logic [$bits(cfr_schd_t)-1:0] cfr_schd_p,
  // Bank Engine Interface
  input  pkt_meta_t [2:0] bke_pkt,
  input  cmd_t      [2:0] bke_cmd,
  input  logic      [2:0] bke_pkt_req,
  output logic      [2:0] bkarb_pkt_ack,
  // Command/Data Handler Interface
  input  logic      bkarb_en,
  output pkt_meta_t bkarb_pkt,
  output cmd_t      bkarb_cmd,
  output logic      bkarb_pkt_valid,
  output logic      bkarb_pkt_ignore);

  // ============================== Signal Declarations ================================
  cfr_schd_t  cfr_schd;                 // Scheduler parameter array
  logic [2:0] bke_idx, bke_idx_nxt;     // Index of the selected engine
  logic       bke_sw_pause;             // Pause signal for disable engine switching

  // ============================== Configuration Register ==============================
  assign cfr_schd = cfr_schd_t'(cfr_schd_p);

  // =============================== Priority Arbitration ===============================
  // Picking the highest priority packet among the active request packets
  always_comb begin
    bke_idx_nxt  = bke_idx;
    for (int idx=2; idx>=0; idx--) begin
      if ((bke_pkt[idx].prio > bke_pkt[bke_idx_nxt].prio || !bke_pkt_req[bke_idx_nxt]) && bke_pkt_req[idx]) begin  // If current priority has no active packets, switch to any active packet
        bke_idx_nxt = idx;
      end
    end
  end

  // Waiting for at least one packet from the new selected engine to be acknowledged before switching engines again
  always @(posedge clk, posedge rst)
    if (rst) bke_sw_pause <= 0;
    else     bke_sw_pause <= bke_sw_pause ? !bkarb_pkt_valid : (bke_idx != bke_idx_nxt);

  // Updating the selected engine index, if allowed by "bke_sw_pause"
  always @(posedge clk, posedge rst)
    if      (rst)           bke_idx <= 0;
    else if (!bke_sw_pause) bke_idx <= bke_idx_nxt;

  // ================================ Response Generation ===============================
  // Immediately responding to requests from the selected engine
  always_comb begin
    bkarb_pkt_ack = 0;
    bkarb_pkt_ack[bke_idx] = bke_pkt_req[bke_idx] && bkarb_en;
  end

  assign bkarb_pkt_valid  = |bkarb_pkt_ack;
  assign bkarb_pkt        = bke_pkt[bke_idx];
  assign bkarb_cmd        = bke_cmd[bke_idx];

  assign bkarb_pkt_ignore = cfr_schd.LOOP_EN && bke_pkt[bke_idx].req_type >= DO_MACSB && bke_pkt[bke_idx].col_addr != 0;

  // ================================== Initialization =================================
  initial begin
    bke_idx = 0;
    bke_sw_pause = 0;
  end

endmodule
