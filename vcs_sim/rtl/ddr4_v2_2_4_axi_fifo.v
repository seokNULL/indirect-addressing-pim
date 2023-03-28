module ddr4_v2_2_4_axi_fifo #
(
  parameter C_WIDTH  = 8,
  parameter C_AWIDTH = 4,
  parameter C_DEPTH  = 16
)
(
  input  wire               clk,       // Main System Clock  (Sync FIFO)
  input  wire               rst,       // FIFO Counter Reset (Clk
  input  wire               wr_en,     // FIFO Write Enable  (Clk)
  input  wire               rd_en,     // FIFO Read Enable   (Clk)
  input  wire [C_WIDTH-1:0] din,       // FIFO Data Input    (Clk)
  output wire [C_WIDTH-1:0] dout,      // FIFO Data Output   (Clk)
  output wire               a_full,
  output wire               full,      // FIFO FULL Status   (Clk)
  output wire               a_empty,
  output wire               empty      // FIFO EMPTY Status  (Clk)
);

///////////////////////////////////////
// FIFO Local Parameters
///////////////////////////////////////
localparam [C_AWIDTH:0] C_EMPTY = ~(0);
localparam [C_AWIDTH-1:0] C_EMPTY_PRE =  0;
localparam [C_AWIDTH-1:0] C_FULL  = C_DEPTH - 1;
localparam [C_AWIDTH-1:0] C_FULL_PRE  = C_DEPTH -2;
 
///////////////////////////////////////
// FIFO Internal Signals
///////////////////////////////////////
reg [C_WIDTH-1:0]  memory [C_DEPTH-1:0];
reg [C_AWIDTH:0] cnt_read;
reg [C_AWIDTH:0] next_cnt_read;

wire [C_AWIDTH:0] cnt_read_plus1;
wire [C_AWIDTH:0] cnt_read_minus1;
wire [C_AWIDTH-1:0] read_addr;

///////////////////////////////////////
// Main FIFO Array
///////////////////////////////////////
assign read_addr = cnt_read[C_AWIDTH-1:0];

assign dout  = memory[read_addr];

always @(posedge clk) begin : BLKSRL
integer i;
  if (wr_en) begin
    for (i = 0; i < C_DEPTH-1; i = i + 1) begin
      memory[i+1] <= memory[i];
    end
    memory[0] <= din;
  end
end

///////////////////////////////////////
// Read Index Counter
// Up/Down Counter
//  *** Notice that there is no ***
//  *** OVERRUN protection.     ***
///////////////////////////////////////
always @(posedge clk) begin
  if (rst) cnt_read <= C_EMPTY;
  else cnt_read <= next_cnt_read;
end

assign cnt_read_plus1 = cnt_read + 1'b1;
assign cnt_read_minus1 = cnt_read - 1'b1;

always @(*) begin
  next_cnt_read = cnt_read;
  if ( wr_en & !rd_en) next_cnt_read = cnt_read_plus1;
  else if (!wr_en &  rd_en) next_cnt_read = cnt_read_minus1;
end

///////////////////////////////////////
// Status Flags / Outputs
// These could be registered, but would
// increase logic in order to pre-decode
// FULL/EMPTY status.
///////////////////////////////////////
assign full  = (cnt_read == C_FULL);
assign empty = (cnt_read == C_EMPTY);
assign a_full  = (cnt_read == C_FULL_PRE);
assign a_empty = (cnt_read == C_EMPTY_PRE);

endmodule // axi_mc_fifo