import aimc_lib::*;
import axi_lib::*;

module ordr_engine #(
    parameter integer NUM_MAX_RD = 256
)
(
  input  logic                            clk,
  input  logic                            rst,
  // DMA Packet Generator Interface (in)
  output logic                            orde_pgen_rdy,
  input  logic                            pgen_orde_pkt_valid,
  `ifdef XILINX_SIMULATOR
  input  logic                           pgen_orde_pkt_marker,
  input  logic                           pgen_orde_pkt_bcast,
  input  logic [$clog2(PRIO)-1:0]        pgen_orde_pkt_prio,
  input  req_t                           pgen_orde_pkt_req_type,
  input  logic [BK_ADDR_WIDTH-1:0]       pgen_orde_pkt_bk_addr,
  input  logic [ROW_ADDR_WIDTH-1:0]      pgen_orde_pkt_row_addr,
  input  logic [COL_ADDR_WIDTH-1:0]      pgen_orde_pkt_col_addr,
  input  logic [MASK_WIDTH-1:0]          pgen_orde_pkt_mask,
  input  logic [DATA_WIDTH-1:0]          pgen_orde_pkt_data,                   
  `else
  input  pkt_t                            pgen_orde_pkt,
  `endif
  input  [$clog2(CH_NUM)-1:0]             pgen_orde_pkt_ch_addr,
  // DMA Packet Generator Interface (out)
  input  logic                            pgen_orde_rdy,
  output logic                            orde_pgen_pkt_valid,
  `ifdef XILINX_SIMULATOR
  output  logic                           orde_pgen_pkt_marker,
  output  logic                           orde_pgen_pkt_bcast,
  output  logic [$clog2(PRIO)-1:0]        orde_pgen_pkt_prio,
  output  req_t                           orde_pgen_pkt_req_type,
  output  logic [BK_ADDR_WIDTH-1:0]       orde_pgen_pkt_bk_addr,
  output  logic [ROW_ADDR_WIDTH-1:0]      orde_pgen_pkt_row_addr,
  output  logic [COL_ADDR_WIDTH-1:0]      orde_pgen_pkt_col_addr,
  output  logic [MASK_WIDTH-1:0]          orde_pgen_pkt_mask,
  output  logic [DATA_WIDTH-1:0]          orde_pgen_pkt_data,                   
  `else
  output pkt_t                            orde_pgen_pkt,
  `endif
  // DMA Register Interface (in)
  output logic                            orde_dreg_rdy,
  input  logic                            dreg_orde_pkt_valid,
  `ifdef XILINX_SIMULATOR
  input  logic                           dreg_orde_pkt_marker,
  input  logic                           dreg_orde_pkt_bcast,
  input  logic [$clog2(PRIO)-1:0]        dreg_orde_pkt_prio,
  input  req_t                           dreg_orde_pkt_req_type,
  input  logic [BK_ADDR_WIDTH-1:0]       dreg_orde_pkt_bk_addr,
  input  logic [ROW_ADDR_WIDTH-1:0]      dreg_orde_pkt_row_addr,
  input  logic [COL_ADDR_WIDTH-1:0]      dreg_orde_pkt_col_addr,
  input  logic [MASK_WIDTH-1:0]          dreg_orde_pkt_mask,
  input  logic [DATA_WIDTH-1:0]          dreg_orde_pkt_data,                   
  `else
  input  pkt_t                           dreg_orde_pkt,
  `endif
  // AiM Interconnect Interface (in)
  output logic                            orde_icnt_rdy,
  input  logic                            icnt_orde_pkt_valid,
  `ifdef XILINX_SIMULATOR
  input  logic                           icnt_orde_pkt_marker,
  input  logic                           icnt_orde_pkt_bcast,
  input  logic [$clog2(PRIO)-1:0]        icnt_orde_pkt_prio,
  input  req_t                           icnt_orde_pkt_req_type,
  input  logic [BK_ADDR_WIDTH-1:0]       icnt_orde_pkt_bk_addr,
  input  logic [ROW_ADDR_WIDTH-1:0]      icnt_orde_pkt_row_addr,
  input  logic [COL_ADDR_WIDTH-1:0]      icnt_orde_pkt_col_addr,
  input  logic [MASK_WIDTH-1:0]          icnt_orde_pkt_mask,
  input  logic [DATA_WIDTH-1:0]          icnt_orde_pkt_data,                   
  `else
  input  pkt_t                           icnt_orde_pkt,
  `endif  
  input  [$clog2(CH_NUM)-1:0]             icnt_orde_pkt_ch_addr,
  // AXI Bridge Interface (out)
  input  logic                            axbr_orde_rdy,
  output logic                            orde_axbr_pkt_valid,
  `ifdef XILINX_SIMULATOR
  output  logic                           orde_axbr_pkt_is_rd,
  output  [AXI_ADDR_WIDTH-1:0]            orde_axbr_pkt_addr,
  output  [AXI_MASK_WIDTH-1:0]            orde_axbr_pkt_mask,
  output  [AXI_DATA_WIDTH-1:0]            orde_axbr_pkt_data                
  `else
    `ifdef SUPPORT_INDIRECT_ADDRESSING
    input [31:0] i_args_reg_A,
    input [31:0] i_args_reg_B,
    input [31:0] i_args_reg_C,
    input [255:0] i_args_reg_LUT_x[15:0],
    input logic  i_HPC_clear,
    `endif
  output trx_t                            orde_axbr_pkt
  `endif  
);

  localparam NUM_PER_BLOCK = 32;
  localparam NUM_BLOCK = NUM_MAX_RD/NUM_PER_BLOCK;

  // ============================= Internal Signals ==============================

  logic                              inc_cnt;
  logic                              dec_cnt;  
  logic [$clog2(NUM_MAX_RD)-1:0]     oldest_idx,oldest_idx_next;        // pointer for the oldest one on address_mem
  logic [$clog2(NUM_MAX_RD)-1:0]     empty_idx,empty_idx_next;          // pointer for empty slot for address_mem, status_mem, data_mem
  logic [$clog2(NUM_MAX_RD):0]       mem_cnt,mem_cnt_next;
  logic                              orde_int_rdy;                     // orde interal ready singal 
  logic                              orde_buf_int_rdy;
  logic                              pgen_orde_pkt_dram_type_valid,pgen_orde_pkt_reg_type_valid;
  logic                              addr_enque_valid;

  logic                              orde_int_pkt_valid;
  trx_t                              orde_int_pkt;
  pkt_t                              icnt_orde_pkt_r;                           
  logic [$clog2(CH_NUM)-1:0]         icnt_orde_pkt_ch_addr_r;
  logic                              icnt_orde_pkt_valid_r;  
  rd_t                               icnt_orde_pkt_rd_type_r;    
  logic [$clog2(NUM_MAX_RD)-1:0]     pop_idx,pop_idx_next;              // pointer for popped pkt (remove the popped pkt)
  logic                              pop_idx_valid,pop_idx_valid_next;    

  (* RAM_STYLE = "BLOCK" *) logic [$bits(orde_pkt_t)-1:0]          addres_mem [NUM_MAX_RD-1:0];   // memory for address of dma_pkt
  (* RAM_STYLE = "ULTRA" *) logic [DATA_WIDTH-1:0]                 rd_data_mem [NUM_MAX_RD-1:0];  // memory for data of icnt_orde_pkt
  
   orde_pkt_t  address_mem_out;                  // output of address_mem. group of bank, row, and column chanel address. 
 
  // inct_dma_pkt buffer -> orde_sub
  orde_pkt_t                                  pop_icnt_orde_pkt;
  orde_pkt_t                                  pgen_orde_pkt_r;
  logic [DATA_WIDTH-1:0]                      buffer_data_mem_out;

  // sub signals for orde_sub_block
  logic [$clog2(NUM_PER_BLOCK)-1:0]           per_oldest_idx [NUM_BLOCK-1:0];
  logic                                       per_oldest_idx_valid [NUM_BLOCK-1:0];
  logic [$clog2(NUM_PER_BLOCK)-1:0]           per_empty_idx [NUM_BLOCK-1:0];
  logic                                       per_empty_idx_valid [NUM_BLOCK-1:0];
  logic [$clog2(NUM_MAX_RD)-1:0]              per_match_idx [NUM_BLOCK-1:0];
  logic [NUM_BLOCK-1:0]                       per_match_idx_valid;
  logic [NUM_BLOCK-1:0]                       per_match_idx_is_young;  
  logic [$clog2(NUM_MAX_RD)-1:0]              per_matched_idx [NUM_BLOCK-1:0];
  logic                                       per_matched_idx_valid [NUM_BLOCK-1:0]; 
  logic [$clog2(NUM_PER_BLOCK)-1:0]           per_oldest_idx_next [NUM_BLOCK-1:0];
  logic                                       per_oldest_idx_next_valid [NUM_BLOCK-1:0];  
  logic [$clog2(NUM_PER_BLOCK)-1:0]           per_pop_idx [NUM_BLOCK-1:0];
  logic                                       per_pop_idx_valid [NUM_BLOCK-1:0];    
  logic [NUM_BLOCK-1:0]                       per_rd_data_valid;
  
  logic [$clog2(NUM_MAX_RD)-1:0]              matched_idx;
  logic                                       matched_idx_valid;  

  orde_pkt_t                                  per_pop_icnt_orde_pkt [NUM_BLOCK-1:0];
  logic                                       per_pop_icnt_orde_pkt_valid [NUM_BLOCK-1:0];

  // debug

  // reg inc_cnt_debug;
  // reg dec_cnt_debug;
  // reg addr_enque_valid_debug;
  // reg [$clog2(NUM_MAX_RD)-1:0] oldest_idx_debug;
  // reg [$clog2(NUM_MAX_RD)-1:0] empty_idx_debug;
  // reg [$clog2(NUM_MAX_RD):0] mem_cnt_debug;
  // reg [$clog2(NUM_MAX_RD):0] mem_cnt_next_debug;
  // reg orde_int_pkt_valid_debug;
  // reg orde_pgen_pkt_valid_debug;
  // reg orde_dreg_rdy_debug;
  // reg orde_icnt_rdy_debug;
  // reg orde_axbr_pkt_valid_debug;
  // reg [NUM_BLOCK-1:0]                       per_match_idx_valid_debug;
  // reg [NUM_BLOCK-1:0]                       per_match_idx_is_young_debug;
  // reg [NUM_BLOCK-1:0]                       per_rd_data_valid_debug;
  // reg [$clog2(NUM_MAX_RD)-1:0]              matched_idx_debug;
  // reg                                       matched_idx_valid_debug;


  // always @(posedge clk, posedge rst)
  //   if (rst) begin  
  //       oldest_idx_debug <= 'b0;
  //       empty_idx_debug <= 'b0;
  //       mem_cnt_debug <= 'b0;
  //       mem_cnt_next_debug <= 'b0;
  //       orde_int_pkt_valid_debug <= 'b0;
  //       orde_pgen_pkt_valid_debug <= 'b0;
  //       orde_dreg_rdy_debug <= 'b0;
  //       orde_icnt_rdy_debug <= 'b0;
  //       orde_axbr_pkt_valid_debug <= 'b0;

  //       per_match_idx_valid_debug <= 'b0;
  //       per_match_idx_is_young_debug <= 'b0;
  //       per_rd_data_valid_debug <= 'b0;
  //       matched_idx_debug <= 'b0;
  //       matched_idx_valid_debug <= 'b0;

  //       addr_enque_valid_debug <= 'b0;

  //       inc_cnt_debug <= 'b0;
  //       dec_cnt_debug <= 'b0;
  //   end
  //   else begin 
  //       oldest_idx_debug <= oldest_idx;
  //       empty_idx_debug <= empty_idx;
  //       mem_cnt_debug <= mem_cnt;
  //       mem_cnt_next_debug <= mem_cnt_next;
  //       orde_int_pkt_valid_debug <= orde_int_pkt_valid;
  //       orde_pgen_pkt_valid_debug <= orde_pgen_pkt_valid;
  //       orde_dreg_rdy_debug <= orde_dreg_rdy;
  //       orde_icnt_rdy_debug <= orde_icnt_rdy;
  //       orde_axbr_pkt_valid_debug <= orde_axbr_pkt_valid;

  //       per_match_idx_valid_debug <= per_match_idx_valid;
  //       per_match_idx_is_young_debug <= per_match_idx_is_young;
  //       per_rd_data_valid_debug <= per_rd_data_valid;
  //       matched_idx_debug <= matched_idx;
  //       matched_idx_valid_debug <= matched_idx_valid;

  //       addr_enque_valid_debug <= addr_enque_valid;

  //       inc_cnt_debug <= inc_cnt;
  //       dec_cnt_debug <= dec_cnt;
    // end
  
  // =================== Oldest/Empty Entry Pointer ===================
`ifdef XILINX_SIMULATOR
  pkt_t pgen_orde_pkt;
  assign pgen_orde_pkt.marker      = pgen_orde_pkt_marker;
  assign pgen_orde_pkt.bcast     = pgen_orde_pkt_bcast;
  assign pgen_orde_pkt.prio      = pgen_orde_pkt_prio;
  assign pgen_orde_pkt.req_type  = pgen_orde_pkt_req_type;
  assign pgen_orde_pkt.bk_addr   = pgen_orde_pkt_bk_addr;
  assign pgen_orde_pkt.row_addr  = pgen_orde_pkt_row_addr;
  assign pgen_orde_pkt.col_addr  = pgen_orde_pkt_col_addr;
  assign pgen_orde_pkt.mask      = pgen_orde_pkt_mask;
  assign pgen_orde_pkt.data      = pgen_orde_pkt_data;
 
  pkt_t orde_pgen_pkt;
  assign orde_pgen_pkt_marker      = orde_pgen_pkt.marker    ;
  assign orde_pgen_pkt_bcast     = orde_pgen_pkt.bcast   ;
  assign orde_pgen_pkt_prio      = orde_pgen_pkt.prio    ;
  assign orde_pgen_pkt_req_type  = orde_pgen_pkt.req_type;
  assign orde_pgen_pkt_bk_addr   = orde_pgen_pkt.bk_addr ;
  assign orde_pgen_pkt_row_addr  = orde_pgen_pkt.row_addr;
  assign orde_pgen_pkt_col_addr  = orde_pgen_pkt.col_addr;
  assign orde_pgen_pkt_mask      = orde_pgen_pkt.mask    ;
  assign orde_pgen_pkt_data      = orde_pgen_pkt.data    ;

  pkt_t dreg_orde_pkt;
  assign dreg_orde_pkt.marker      = dreg_orde_pkt_marker;
  assign dreg_orde_pkt.bcast     = dreg_orde_pkt_bcast;
  assign dreg_orde_pkt.prio      = dreg_orde_pkt_prio;
  assign dreg_orde_pkt.req_type  = dreg_orde_pkt_req_type;
  assign dreg_orde_pkt.bk_addr   = dreg_orde_pkt_bk_addr;
  assign dreg_orde_pkt.row_addr  = dreg_orde_pkt_row_addr;
  assign dreg_orde_pkt.col_addr  = dreg_orde_pkt_col_addr;
  assign dreg_orde_pkt.mask      = dreg_orde_pkt_mask;
  assign dreg_orde_pkt.data      = dreg_orde_pkt_data;  

  pkt_t icnt_orde_pkt;
  assign icnt_orde_pkt.marker      = icnt_orde_pkt_marker;
  assign icnt_orde_pkt.bcast     = icnt_orde_pkt_bcast;
  assign icnt_orde_pkt.prio      = icnt_orde_pkt_prio;
  assign icnt_orde_pkt.req_type  = icnt_orde_pkt_req_type;
  assign icnt_orde_pkt.bk_addr   = icnt_orde_pkt_bk_addr;
  assign icnt_orde_pkt.row_addr  = icnt_orde_pkt_row_addr;
  assign icnt_orde_pkt.col_addr  = icnt_orde_pkt_col_addr;
  assign icnt_orde_pkt.mask      = icnt_orde_pkt_mask;
  assign icnt_orde_pkt.data      = icnt_orde_pkt_data;  

  trx_t orde_axbr_pkt;
  assign orde_axbr_pkt_is_rd = orde_axbr_pkt.is_rd;
  assign orde_axbr_pkt_addr  = orde_axbr_pkt.addr; 
  assign orde_axbr_pkt_mask  = orde_axbr_pkt.mask;
  assign orde_axbr_pkt_data  = orde_axbr_pkt.data;
  `endif    

  always @(posedge clk, posedge rst)
    if (rst) begin  
      oldest_idx      <= 0;
      empty_idx       <= 0;
      mem_cnt         <= 0;    
      pop_idx         <= 0;
      pop_idx_valid   <= 0;
    end
    else begin 
      oldest_idx      <= oldest_idx_next;
      empty_idx       <= empty_idx_next;
      mem_cnt         <= mem_cnt_next;  
      pop_idx         <= pop_idx_next;
      pop_idx_valid   <= pop_idx_valid_next;
    end

  always_comb begin
    oldest_idx_next     = oldest_idx;
    empty_idx_next      = empty_idx;
    mem_cnt_next        = mem_cnt;
    pop_idx_next        = pop_idx;

    //inc_cnt  = pgen_orde_pkt_valid && (pgen_orde_pkt.req_type == READ) && orde_pgen_rdy;
    //dec_cnt  = orde_axbr_pkt_valid && axbr_orde_rdy && mem_cnt > 0;
    inc_cnt  = addr_enque_valid; 
    dec_cnt  = ((orde_axbr_pkt_valid && axbr_orde_rdy) || (orde_pgen_pkt_valid && pgen_orde_rdy)) && mem_cnt > 0; 

    if(dec_cnt) oldest_idx_next = oldest_idx + 1;
    if(inc_cnt) empty_idx_next = empty_idx + 1;

    if(inc_cnt && !dec_cnt)      mem_cnt_next =  mem_cnt + 1;
    else if(!inc_cnt && dec_cnt) mem_cnt_next =  mem_cnt - 1;

    if(dec_cnt) pop_idx_next = oldest_idx;
    if(dec_cnt) pop_idx_valid_next = 1;
    else        pop_idx_valid_next = 0;
  end

  assign pgen_orde_pkt_dram_type_valid = pgen_orde_pkt.req_type == READ || pgen_orde_pkt.req_type == READ_SBK || pgen_orde_pkt.req_type == READ_MAC || pgen_orde_pkt.req_type == READ_AF;
  assign pgen_orde_pkt_reg_type_valid  = pgen_orde_pkt.req_type == NONE;

// =================== Input/Output Muxing and Ready Signal Control ===================

  assign orde_int_rdy = mem_cnt < (NUM_MAX_RD - 6);
  assign orde_pgen_rdy = orde_int_rdy;     
  assign orde_dreg_rdy = orde_buf_int_rdy && pgen_orde_pkt_reg_type_valid && dreg_orde_pkt_valid;   
  assign orde_icnt_rdy = orde_buf_int_rdy && ~(pgen_orde_pkt_reg_type_valid && dreg_orde_pkt_valid); 

  assign orde_pgen_pkt       = orde_int_pkt;
  assign orde_pgen_pkt_valid = orde_int_pkt_valid && (address_mem_out.rd_type == DRAMSBK_RD || address_mem_out.rd_type == MACREG_RD || address_mem_out.rd_type == AFREG_RD);

  assign orde_axbr_pkt       = orde_int_pkt;
  assign orde_axbr_pkt_valid = orde_int_pkt_valid && (address_mem_out.rd_type == DRAM_RD || address_mem_out.rd_type == DMAREG_RD);

  // =================== Address Memroy ===================

  assign addr_enque_valid =  pgen_orde_pkt_valid && orde_pgen_rdy && ((pgen_orde_pkt_dram_type_valid) || (pgen_orde_pkt_reg_type_valid && dreg_orde_pkt_valid && orde_dreg_rdy));
  always @(posedge clk) begin
    if (addr_enque_valid) begin 
        addres_mem[empty_idx] <= pgen_orde_pkt_r;  
    end
    address_mem_out <= addres_mem[oldest_idx_next];
  end

  always_comb begin
    case(pgen_orde_pkt.req_type) 
      READ     :  pgen_orde_pkt_r.rd_type = DRAM_RD;
      READ_SBK :  pgen_orde_pkt_r.rd_type = DRAMSBK_RD;
      READ_MAC :  pgen_orde_pkt_r.rd_type = MACREG_RD;
      READ_AF  :  pgen_orde_pkt_r.rd_type = AFREG_RD;
      NONE     :  pgen_orde_pkt_r.rd_type = DMAREG_RD;
      default  :  pgen_orde_pkt_r.rd_type = DRAM_RD;
    endcase
  end
  assign pgen_orde_pkt_r.ch_addr  = pgen_orde_pkt_ch_addr;
  assign pgen_orde_pkt_r.bk_addr  = pgen_orde_pkt.bk_addr;
  assign pgen_orde_pkt_r.row_addr = pgen_orde_pkt.row_addr;
  assign pgen_orde_pkt_r.col_addr = pgen_orde_pkt.col_addr;

  // =================== RD Response Packet Buffering ===================
  assign icnt_orde_pkt_r         = pgen_orde_pkt_reg_type_valid && dreg_orde_pkt_valid ? dreg_orde_pkt    : icnt_orde_pkt;
  assign icnt_orde_pkt_ch_addr_r = pgen_orde_pkt_reg_type_valid && dreg_orde_pkt_valid ? 0                : icnt_orde_pkt_ch_addr;
  assign icnt_orde_pkt_valid_r   = pgen_orde_pkt_reg_type_valid && dreg_orde_pkt_valid ? addr_enque_valid : icnt_orde_pkt_valid && (icnt_orde_pkt.req_type == READ || 
                                                                                                                                    icnt_orde_pkt.req_type == READ_MAC || 
                                                                                                                                    icnt_orde_pkt.req_type == READ_SBK ||
                                                                                                                                    icnt_orde_pkt.req_type == READ_AF)
                                                                                                                                    && (mem_cnt > 0);

  always_comb begin
    if(pgen_orde_pkt_reg_type_valid && dreg_orde_pkt_valid) icnt_orde_pkt_rd_type_r = DMAREG_RD;
    else begin 
      case(icnt_orde_pkt.req_type)
      READ     : icnt_orde_pkt_rd_type_r = DRAM_RD;
      READ_SBK : icnt_orde_pkt_rd_type_r = DRAMSBK_RD;
      READ_MAC : icnt_orde_pkt_rd_type_r = MACREG_RD;
      READ_AF  : icnt_orde_pkt_rd_type_r = AFREG_RD;
      default  : icnt_orde_pkt_rd_type_r = DRAM_RD;
      endcase
    end
  end  

  orde_resp_buf #(.NUM_BUFFERING(16)) u_orde_resp_buf (
    .clk, .rst,
    .icnt_orde_pkt_rd_type(icnt_orde_pkt_rd_type_r),
    .icnt_orde_pkt(icnt_orde_pkt_r),
    .icnt_orde_pkt_ch_addr(icnt_orde_pkt_ch_addr_r),
    .icnt_orde_pkt_valid(icnt_orde_pkt_valid_r),  
    .orde_rdy(orde_buf_int_rdy),
    .pop_pkt(pop_icnt_orde_pkt),
    .pop_pkt_valid(pop_icnt_orde_pkt_valid),
    .data_pop(matched_idx_valid),   

    `ifdef SUPPORT_INDIRECT_ADDRESSING
    .i_reg_A_data(i_args_reg_A),
    .i_reg_B_data(i_args_reg_B),
    .i_reg_C_data(i_args_reg_C),
    .i_reg_LUT_data(i_args_reg_LUT_x),
    .i_HPC_clear(i_HPC_clear),
    // .i_orde_axbr_pkt_valid(orde_axbr_pkt_valid),
    `endif
    .buffer_data_mem_out(buffer_data_mem_out));

   // =================== Sub ReOrder Response Unt  ===================

  genvar k;
  generate
    for (k=0; k<NUM_BLOCK; k++) begin

      orde_l1_search #(
          .NUM_PER_BLOCK  (NUM_PER_BLOCK  ),
          .NUM_MAX_RD     (NUM_MAX_RD     ),
          .BLOCK_IDX      (k              )
      ) u_orde_l1_search
      (
      .clk                      (clk                          ),
      .rst                      (rst                          ),
      // AiM DMA -> ORD 
      .dma_pkt                  (pgen_orde_pkt_r                   ),
      .dma_pkt_valid            (addr_enque_valid             ),
      // ICNT -> ORD
      .icnt_orde_pkt             (per_pop_icnt_orde_pkt[k]      ),
      .icnt_orde_pkt_valid       (per_pop_icnt_orde_pkt_valid[k]),  
       // Index (Oldest, Empty IDX (header?tail?))
      .oldest_idx_valid         (per_oldest_idx_valid[k]      ),
      .oldest_idx               (per_oldest_idx[k]            ),
      .empty_idx_valid          (per_empty_idx_valid[k]       ),
      .empty_idx                (per_empty_idx[k]             ),  
      .matched_idx_valid        (per_matched_idx_valid[k]     ),
      .matched_idx              (per_matched_idx[k]           ), 
      .match_idx_is_young       (per_match_idx_is_young[k]    ),
      // L1 ORD -> L2 ORD    
      .match_idx                (per_match_idx[k]             ),
      .match_idx_valid          (per_match_idx_valid[k]       ),

      .oldest_idx_next_valid    (per_oldest_idx_next_valid[k] ),
      .oldest_idx_next          (per_oldest_idx_next[k]       ),
      .oldest_pkt_valid         (per_rd_data_valid[k]         ),
      .pop_idx_valid            (per_pop_idx_valid[k]        ),
      .pop_idx                  (per_pop_idx[k]              )
      );

      always @(posedge clk) begin 
        per_pop_icnt_orde_pkt[k]          <= pop_icnt_orde_pkt;
        per_pop_icnt_orde_pkt_valid[k]    <= pop_icnt_orde_pkt_valid ;
      end   

      assign per_oldest_idx[k]           = oldest_idx[$clog2(NUM_PER_BLOCK)-1:0];
      assign per_oldest_idx_valid[k]     = oldest_idx[$clog2(NUM_MAX_RD)-1:$clog2(NUM_PER_BLOCK)] == k;

      assign per_empty_idx[k]            = empty_idx[$clog2(NUM_PER_BLOCK)-1:0];
      assign per_empty_idx_valid[k]      = empty_idx[$clog2(NUM_MAX_RD)-1:$clog2(NUM_PER_BLOCK)] == k;                 

      assign per_matched_idx[k]          = matched_idx[$clog2(NUM_PER_BLOCK)-1:0];
      assign per_matched_idx_valid[k]    = matched_idx_valid && (matched_idx[$clog2(NUM_MAX_RD)-1:$clog2(NUM_PER_BLOCK)] == k);            

      assign per_oldest_idx_next[k]      = oldest_idx_next[$clog2(NUM_PER_BLOCK)-1:0];
      assign per_oldest_idx_next_valid[k]= oldest_idx_next[$clog2(NUM_MAX_RD)-1:$clog2(NUM_PER_BLOCK)] == k;            

      assign per_pop_idx[k]             = pop_idx[$clog2(NUM_PER_BLOCK)-1:0];
      assign per_pop_idx_valid[k]       = (pop_idx[$clog2(NUM_MAX_RD)-1:$clog2(NUM_PER_BLOCK)] == k) && pop_idx_valid;                  
    end  
  endgenerate
   
  // =================== Find Oldest PKT Unit ===================

  orde_l2_search #(.NUM_PER_BLOCK(NUM_PER_BLOCK),.NUM_MAX_RD(NUM_MAX_RD), .NUM_BLOCK(NUM_BLOCK)) 
  u_orde_l2_search  (
    .clk, .rst,
    .oldest_idx(oldest_idx),
    .per_match_idx(per_match_idx),
    .per_match_idx_valid(per_match_idx_valid),
    .per_match_idx_is_young(|per_match_idx_is_young),
    .matched_idx(matched_idx),
    .matched_idx_valid(matched_idx_valid)
  );  
`ifdef SUPPORT_INDIRECT_ADDRESSING
(* keep = "true", mark_debug = "true" *)reg                          matched_idx_valid_r;
(* keep = "true", mark_debug = "true" *)reg [$clog2(NUM_MAX_RD)-1:0] matched_idx_r;

always@(posedge clk,  posedge rst )begin
  if(rst)               matched_idx_valid_r <= 'b0;
  else                  matched_idx_valid_r <= matched_idx_valid;
end

always@(posedge clk,  posedge rst )begin
  if(rst)               matched_idx_r <= 'b0;
  else                  matched_idx_r <= matched_idx;
end

`endif
    // =================== RD Response Memory ===================
  always @(posedge clk) begin 
    // Read/Write RD Data Buffer
    orde_int_pkt.is_rd     <= 1'b1;  // Only handling READ packets for now
    orde_int_pkt.addr      <= 0;     // Address is not required by AXI Bridge if we only handle READ transactions (responses leave in-order)
    orde_int_pkt.mask      <= 0;     // Not required
    orde_int_pkt.data      <= rd_data_mem[oldest_idx_next];    
    orde_int_pkt_valid     <= |per_rd_data_valid && (mem_cnt > 0 && !(mem_cnt == 1 && mem_cnt_next == 0));
    // `ifdef SUPPORT_INDIRECT_ADDRESSING
    // if (matched_idx_valid_r) rd_data_mem[matched_idx_r] <= buffer_data_mem_out;
    // `else
    if (matched_idx_valid) rd_data_mem[matched_idx] <= buffer_data_mem_out;
    // `endif
  end
  
  (* keep = "true", mark_debug = "true" *)reg [255:0]  debug_orde_int_pkt_data;
  always@(posedge clk,  posedge rst )begin
  if(rst) begin   
                                debug_orde_int_pkt_data  <='b0;
  end
  else begin
                                debug_orde_int_pkt_data  <=orde_int_pkt.data;    
  end
  end

  

  // ============================= Initialization ==============================
  initial begin
    oldest_idx                  = 0;
    empty_idx                   = 0;
    mem_cnt                     = 0;
    orde_int_pkt               = 0;
    orde_int_pkt_valid         = 0;
    per_pop_icnt_orde_pkt       = '{NUM_BLOCK{0}};
    per_pop_icnt_orde_pkt_valid = '{NUM_BLOCK{0}};        
    rd_data_mem                 = '{NUM_MAX_RD{0}};
    addres_mem                  = '{NUM_MAX_RD{0}};
  end
  
endmodule 

