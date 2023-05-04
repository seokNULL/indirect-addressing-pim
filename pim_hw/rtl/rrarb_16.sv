`timescale 1ps / 1ps

// This is hard-coded round-robin arbiter that is used to choose a single request from req_list.
// The selection process starts from the rr_cnt index and goes UP until an active request is encountered.

module rrarb_16 (
  input  logic [15:0] req_list,
  input  logic [3:0]  rr_cnt,
  output logic        req_prsnt,
  output logic [3:0]  req_idx);
  
  logic [1:0] req_idx_low [3:0];
  logic [1:0] req_idx_high;
  logic [3:0] req_prsnt_low;

  generate
    for (genvar i=0; i<4; i++) begin
      always_comb begin
        casex ({rr_cnt[1:0], req_list[4*i+:4]})
          6'b00_???1 : req_idx_low [i] = 2'd0;
          6'b00_??10 : req_idx_low [i] = 2'd1;
          6'b00_?100 : req_idx_low [i] = 2'd2;
          6'b00_1000 : req_idx_low [i] = 2'd3;

          6'b01_0001 : req_idx_low [i] = 2'd0;
          6'b01_??1? : req_idx_low [i] = 2'd1;
          6'b01_?10? : req_idx_low [i] = 2'd2;
          6'b01_100? : req_idx_low [i] = 2'd3;

          6'b10_00?1 : req_idx_low [i] = 2'd0;
          6'b10_0010 : req_idx_low [i] = 2'd1; 
          6'b10_?1?? : req_idx_low [i] = 2'd2;
          6'b10_10?? : req_idx_low [i] = 2'd3;

          6'b11_0??1 : req_idx_low [i] = 2'd0;
          6'b11_0?10 : req_idx_low [i] = 2'd1;
          6'b11_0100 : req_idx_low [i] = 2'd2;
          6'b11_1??? : req_idx_low [i] = 2'd3;

          default    : req_idx_low [i] = 2'd0;
        endcase
      end
      assign req_prsnt_low[i] = |req_list[4*i+:4];
    end
  endgenerate

  always_comb begin
    casex ({rr_cnt[3:2], req_prsnt_low})
      6'b00_???1 : req_idx_high = 2'd0;
      6'b00_??10 : req_idx_high = 2'd1;
      6'b00_?100 : req_idx_high = 2'd2;
      6'b00_1000 : req_idx_high = 2'd3;

      6'b01_0001 : req_idx_high = 2'd0;
      6'b01_??1? : req_idx_high = 2'd1;
      6'b01_?10? : req_idx_high = 2'd2;
      6'b01_100? : req_idx_high = 2'd3;

      6'b10_00?1 : req_idx_high = 2'd0;
      6'b10_0010 : req_idx_high = 2'd1; 
      6'b10_?1?? : req_idx_high = 2'd2;
      6'b10_10?? : req_idx_high = 2'd3;

      6'b11_0??1 : req_idx_high = 2'd0;
      6'b11_0?10 : req_idx_high = 2'd1;
      6'b11_0100 : req_idx_high = 2'd2;
      6'b11_1??? : req_idx_high = 2'd3;

      default    : req_idx_high = 2'd0;
    endcase
  end

  assign req_idx[3:2] = req_idx_high;
  assign req_idx[1:0] = req_idx_low[req_idx_high];
  assign req_prsnt = |req_prsnt_low;

endmodule
