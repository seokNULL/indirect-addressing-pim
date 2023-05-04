import aimc_lib::*;

module orde_cam #(
    parameter integer CAM_DEPTH = 32,
    parameter integer CAM_WIDTH = 23
)
(
  input  logic                                clk,
  input  logic                                rst,
  // Insert READ Request 
  input  logic [CAM_WIDTH-1:0]                cam_in,
  input  logic                                cam_in_valid,
  input  logic [$clog2(CAM_DEPTH)-1:0]        cam_in_idx,
  
  // Search CAM_KEY
  input  logic                                cam_key_valid,
  input  logic [CAM_WIDTH-1:0]                cam_key, 

  // Final Match Key IDX 
  input  logic [$clog2(CAM_DEPTH)-1:0]        match_idx,  
  input  logic                                match_idx_valid,

  output logic [CAM_DEPTH-1:0]                match_entry_array,

  input  logic                                status_mem_idx_valid,
  input  logic [$clog2(CAM_DEPTH)-1:0]        status_mem_idx,
  input  logic                                pop_idx_valid,
  input  logic [$clog2(CAM_DEPTH)-1:0]        pop_idx,  
  output logic                                status  
  );

  logic [CAM_DEPTH-1:0]   wr_cam_sel;
  logic [CAM_WIDTH-1:0]   cam_memory [CAM_DEPTH-1:0];   
  logic [CAM_DEPTH-1:0]   cam_match_entry_array;

  logic [CAM_DEPTH-1:0]   status_memory ;   
  logic [CAM_DEPTH-1:0]   valid_status_memory;
  logic [CAM_DEPTH-1:0]   pre_match_idx_array;   
  logic [CAM_DEPTH-1:0]   pop_idx_array;   

  always_comb begin
    // one hot encoding to write new entry 
    wr_cam_sel              = 0;
    wr_cam_sel[cam_in_idx]  = cam_in_valid;
  end

  genvar k;
  generate
    for (k=0; k<CAM_DEPTH; k++) begin
      always @(posedge clk)
        if (wr_cam_sel[k]) cam_memory[k] <= cam_in;

      always_comb begin
          cam_match_entry_array[k] = (cam_memory[k] == cam_key) && cam_key_valid/* : 0*/;
      end 
    end  
  endgenerate

  always_comb begin
    // one hot encoding for insert Match IDX 
    pre_match_idx_array                  = 0;
    pre_match_idx_array[match_idx]       = match_idx_valid;
  end

 always_comb begin
   // one hot encoding for poped IDX 
   pop_idx_array                  = 0;
   pop_idx_array[pop_idx]         = pop_idx_valid;
 end  
  
  generate
    for (k=0; k<CAM_DEPTH; k++) begin
      always @(posedge clk)
        if (wr_cam_sel[k] |pop_idx_array[k])          status_memory[k] <= 0;
        else if(pre_match_idx_array[k])               status_memory[k] <= 1;    
      always @(posedge clk)
        if (wr_cam_sel[k])                            valid_status_memory[k] <= 0;
        else if(pre_match_idx_array[k])               valid_status_memory[k] <= 1;                                             
    end  
  endgenerate  

  assign match_entry_array = cam_match_entry_array & ~valid_status_memory & ~status_memory & ~pre_match_idx_array;  
  assign status            = status_memory[status_mem_idx] && status_mem_idx_valid;

  initial begin
    cam_memory           = '{CAM_DEPTH{0}};
    status_memory        = '{CAM_DEPTH{0}};
  end
  endmodule 