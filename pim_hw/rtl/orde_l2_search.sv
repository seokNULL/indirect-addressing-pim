
import aimc_lib::*;

module orde_l2_search #(
    parameter integer NUM_PER_BLOCK = 32,
    parameter integer NUM_MAX_RD    = 512,    
    parameter integer NUM_BLOCK     = 16
)
(
  input  logic                                clk,
  input  logic                                rst,

  input logic [$clog2(NUM_MAX_RD)-1:0]        oldest_idx,
  input logic [$clog2(NUM_MAX_RD)-1:0]        per_match_idx [NUM_BLOCK-1:0],
  input logic [NUM_BLOCK-1:0]                 per_match_idx_valid,
  input logic                                 per_match_idx_is_young,

  output logic [$clog2(NUM_MAX_RD)-1:0]       matched_idx,
  output logic                                matched_idx_valid
);

  localparam NUM_DIV = 4;


  logic [$clog2(NUM_MAX_RD)-1:0]        oldest_idx_p [1:0];
  logic [NUM_BLOCK-1:0]                 shifted_per_match_idx_valid ;
  logic [$clog2(NUM_BLOCK)-1:0]         rr_ptr [NUM_BLOCK-1:0]; 

  logic [$clog2(NUM_BLOCK)-1:0]         per_block_match_idx [NUM_DIV-1:0];
  logic                                 per_block_match_idx_valid [NUM_DIV-1:0];

  logic [$clog2(NUM_BLOCK)-1:0]         matched_block_idx;                       // index of matched entry with address of icnt_pkt
  logic [$clog2(NUM_BLOCK)-1:0]         matched_block_idx2;                      // index of matched entry with address of icnt_pkt
  logic                                 matched_block_idx_valid;                 // index valid of matched entry with address of icnt_pkt

  logic                                 rr_shift;

  always @(posedge clk) begin
    oldest_idx_p   <= {oldest_idx_p[0],oldest_idx};
  end    

  assign shifted_per_match_idx_valid = per_match_idx_valid >> (oldest_idx_p[1][$clog2(NUM_MAX_RD)-1:$clog2(NUM_PER_BLOCK)]+per_match_idx_is_young) | 
                                       per_match_idx_valid << (NUM_BLOCK-oldest_idx_p[1][$clog2(NUM_MAX_RD)-1:$clog2(NUM_PER_BLOCK)]-per_match_idx_is_young);


  genvar k;
  
  generate
  for(k=0; k<NUM_BLOCK; k++) begin
    always @(posedge clk) begin
      rr_ptr[k] <= k + oldest_idx_p[0][$clog2(NUM_MAX_RD)-1:$clog2(NUM_PER_BLOCK)];
    end      
  end
  endgenerate
  
  generate
  for(k=0; k<NUM_DIV; k++) begin
    always_comb begin 
    per_block_match_idx[k] = 0;  
    per_block_match_idx_valid[k] = 0;
      for(int i=(k+1)*NUM_BLOCK/NUM_DIV-1; i>=k*NUM_BLOCK/NUM_DIV; i--) begin
        if(shifted_per_match_idx_valid[i]) begin 
          per_block_match_idx[k]       = rr_ptr[i];
          per_block_match_idx_valid[k] = 1;
        end
      end
  end 
  end
  endgenerate  

  always_comb begin 
  matched_block_idx = 0;  
  matched_block_idx_valid = 0;
    for(int i=NUM_DIV-1; i>=0; i--) begin
      if(per_block_match_idx_valid[i]) begin 
        matched_block_idx       = per_block_match_idx[i];
        matched_block_idx_valid = 1;
      end
    end
  end

  assign matched_block_idx2 = matched_block_idx + per_match_idx_is_young;
  always @(posedge clk) begin 
     matched_idx        <= per_match_idx[matched_block_idx2];
     matched_idx_valid  <= matched_block_idx_valid;
  end  
  initial begin
    oldest_idx_p             = {0,0};
    matched_idx       = 0;
    matched_idx_valid = 0;
  end

endmodule