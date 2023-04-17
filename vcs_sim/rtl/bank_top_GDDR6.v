`define ENABLE_HPC
`define DEBUG_KEEP
// `define SYN_FAST_NOT_COMPUTE
// `define BANK0_ONLY

`define SUPPORT_INDIRECT_ADDRESSING

module Device_top
(
    clk,
    rst_x,

    read_en,
    write_en,
    addr_in,

    rd_data_valid,
    data_bus_from_memory,

`ifdef SUPPORT_INDIRECT_ADDRESSING
    indirect_addr_out,
    indirect_addr_valid,
`endif

    is_PIM_result,
    PIM_result_to_DRAM
);

localparam BANK_NUM           = 16;
localparam DESC_ADDR_BASE     = 32'h0000_0000;
localparam DESC_ADDR_SIZE     = 32'h0000_0100;
localparam AIM_WORK_SIG       = 32'h0000_4000;
localparam HPC_CLR_SIG        = 32'h0000_5000;
localparam RSV_DESC_MEM_BASE  = 32'h0080_0000;
localparam RSV_DESC_MEM_SIZE  = 32'h0080_0000;

`ifdef SUPPORT_INDIRECT_ADDRESSING
localparam MM_INDIRECT_ARGS = 32'h0000_1000;

`endif

input                              clk;
input                              rst_x;

input                              read_en;
input                              write_en;
input  [31:0]                      addr_in;

`ifdef SUPPORT_INDIRECT_ADDRESSING
output  [31:0]                     indirect_addr_out;
output                             indirect_addr_valid;
`endif

input                              rd_data_valid;
input  [255:0]                     data_bus_from_memory;

output                             is_PIM_result;
output [255:0]                     PIM_result_to_DRAM;

genvar i;


//{is_desc_range_incr, is_desc_clr_TEST, PIM_src_A_pass_reg_tot, PIM_src_B_pass_reg_tot, ui_write_req, ui_read_req, ui_addr};
// 1             +1           +1                      +1                      +1            +1           +32      (6+32)
wire [37:0] CAS_rw_queue_entry;
wire [37:0] CAS_rw_queue_head;

wire CAS_rw_queue_full;
wire CAS_rw_queue_empty;
wire CAS_rw_queue_wr_en;
reg  CAS_rw_queue_rd_en;

wire [256:0] CAS_read_data_queue_entry;
wire [256:0] CAS_read_data_queue_head;

wire CAS_read_data_queue_full;
wire CAS_read_data_queue_empty;
wire CAS_read_data_QUEUE_wr_en;
wire CAS_read_data_QUEUE_rd_en;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//enqueue data
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

(* keep = "true", mark_debug = "true" *)wire [31:0] ui_addr = addr_in;

(* keep = "true", mark_debug = "true" *)wire ui_write_req = write_en;
(* keep = "true", mark_debug = "true" *)wire ui_read_req  = read_en;

wire PIM_src_A_pass_reg_tot;
wire PIM_src_B_pass_reg_tot;
wire PIM_dst_C_pass_reg_tot;


wire is_desc_clr_TEST;
wire is_desc_range_incr;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
assign CAS_rw_queue_entry = {is_desc_range_incr, is_desc_clr_TEST, PIM_src_A_pass_reg_tot, PIM_src_B_pass_reg_tot, ui_write_req, ui_read_req, ui_addr};
//1+1+1+1+1+1+32 = 38

assign CAS_rw_queue_wr_en = (ui_read_req || (ui_write_req && !PIM_dst_C_pass_reg_tot));

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//RW queue
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
ddr4_v2_2_4_axi_fifo #(.C_WIDTH(38), .C_AWIDTH(12), .C_DEPTH(4096)) U0_CAS_RW_QUEUE(
    .clk                    (clk                        ),
    .rst                    (!rst_x                     ), 
    .wr_en                  (CAS_rw_queue_wr_en         ),
    .rd_en                  (CAS_rw_queue_rd_en         ),
    .din                    (CAS_rw_queue_entry         ),
    .dout                   (CAS_rw_queue_head          ),
    .a_full                 (                           ),
    .full                   (CAS_rw_queue_full          ),
    .a_empty                (                           ),
    .empty                  (CAS_rw_queue_empty         )
);

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
assign CAS_read_data_queue_entry = {rd_data_valid, data_bus_from_memory};
assign CAS_read_data_QUEUE_wr_en = rd_data_valid;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//Read data queue (timing sync)
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
ddr4_v2_2_4_axi_fifo #(.C_WIDTH(257), .C_AWIDTH(9), .C_DEPTH(512)) U0_CAS_R_DATA_QUEUE(
    .clk                    (clk                        ),
    .rst                    (!rst_x                     ), 
    .wr_en                  (CAS_read_data_QUEUE_wr_en  ),
    .rd_en                  (CAS_read_data_QUEUE_rd_en  ),
    .din                    (CAS_read_data_queue_entry  ),
    .dout                   (CAS_read_data_queue_head   ),
    .a_full                 (                           ),
    .full                   (CAS_read_data_queue_full   ),
    .a_empty                (                           ),
    .empty                  (CAS_read_data_queue_empty  )
);

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//Dequeue siganl decision
// CAS_queue_head_r / DRAM_data <-- final dequeue data
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//wire [294:0] CAS_rw_queue_head;

wire         ui_is_desc_range = CAS_rw_queue_head[37] && !CAS_rw_queue_empty;
wire         ui_is_desc_clr   = CAS_rw_queue_head[36] && !CAS_rw_queue_empty;

wire         ui_srcA_pass = CAS_rw_queue_head[35] && !CAS_rw_queue_empty;
wire         ui_srcB_pass = CAS_rw_queue_head[34] && !CAS_rw_queue_empty;

wire         ui_write_valid = CAS_rw_queue_head[33] && !CAS_rw_queue_empty;
wire         ui_read_valid  = CAS_rw_queue_head[32] && !CAS_rw_queue_empty;

//wire [255:0] ui_write_data  = CAS_rw_queue_head[287:32];
wire [255:0] ui_read_data   = CAS_read_data_queue_head[255:0];
wire [31:0]  ui_addr_data   = CAS_rw_queue_head[31:0];

always @(*) begin
    if(!PIM_dst_C_pass_reg_tot) begin
        if     (ui_write_valid)             CAS_rw_queue_rd_en = 1'b1;
        else if(CAS_read_data_QUEUE_rd_en)  CAS_rw_queue_rd_en = 1'b1;
        else                                CAS_rw_queue_rd_en = 1'b0;
    end
    else                                    CAS_rw_queue_rd_en = 1'b0;
end

assign CAS_read_data_QUEUE_rd_en = ((CAS_read_data_queue_head[256] && !CAS_read_data_queue_empty) && ui_read_valid) && !PIM_dst_C_pass_reg_tot;


//reg [293:0] CAS_queue_head_r; 
reg [37:0] CAS_queue_head_r; 

wire CAS_queue_head_r_valid = (CAS_queue_head_r[33] || CAS_queue_head_r[32]);

always @(posedge clk or negedge rst_x) begin
    if (~rst_x)                                                  CAS_queue_head_r <= 'b0;    else if(!PIM_dst_C_pass_reg_tot) begin
        if(ui_write_valid ||CAS_read_data_QUEUE_rd_en)           CAS_queue_head_r <= {ui_is_desc_range, ui_is_desc_clr, ui_srcA_pass, ui_srcB_pass, ui_write_valid, ui_read_valid, ui_addr_data};
        else                                                     CAS_queue_head_r <= 'b0;
    end
    else if(PIM_dst_C_pass_reg_tot && CAS_queue_head_r_valid)    CAS_queue_head_r <= CAS_queue_head_r;                          
    else                                                         CAS_queue_head_r <= 'b0;
end

reg [255:0] DRAM_data;
always @(posedge clk or negedge rst_x) begin
    if (~rst_x)                               DRAM_data <= 'b0;
    else if(CAS_read_data_QUEUE_rd_en)        DRAM_data <= ui_read_data;
end

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
(* keep = "true", mark_debug = "true" *) reg            req_is_desc_range;
(* keep = "true", mark_debug = "true" *) reg            req_is_desc_clr;
reg            req_srcA_pass;
reg            req_srcB_pass;
reg            req_dstC_pass;
reg            req_valid;
reg            req_wr;
reg            req_rd;
reg [31:0]     req_addr;
reg [1:0]      req_bg;
reg [1:0]      req_bk;
//reg [3:0]      req_col; //just for debugging
//reg [1:0]      req_row; //just for debugging
//reg [255:0]    req_data;
always @(*) begin
   //for PIM write timing,,, should be bypassed
   if(PIM_dst_C_pass_reg_tot) begin
                                       req_is_desc_range = 1'b0;
                                       req_is_desc_clr = 1'b0;
                                       req_srcA_pass   = 1'b0;
                                       req_srcB_pass   = 1'b0;
                                       req_dstC_pass   = 1'b1;
                                       req_valid       = 1'b1;
                                       req_wr          = 1'b1;
                                       req_rd          = 1'b0;
                                       //req_data        = 256'b0;
                                       req_addr        = ui_addr;
                                       req_bg          = req_addr[6:5];
                                       req_bk          = req_addr[8:7];
                                       //req_col         = req_addr[13:10];
                                       //req_row         = req_addr[15:14];                                        
   end
   else begin
                                       req_is_desc_range = CAS_queue_head_r[37];
                                       req_is_desc_clr   = CAS_queue_head_r[36];
                                       req_srcA_pass   = CAS_queue_head_r[35];
                                       req_srcB_pass   = CAS_queue_head_r[34];
                                       req_dstC_pass   = 1'b0;        
                                       req_valid       = CAS_queue_head_r[33] || CAS_queue_head_r[32];
                                       req_wr          = CAS_queue_head_r[33];
                                       req_rd          = CAS_queue_head_r[32];
                                       //req_data        = CAS_queue_head_r[287:32];
                                       req_addr        = CAS_queue_head_r[31:0];
                                       req_bg          = req_addr[6:5];
                                       req_bk          = req_addr[8:7];
                                       //req_col         = req_addr[13:10];
                                       //req_row         = req_addr[15:14];
   end
end

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

`ifdef DEBUG_KEEP
(* keep = "true", mark_debug = "true" *) reg debug_ui_write_req_r;
(* keep = "true", mark_debug = "true" *) reg debug_ui_read_req_r;
(* keep = "true", mark_debug = "true" *) reg [31:0] debug_ui_addr_r;
(* keep = "true", mark_debug = "true" *) reg debug_PIM_src_A_pass_reg_tot_r;
(* keep = "true", mark_debug = "true" *) reg debug_PIM_src_B_pass_reg_tot_r;
(* keep = "true", mark_debug = "true" *) reg debug_PIM_dst_C_pass_reg_tot_r;


(* keep = "true", mark_debug = "true" *) reg debug_is_desc_clr_TEST;
(* keep = "true", mark_debug = "true" *) reg debug_is_desc_range_incr;
always @(posedge clk or negedge rst_x) begin
    if (~rst_x) begin
                                                    debug_ui_write_req_r         <= 'b0;
                                                    debug_ui_read_req_r          <= 'b0;                                                    debug_ui_addr_r              <= 'b0;
                                                    debug_PIM_src_A_pass_reg_tot_r <= 'b0;
                                                    debug_PIM_src_B_pass_reg_tot_r <= 'b0;
                                                    debug_PIM_dst_C_pass_reg_tot_r <= 'b0;

                                                    debug_is_desc_clr_TEST <= 'b0;
                                                    debug_is_desc_range_incr <= 'b0;
    end
    else begin
                                                    debug_ui_write_req_r <= ui_write_req;
                                                    debug_ui_read_req_r  <= ui_read_req;
                                                    debug_ui_addr_r      <= ui_addr;
                                                    debug_PIM_src_A_pass_reg_tot_r <= PIM_src_A_pass_reg_tot;
                                                    debug_PIM_src_B_pass_reg_tot_r <= PIM_src_B_pass_reg_tot;
                                                    debug_PIM_dst_C_pass_reg_tot_r <= PIM_dst_C_pass_reg_tot;

                                                    debug_is_desc_clr_TEST <= is_desc_clr_TEST;
                                                    debug_is_desc_range_incr <= is_desc_range_incr;
    end
end
`else
`endif

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


///////////////////////////////////////////////////////////////////////////////////////////////////
//PIM memory mapped regs

//DESC_ADDR_BASE     = 32'hx000_0000;
//DESC_ADDR_SIZE     = 32'hx000_0100;
//AIM_WORK_SIG       = 32'hx000_4000;
//HPC_CLR_SIG        = 32'hx000_5000;


wire req_AIM_WORKING;
wire req_HPC_CLR_SIG;

assign req_AIM_WORKING       = (( req_addr[31:0]  == AIM_WORK_SIG     ) && req_wr)                 ? 1'b1 : 1'b0;
assign req_HPC_CLR_SIG       = (( req_addr[31:0]  == HPC_CLR_SIG      ) && req_wr)                 ? 1'b1 : 1'b0;
///////////////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//HOST desc config memory-mapped reg (addr/size) 
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
(* keep = "true", mark_debug = "true" *)reg [31:0] PIM_desc_base_addr;
(* keep = "true", mark_debug = "true" *)reg [31:0] PIM_desc_addr_size;

(* keep = "true", mark_debug = "true" *)wire [31:0] PIM_desc_range;
(* keep = "true", mark_debug = "true" *)wire [32:0] diff_desc_addr0;
(* keep = "true", mark_debug = "true" *)wire [32:0] diff_desc_addr1;

(* keep = "true", mark_debug = "true" *) reg HPC_clear_sig;
(* keep = "true", mark_debug = "true" *) reg AIM_working;

always @(posedge clk or negedge rst_x) begin
    if (~rst_x) begin
                                                                PIM_desc_base_addr <= 'b0;
                                                                PIM_desc_addr_size <= 'b0;
    end
    else begin
                                                                PIM_desc_base_addr <= RSV_DESC_MEM_BASE;
                                                                PIM_desc_addr_size <= RSV_DESC_MEM_SIZE;
    end
end

assign PIM_desc_range = PIM_desc_base_addr + PIM_desc_addr_size;

assign diff_desc_addr0 = (PIM_desc_range - 1 - ui_addr);
assign diff_desc_addr1 = (ui_addr - PIM_desc_base_addr);

(* keep = "true", mark_debug = "true" *) reg [31:0] current_desc_addr;
(* keep = "true", mark_debug = "true" *) reg [31:0] next_desc_addr;
(* keep = "true", mark_debug = "true" *) wire       desc_incr_enable;

assign is_desc_clr_TEST   = (ui_addr[5:0] == 6'b011100) && AIM_working && (!diff_desc_addr0[32]) && (!diff_desc_addr1[32]) && ui_write_req ? 1'b1 : 1'b0;
assign is_desc_range_incr = (desc_incr_enable) && (ui_addr[5:0] == 6'b000000) && AIM_working && (!diff_desc_addr0[32]) && (!diff_desc_addr1[32]) && ui_read_req ? 1'b1 : 1'b0;




always @(posedge clk or negedge rst_x) begin
  if( (~rst_x)| req_AIM_WORKING) begin
          current_desc_addr                         <= 'b0;
          next_desc_addr                            <= 'b0;
  end
  else if(HPC_clear_sig) begin
          current_desc_addr                         <= RSV_DESC_MEM_BASE;
          next_desc_addr                            <= RSV_DESC_MEM_BASE + 32'h0000_0040;
          
  end
  else if(ui_addr==next_desc_addr) begin
          current_desc_addr                         <= ui_addr;
          next_desc_addr                            <= ui_addr + 32'h0000_0040;
  end
end
assign desc_incr_enable = ((ui_addr==RSV_DESC_MEM_BASE)||(ui_addr==next_desc_addr))? 1'b1 : 1'b0;


///////////////////////////////////////////////////////////////////////////////////////////////////
//// Support indirect addressing mode 
///////////////////////////////////////////////////////////////////////////////////////////////////

`ifdef SUPPORT_INDIRECT_ADDRESSING

wire is_read_descr;
  assign is_read_descr = is_desc_range_incr;
// Determine if instruction's source address need to be calculated with indirect mode.
wire is_indirect;
  assign is_indirect = is_read_descr && AIM_working && (data_bus_from_memory[0]==1'b1);
// Determine whete is the offset of source address.
wire is_offset_immediate;
wire is_offset_register;
  assign is_offset_immediate =  is_read_descr && AIM_working && (data_bus_from_memory[1]==1'b1);
  assign is_offset_register  =  is_read_descr && AIM_working && (data_bus_from_memory[2]==1'b1);


//Indirect address's base value
wire req_MM_args;
assign req_MM_args = (( ui_addr[31:0]  == MM_INDIRECT_ARGS) && ui_write_req) ? 1'b1 : 1'b0;
reg [31:0] args_reg_A;
reg [31:0] args_reg_B;
reg [31:0] args_reg_C;

always @(posedge clk or negedge rst_x) begin
    if(~rst_x) begin
                                         args_reg_A <= 'b0;
                                         args_reg_B <= 'b0;
                                         args_reg_C <= 'b0;
    end
    else if(req_HPC_CLR_SIG) begin
                                         args_reg_A <= 'b0;
                                         args_reg_B <= 'b0;
                                         args_reg_C <= 'b0;    
    end
    else if(req_MM_args) begin
                                        args_reg_A <= data_bus_from_memory[32*1-1: 32*0];
                                        args_reg_B <= data_bus_from_memory[32*2-1: 32*1];
                                        args_reg_C <= data_bus_from_memory[32*3-1: 32*2];
    end
end

//Indirect address's offset value (Immediate). Immediate value comes from instruction(descriptor's source address)
wire [31:0] offset_immdediate;
  //Need to be modified afeter LUT operation enable, right now, just temporally wiring source address from descriptor
  assign offset_immdediate = (req_is_desc_range && is_offset_immediate) ? data_bus_from_memory[32*3-1 :32*2] : 'b0;

wire [31:0] current_pim_opcode;
  // [3]=>C [2]=>B [1]=>A
  assign current_pim_opcode = (req_is_desc_range)? data_bus_from_memory[32*8-1 :32*7] : 'b0;
wire is_desc_A;
wire is_desc_B;
wire is_desc_C;
  assign is_desc_A = current_pim_opcode[0];
  assign is_desc_B = current_pim_opcode[1];
  assign is_desc_C = current_pim_opcode[2];

reg [31:0] offset_in;
reg [31:0] base_in;
always @(*)begin
  if(is_offset_immediate && is_desc_A)             base_in = args_reg_A;
  else if(is_offset_immediate && is_desc_B)        base_in = args_reg_B;
  else if(is_offset_immediate && is_desc_C)        base_in = args_reg_C;
  else                                             base_in = 'b0;
end

always @(*)begin
  if(is_offset_immediate)                          offset_in = offset_immdediate;
  else                                             offset_in = 'b0;
end

assign indirect_addr_out = base_in + offset_in;
assign indirect_addr_valid = is_indirect;
// output  [31:0]                     indirect_addr_out;
// output                             indirect_addr_valid;


`endif




/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//DESC addr offloading regs (max 8)
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

`ifdef DEBUG_KEEP
(* keep = "true", mark_debug = "true" *) reg [31:0] PIM_SRC_ADDR_from_desc_reg[0:7];
(* keep = "true", mark_debug = "true" *) reg [31:0] PIM_DST_ADDR_from_desc_reg[0:7];
(* keep = "true", mark_debug = "true" *) reg [31:0] PIM_SIZE_from_desc_reg[0:7];
(* keep = "true", mark_debug = "true" *) reg [31:0] PIM_INFO_from_desc_reg[0:7];

(* keep = "true", mark_debug = "true" *) reg [2:0] PIM_addr_match_wr_ptr;
(* keep = "true", mark_debug = "true" *) reg [2:0] PIM_addr_match_clr_ptr;
`else
reg [31:0] PIM_SRC_ADDR_from_desc_reg[0:7];
reg [31:0] PIM_DST_ADDR_from_desc_reg[0:7];
reg [31:0] PIM_SIZE_from_desc_reg[0:7];
reg [31:0] PIM_INFO_from_desc_reg[0:7];

reg [2:0] PIM_addr_match_wr_ptr;
reg [2:0] PIM_addr_match_clr_ptr;
`endif

always @(posedge clk or negedge rst_x) begin
    if (~rst_x)                 PIM_addr_match_wr_ptr <= 'b0;
    else if(HPC_clear_sig)      PIM_addr_match_wr_ptr <= 'b0;
    else if(req_is_desc_range)  PIM_addr_match_wr_ptr <= PIM_addr_match_wr_ptr + 1;
end

always @(posedge clk or negedge rst_x) begin
    if (~rst_x)                 PIM_addr_match_clr_ptr <= 'b0;
    else if(HPC_clear_sig)      PIM_addr_match_clr_ptr <= 'b0;
    else if(req_is_desc_clr)    PIM_addr_match_clr_ptr <= PIM_addr_match_clr_ptr + 1;
end

generate 
  for(i = 0; i < 8; i = i + 1) begin: GEN_PIM_INFO_REG
    always @(posedge clk or negedge rst_x) begin
      if (~rst_x) begin
                                                                          PIM_SRC_ADDR_from_desc_reg[i] <= 'b0;
                                                                          PIM_DST_ADDR_from_desc_reg[i] <= 'b0;
                                                                          PIM_SIZE_from_desc_reg[i]     <= 'b0;
                                                                          PIM_INFO_from_desc_reg[i]     <= 'b0;
      end
      else if(HPC_clear_sig) begin
                                                                          PIM_SRC_ADDR_from_desc_reg[i] <= 'b0;
                                                                          PIM_DST_ADDR_from_desc_reg[i] <= 'b0;
                                                                          PIM_SIZE_from_desc_reg[i]     <= 'b0;
                                                                          PIM_INFO_from_desc_reg[i]     <= 'b0;
      end
      else if(req_is_desc_clr && (PIM_addr_match_clr_ptr == i)) begin
                                                                          PIM_SRC_ADDR_from_desc_reg[i] <= 'b0;
                                                                          PIM_DST_ADDR_from_desc_reg[i] <= 'b0;
                                                                          PIM_SIZE_from_desc_reg[i]     <= 'b0;
                                                                          PIM_INFO_from_desc_reg[i]     <= 'b0;
      end
      else if(req_is_desc_range && (PIM_addr_match_wr_ptr == i)) begin
                                                                          `ifdef SUPPORT_INDIRECT_ADDRESSING
                                                                          PIM_SRC_ADDR_from_desc_reg[i] <= is_indirect? indirect_addr_out:DRAM_data[32*3-1 :32*2];
                                                                          `else
                                                                          PIM_SRC_ADDR_from_desc_reg[i] <= DRAM_data[32*3-1 :32*2];
                                                                          `endif
                                                                          PIM_DST_ADDR_from_desc_reg[i] <= DRAM_data[32*5-1 :32*4];
                                                                          PIM_SIZE_from_desc_reg[i]     <= DRAM_data[32*7-1 :32*6];
                                                                          PIM_INFO_from_desc_reg[i]     <= DRAM_data[32*8-1 :32*7];
      end
    end
  end
endgenerate


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//Desc address matching logic
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

wire [31:0] PIM_base_addr_reg[0:7];
wire [31:0] PIM_base_addr_size_reg[0:7];
wire [2:0]  PIM_base_addr_type_reg[0:7];
wire [31:0] PIM_range_reg[0:7];

wire [32:0] diff_addr0_reg[0:7];
wire [32:0] diff_addr1_reg[0:7];

wire [7:0] PIM_src_A_pass_reg;
wire [7:0] PIM_src_B_pass_reg;
wire [7:0] PIM_dst_C_pass_reg;


generate 
  for(i = 0; i < 8; i = i + 1) begin: PIM_ADDR_MATCH
    assign PIM_base_addr_reg[i]      = PIM_INFO_from_desc_reg[i][0] ? PIM_DST_ADDR_from_desc_reg[i] : PIM_SRC_ADDR_from_desc_reg[i];
    assign PIM_base_addr_size_reg[i] = PIM_SIZE_from_desc_reg[i];
    assign PIM_base_addr_type_reg[i] = PIM_INFO_from_desc_reg[i][3:1];
    
    assign PIM_range_reg[i] = PIM_base_addr_reg[i] + PIM_base_addr_size_reg[i];
    
    assign diff_addr0_reg[i] = (PIM_range_reg[i] - 1 - ui_addr);
    assign diff_addr1_reg[i] = (ui_addr - PIM_base_addr_reg[i]);
    
    assign PIM_src_A_pass_reg[i] = (!diff_addr0_reg[i][32]) && (!diff_addr1_reg[i][32]) && PIM_base_addr_type_reg[i][0] ? 1'b1 : 1'b0;
    assign PIM_src_B_pass_reg[i] = (!diff_addr0_reg[i][32]) && (!diff_addr1_reg[i][32]) && PIM_base_addr_type_reg[i][1] ? 1'b1 : 1'b0;
    assign PIM_dst_C_pass_reg[i] = (!diff_addr0_reg[i][32]) && (!diff_addr1_reg[i][32]) && PIM_base_addr_type_reg[i][2] ? 1'b1 : 1'b0;
  end
endgenerate

//PIM R/W decision --> final PIM operand checking
assign PIM_src_A_pass_reg_tot = (|PIM_src_A_pass_reg) && ui_read_req;
assign PIM_src_B_pass_reg_tot = (|PIM_src_B_pass_reg) && ui_read_req;
assign PIM_dst_C_pass_reg_tot = (|PIM_dst_C_pass_reg) && ui_write_req;

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////
//HPC signal
///////////////////////////////////////////////////////////////////////////////////////////////////

`ifdef ENABLE_HPC
reg [127:0] AIM_processing_cycle;
//reg [127:0] AIM_prof_cnt;

always @(posedge clk or negedge rst_x) begin
    if (~rst_x)                                     HPC_clear_sig <= 1'b0;
    else if(req_HPC_CLR_SIG)                        HPC_clear_sig <= 1'b1;
    else                                            HPC_clear_sig <= 1'b0;
end

always @(posedge clk or negedge rst_x) begin
    if (~rst_x)                                     AIM_working <= 1'b0;
    //else if(HPC_clear_sig)                          AIM_working <= 1'b0;
    else if(req_AIM_WORKING && AIM_working)         AIM_working <= 1'b0;
    else if(req_AIM_WORKING)                        AIM_working <= 1'b1;
end

always @(posedge clk or negedge rst_x) begin
    if (~rst_x)                                     AIM_processing_cycle <= 'b0;
    else if(AIM_working && req_AIM_WORKING)         AIM_processing_cycle <= 'b0;
    else if(AIM_working)                            AIM_processing_cycle <= AIM_processing_cycle + 1;
end

//(* keep = "true", mark_debug = "true" *) reg PROF_sig;
//
//always @(posedge clk or negedge rst_x) begin
//    if (~rst_x)                          PROF_sig <= 1'b0;
//    else if(req_PROF_SIG && PROF_sig)    PROF_sig <= 1'b0;
//    else if(req_PROF_SIG)                PROF_sig <= 1'b1;
//end
//
//always @(posedge clk or negedge rst_x) begin
//    if (~rst_x)                          AIM_prof_cnt <= 'b0;
//    else if(req_PROF_SIG && PROF_sig)    AIM_prof_cnt <= 'b0;
//    else if(PROF_sig)                    AIM_prof_cnt <= AIM_prof_cnt + 1;
//end

`else
wire HPC_clear_sig = 1'b0;
wire AIM_working = 1'b0;
`endif






///////////////////////////////////////////////////////////////////////////////////////////////////
//Bank configuration regs
///////////////////////////////////////////////////////////////////////////////////////////////////

//Bank config timing
(* keep = "true", mark_debug = "true" *)reg req_is_desc_range_r;
(* keep = "true", mark_debug = "true" *)reg [2:0] PIM_addr_match_wr_ptr_r;
reg [27:0] bank_config_reg;

always @(posedge clk or negedge rst_x) begin
    if (~rst_x)                 req_is_desc_range_r <= 'b0;
    else                        req_is_desc_range_r <= req_is_desc_range;
end

always @(posedge clk or negedge rst_x) begin
    if (~rst_x)                 PIM_addr_match_wr_ptr_r <= 'b0;
    else                        PIM_addr_match_wr_ptr_r <= PIM_addr_match_wr_ptr;
end


////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//bank config for fusion
////////////////////////////////////////////////////////////////////////////////////////////////////////////////


`ifdef DEBUG_KEEP
(* keep = "true", mark_debug = "true" *) reg [9:0] PIM_req_A_cnt;
(* keep = "true", mark_debug = "true" *) reg [9:0] PIM_req_B_cnt;
(* keep = "true", mark_debug = "true" *) reg [9:0] PIM_req_C_cnt;

(* keep = "true", mark_debug = "true" *) reg [2:0] PIM_opcode_match_ptr;

(* keep = "true", mark_debug = "true" *) reg [31:0] current_opcode_data;
(* keep = "true", mark_debug = "true" *) reg [31:0] current_desc_size;

(* keep = "true", mark_debug = "true" *) wire check_srcA_desc_done;
(* keep = "true", mark_debug = "true" *) wire check_srcB_desc_done;
(* keep = "true", mark_debug = "true" *) wire check_dstC_desc_done;

(* keep = "true", mark_debug = "true" *) reg check_current_desc_done;
(* keep = "true", mark_debug = "true" *) reg check_current_desc_done_r;
(* keep = "true", mark_debug = "true" *) reg check_current_desc_done_rr;
(* keep = "true", mark_debug = "true" *) reg check_current_desc_done_rrr;
(* keep = "true", mark_debug = "true" *) reg check_current_desc_done_rrrr;


`else

reg [9:0] PIM_req_A_cnt;
reg [9:0] PIM_req_B_cnt;
reg [9:0] PIM_req_C_cnt;

reg [2:0] PIM_opcode_match_ptr;

reg [31:0] current_opcode_data;
reg [31:0] current_desc_size;

wire check_srcA_desc_done;
wire check_srcB_desc_done;
wire check_dstC_desc_done;

reg check_current_desc_done;
reg check_current_desc_done_r;
reg check_current_desc_done_rr;
reg check_current_desc_done_rrr;
reg check_current_desc_done_rrrr;
`endif


always @(posedge clk or negedge rst_x) begin 
  if(~rst_x)begin
              check_current_desc_done_r              <=1'b0;
              check_current_desc_done_rr             <=1'b0;
              check_current_desc_done_rrr            <=1'b0;
              check_current_desc_done_rrrr           <=1'b0;    
  end
  else begin
              check_current_desc_done_r              <=check_current_desc_done;
              check_current_desc_done_rr             <=check_current_desc_done_r;
              check_current_desc_done_rrr            <=check_current_desc_done_rr;
              check_current_desc_done_rrrr           <=check_current_desc_done_rrr;  
  end
end


always @(posedge clk or negedge rst_x) begin
    if (~rst_x)                                     PIM_req_A_cnt <= 'b0;
    else if(check_srcA_desc_done && req_srcA_pass)  PIM_req_A_cnt <= 1;
    else if(HPC_clear_sig || check_srcA_desc_done)  PIM_req_A_cnt <= 'b0;
    else if(req_srcA_pass)                          PIM_req_A_cnt <= PIM_req_A_cnt + 1;
end

always @(posedge clk or negedge rst_x) begin
    if (~rst_x)                                     PIM_req_B_cnt <= 'b0;
    else if(check_srcB_desc_done && req_srcB_pass)  PIM_req_B_cnt <= 1;
    else if(HPC_clear_sig || check_srcB_desc_done)  PIM_req_B_cnt <= 'b0;
    else if(req_srcB_pass)                          PIM_req_B_cnt <= PIM_req_B_cnt + 1;
end

always @(posedge clk or negedge rst_x) begin
    if (~rst_x)                                     PIM_req_C_cnt <= 'b0;
    else if(check_dstC_desc_done && req_dstC_pass)  PIM_req_C_cnt <= 1;
    else if(HPC_clear_sig || check_dstC_desc_done)  PIM_req_C_cnt <= 'b0;
    else if(req_dstC_pass)                          PIM_req_C_cnt <= PIM_req_C_cnt + 1;
end

always @(posedge clk or negedge rst_x) begin
    if (~rst_x)                                     PIM_opcode_match_ptr <= 'b0;
    else if(HPC_clear_sig)                          PIM_opcode_match_ptr <= 'b0;
    // else if(check_current_desc_done)                PIM_opcode_match_ptr <= PIM_opcode_match_ptr + 1;
    else if(check_current_desc_done_rrrr)                PIM_opcode_match_ptr <= PIM_opcode_match_ptr + 1;
end


always @(*) begin
    if     (PIM_opcode_match_ptr == 3'b000)         current_opcode_data = PIM_INFO_from_desc_reg[0];
    else if(PIM_opcode_match_ptr == 3'b001)         current_opcode_data = PIM_INFO_from_desc_reg[1];
    else if(PIM_opcode_match_ptr == 3'b010)         current_opcode_data = PIM_INFO_from_desc_reg[2];
    else if(PIM_opcode_match_ptr == 3'b011)         current_opcode_data = PIM_INFO_from_desc_reg[3];
    else if(PIM_opcode_match_ptr == 3'b100)         current_opcode_data = PIM_INFO_from_desc_reg[4];
    else if(PIM_opcode_match_ptr == 3'b101)         current_opcode_data = PIM_INFO_from_desc_reg[5];
    else if(PIM_opcode_match_ptr == 3'b110)         current_opcode_data = PIM_INFO_from_desc_reg[6];
    else if(PIM_opcode_match_ptr == 3'b111)         current_opcode_data = PIM_INFO_from_desc_reg[7];
    else                                            current_opcode_data = 'b0;
end

always @(*) begin
    if     (PIM_opcode_match_ptr == 3'b000)         current_desc_size = PIM_SIZE_from_desc_reg[0] >> 5; //32-byte || 64-byte --> >> 6
    else if(PIM_opcode_match_ptr == 3'b001)         current_desc_size = PIM_SIZE_from_desc_reg[1] >> 5; //32-byte || 64-byte --> >> 6
    else if(PIM_opcode_match_ptr == 3'b010)         current_desc_size = PIM_SIZE_from_desc_reg[2] >> 5; //32-byte || 64-byte --> >> 6
    else if(PIM_opcode_match_ptr == 3'b011)         current_desc_size = PIM_SIZE_from_desc_reg[3] >> 5; //32-byte || 64-byte --> >> 6
    else if(PIM_opcode_match_ptr == 3'b100)         current_desc_size = PIM_SIZE_from_desc_reg[4] >> 5; //32-byte || 64-byte --> >> 6
    else if(PIM_opcode_match_ptr == 3'b101)         current_desc_size = PIM_SIZE_from_desc_reg[5] >> 5; //32-byte || 64-byte --> >> 6
    else if(PIM_opcode_match_ptr == 3'b110)         current_desc_size = PIM_SIZE_from_desc_reg[6] >> 5; //32-byte || 64-byte --> >> 6
    else if(PIM_opcode_match_ptr == 3'b111)         current_desc_size = PIM_SIZE_from_desc_reg[7] >> 5; //32-byte || 64-byte --> >> 6
    else                                            current_desc_size = 'b0;
end

assign check_srcA_desc_done = ((current_opcode_data[1])  && (current_desc_size == PIM_req_A_cnt)) ? 1'b1 : 1'b0;
assign check_srcB_desc_done = ((current_opcode_data[2])  && (current_desc_size == PIM_req_B_cnt)) ? 1'b1 : 1'b0;
assign check_dstC_desc_done = ((current_opcode_data[3])  && (current_desc_size == PIM_req_C_cnt)) ? 1'b1 : 1'b0;

always@(*) begin
    if     (current_opcode_data[1]) check_current_desc_done = check_srcA_desc_done;
    else if(current_opcode_data[2]) check_current_desc_done = check_srcB_desc_done;
    else if(current_opcode_data[3]) check_current_desc_done = check_dstC_desc_done;
    else                            check_current_desc_done = 1'b0;
end

always@(*) begin
    if     (PIM_opcode_match_ptr == 3'b000)     bank_config_reg = PIM_INFO_from_desc_reg[0][31:4];
    else if(PIM_opcode_match_ptr == 3'b001)     bank_config_reg = PIM_INFO_from_desc_reg[1][31:4];
    else if(PIM_opcode_match_ptr == 3'b010)     bank_config_reg = PIM_INFO_from_desc_reg[2][31:4];
    else if(PIM_opcode_match_ptr == 3'b011)     bank_config_reg = PIM_INFO_from_desc_reg[3][31:4];
    else if(PIM_opcode_match_ptr == 3'b100)     bank_config_reg = PIM_INFO_from_desc_reg[4][31:4];
    else if(PIM_opcode_match_ptr == 3'b101)     bank_config_reg = PIM_INFO_from_desc_reg[5][31:4];
    else if(PIM_opcode_match_ptr == 3'b110)     bank_config_reg = PIM_INFO_from_desc_reg[6][31:4];
    else if(PIM_opcode_match_ptr == 3'b111)     bank_config_reg = PIM_INFO_from_desc_reg[7][31:4];
    else                                        bank_config_reg = 'b0;
end

//Inter bank comunication

wire is_vecA_rd_broadcast_config = bank_config_reg[15];
wire is_vecB_rd_broadcast_config = bank_config_reg[16];

wire is_vecA_rd_broadcast = is_vecA_rd_broadcast_config;
wire is_vecB_rd_broadcast = is_vecB_rd_broadcast_config;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
reg  [BANK_NUM-1:0] bank_access;
wire [BANK_NUM-1:0] rd_cmd;
wire [BANK_NUM-1:0] wr_cmd;

`ifdef DEBUG_KEEP

//important debug_sig
(* keep = "true", mark_debug = "true" *) reg  [31:0]    debug_req_addr_r;
(* keep = "true", mark_debug = "true" *) reg            debug_req_valid_r;
//(* keep = "true", mark_debug = "true" *) reg  [255:0]   debug_req_data_r;
(* keep = "true", mark_debug = "true" *) reg            debug_req_wr_r;
(* keep = "true", mark_debug = "true" *) reg            debug_req_rd_r;

(* keep = "true", mark_debug = "true" *) reg            debug_req_srcA_pass_r;
(* keep = "true", mark_debug = "true" *) reg            debug_req_srcB_pass_r;
(* keep = "true", mark_debug = "true" *) reg            debug_req_dstC_pass_r;

always @(posedge clk or negedge rst_x) begin
  if (~rst_x) begin
                                                debug_req_addr_r <= 'b0;
                                                debug_req_valid_r <= 'b0;
                                                //debug_req_data_r <= 'b0;
                                                debug_req_wr_r <= 'b0;
                                                debug_req_rd_r <= 'b0;

                                                debug_req_srcA_pass_r <= 'b0;
                                                debug_req_srcB_pass_r <= 'b0;
                                                debug_req_dstC_pass_r <= 'b0;
  end
  else begin
                                                debug_req_addr_r <= req_addr;
                                                debug_req_valid_r <= req_valid;
                                                //debug_req_data_r  <= req_data;
                                                debug_req_wr_r <= req_wr;
                                                debug_req_rd_r <= req_rd;

                                                debug_req_srcA_pass_r <= req_srcA_pass;
                                                debug_req_srcB_pass_r <= req_srcB_pass;
                                                debug_req_dstC_pass_r <= req_dstC_pass;
  end
end

`else
`endif


//////////////////////
always@(*) begin
  case({req_bg,req_bk}) // synopsys parallel_case full_case
      4'b0000 : bank_access = 16'b0000000000000001;
      4'b0001 : bank_access = 16'b0000000000000010;
      4'b0010 : bank_access = 16'b0000000000000100;
      4'b0011 : bank_access = 16'b0000000000001000;
      4'b0100 : bank_access = 16'b0000000000010000;
      4'b0101 : bank_access = 16'b0000000000100000;
      4'b0110 : bank_access = 16'b0000000001000000;
      4'b0111 : bank_access = 16'b0000000010000000;
      4'b1000 : bank_access = 16'b0000000100000000;
      4'b1001 : bank_access = 16'b0000001000000000;
      4'b1010 : bank_access = 16'b0000010000000000;
      4'b1011 : bank_access = 16'b0000100000000000;
      4'b1100 : bank_access = 16'b0001000000000000;
      4'b1101 : bank_access = 16'b0010000000000000;
      4'b1110 : bank_access = 16'b0100000000000000;
      4'b1111 : bank_access = 16'b1000000000000000;
  endcase
end

generate 
  for(i = 0; i < BANK_NUM; i = i + 1) begin: BANK_ACCESS
    assign wr_cmd[i] = (bank_access[i]) ? req_wr : 1'b0;
    assign rd_cmd[i] = (bank_access[i]) ? req_rd : 1'b0; 
  end
endgenerate

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire [255:0] PIM_result_per_bank[BANK_NUM-1:0];
reg  [255:0] PIM_result_to_DRAM;

`ifdef SYN_FAST_NOT_COMPUTE
    always@(*) begin
  PIM_result_to_DRAM = 0;
    end
`else
    `ifdef BANK0_ONLY
    always@(*) begin
        case({req_bg,req_bk}) // synopsys parallel_case full_case
          4'b0000 : PIM_result_to_DRAM = PIM_result_per_bank[0];
          4'b0001 : PIM_result_to_DRAM = 'b0;
          4'b0010 : PIM_result_to_DRAM = 'b0;
          4'b0011 : PIM_result_to_DRAM = 'b0;
          4'b0100 : PIM_result_to_DRAM = 'b0;
          4'b0101 : PIM_result_to_DRAM = 'b0;
          4'b0110 : PIM_result_to_DRAM = 'b0;
          4'b0111 : PIM_result_to_DRAM = 'b0;
          4'b1000 : PIM_result_to_DRAM = 'b0;
          4'b1001 : PIM_result_to_DRAM = 'b0;
          4'b1010 : PIM_result_to_DRAM = 'b0;
          4'b1011 : PIM_result_to_DRAM = 'b0;
          4'b1100 : PIM_result_to_DRAM = 'b0;
          4'b1101 : PIM_result_to_DRAM = 'b0;
          4'b1110 : PIM_result_to_DRAM = 'b0;
          4'b1111 : PIM_result_to_DRAM = 'b0;
      endcase
    end
    `else 
    always@(*) begin
        case({req_bg,req_bk}) // synopsys parallel_case full_case
          4'b0000 : PIM_result_to_DRAM = PIM_result_per_bank[0];
          4'b0001 : PIM_result_to_DRAM = PIM_result_per_bank[1];
          4'b0010 : PIM_result_to_DRAM = PIM_result_per_bank[2];
          4'b0011 : PIM_result_to_DRAM = PIM_result_per_bank[3];
          4'b0100 : PIM_result_to_DRAM = PIM_result_per_bank[4];
          4'b0101 : PIM_result_to_DRAM = PIM_result_per_bank[5];
          4'b0110 : PIM_result_to_DRAM = PIM_result_per_bank[6];
          4'b0111 : PIM_result_to_DRAM = PIM_result_per_bank[7];
          4'b1000 : PIM_result_to_DRAM = PIM_result_per_bank[8];
          4'b1001 : PIM_result_to_DRAM = PIM_result_per_bank[9];
          4'b1010 : PIM_result_to_DRAM = PIM_result_per_bank[10];
          4'b1011 : PIM_result_to_DRAM = PIM_result_per_bank[11];
          4'b1100 : PIM_result_to_DRAM = PIM_result_per_bank[12];
          4'b1101 : PIM_result_to_DRAM = PIM_result_per_bank[13];
          4'b1110 : PIM_result_to_DRAM = PIM_result_per_bank[14];
          4'b1111 : PIM_result_to_DRAM = PIM_result_per_bank[15];
      endcase
    end
    `endif
`endif

//////////////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////
//SRC/DST address PASS
////////////////////////////////////////////////////////////////////////////////////////////////////////

wire [BANK_NUM-1:0] src_A_RD_pass;
wire [BANK_NUM-1:0] src_B_RD_pass;
wire [BANK_NUM-1:0] dst_C_WR_pass;

generate 
  for(i = 0; i < BANK_NUM; i = i + 1) begin: GEN_PASS
    assign src_A_RD_pass[i] = req_srcA_pass && rd_cmd[i];
    assign src_B_RD_pass[i] = req_srcB_pass && rd_cmd[i];
    assign dst_C_WR_pass[i] = req_dstC_pass && wr_cmd[i];
  end
endgenerate

//vecRD broadcast logic

wire srcA_RD_pass_en;
wire srcB_RD_pass_en;

assign srcA_RD_pass_en = |src_A_RD_pass;
assign srcB_RD_pass_en = |src_B_RD_pass;

wire [BANK_NUM-1:0] src_A_RD_pass_mux;
wire [BANK_NUM-1:0] src_B_RD_pass_mux;

assign src_A_RD_pass_mux = (is_vecA_rd_broadcast && srcA_RD_pass_en) ? 16'hffff : src_A_RD_pass;
assign src_B_RD_pass_mux = (is_vecB_rd_broadcast && srcB_RD_pass_en) ? 16'hffff : src_B_RD_pass;

wire is_PIM_result = |dst_C_WR_pass;


`ifdef SYN_FAST_NOT_COMPUTE
`else 
    `ifdef BANK0_ONLY
        //BANK0 only
        bank_top U0_BANK_TOP(
          .clk                            (clk                        ),
          .rst_x                          (rst_x                      ),
    
          .HPC_clear_sig                  (HPC_clear_sig              ),

          //.req_row                        (req_row                    ),
          //.req_col                        (req_col                    ),
          //.req_data                       (req_data                   ),
    
          .DRAM_data                      (DRAM_data                  ),
    
          .src_A_RD_pass                  (src_A_RD_pass_mux[0]       ),
          .src_B_RD_pass                  (src_B_RD_pass_mux[0]       ),
          .dst_C_WR_pass                  (dst_C_WR_pass[0]           ),
    
          //.req_MM_vecA_write              (req_MM_vecA_write_per_bank[0] ),
    
          .bank_config_reg                (bank_config_reg            ),
          .PIM_result                     (PIM_result_per_bank[0]     )
        );
    `else
        generate 
          for(i = 0; i < BANK_NUM; i = i + 1) begin: BANK
            bank_top U0_BANK_TOP(
              .clk                            (clk                        ),
              .rst_x                          (rst_x                      ),
    
              .HPC_clear_sig                  (HPC_clear_sig              ),

              //.req_row                        (req_row                    ),
              //.req_col                        (req_col                    ),
              //.req_data                       (req_data                   ),
    
              .DRAM_data                      (DRAM_data                  ),
    
              .src_A_RD_pass                  (src_A_RD_pass_mux[i]       ),
              .src_B_RD_pass                  (src_B_RD_pass_mux[i]       ),
              .dst_C_WR_pass                  (dst_C_WR_pass[i]           ),
    
              //.req_MM_vecA_write              (req_MM_vecA_write_per_bank[i] ),

              .bank_config_reg                (bank_config_reg            ),
              .PIM_result                     (PIM_result_per_bank[i]     )
            );
          end
        endgenerate
    `endif
`endif

endmodule

module bank_top(
  clk,
  rst_x,
  HPC_clear_sig,
  //req_row,
  //req_col,
  //req_data,
  DRAM_data,

  src_A_RD_pass,
  src_B_RD_pass,
  dst_C_WR_pass,

  //req_MM_vecA_write,

  bank_config_reg,

  PIM_result
);

input                           clk;
input                           rst_x;
input                           HPC_clear_sig;
//input  [1:0]                    req_row;
//input  [3:0]                    req_col;
//input  [255:0]                  req_data;
input  [255:0]                  DRAM_data;

input                           src_A_RD_pass;
input                           src_B_RD_pass;
input                           dst_C_WR_pass;

//input                           req_MM_vecA_write;

input [27:0]                    bank_config_reg;

output [255:0]                  PIM_result;

genvar i,j;

///DECODING///////////////////////////////////////////////////////////////////////////////////////////////////////////////


//pipe 0
wire is_CLR_vecA_config          = HPC_clear_sig;
wire is_CLR_vecB_config          = HPC_clear_sig;
wire is_CLR_ACC_config           = HPC_clear_sig;
wire is_CLR_CTRL_reg_config      = HPC_clear_sig;

//pipe 1
wire is_DUP_config               = bank_config_reg[4];
reg  is_DUP_config_r;
always @(posedge clk or negedge rst_x) begin
    if(!rst_x)      is_DUP_config_r <= 'b0;
    else            is_DUP_config_r <= is_DUP_config;
end
//pipe 2
wire is_ADD_config               = bank_config_reg[5];
wire is_SUB_config               = bank_config_reg[6];
wire is_MUL_config               = bank_config_reg[7];
wire is_MAC_config               = bank_config_reg[8];
wire is_vecA_start_config        = bank_config_reg[9];
wire is_vecB_start_config        = bank_config_reg[10];

reg is_ADD_config_r;
reg is_SUB_config_r;
reg is_MUL_config_r;
reg is_MAC_config_r;
reg is_vecA_start_config_r;
reg is_vecB_start_config_r;

reg is_ADD_config_rr;
reg is_SUB_config_rr;
reg is_MUL_config_rr;
reg is_MAC_config_rr;
reg is_vecA_start_config_rr;
reg is_vecB_start_config_rr;

always @(posedge clk or negedge rst_x) begin
    if(!rst_x) begin
                        is_ADD_config_r         <= 'b0;
                        is_SUB_config_r         <= 'b0;
                        is_MUL_config_r         <= 'b0;
                        is_MAC_config_r         <= 'b0;
                        is_vecA_start_config_r  <= 'b0;
                        is_vecB_start_config_r  <= 'b0;
    end
    else begin
                        is_ADD_config_r         <= is_ADD_config;
                        is_SUB_config_r         <= is_SUB_config;
                        is_MUL_config_r         <= is_MUL_config;
                        is_MAC_config_r         <= is_MAC_config;
                        is_vecA_start_config_r  <= is_vecA_start_config;
                        is_vecB_start_config_r  <= is_vecB_start_config;
    end
end

always @(posedge clk or negedge rst_x) begin
    if(!rst_x) begin
                        is_ADD_config_rr         <= 'b0;
                        is_SUB_config_rr         <= 'b0;
                        is_MUL_config_rr         <= 'b0;
                        is_MAC_config_rr         <= 'b0;
                        is_vecA_start_config_rr  <= 'b0;
                        is_vecB_start_config_rr  <= 'b0;
    end
    else begin
                        is_ADD_config_rr         <= is_ADD_config_r;
                        is_SUB_config_rr         <= is_SUB_config_r;
                        is_MUL_config_rr         <= is_MUL_config_r;
                        is_MAC_config_rr         <= is_MAC_config_r;
                        is_vecA_start_config_rr  <= is_vecA_start_config_r;
                        is_vecB_start_config_rr  <= is_vecB_start_config_r;
    end
end

wire is_CLR_vecA                 = is_CLR_vecA_config;
wire is_CLR_vecB                 = is_CLR_vecB_config;
wire is_CLR_ACC                  = is_CLR_ACC_config;
wire is_CLR_CTRL_reg             = is_CLR_CTRL_reg_config;
wire is_DUP                      = is_DUP_config_r;
wire is_ADD                      = is_ADD_config_rr;
wire is_SUB                      = is_SUB_config_rr;
wire is_MUL                      = is_MUL_config_rr;
wire is_MAC                      = is_MAC_config_rr;
wire is_vecA_start               = is_vecA_start_config_rr;
wire is_vecB_start               = is_vecB_start_config_rr;

wire req_AIM_RD;
wire req_AIM_WR;

assign req_AIM_RD = (src_A_RD_pass || src_B_RD_pass); // && is_AIM_enable;//&& rd_cmd && is_AIM_enable;
assign req_AIM_WR = (dst_C_WR_pass                 ); // && is_AIM_enable;//&& wr_cmd && is_AIM_enable;

reg req_AIM_RD_r;
reg req_AIM_WR_r;
reg src_A_RD_pass_r;
reg src_B_RD_pass_r;

always @(posedge clk or negedge rst_x) begin
  if(!rst_x) begin
                                                req_AIM_RD_r        <= 'b0;
                                                req_AIM_WR_r        <= 'b0;
                                                src_A_RD_pass_r     <= 'b0;
                                                src_B_RD_pass_r     <= 'b0;
  end
  else begin
                                                req_AIM_RD_r        <= req_AIM_RD;
                                                req_AIM_WR_r        <= req_AIM_WR;
                                                src_A_RD_pass_r     <= src_A_RD_pass;
                                                src_B_RD_pass_r     <= src_B_RD_pass;
  end
end

/////////////////////////////////////////////////////////////

//RF control signal
wire      PIM_RD_A_sig = (req_AIM_RD_r && src_A_RD_pass_r);
wire      PIM_RD_B_sig = req_AIM_RD_r && src_B_RD_pass_r;
wire      PIM_WR_C_sig = req_AIM_WR;

reg [3:0] global_burst_cnt_SCAL_gran;
reg       PIM_vecA_read_burst;
reg       PIM_vecB_read_burst;
reg       PIM_write_burst;
wire      PIM_result_WB_done;

always @(posedge clk or negedge rst_x) begin
    if (~rst_x)                                     PIM_vecA_read_burst <= 1'b0;
    //else if(PIM_RD_A_sig)                           PIM_vecA_read_burst <= 1'b1;
    else if(src_A_RD_pass_r)                        PIM_vecA_read_burst <= 1'b1;
    else if(PIM_vecA_read_burst)                    PIM_vecA_read_burst <= 1'b0;
end
always @(posedge clk or negedge rst_x) begin
    if (~rst_x)                                     PIM_vecB_read_burst <= 1'b0;
    //else if(PIM_RD_B_sig)                           PIM_vecB_read_burst <= 1'b1;
    else if(src_B_RD_pass_r)                        PIM_vecB_read_burst <= 1'b1;
    else if(PIM_vecB_read_burst)                    PIM_vecB_read_burst <= 1'b0;
end
always @(posedge clk or negedge rst_x) begin
    if (~rst_x)                                     PIM_write_burst <= 1'b0;
    //else if(PIM_WR_C_sig)                           PIM_write_burst <= 1'b1;
    else if(dst_C_WR_pass)                          PIM_write_burst <= 1'b1;
    else if(PIM_write_burst)                        PIM_write_burst <= 1'b0;
end

wire PIM_proc = (PIM_vecA_read_burst || PIM_vecB_read_burst || PIM_write_burst);

reg PIM_ALU_proc;

wire case_vecA = 'b0;
wire case_vecB = (is_MAC || is_MUL);
wire case_both = !(case_vecA || case_vecB);

wire [2:0] PIM_ALU_proc_case = {
                                  case_both,
                                  case_vecA,
                                  case_vecB
                               };

always@(*) begin
  case(PIM_ALU_proc_case) // synopsys parallel_case full_case
    3'b001  : PIM_ALU_proc = PIM_vecB_read_burst;
    3'b010  : PIM_ALU_proc = PIM_vecA_read_burst;
    3'b100  : PIM_ALU_proc = PIM_vecA_read_burst || PIM_vecB_read_burst;
  endcase
end

wire global_burst_cnt_SCAL_gran_rst = ((global_burst_cnt_SCAL_gran == 4'b1111) && (global_burst_cnt_SCAL_gran == 2'b11)) || (PIM_result_WB_done || is_CLR_CTRL_reg);

always @(posedge clk or negedge rst_x) begin
    if (~rst_x)                                       global_burst_cnt_SCAL_gran <= 'b0;
    else if(global_burst_cnt_SCAL_gran_rst)           global_burst_cnt_SCAL_gran <= 'b0;
    else if(is_DUP && PIM_vecB_read_burst)            global_burst_cnt_SCAL_gran <= global_burst_cnt_SCAL_gran + 1; 
end

//////////////////////////////////////////////////////////////////////////////////////////
//pipeline
reg PIM_vecA_read_burst_r;
reg PIM_vecA_read_burst_rr;
reg PIM_vecB_read_burst_r;
reg PIM_vecB_read_burst_rr;
reg PIM_vecB_read_burst_rrr;

reg PIM_ALU_proc_r;
reg PIM_ALU_proc_rr;
reg PIM_ALU_proc_rrr;
reg PIM_ALU_proc_rrrr;
reg PIM_ALU_proc_rrrrr;

(* keep = "true", mark_debug = "true" *)  reg [3:0] global_burst_cnt_SCAL_gran_r;
reg [3:0] global_burst_cnt_SCAL_gran_rr;
reg [3:0] global_burst_cnt_SCAL_gran_rrr;
reg [3:0] global_burst_cnt_SCAL_gran_rrrr;

reg       global_burst_cnt_SCAL_gran_rst_r;

always @(posedge clk or negedge rst_x) begin
    if (~rst_x) begin

                                                  PIM_vecA_read_burst_r           <= 1'b0;
                                                  PIM_vecA_read_burst_rr          <= 1'b0;
                                                  PIM_vecB_read_burst_r           <= 1'b0;
                                                  PIM_vecB_read_burst_rr          <= 1'b0;
                                                  PIM_vecB_read_burst_rrr         <= 1'b0;

                                                  PIM_ALU_proc_r                  <= 1'b0;
                                                  PIM_ALU_proc_rr                 <= 1'b0;
                                                  PIM_ALU_proc_rrr                <= 1'b0;
                                                  PIM_ALU_proc_rrrr               <= 1'b0;
                                                  PIM_ALU_proc_rrrrr              <= 1'b0;

                                                  global_burst_cnt_SCAL_gran_r    <= 'b0;
                                                  global_burst_cnt_SCAL_gran_rr   <= 'b0;
                                                  global_burst_cnt_SCAL_gran_rrr  <= 'b0;
                                                  global_burst_cnt_SCAL_gran_rrrr <= 'b0;

                                                  global_burst_cnt_SCAL_gran_rst_r<= 'b0;
    end
    else begin
                                                  PIM_vecA_read_burst_r           <= PIM_vecA_read_burst;
                                                  PIM_vecA_read_burst_rr          <= PIM_vecA_read_burst_r;
                                                  PIM_vecB_read_burst_r           <= PIM_vecB_read_burst;
                                                  PIM_vecB_read_burst_rr          <= PIM_vecB_read_burst_r;
                                                  PIM_vecB_read_burst_rrr         <= PIM_vecB_read_burst_rr;

                                                  PIM_ALU_proc_r                  <= PIM_ALU_proc;
                                                  PIM_ALU_proc_rr                 <= PIM_ALU_proc_r;
                                                  PIM_ALU_proc_rrr                <= PIM_ALU_proc_rr;
                                                  PIM_ALU_proc_rrrr               <= PIM_ALU_proc_rrr;
                                                  PIM_ALU_proc_rrrrr              <= PIM_ALU_proc_rrrr;

                                                  global_burst_cnt_SCAL_gran_r    <= global_burst_cnt_SCAL_gran;
                                                  global_burst_cnt_SCAL_gran_rr   <= global_burst_cnt_SCAL_gran_r;
                                                  global_burst_cnt_SCAL_gran_rrr  <= global_burst_cnt_SCAL_gran_rr;
                                                  global_burst_cnt_SCAL_gran_rrrr <= global_burst_cnt_SCAL_gran_rrr;

                                                  global_burst_cnt_SCAL_gran_rst_r<= global_burst_cnt_SCAL_gran_rst;

    end
end

wire EX1_burst = PIM_ALU_proc_rrr;
wire WB_burst  = PIM_ALU_proc_rrrr;

wire FE_vecB_burst_delay = PIM_vecB_read_burst_r;

assign PIM_result_WB_done = PIM_write_burst;

/////////////////////////////////////////////////////////////

//Data from Bank
wire [255:0] data_burst;

assign data_burst = DRAM_data;

reg [255:0] data_burst_r;
reg [255:0] data_burst_rr;

always @(posedge clk or negedge rst_x) begin
  if (~rst_x) begin
                                                data_burst_r <= 'b0;
  end
  else if(src_A_RD_pass || src_B_RD_pass) begin
                                                data_burst_r <= data_burst;
  end
end

always @(posedge clk or negedge rst_x) begin
  if (~rst_x) begin
                                                data_burst_rr <= 'b0;
  end
  else begin
                                                data_burst_rr <= data_burst_r;
  end
end

////req_MM_vecA_write timing
//reg [255:0] req_data_r;
//
//always @(posedge clk or negedge rst_x) begin
//    if (~rst_x)                                 req_data_r <= 'b0;
//    else                                        req_data_r <= req_data;
//end
////////////////////Register file data path/////////////////

//vecA 32-byte (256-bit)
//vecB 32-byte (256-bit)
//vACC 44-byte (352-bit)

reg [(16*16-1):0]  vecA;
reg [(16*16-1):0]  vecB;

reg [21:0] vACC[0:15];
reg [21:0] vACC_in[0:15];

wire [15:0]  alu_result_sign;
wire [4:0]   alu_result_exp[0:15];
wire [15:0]  alu_result_mant[0:15];

reg  [21:0]  norm_in[0:15];
wire [15:0]  norm_result[0:15];
wire [255:0] norm_result_vec;

////VEC A LOAD////////////////////////////////////
reg [(16*16-1):0] vecA_in;

//wire memory_mapped_vecA = req_MM_vecA_write;

wire vecA_clr   = is_CLR_vecA;
wire vecA_load  = PIM_vecA_read_burst;
//wire vecA_keep = !(memory_mapped_vecA || vecA_clr || vecA_load);
wire vecA_keep = !(vecA_clr || vecA_load);

//wire [3:0] vecA_load_case;
//assign vecA_load_case = {vecA_keep,memory_mapped_vecA,vecA_load,vecA_clr};
wire [2:0] vecA_load_case;
assign vecA_load_case = {vecA_keep,vecA_load,vecA_clr};

always @(*) begin
  casez(vecA_load_case) // synopsys full_case parallel_case
      3'b??1 : vecA_in = 256'b0;
      3'b?1? : vecA_in = data_burst_rr;
      3'b1?? : vecA_in = vecA;
  endcase
end
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

always @(posedge clk or negedge rst_x) begin
  if (~rst_x) begin
                                                    vecA <= 256'b0;
  end
  else begin
                                                    vecA <= vecA_in;
  end
end

////VEC B LOAD/////////////////////////////////////////////////////////////////////////////////////////
reg [255:0] vecB_in;

wire vecB_clr    = is_CLR_vecB || PIM_result_WB_done;
wire vecB_keep   = !(vecB_clr || PIM_vecB_read_burst);

wire [2:0] vecB_load_case;
assign vecB_load_case = {vecB_keep,PIM_vecB_read_burst,vecB_clr};

always @(*) begin
  casez(vecB_load_case) // synopsys parallel_case full_case
    3'b??1 : vecB_in = 256'b0;
    3'b?1? : vecB_in = data_burst_rr;
    3'b1?? : vecB_in = vecB;
  endcase
end

always @(posedge clk or negedge rst_x) begin
  if (~rst_x)                                       vecB <= 256'b0;
  else                                              vecB <= vecB_in;
end
////////////////////////////////////////////////////////////////////////////////////////////////////////////

////VEC A Layout////////////////////////////////////
wire [15:0] vA_s[0:15];

generate
  for(i=0;i<16;i=i+1) begin : DUP_SCAL
    assign vA_s[i] = vecA[16*(i+1)-1:16*i];
  end
endgenerate

wire [3:0] vecA_dup_cnt = global_burst_cnt_SCAL_gran_r;

wire [255:0] vecA_temp;
reg  [255:0] srcA_temp;

always @(*) begin
  case(vecA_dup_cnt) // synopsys parallel_case full_case
    4'b0000 : srcA_temp = {16{vA_s[ 0]}};
    4'b0001 : srcA_temp = {16{vA_s[ 1]}};
    4'b0010 : srcA_temp = {16{vA_s[ 2]}};
    4'b0011 : srcA_temp = {16{vA_s[ 3]}};
    4'b0100 : srcA_temp = {16{vA_s[ 4]}};
    4'b0101 : srcA_temp = {16{vA_s[ 5]}};
    4'b0110 : srcA_temp = {16{vA_s[ 6]}};
    4'b0111 : srcA_temp = {16{vA_s[ 7]}};
    4'b1000 : srcA_temp = {16{vA_s[ 8]}};
    4'b1001 : srcA_temp = {16{vA_s[ 9]}};
    4'b1010 : srcA_temp = {16{vA_s[10]}};
    4'b1011 : srcA_temp = {16{vA_s[11]}};
    4'b1100 : srcA_temp = {16{vA_s[12]}};
    4'b1101 : srcA_temp = {16{vA_s[13]}};
    4'b1110 : srcA_temp = {16{vA_s[14]}};
    4'b1111 : srcA_temp = {16{vA_s[15]}};
  endcase
end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

wire [255:0] srcA_input;
assign srcA_input = srcA_temp;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

wire [255:0] vecA_burst;

assign vecA_burst = vecA;
assign vecA_temp = (is_DUP) ? srcA_input : vecA_burst;

////VEC B Layout////////////////////////////////////
wire [255:0] vecB_temp;

assign vecB_temp = FE_vecB_burst_delay ? vecB : 256'b0;

////////////////////////////////////////////////////

////vACC LOAD//////////////////////////////////////
wire vACC_burst = EX1_burst;
wire [2:0] acc_case[0:15];
wire acc_rst = is_CLR_ACC || PIM_result_WB_done;
wire acc_result_en = EX1_burst;
wire [15:0] acc_keep;

generate
  for(i=0;i<16;i=i+1) begin : ACC_CTRL
    assign acc_keep[i] = !(acc_result_en || acc_rst);
  end
endgenerate

//////////////////////////////////////////////////////////////////////////////////////////////////////
generate
  for(i=0;i<16;i=i+1) begin : ACC_CASE

    assign acc_case[i] = {acc_keep[i], acc_result_en, acc_rst};

    always@(*) begin
      casez(acc_case[i]) // synopsys full_case parallel_case
        3'b??1 : vACC_in[i] = 22'b0;
        3'b?1? : vACC_in[i] = {alu_result_sign[i],alu_result_exp[i],alu_result_mant[i]};
        3'b1?? : vACC_in[i] = vACC[i];
      endcase
    end
  end
endgenerate

generate
  for(i=0;i<16;i=i+1) begin : ACC_GEN

    always @(posedge clk or negedge rst_x) begin
      if (~rst_x) begin
                                                      vACC[i] <= 22'b0;
      end
      else begin
                                                      vACC[i] <= vACC_in[i];
      end
    end

    //Normalized!!!
    NORM_stage_DEBUG NORM_LOGIC(
        .in_sign              (vACC[i][21]),
        .in_exp               (vACC[i][20:16]),
        .in_mant              (vACC[i][15:0]),
        .out                  (norm_result[i])
    );

  end
endgenerate

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
(* keep = "true", mark_debug = "true" *) reg [255:0] PIM_result;

assign norm_result_vec = {
                            norm_result[15],
                            norm_result[14],
                            norm_result[13],
                            norm_result[12],
                            norm_result[11],
                            norm_result[10],
                            norm_result[9 ],
                            norm_result[8 ],
                            norm_result[7 ],
                            norm_result[6 ],
                            norm_result[5 ],
                            norm_result[4 ],
                            norm_result[3 ],
                            norm_result[2 ],
                            norm_result[1 ],
                            norm_result[0 ]
                          };

always @(posedge clk or negedge rst_x) begin
  if (~rst_x) begin
                                                    PIM_result <= 'b0;
  end
  else if(PIM_result_WB_done) begin
                                                    PIM_result <= 'b0;
  end
  else begin
    if(WB_burst) begin
                                                    PIM_result <= norm_result_vec;
    end
  end
end

////////////////////////////////Bfloat16 ALU ///////////////////////////////////////////

wire [15:0] alu_src0[0:15];
wire [15:0] alu_src1[0:15];

reg [15:0] alu_src0_r[0:15];
reg [15:0] alu_src1_r[0:15];

////////////////////////////////////////////////////////////////////////////////////

generate
  for(i=0;i<16;i=i+1) begin : DELAY_SRC_REG
    always @(posedge clk or negedge rst_x) begin
      if (~rst_x) begin
                          alu_src0_r[i]     <= 'b0;
                          alu_src1_r[i]     <= 'b0;
      end
      else begin
                          alu_src0_r[i]     <= alu_src0[i];
                          alu_src1_r[i]     <= alu_src1[i];
      end
    end
  end
endgenerate

////////////////////////////////////////////////////////////////////////////////////

generate
  for(i=0;i<16;i=i+1) begin : BFLOAT16_ALU

    assign alu_src0[i] = vecA_temp[16*(i+1)-1:16*i];
    assign alu_src1[i] = vecB_temp[16*(i+1)-1:16*i];

    bfloat_MAC_pipe_OPT BFLOAT_ALU(

        .clk                        (clk),
        .rst_x                      (rst_x),

        .is_MAC                     (is_MAC),
        .is_MUL                     (is_MUL),
        .is_ADD                     (is_ADD),
        .is_SUB                     (is_SUB),

        .is_vecA_start              (is_vecA_start),
        .is_vecB_start              (is_vecB_start),

        .vACC_in                    (vACC[i]),

        .PIM_vecA_read_burst_r      (PIM_vecA_read_burst_rr),
        .PIM_vecB_read_burst_r      (PIM_vecB_read_burst_rr),

        .alu_src0                   (alu_src0_r[i]),
        .alu_src1                   (alu_src1_r[i]),

        .result_sign                (alu_result_sign[i]),
        .result_exp                 (alu_result_exp[i]),
        .result_mant                (alu_result_mant[i])
    );
  end
endgenerate

////////////////////////////////////////////////////////////////////////////////////
endmodule

module bfloat_MAC_pipe_OPT(
    clk,
    rst_x,

    is_MAC,
    is_MUL,
    is_ADD,
    is_SUB,

    is_vecA_start,
    is_vecB_start,    

    vACC_in,

    PIM_vecA_read_burst_r,
    PIM_vecB_read_burst_r,

    alu_src0,
    alu_src1,

    result_sign,
    result_exp,
    result_mant
);

input               clk;
input               rst_x;

input               is_MAC;
input               is_MUL;
input               is_ADD;
input               is_SUB;

input               is_vecA_start;
input               is_vecB_start;

input  [21:0]       vACC_in;

input               PIM_vecA_read_burst_r;
input               PIM_vecB_read_burst_r;

input  [15:0]       alu_src0;
input  [15:0]       alu_src1;

output              result_sign;
output [4:0]        result_exp;
output [15:0]       result_mant;

wire                result_sign;
wire [4:0]          result_exp;
wire [15:0]         result_mant;

//////////////////////////////////////////////////////////////////////////////
//vACC////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////

wire        vACC_sign = vACC_in[21];  //input sign need
wire [4:0]  vACC_exp  = vACC_in[20:16];
wire [15:0] vACC_mant = vACC_in[15:0] ;

//////////////////////////////////////////////////////////////////////////////
//PIPE STAGE1/////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////

//MUL0
wire        MUL0_out_sign_temp;
reg         MUL0_out_sign;
wire [4:0]  MUL0_out_exp;
wire [11:0] MUL0_out_mant;

wire [2:0] exp_control;

//////////////////////////////////////////////////////////////////////////////
//PIPE STAGE2/////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////

//ADD0
reg         ADD0_in_sign;
reg [4:0]   ADD0_in_exp;
reg [11:0]  ADD0_in_mant;

//////////////////////////////////////////////////////////////////////
//PIPE STAGE1/////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

MUL_OPT U_MUL0(
    //input
    .in_A                   (alu_src0),
    .in_B                   (alu_src1),

    .is_ADD                 (is_ADD),
    .is_SUB                 (is_SUB),

    .PIM_vecA_read_burst_r  (PIM_vecA_read_burst_r),
    .PIM_vecB_read_burst_r  (PIM_vecB_read_burst_r),

    //output
    .out_mul_sign           (MUL0_out_sign_temp),
    .out_mul_exp            (MUL0_out_exp),
    .out_mul_mant           (MUL0_out_mant),
    .exp_control            (exp_control)

);

wire mul_result_zero = (MUL0_out_exp == 5'b0) ? 1'b1 : 1'b0;

always@(*) begin
  if(mul_result_zero)                                      MUL0_out_sign = 1'b0;
  else if(is_SUB) begin
    if((is_vecA_start && PIM_vecA_read_burst_r) ||
       (is_vecB_start && PIM_vecB_read_burst_r))           MUL0_out_sign = MUL0_out_sign_temp ^ is_SUB;
    else                                                   MUL0_out_sign = MUL0_out_sign_temp;
  end
  else                                                     MUL0_out_sign = MUL0_out_sign_temp;
end

always@(posedge clk or negedge rst_x) begin
  if(~rst_x) begin
                                                          ADD0_in_sign          <= 'b0;
                                                          ADD0_in_exp           <= 'b0;
                                                          ADD0_in_mant          <= 'b0;
                                                        
  end
  else begin
                                                          ADD0_in_sign          <= MUL0_out_sign;
                                                          ADD0_in_exp           <= MUL0_out_exp;
                                                          ADD0_in_mant          <= MUL0_out_mant;
  end
end

reg [2:0] exp_control_r;
always@(posedge clk or negedge rst_x) begin
  if(~rst_x) exp_control_r <= 'b0;  
  else       exp_control_r <= exp_control;
end

//////////////////////////////////////////////////////////////////////
//PIPE STAGE2/////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

  ADD_module_OPT U0_ADD_STAGE(
    .in_sign                  (ADD0_in_sign),
    .in_exp                   (ADD0_in_exp),
    .in_mant                  (ADD0_in_mant),

    .in_acc_sign              (vACC_sign),
    .in_acc_exp               (vACC_exp),
    .in_acc_mant              (vACC_mant),

    .result_sign              (result_sign),
    .result_exp               (result_exp),
    .result_mant              (result_mant),

    .exp_control              (exp_control_r)
);

endmodule

module MUL_OPT(
    in_A,
    in_B,

    is_ADD,
    is_SUB,

    PIM_vecA_read_burst_r,
    PIM_vecB_read_burst_r,

    out_mul_sign,
    out_mul_exp,
    out_mul_mant,
    exp_control    
);

input [15:0]        in_A;
input [15:0]        in_B;

input               is_ADD;
input               is_SUB;

input               PIM_vecA_read_burst_r;
input               PIM_vecB_read_burst_r;

output              out_mul_sign;
output [4:0]        out_mul_exp;
output [11:0]       out_mul_mant;
output [2:0]        exp_control;

reg       in_A_sign;
reg [7:0] in_A_exp;
reg [7:0] in_A_mant;

reg       in_B_sign;
reg [7:0] in_B_exp;
reg [7:0] in_B_mant;

always@(*) begin
  if((is_ADD||is_SUB) && PIM_vecB_read_burst_r) begin
                                                            in_A_sign = 1'b0;
                                                            in_A_exp  = 8'b01111111;
                                                            in_A_mant = 8'b10000000;
  end
  else begin
                                                            in_A_sign = in_A[15]         ;
                                                            in_A_exp  = in_A[14:7]       ;
                                                            in_A_mant = {1'b1, in_A[6:0]};
  end
end

always@(*) begin
  if((is_ADD||is_SUB) && PIM_vecA_read_burst_r) begin
                                                            in_B_sign = 1'b0;
                                                            in_B_exp  = 8'b01111111;
                                                            in_B_mant = 8'b10000000;
  end
  else begin
                                                            in_B_sign = in_B[15]         ;
                                                            in_B_exp  = in_B[14:7]       ;
                                                            in_B_mant = {1'b1, in_B[6:0]};
  end
end


wire check_zero;
wire [8:0] exp_add_temp;
wire [8:0] exp_bias_sub;

assign check_zero = (in_A_exp == 8'b0 || in_B_exp == 8'b0) || exp_bias_sub[8];

//sign control
wire mul_sign = (check_zero) ? 1'b0 : in_A_sign ^ in_B_sign;

//exponent cal
assign exp_add_temp = in_A_exp + in_B_exp;
assign exp_bias_sub = exp_add_temp - 8'b0111_1111;

wire [7:0]  mul_exp = (check_zero) ? 8'b00000000 : exp_bias_sub[7:0];

//mant cal
wire [11:0] mul_HH = in_A_mant[7:0] * in_B_mant[7:4]; //8x4;
wire [7:0]  mul_HL = in_A_mant[7:4] * in_B_mant[3:0]; //4x4;
wire [11:0] mul_mant = mul_HH + mul_HL;
wire [2:0] exp_control = mul_exp[2:0]; //3-bit
wire [4:0] exp_compare = mul_exp[7:3]; //5-bit

assign out_mul_sign = mul_sign;
assign out_mul_exp  = exp_compare;
assign out_mul_mant = (check_zero) ? 12'b0 : mul_mant;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

endmodule

module ADD_module_OPT(
    in_sign,
    in_exp,
    in_mant,

    in_acc_sign,
    in_acc_exp,
    in_acc_mant,

    result_sign,
    result_exp,
    result_mant,

    exp_control
);

input               in_sign;
input  [4:0]        in_exp;
input  [11:0]       in_mant;

input               in_acc_sign;
input  [4:0]        in_acc_exp;
input  [15:0]       in_acc_mant;

output              result_sign;
output [4:0]        result_exp;
output [15:0]       result_mant;

input [2:0]         exp_control;

//mant align
wire [19:0] mant_align_sft;
wire [15:0] mant_align;

assign mant_align_sft = (in_mant << exp_control);
assign mant_align = mant_align_sft[18:3];

//check exponent diff

//mul_result_exp - acc_exp

wire [5:0] exp_diff = ({1'b0,in_exp} - {1'b0,in_acc_exp});

wire mul_mant_larger_than_acc_mant_2;
wire mul_mant_larger_than_acc_mant_1;
wire mul_mant_same;
wire mul_mant_smaller_than_acc_mant_1;
wire mul_mant_smaller_than_acc_mant_2;

assign mul_mant_larger_than_acc_mant_2  = (in_exp > in_acc_exp) && !mul_mant_larger_than_acc_mant_1;   //case 1 in_coming_exp > acc_exp +  1
assign mul_mant_larger_than_acc_mant_1  = (exp_diff == 6'b000001);                                     //case 2 in_coming_exp - acc_exp =  1
assign mul_mant_same                    = (exp_diff == 6'b000000);                                     //case 3 in_coming_exp - acc_exp =  0
assign mul_mant_smaller_than_acc_mant_1 = (exp_diff == 6'b111111);                                     //case 4 in_coming_exp - acc_exp = -1
assign mul_mant_smaller_than_acc_mant_2 = (in_exp < in_acc_exp) && !mul_mant_smaller_than_acc_mant_1;  //case 5 in_coming_exp < acc_exp -  1

//select large value
wire        large_sign = (mul_mant_larger_than_acc_mant_2||mul_mant_larger_than_acc_mant_1) ? in_sign    : in_acc_sign;
wire [4:0]  large_exp  = (mul_mant_larger_than_acc_mant_2||mul_mant_larger_than_acc_mant_1) ? in_exp     : in_acc_exp;
wire [15:0] large_mant = (mul_mant_larger_than_acc_mant_2||mul_mant_larger_than_acc_mant_1) ? mant_align : in_acc_mant;

wire [15:0] mul_result_aligned_mant;
wire [15:0] acc_result_aligned_mant;

wire mul_result_mant_need_shift;
wire acc_result_mant_need_shift;

assign mul_result_mant_need_shift = mul_mant_smaller_than_acc_mant_1;
assign acc_result_mant_need_shift = mul_mant_larger_than_acc_mant_1;

assign mul_result_aligned_mant = (mul_result_mant_need_shift) ? {8'b00000000, mant_align[15:8]}  : mant_align;
assign acc_result_aligned_mant = (acc_result_mant_need_shift) ? {8'b00000000, in_acc_mant[15:8]} : in_acc_mant;

wire diff_sign = in_sign ^ in_acc_sign;

reg  [16:0] mantissa_ADD_temp;

always@(*) begin
  if(diff_sign) begin
    if(in_sign)              mantissa_ADD_temp = - mul_result_aligned_mant + acc_result_aligned_mant;
    else                     mantissa_ADD_temp =   mul_result_aligned_mant - acc_result_aligned_mant;
  end
  else                       mantissa_ADD_temp =   mul_result_aligned_mant + acc_result_aligned_mant;
end

wire [16:0] mantissa_ADD;

assign mantissa_ADD = (diff_sign && mantissa_ADD_temp[16]) ? -mantissa_ADD_temp : mantissa_ADD_temp;

wire check_result_zero = (mantissa_ADD == 17'b0);

////overflow
wire mant_ovf = (mantissa_ADD[16] && !diff_sign);

wire [4:0] aligned_ovf_exp;
assign aligned_ovf_exp = large_exp + 1'b1;

wire [15:0] aligned_ovf_mant;
assign aligned_ovf_mant = {7'b0, 1'b1, mantissa_ADD[15:8]};

wire        add_result_sign = (diff_sign) ? mantissa_ADD_temp[16]  : in_sign;
wire [4:0]  add_result_exp  = (mant_ovf)  ? aligned_ovf_exp        : large_exp;
wire [15:0] add_result_mant = (mant_ovf)  ? aligned_ovf_mant       : mantissa_ADD[15:0];

reg        MAC_result_sign;
reg  [4:0] MAC_result_exp;
reg [15:0] MAC_result_mant;

always@(*) begin
    if(mul_mant_larger_than_acc_mant_2 || mul_mant_smaller_than_acc_mant_2) begin
                                                                                    MAC_result_sign = large_sign;
                                                                                    MAC_result_exp  = large_exp;
                                                                                    MAC_result_mant = large_mant;
    end
    else begin
                                                                                    MAC_result_sign = add_result_sign;
                                                                                    MAC_result_exp  = add_result_exp;
                                                                                    MAC_result_mant = add_result_mant;
    end
end

assign result_sign = MAC_result_sign;
assign result_exp  = MAC_result_exp;
assign result_mant = MAC_result_mant;

endmodule

////////////////////////////////////////////////////////////////////////////////////////////////////////////
module NORM_stage_DEBUG(
    in_sign,
    in_exp,
    in_mant,
    out
);

input          in_sign;
input  [4:0]   in_exp;
input  [15:0]  in_mant;
output [15:0]  out;

//mantissa
//(9, 7) [9] [8] [7] . [6] [5] 

reg [4:0] out_exp_upper;
reg [2:0] out_exp_reg;
reg [15:0] out_mant_reg;

always@(*) begin
    if(in_mant[15]) begin
                                            out_exp_upper   <= in_exp + 1;
                                            out_exp_reg     <= 3'b000;
                                            out_mant_reg    <= in_mant >> 8;
    end
    else if(in_mant[14]) begin
                                            out_exp_upper   <= in_exp;
                                            out_exp_reg     <= 3'b111;
                                            out_mant_reg    <= in_mant >> 7;
    end
    else if(in_mant[13]) begin
                                            out_exp_upper   <= in_exp;
                                            out_exp_reg     <= 3'b110;
                                            out_mant_reg    <= in_mant >> 6;
    end
    else if (in_mant[12]) begin
                                            out_exp_upper   <= in_exp;
                                            out_exp_reg     <= 3'b101;
                                            out_mant_reg    <= in_mant >> 5;
    end
    else if (in_mant[11]) begin
                                            out_exp_upper   <= in_exp;
                                            out_exp_reg <= 3'b100;
                                            out_mant_reg    <= in_mant >> 4;
    end
    else if (in_mant[10]) begin
                                            out_exp_upper   <= in_exp;
                                            out_exp_reg <= 3'b011;
                                            out_mant_reg    <= in_mant >> 3;
    end
    else if (in_mant[9]) begin
                                            out_exp_upper   <= in_exp;
                                            out_exp_reg     <= 3'b010;
                                            out_mant_reg    <= in_mant >> 2;
    end
    else if (in_mant[8]) begin
                                            out_exp_upper   <= in_exp;
                                            out_exp_reg     <= 3'b001;
                                            out_mant_reg    <= in_mant >> 1;
    end
    else if (in_mant[7]) begin
                                            out_exp_upper   <= in_exp;
                                            out_exp_reg     <= 3'b000;
                                            out_mant_reg    <= in_mant;
    end
    else if (in_mant[6]) begin
                                            out_exp_upper   <= in_exp - 1;   
                                            out_exp_reg     <= 3'b111;
                                            out_mant_reg    <= in_mant << 1;
    end
    else if (in_mant[5]) begin
                                            out_exp_upper   <= in_exp - 1;
                                            out_exp_reg     <= 3'b110;
                                            out_mant_reg    <= in_mant << 2;
    end
    else if (in_mant[4]) begin
                                            out_exp_upper   <= in_exp - 1;
                                            out_exp_reg     <= 3'b101;
                                            out_mant_reg    <= in_mant << 3;
    end
    else if (in_mant[3]) begin
                                            out_exp_upper   <= in_exp - 1;
                                            out_exp_reg     <= 3'b100;
                                            out_mant_reg    <= in_mant << 4;
    end
    else if (in_mant[2]) begin
                                            out_exp_upper   <= in_exp - 1;
                                            out_exp_reg     <= 3'b011;
                                            out_mant_reg    <= in_mant << 5;
    end
    else if (in_mant[1]) begin
                                            out_exp_upper   <= in_exp - 1;
                                            out_exp_reg     <= 3'b010;
                                            out_mant_reg    <= in_mant << 6;
    end      
    else if (in_mant[0]) begin
                                            out_exp_upper   <= in_exp - 1;
                                            out_exp_reg     <= 3'b001;
                                            out_mant_reg    <= in_mant << 7;
    end
    else begin
                                            out_exp_upper   <= in_exp;
                                            out_exp_reg     <= 3'b000;
                                            out_mant_reg    <= 'b0;
    end
end

assign out = {in_sign, out_exp_upper, out_exp_reg, out_mant_reg[6:0]};

endmodule

