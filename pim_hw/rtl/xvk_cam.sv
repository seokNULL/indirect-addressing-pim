`timescale 1ps / 1ps

module xvk_cam #(parameter
  CAM_WIDTH = 13,
  CAM_DEPTH = 16)
(
  input  logic clk, rst,
  input  logic [$clog2(CAM_DEPTH)-1:0] cam_wr_addr,      // Address used for data storage
  input  logic cam_we,                                   // Write enable, when asserted, cam_din is stored to cam_wr_addr
  input  logic [CAM_WIDTH-1:0] cam_din,                  // Data to be written to CAM with "cam_we" asserted
  input  logic [CAM_WIDTH-1:0] cam_key,                  // Key data to be matched with CAM contents
  input  logic cam_se,                                   // Search enable, search is initiated when this signal is asserted
  input  logic [CAM_DEPTH-1:0] cam_ignore,               // List of CAM slots to be ignored during search (set to zero if not required)
  output logic cam_match,                                // Line is asserted when at least one data cam_match with the cam_key is found
  output logic [$clog2(CAM_DEPTH)-1:0] cam_match_addr);  // Address of the cam_match, if multiple matches are found, the highest address is returned

  // ============================ Local Definitions ============================
  // Address decoder signals
  logic [CAM_DEPTH-1:0] wr_sel;
  // Memory array
  logic [CAM_WIDTH-1:0] cam_mem [CAM_DEPTH-1:0];
  // Data matching signals
  logic [CAM_DEPTH-1:0] match_line;
  logic match_early;
  logic [$clog2(CAM_DEPTH)-1:0] match_addr_early;

  // =========================== CAM Implementation ============================
  // Write Address Decoder and Row Selector
  always_comb begin
    wr_sel = 0;
    wr_sel[cam_wr_addr] = cam_we;
  end

  // Memory Function Implementation
  genvar k;
  generate
    for (k=0; k<CAM_DEPTH; k++) begin: cam_memory
      // Writing new contents to the memory
      always @(posedge clk)
        if      (wr_sel[k])     cam_mem[k] <= cam_din;
        else if (cam_ignore[k]) cam_mem[k] <= {CAM_WIDTH{1'b1}};                   // Setting memory to an "unreachable" value to make sure that pointer queue doesn't accidentally get "reaused" after being ignored
      // Looking for a cam_match with the delayed cam_key (note, if equal data and cam_key are applied at the same time, the "new" cam_match WILL NOT be registered)
      always_comb begin
        if (wr_sel[k]) match_line[k] = (cam_key == cam_din);                       // If a line is currently being written, use the new data
        else           match_line[k] = (cam_key == cam_mem[k]) && !cam_ignore[k];
      end
    end
  endgenerate

  // Match Dectection and Match Address Encoding
  assign match_early = |match_line;

  always_comb begin
    match_addr_early = 0;
    for (int i=0; i<CAM_DEPTH; i++) begin
      if (match_line[i]) match_addr_early = i;
    end
  end

  // Output register stage
  always @(posedge clk, posedge rst) begin
    if (rst) begin
      cam_match      <= 0;
      cam_match_addr <= 0;
    end
    else if (cam_se) begin
      cam_match      <= match_early;
      cam_match_addr <= match_addr_early;
    end
    else
      cam_match <= 0;
  end

  // ============================= Initialization ==============================
  initial begin
    cam_match      = 0;
    cam_match_addr = 0;
    cam_mem        = '{CAM_DEPTH{{CAM_WIDTH{1'b1}}}};  // Initializing to "uncreachable" values (prio=2'b11 is never used with this CAM) to avoid accidental matches with some requests
  end

endmodule
