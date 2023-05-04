import aimc_lib::*;

module orde_l1_search #(
    parameter integer NUM_PER_BLOCK = 32,
    parameter integer NUM_MAX_RD    = 512,
    parameter integer BLOCK_IDX     = 1
)
(
  input  logic                                clk,
  input  logic                                rst,
  // axbr interface
  input  orde_pkt_t                           dma_pkt,
  input  logic                                dma_pkt_valid,
  // icnt_orde_pkt interface
  input  orde_pkt_t                           icnt_orde_pkt,
  input  logic                                icnt_orde_pkt_valid,  

  input  logic                                oldest_idx_valid,
  input  logic [$clog2(NUM_PER_BLOCK)-1:0]    oldest_idx,
  input  logic                                empty_idx_valid,
  input  logic [$clog2(NUM_PER_BLOCK)-1:0]    empty_idx,  
  input  logic                                matched_idx_valid,
  input  logic [$clog2(NUM_PER_BLOCK)-1:0]    matched_idx,    
  output logic [$clog2(NUM_MAX_RD)-1:0]       match_idx,
  output logic                                match_idx_valid,
  output logic                                match_idx_is_young,
  
  input  logic                                oldest_idx_next_valid,
  input  logic [$clog2(NUM_PER_BLOCK)-1:0]    oldest_idx_next,
  output logic                                oldest_pkt_valid,
  input  logic                                pop_idx_valid,
  input  logic [$clog2(NUM_PER_BLOCK)-1:0]    pop_idx
  );

  logic [NUM_PER_BLOCK-1:0]         match_array;
  logic [NUM_PER_BLOCK-1:0]         shifted_match_entry_array;
  logic [$clog2(NUM_PER_BLOCK)-1:0] match_idx_next;
  logic [$clog2(NUM_PER_BLOCK)-1:0] match_idx_next_s1;
  logic [$clog2(NUM_MAX_RD)-1:0]    match_idx_next_s2;
  logic                             match_idx_valid_next;

  logic                             oldest_idx_valid_p [1:0];
  logic [$clog2(NUM_PER_BLOCK)-1:0] oldest_idx_p [1:0];

  logic                             match_idx_is_young_next;

 // ================================= Address CAM =====================================

 orde_cam #(.CAM_DEPTH(NUM_PER_BLOCK),.CAM_WIDTH($bits(orde_pkt_t))) address_cam (
  .clk,.rst,
  .cam_in(dma_pkt),                                             // address of axbr_pkt
  .cam_in_valid(dma_pkt_valid && empty_idx_valid),              // orde insert when axbr_pkt is valid
  .cam_in_idx(empty_idx),                                       // index to insert entry into orde_CAM
  .cam_key_valid(icnt_orde_pkt_valid),                           // icnt_orde_pkt valid
  .cam_key(icnt_orde_pkt),                                       // address of icnt_orde_pkt to search the match idx in orde_CAM
  .match_idx(matched_idx),                                      // the oldest match idx which is found through l1_search, l2_search                    
  .match_idx_valid(matched_idx_valid),                          // the oldest match idx valid
  .match_entry_array(match_array),                              // array of match idx with icnt_orde_pkt (it can have one one bits)
  .status_mem_idx_valid(oldest_idx_next_valid),                 // oldest_idx valid signal
  .status_mem_idx(oldest_idx_next),                             // oldest_idx_next (it is different with oldest_idx)
  .status(oldest_pkt_valid),                                    // oldest RD Response status (if it is "1", means that orde get the oldest RD response)
  .pop_idx(pop_idx),                                            // popped entry index (returned RD Response pkt idx) to reset the entry of state memroy 
  .pop_idx_valid(pop_idx_valid)                                 // popped entry index valid signal
  );
  
// ================================= Find Oldest RD PKT =====================================  
  
  always @(posedge clk) begin 
    // shift match_array
    if(oldest_idx_valid_p[0])   shifted_match_entry_array  <=  match_array >> oldest_idx_p[0] | match_array << (NUM_PER_BLOCK - oldest_idx_p[0]);
    else                        shifted_match_entry_array  <=  match_array;
    oldest_idx_p        <= {oldest_idx_p[0],oldest_idx};
    oldest_idx_valid_p  <= {oldest_idx_valid_p[0],oldest_idx_valid};
  end

  always_comb begin
    match_idx_next       = 0;
    match_idx_valid_next = 0;
    for (int i=NUM_PER_BLOCK-1; i>=0; i--) begin  
      if (shifted_match_entry_array[i]) begin 
        match_idx_next  = i;
        match_idx_valid_next = 1;
      end
    end
  end

  always_comb begin
    if(oldest_idx_valid_p[1]) match_idx_next_s1  = match_idx_next + oldest_idx_p[1];
    else                      match_idx_next_s1  = match_idx_next;
                              match_idx_next_s2  = match_idx_next_s1 + NUM_PER_BLOCK * BLOCK_IDX;
    if(oldest_idx_valid_p[1] && match_idx_valid_next) match_idx_is_young_next = (oldest_idx_p[1] + NUM_PER_BLOCK * BLOCK_IDX) > match_idx_next_s2;
    else                                              match_idx_is_young_next = 0;
  end

  always @(posedge clk) begin 
    match_idx          <= match_idx_next_s2;
    match_idx_valid    <= match_idx_valid_next;
    match_idx_is_young <= match_idx_is_young_next;
  end  
// ================================== Initialization =================================  
  initial begin
    oldest_idx_p             = {0,0};
    oldest_idx_valid_p       = {0,0};
  end
  endmodule 