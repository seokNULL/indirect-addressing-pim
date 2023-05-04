`timescale 1ps / 1ps

// WARNING : This module is NOT PARAMETRIZED. It is hand-crafted for 16 Bank Engines, one AiM Engine, and one Refresh Handler.
// Please keep this in mind when changing the BK_ADDR_WIDTH parameter in aimc_lib package.

module bank_arbiter (
  input  logic clk,
  input  logic rst,
  // Configuration Register
  input  logic [$bits(cfr_schd_t)-1:0] cfr_schd_p,
  // Bank Engine Interface
  input  pkt_meta_t [17:0] bke_pkt,
  input  cmd_t      [17:0] bke_cmd,
  input  logic      [17:0] bke_pkt_req,
  output logic      [17:0] bkarb_pkt_ack,
  // Command/Data Handler Interface
  input  logic      bkarb_en,
  output pkt_meta_t bkarb_pkt,
  output cmd_t      bkarb_cmd,
  output logic      bkarb_pkt_valid,
  output logic      bkarb_pkt_ignore);

  // ============================== Signal Declarations ================================
  cfr_schd_t   cfr_schd;                // Scheduler parameter array
  logic [17:0] req_list   [PRIO-1:0];   // List of requests for each priority
  logic [4:0]  req_idx    [PRIO-1:0];   // Index of the selected request in each priority
  logic [3:0]  req_idx_4b [PRIO-1:0];   // Index of the selected request in each priority (4-bit version for rrarb_16 units)
  logic [PRIO-1:0] req_prsnt;           // Flag indicating that at least one request is present in the priority rotation
  logic [$clog2(PRIO)-1:0] prio_idx;    // Index of the highest active priority
  logic [17:0] local_ack;               // Unbuffered acknowledgement signals
  logic [3:0] rr_cnt;                   // Round-robin counter for normal requests (non-aim and non-refresh)
  logic [4:0] prio_req_idx;             // Final selected request index
  logic [3:0] prio_req_idx_d;           // Buffered and cropped selected request index

  // ============================== Configuration Register ==============================
  assign cfr_schd = cfr_schd_t'(cfr_schd_p);

  // ============================== Round-Robin Arbitraters =============================
  genvar i;
  generate
    for (i=0; i<PRIO; i++) begin : prioLvl
      // PRIO=1 : AiM Packets
      if (i==1) begin
        assign req_list  [i] = 0;
        assign req_idx   [i] = 5'd16;
        assign req_idx_4b[i] = 0;
        assign req_prsnt [i] = bke_pkt_req[16];
      end
      // PRIO=PRIO-1 : Refresh Packets
      else if (i==PRIO-1) begin
        assign req_list  [i] = 0;
        assign req_idx   [i] = 5'd17;
        assign req_idx_4b[i] = 0;
        assign req_prsnt [i] = bke_pkt_req[17];
      end
      // PRIO=0,2.. : Normal Packets
      else begin
        rrarb_16 rrarb_16 (
          .req_list  (req_list[i][15:0]),
          .rr_cnt    (rr_cnt),
          .req_prsnt (req_prsnt [i]),
          .req_idx   (req_idx_4b[i]));

        assign req_idx[i] = {1'b0, req_idx_4b[i]};

        always_comb begin
          req_list[i] = 0;
          for (int idx=0; idx<16; idx++) req_list[i][idx] = bke_pkt_req[idx] && (bke_pkt[idx].prio == i);
        end
      end
    end
  endgenerate

  always @(posedge clk, posedge rst)
    if      (rst)                  rr_cnt <= 0;
    else if (|bkarb_pkt_ack[15:0]) rr_cnt <= prio_req_idx_d + 1'b1;  // Only rotating when a signal from a regular Bank Engine (not AiM or Refresh) is acknowledged
    // else if (|bkarb_pkt_ack[15:0]) rr_cnt <= rr_cnt + 1'b1;

  // Priority Encoder for choosing the highest priority with an active request
  always_comb begin
    prio_idx = 0;
    for (int idx=1; idx<PRIO; idx++) begin
      if (req_prsnt[idx]) prio_idx = idx;
    end
  end

  assign prio_req_idx = req_idx[prio_idx];  // Selected request index from the highest active priority

  always @(posedge clk, posedge rst)
    if (rst) prio_req_idx_d <= 0;
    else     prio_req_idx_d <= prio_req_idx[3:0];

  always_comb begin
    local_ack = 0;
    local_ack[prio_req_idx] = bke_pkt_req[prio_req_idx] && bkarb_en && !(|bkarb_pkt_ack);  // Skipping every second clock cycle with !(|bkarb_pkt_ack)
  end

  // ================================= Output Registers ================================
  always @(posedge clk, posedge rst)
    if (rst) bkarb_pkt_ack <= 0;
    else     bkarb_pkt_ack <= local_ack;

  always @(posedge clk, posedge rst)
    if (rst) bkarb_pkt_valid <= 0;
    else     bkarb_pkt_valid <= |local_ack;

    always @(posedge clk, posedge rst)
      if (rst) bkarb_pkt_ignore <= 0;
      else     bkarb_pkt_ignore <= cfr_schd.LOOP_EN && bke_pkt[prio_req_idx].req_type >= DO_MACSB && bke_pkt[prio_req_idx].col_addr != 0;

  always @(posedge clk)
    if (|local_ack) begin
      bkarb_pkt <= bke_pkt[prio_req_idx];
      bkarb_cmd <= bke_cmd[prio_req_idx];
    end

  // ================================== Initialization =================================
  initial begin
    rr_cnt = 0;
    prio_req_idx_d = 0;
    bkarb_pkt_ack = 0;
    bkarb_pkt_valid = 0;
    bkarb_pkt_ignore = 0;
    bkarb_pkt = 0;
    bkarb_cmd = NOP1;
  end

endmodule
