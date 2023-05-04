`timescale 1ns / 1ps

import aimc_lib::*;

module latency_mon (
  input  logic clk,
  input  logic rst,
  output logic pkt_marker,               // Packet marker used for flagging packets participating in latency counting
  input  logic req_pkt_valid,            // Request packet validity signal
  input  logic req_sink_rdy,             // Readiness signal from the block accepting request packets
  input  logic resp_pkt_valid,           // Response packet validity signal
  input  logic resp_sink_rdy,            // Readiness signal from the block accepting response packets
  input  logic resp_pkt_marker,          // Response packet marker
  input  logic mon_upd,
  output logic [7:0]  latency_min,
  output logic [7:0]  latency_max,
  output logic [15:0] latency_pkt_cnt);  // Number of packets used for evaluating latency values

  // =========================== Signal Declarations ===========================
  logic pkt_marker_nxt;
  enum logic {LATMON_IDLE=0, LATMON_WAIT} latmon_state, latmon_state_nxt;
  logic [7:0]  latency_cnt, latency_cnt_nxt;
  logic [7:0]  latency_min_nxt;
  logic [7:0]  latency_max_nxt;
  logic [15:0] latency_pkt_cnt_nxt;

  // ============================ Latency Counters =============================
  always @(posedge clk, posedge rst)
    if (rst) begin
      latmon_state    <= LATMON_IDLE;
      pkt_marker      <= 1;
      latency_cnt     <= 0;
      latency_min     <= 8'd255;
      latency_max     <= 0;
      latency_pkt_cnt <= 0;
    end
    else begin
      latmon_state    <= latmon_state_nxt;
      pkt_marker      <= pkt_marker_nxt;
      latency_cnt     <= latency_cnt_nxt;
      latency_min     <= mon_upd ? 8'd255      : latency_min_nxt;
      latency_max     <= mon_upd ? 0           : latency_max_nxt;
      latency_pkt_cnt <= mon_upd ? 0           : latency_pkt_cnt_nxt;
    end

  always_comb begin
    latmon_state_nxt    = latmon_state;
    pkt_marker_nxt      = pkt_marker;
    latency_cnt_nxt     = latency_cnt;
    latency_min_nxt     = latency_min;
    latency_max_nxt     = latency_max;
    latency_pkt_cnt_nxt = latency_pkt_cnt;

    case (latmon_state)
      LATMON_IDLE : begin
        if (req_pkt_valid && req_sink_rdy && latency_pkt_cnt < {16{1'b1}}) begin
          pkt_marker_nxt   = 0;
          latmon_state_nxt = LATMON_WAIT;
          latency_cnt_nxt  = 1;            // Including one cycle it takes to switch to the next state
        end
      end

      LATMON_WAIT : begin
        latency_cnt_nxt = latency_cnt == 8'd255 ? 8'd255 : latency_cnt + 1'b1;  // Not registering latencies above 255 clock cycles

        if (resp_pkt_valid && resp_sink_rdy && resp_pkt_marker) begin
          pkt_marker_nxt      = 1;
          latmon_state_nxt    = LATMON_IDLE;
          latency_min_nxt     = latency_cnt < latency_min ? latency_cnt : latency_min;
          latency_max_nxt     = latency_cnt > latency_max ? latency_cnt : latency_max;
          latency_pkt_cnt_nxt = latency_pkt_cnt + 1'b1;
        end
      end
    endcase
  end

  // ============================= Initialization ==============================
  initial begin
    latmon_state    = LATMON_IDLE;
    pkt_marker      = 1;
    latency_cnt     = 0;
    latency_min     = 8'd255;
    latency_max     = 0;
    latency_pkt_cnt = 0;
  end

endmodule
