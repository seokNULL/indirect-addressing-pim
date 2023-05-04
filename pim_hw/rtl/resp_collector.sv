`timescale 1ps / 1ps

import aimc_lib::*;

module resp_collector (
  input  logic clk,
  input  logic rst,
  input  logic bcast_add,                                                            // Adds broadcast request (used for counting in-flight packets)
  input  logic [CH_NUM-1:0] bcast_mask,
  input  logic bcast_pull,
  output logic bcast_pipe_full,
  input  logic [CH_NUM-1:0] aimc_bcast_resp,
  output logic bcast_resp);

  // ============================= Signal Declarations =============================
  // Response Array
  logic [BCAST_PIPE_LENGTH-1:0]                       resp_array      [CH_NUM-1:0];  // Broadcast response array (queues for each channel)
  logic [RP_SHIFT_NUM-1:0][RP_SHIFT_SIZE-1:0]         resp_array_0    [CH_NUM-1:0];
  logic [$clog2(BCAST_PIPE_LENGTH)-1:0]               resp_push_ptr   [CH_NUM-1:0];  // Broadcast response push pointer for each channel (derived from resp_push_cnt)
  logic [RP_SHIFT_NUM-1:0][$clog2(RP_SHIFT_SIZE)-1:0] resp_push_ptr_0 [CH_NUM-1:0];
  logic [$clog2(BCAST_PIPE_LENGTH)-1:0]               resp_push_cnt   [CH_NUM-1:0];  // Broadcast response push counter for each channel
  logic [RP_SHIFT_NUM-1:0][$clog2(RP_SHIFT_SIZE)-1:0] resp_push_cnt_0 [CH_NUM-1:0];
  logic [RP_SHIFT_NUM-1:0]                            carry_out       [CH_NUM-1:0];  // Carry-out indicator for shifters
  logic [$clog2(RP_SHIFT_NUM)-1:0]                    rptr_shift8_sel [CH_NUM-1:0];  // Response pointer shifter selector
  logic [BCAST_PIPE_LENGTH-1:0]                       resp_array_push [CH_NUM-1:0];  // Write enable signals for resp_array used for pushing responses
  logic [BCAST_PIPE_LENGTH-1:0]                       resp_array_pull [CH_NUM-1:0];  // Write enable signals for resp_array used for pulling responses
  logic [BCAST_PIPE_LENGTH-1:0]                       resp_array_mset [CH_NUM-1:0];  // Write enable signals for resp_array used for setting the mask
  logic [BCAST_PIPE_LENGTH-1:0]                       resp_done;                     // Indicator that all broadcast responses for a particular column have been collected
  logic [$clog2(BCAST_PIPE_LENGTH)-1:0]               next_mask_ptr;                 // Pipeline index corresponding to the first empty response slot (required for filling columns with mask data) 
  // Collector Status
  logic [$clog2(BCAST_PIPE_LENGTH):0]                 bcast_cnt;
  logic [$clog2(BCAST_PIPE_LENGTH)-1:0]               resp_pull_ptr;                 // Counter pointing at the next response to pull

  genvar i, ii;
  // ========================== Broadcast Response Array ===========================
  generate
    for (i=0; i<CH_NUM; i++) begin : respArray
      // "Write enable" for collecting responses
      always_comb begin
        resp_array_push[i] = 0;
        resp_array_push[i][resp_push_ptr[i]] = aimc_bcast_resp[i];
      end
      // "Write enable" for setting the broadcast mask
      always_comb begin
        resp_array_mset[i] = 0;
        resp_array_mset[i][next_mask_ptr] = ~bcast_mask[i] && bcast_add;  // Presetting unused bits to "1", which corresponds to gathering fake responses from channels not participating in the current bcast
      end
      // "Write enable" for pulling requests from the pipe
      always_comb begin
        resp_array_pull[i] = 0;
        resp_array_pull[i][resp_pull_ptr] = resp_done[resp_pull_ptr] && bcast_pull;
      end

      for (ii=0; ii<BCAST_PIPE_LENGTH; ii++) begin : respQue
        always @(posedge clk, posedge rst)
          if      (rst)                                                                        resp_array[i][ii] <= 0;
          else if (resp_array_pull[i][ii] || resp_array_push[i][ii] || resp_array_mset[i][ii]) resp_array[i][ii] <= !resp_array_pull[i][ii];
      end 

      always @(posedge clk, posedge rst)
        if (rst) resp_push_cnt[i] <= 0;
        else     resp_push_cnt[i] <= aimc_bcast_resp[i] ? (resp_push_ptr[i] + 1'b1) : resp_push_ptr[i];

      // -------------------------------------------------------------------------
      // // Response pointer shifter (single module)
      // rptr_shift8 rptr_shift8 (
      //   .resp_array    (resp_array[i]),
      //   .resp_push_cnt (resp_push_cnt[i]),
      //   .resp_push_ptr (resp_push_ptr[i]),
      //   .carry_out   ());

      // -------------------------------------------------------------------------
      // Response pointer shifters (to account for "preset" multicast bits)
      for (ii=0; ii<RP_SHIFT_NUM; ii++) begin : rptrShift
        rptr_shift8 rptr_shift8 (
          .resp_array    (resp_array_0    [i][ii]),
          .resp_push_cnt (resp_push_cnt_0 [i][ii]),
          .resp_push_ptr (resp_push_ptr_0 [i][ii]),
          .carry_out     (carry_out       [i][ii]));

        assign resp_array_0    [i][ii] = resp_array[i][ii*RP_SHIFT_SIZE+:RP_SHIFT_SIZE];
        assign rptr_shift8_sel [i]     = resp_push_cnt[i][$clog2(RP_SHIFT_SIZE)+:$clog2(RP_SHIFT_NUM)];
        assign resp_push_cnt_0 [i][ii] = (rptr_shift8_sel[i] == ii) ? resp_push_cnt[i][$clog2(RP_SHIFT_SIZE)-1:0] : 0;
      end

      // Response pointer multiplexer (from multiple shifters)
      always_comb begin
        resp_push_ptr[i] = 0;
        resp_push_ptr[i][$clog2(RP_SHIFT_SIZE)-1:0] = resp_push_ptr_0[i][0];  // In case of all carry_out signals asserted, wrap around to the first array

        for (int idx=RP_SHIFT_NUM-1; idx>=0; idx--) begin
          if (idx>=rptr_shift8_sel[i] && !carry_out[i][idx]) resp_push_ptr[i] = {idx[$clog2(RP_SHIFT_NUM)-1:0], resp_push_ptr_0[i][idx]};
        end
      end
    end
    // ---------------------------------------------------------------------------

    // Combined Response Constructor
    for (ii=0; ii<BCAST_PIPE_LENGTH; ii++) begin : respCollect
      always_comb begin
        resp_done[ii] = resp_array[0][ii];
        for (int idx=1; idx<CH_NUM; idx++) begin
          resp_done[ii] = resp_done[ii] && resp_array[idx][ii];
        end
      end
    end
  endgenerate

  // Next response pointer (simply rotating around the pipe with each added packet)
  always @(posedge clk, posedge rst)
    if      (rst)       next_mask_ptr <= 0;
    else if (bcast_add) next_mask_ptr <= next_mask_ptr + 1'b1;

  // ============================== Collector Status ===============================
  always @(posedge clk, posedge rst)
    if      (rst)                    bcast_cnt <= 0;
    else if (bcast_add ^ bcast_pull) bcast_cnt <= bcast_cnt + bcast_add - bcast_pull;

  always @(posedge clk, posedge rst)
    if      (rst)        resp_pull_ptr <= 0;
    else if (bcast_pull) resp_pull_ptr <= resp_pull_ptr + 1'b1;

  assign bcast_pipe_full = bcast_cnt == BCAST_PIPE_LENGTH;
  assign bcast_resp = |resp_done;

  // ================================ Initialization ===============================
  initial begin
    // Response Array
    resp_array    = '{CH_NUM{0}};
    resp_push_cnt = '{CH_NUM{0}};
    next_mask_ptr = 0;
    // Collector Status
    bcast_cnt     = 0;
    resp_pull_ptr = 0;
  end

endmodule
