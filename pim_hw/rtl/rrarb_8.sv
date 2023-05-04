`timescale 1ps / 1ps

// This is hard-coded round-robin arbiter that is used to choose a single request from rr_req_list.
// The selection process starts from the rr_base_idx index and goes UP until an active request is encountered.

module rrarb_8 (
  input  logic [7:0] rr_req_list,
  input  logic [2:0] rr_base_idx,
  output logic [2:0] rr_sel_idx);
  
  logic [1:0] rr_sel_idx_low [3:0];
  logic [1:0] rr_sel_idx_high;
  logic [3:0] req_prsnt_low;

  generate
    for (genvar i=0; i<4; i++) begin
      always_comb begin
        casex ({rr_base_idx[0], rr_req_list[2*i+:2]})
          3'b0_?1 : rr_sel_idx_low [i] = 1'd0;
          3'b0_10 : rr_sel_idx_low [i] = 1'd1;

          3'b1_01 : rr_sel_idx_low [i] = 1'd0;
          3'b1_1? : rr_sel_idx_low [i] = 1'd1;

          default : rr_sel_idx_low [i] = 1'd0;
        endcase
      end
      assign req_prsnt_low[i] = |rr_req_list[2*i+:2];
    end
  endgenerate

  always_comb begin
    casex ({rr_base_idx[2:1], req_prsnt_low})
      6'b00_???1 : rr_sel_idx_high = 2'd0;
      6'b00_??10 : rr_sel_idx_high = 2'd1;
      6'b00_?100 : rr_sel_idx_high = 2'd2;
      6'b00_1000 : rr_sel_idx_high = 2'd3;

      6'b01_0001 : rr_sel_idx_high = 2'd0;
      6'b01_??1? : rr_sel_idx_high = 2'd1;
      6'b01_?10? : rr_sel_idx_high = 2'd2;
      6'b01_100? : rr_sel_idx_high = 2'd3;

      6'b10_00?1 : rr_sel_idx_high = 2'd0;
      6'b10_0010 : rr_sel_idx_high = 2'd1; 
      6'b10_?1?? : rr_sel_idx_high = 2'd2;
      6'b10_10?? : rr_sel_idx_high = 2'd3;

      6'b11_0??1 : rr_sel_idx_high = 2'd0;
      6'b11_0?10 : rr_sel_idx_high = 2'd1;
      6'b11_0100 : rr_sel_idx_high = 2'd2;
      6'b11_1??? : rr_sel_idx_high = 2'd3;

      default    : rr_sel_idx_high = 2'd0;
    endcase
  end

  assign rr_sel_idx[2:1] = rr_sel_idx_high;
  assign rr_sel_idx[0]   = rr_sel_idx_low[rr_sel_idx_high];

endmodule
