import aimc_lib::*;

module orde_resp_buf #(
    parameter integer NUM_BUFFERING = 8
)
(
  input  logic                                clk,
  input  logic                                rst,
  input  rd_t                                 icnt_orde_pkt_rd_type,
  input  pkt_t                                icnt_orde_pkt,
  input  [$clog2(CH_NUM)-1:0]                 icnt_orde_pkt_ch_addr,
  input  logic                                icnt_orde_pkt_valid,  
  output logic                                orde_rdy,
  output orde_pkt_t                           pop_pkt,  
  output logic                                pop_pkt_valid,

  input  logic                                data_pop,
  `ifdef SUPPORT_INDIRECT_ADDRESSING
    input logic [31:0] i_reg_A_data,
    input logic [31:0] i_reg_B_data,
    input logic [31:0] i_reg_C_data,  

    `ifdef SUPPORT_LUT_DATAPATH
      input  logic         i_lut_load_sig,
      input  logic [255:0] i_lut_target_bank_x_data,
    `endif
  `endif
  output logic [DATA_WIDTH-1:0]               buffer_data_mem_out
);

  // ============================= Internal Signals ==============================

  (* RAM_STYLE = "distributed" *)     logic [$bits(orde_pkt_t)-1:0]   buffer_meta_mem [NUM_BUFFERING-1:0];   // buffer memory for icnt_orde_pkt meta data
  (* RAM_STYLE = "BLOCK" *)           logic [DATA_WIDTH-1:0]          buffer_data_mem [NUM_BUFFERING-1:0];   // buffer memory for icnt_orde_pkt data 

  logic [$bits(orde_pkt_t)-1:0]     buffer_meta_mem_out;                  // output of buffer_meta_mem
  logic                             buffer_meta_mem_out_valid;            // valid signal for output of buffer_meta_mem 
  logic [$clog2(NUM_BUFFERING):0]   buffer_meta_cnt,buffer_meta_cnt_next; // counter of buffer_meta_mem
  logic [$clog2(NUM_BUFFERING):0]   buffer_data_cnt,buffer_data_cnt_next; // counter of buffer_data_mem
  logic [$clog2(NUM_BUFFERING)-1:0] pkt_insert_ptr;                       // pointer for empty slot for buffer_meta_mem and buffer_data_mem
  logic                             pkt_insert_valid;                     // valid singal for input pkt 
  logic [$clog2(NUM_BUFFERING)-1:0] address_pop_ptr,address_pop_ptr_next; // pointer to pop meta data (address) from buffer_meta_mem
  logic [$clog2(NUM_BUFFERING)-1:0] data_pop_ptr,data_pop_ptr_next;       // pointer to pop data from buffer_data_mem 
  logic                             address_pop;                          // enable pop meta data (address) from buffer_meta_mem
  logic                             equal_pop_mem,equal_pre_pop_mem;      // result of compare the head pkt with previous popped pktes

  // latch previous popped pkt to compare the head pkt of the buffer_meta_mem
  orde_pkt_t                        pop_pkt_r;
  logic                             pop_pkt_valid_r;
  
  // ============================= RD Resp. Buffer  ==============================

  always @(posedge clk) begin
      address_pop_ptr <= address_pop_ptr_next;
      data_pop_ptr    <= data_pop_ptr_next;    
      buffer_meta_cnt <= buffer_meta_cnt_next;
      buffer_data_cnt <= buffer_data_cnt_next;
  end 

  always_comb begin
    address_pop_ptr_next = address_pop_ptr;
    data_pop_ptr_next    = data_pop_ptr;
    buffer_meta_cnt_next = buffer_meta_cnt;
    buffer_data_cnt_next = buffer_data_cnt;

    if(address_pop)      address_pop_ptr_next = address_pop_ptr + 1;  // increase address_pop_ptr when pop one of buffer_meta_mem 
    if(data_pop)         data_pop_ptr_next    = data_pop_ptr    + 1;  // increase data_pop_ptr when find matched index with popped pkt in orde

    if(pkt_insert_valid && !address_pop)        buffer_meta_cnt_next = buffer_meta_cnt + 1;
    else if(!pkt_insert_valid && address_pop)   buffer_meta_cnt_next = buffer_meta_cnt - 1;    
    if(pkt_insert_valid && !data_pop)           buffer_data_cnt_next = buffer_data_cnt + 1;
    else if(!pkt_insert_valid && data_pop)      buffer_data_cnt_next = buffer_data_cnt - 1;      
    
  end  
  
  assign pkt_insert_valid = icnt_orde_pkt_valid && orde_rdy; // buffering icnt_orde_pkt when icnt_orde_pkt is valid and a room of buffer is enough. 

`ifdef SUPPORT_INDIRECT_ADDRESSING
  wire [31:0] bus_desc_addr_h;
  wire [31:0] bus_desc_addr_l;
  wire [31:0] bus_desc_pim_opcode;

  wire [255:0] w_buffer_data_mem;
    assign w_buffer_data_mem = buffer_data_mem[data_pop_ptr_next];
    assign bus_desc_addr_l = w_buffer_data_mem[32*1-1: 32*0];
    assign bus_desc_addr_h = w_buffer_data_mem[32*2-1: 32*1];
    assign bus_desc_pim_opcode = w_buffer_data_mem[32*8-1:32*7];      


(* keep = "true", mark_debug = "true" *)wire descr_enable;
    assign descr_enable = //(pkt_insert_valid) && 
                          (bus_desc_addr_h[31:16] == 16'h0000) && 
                          (bus_desc_addr_h[15:0]  == 16'h0004) && 
                          ((bus_desc_addr_l[5:0]  == 6'b000011)||(bus_desc_addr_l[5:0]   == 6'b000101)) &&
                          (bus_desc_addr_l[23:20] ==4'b1???) &&
                          (bus_desc_addr_l[31:24] ==8'h00);
(* keep = "true", mark_debug = "true" *)wire is_desc_A;
(* keep = "true", mark_debug = "true" *)wire is_desc_B;
(* keep = "true", mark_debug = "true" *)wire is_desc_C;
    assign is_desc_A = descr_enable && bus_desc_pim_opcode[1];
    assign is_desc_B = descr_enable && bus_desc_pim_opcode[2];
    assign is_desc_C = descr_enable && bus_desc_pim_opcode[3];

(* keep = "true", mark_debug = "true" *)wire is_indirect;
(* keep = "true", mark_debug = "true" *)wire is_immediate;
(* keep = "true", mark_debug = "true" *)wire is_register;
    assign is_indirect = descr_enable && w_buffer_data_mem[0];
    assign is_immediate = descr_enable && w_buffer_data_mem[1];
    assign is_register = descr_enable && w_buffer_data_mem[2];

`ifdef SUPPORT_LUT_DATAPATH
(* keep = "true", mark_debug = "true" *)reg  [255:0] lut_x_from_memory;
(* keep = "true", mark_debug = "true" *)wire [3:0]   lut_acc_index;
  assign lut_acc_index = bus_desc_pim_opcode[24:21];

always@(posedge clk,  posedge rst )begin
  if(rst)                    lut_x_from_memory <= 'b0;
  else if(is_desc_C)         lut_x_from_memory <= 'b0;
  else if(i_lut_load_sig)    lut_x_from_memory <= i_lut_target_bank_x_data;                
end

reg [11:0] lut_offset_in;
always @(*) begin
  if(is_register) begin
    if(lut_acc_index == 4'b0000)       lut_offset_in = lut_x_from_memory[(16*1-1):(16*0)+4];
    else if(lut_acc_index == 4'b0001)  lut_offset_in = lut_x_from_memory[(16*2-1):(16*1)+4];
    else if(lut_acc_index == 4'b0010)  lut_offset_in = lut_x_from_memory[(16*3-1):(16*2)+4];
    else if(lut_acc_index == 4'b0011)  lut_offset_in = lut_x_from_memory[(16*4-1):(16*3)+4];
    else if(lut_acc_index == 4'b0100)  lut_offset_in = lut_x_from_memory[(16*5-1):(16*4)+4];
    else if(lut_acc_index == 4'b0101)  lut_offset_in = lut_x_from_memory[(16*6-1):(16*5)+4];
    else if(lut_acc_index == 4'b0110)  lut_offset_in = lut_x_from_memory[(16*7-1):(16*6)+4];
    else if(lut_acc_index == 4'b0111)  lut_offset_in = lut_x_from_memory[(16*8-1):(16*7)+4];
    else if(lut_acc_index == 4'b1000)  lut_offset_in = lut_x_from_memory[(16*9-1):(16*8)+4];
    else if(lut_acc_index == 4'b1001)  lut_offset_in = lut_x_from_memory[(16*10-1):(16*9)+4];
    else if(lut_acc_index == 4'b1010)  lut_offset_in = lut_x_from_memory[(16*11-1):(16*10)+4];
    else if(lut_acc_index == 4'b1011)  lut_offset_in = lut_x_from_memory[(16*12-1):(16*11)+4];
    else if(lut_acc_index == 4'b1100)  lut_offset_in = lut_x_from_memory[(16*13-1):(16*12)+4];
    else if(lut_acc_index == 4'b1101)  lut_offset_in = lut_x_from_memory[(16*14-1):(16*13)+4];
    else if(lut_acc_index == 4'b1110)  lut_offset_in = lut_x_from_memory[(16*15-1):(16*14)+4];
    else if(lut_acc_index == 4'b1111)  lut_offset_in = lut_x_from_memory[(16*16-1):(16*15)+4];
  end
  else                                 lut_offset_in ='b0;
end
`endif 

//Indirect address calculation
(* keep = "true", mark_debug = "true" *)reg [31:0] offset_in;
(* keep = "true", mark_debug = "true" *)reg [31:0] base_in;
always @(*) begin
    if(is_indirect && is_desc_A  && is_immediate)           offset_in = w_buffer_data_mem[32*3-1 :32*2];
    else if(is_indirect && is_desc_B && is_immediate)       offset_in = w_buffer_data_mem[32*3-1 :32*2];
    else if(is_indirect && is_desc_C && is_immediate)       offset_in = w_buffer_data_mem[32*5-1 :32*4];
    `ifdef SUPPORT_LUT_DATAPATH
    else if(is_indirect && is_desc_B && is_register)        offset_in = {'b0, lut_offset_in, 4'b0000};
    `endif
    else                                    offset_in = 'b0;
end

always @(*) begin
    if(is_indirect && is_desc_A && is_immediate)           base_in = i_reg_A_data; 
    else if(is_indirect && is_desc_B  && is_immediate)     base_in = i_reg_B_data; 
    else if(is_indirect && is_desc_C  && is_immediate)     base_in = i_reg_C_data; 
    `ifdef SUPPORT_LUT_DATAPATH
    else if(is_indirect && is_desc_B  && is_register)      base_in = i_reg_B_data; 
    `endif
    else                                                   base_in = 'b0;
end

(* keep = "true", mark_debug = "true" *)wire [31:0] indirect_address;
  // assign indirect_address = is_indirect ? offset_in | base_in : 'b0;
  assign indirect_address = is_indirect ? (offset_in + base_in) : 'b0;

wire [255:0] modified_buffer_data_mem;
(* keep = "true", mark_debug = "true" *)reg [255:0] tmp_indirect_data_mem;
  
always @(*) begin
  if(is_indirect) begin
    if(is_desc_A | is_desc_B)       tmp_indirect_data_mem = {w_buffer_data_mem[32*8-1:32*3], indirect_address, w_buffer_data_mem[32*2-1:32*0]};
    else if(is_desc_C)              tmp_indirect_data_mem = {w_buffer_data_mem[32*8-1:32*5], indirect_address, w_buffer_data_mem[32*4-1:32*0]};
  end                                   
  else                              tmp_indirect_data_mem = 'b0;
end
  assign modified_buffer_data_mem = descr_enable? tmp_indirect_data_mem: w_buffer_data_mem;

(* keep = "true", mark_debug = "true" *)reg [255:0] modified_buffer_data_mem_r;//Timing Latch
always@(posedge clk,  posedge rst )begin
  if(rst)               modified_buffer_data_mem_r <= 'b0;
  else                  modified_buffer_data_mem_r <= modified_buffer_data_mem;
end
`endif


  always @(posedge clk) begin
      if(pkt_insert_valid) begin 
        pkt_insert_ptr                  <=  pkt_insert_ptr + 1;
        buffer_meta_mem[pkt_insert_ptr] <=  {icnt_orde_pkt_rd_type,icnt_orde_pkt_ch_addr,icnt_orde_pkt.bk_addr,icnt_orde_pkt.row_addr,icnt_orde_pkt.col_addr};
        //buffer_meta_mem[pkt_insert_ptr] <=  {icnt_orde_pkt_ch_addr, icnt_orde_pkt.bk_addr,icnt_orde_pkt.row_addr,icnt_orde_pkt.col_addr};
        buffer_data_mem[pkt_insert_ptr] <=  icnt_orde_pkt.data;
      end
      
      if(address_pop)                              buffer_meta_mem_out       <= buffer_meta_mem[address_pop_ptr];
      if(address_pop)                              buffer_meta_mem_out_valid <= buffer_meta_cnt > 0;
      else if(equal_pop_mem || equal_pre_pop_mem)  buffer_meta_mem_out_valid <= buffer_meta_mem_out_valid;
      else if(buffer_meta_mem_out_valid)           buffer_meta_mem_out_valid <= 0;

      `ifdef SUPPORT_INDIRECT_ADDRESSING
      buffer_data_mem_out  <= descr_enable? modified_buffer_data_mem_r:w_buffer_data_mem;
      // buffer_data_mem_out  <= buffer_data_mem[data_pop_ptr_next];
      `else
      buffer_data_mem_out  <= buffer_data_mem[data_pop_ptr_next];
      `endif
  end 
  
  assign orde_rdy = buffer_data_cnt < (NUM_BUFFERING - 2);

  // ============================= Pop Resp. Packet  ==============================
  
  // pop meta data when buffer_meta_cnt has valid data and the head pkt is not equal with previos popped pkt
  assign address_pop       = buffer_meta_cnt > 0 && !equal_pop_mem && !equal_pre_pop_mem; 
  // compare the head pkt with two previous popped pkt 
  
  assign equal_pop_mem     = (pop_pkt == buffer_meta_mem_out) && pop_pkt_valid && buffer_meta_mem_out_valid;
  assign equal_pre_pop_mem = (pop_pkt_r == buffer_meta_mem_out) && pop_pkt_valid_r && buffer_meta_mem_out_valid;

  always @(posedge clk) begin
      pop_pkt                <= buffer_meta_mem_out;
      if(address_pop)                               pop_pkt_valid <= buffer_meta_mem_out_valid;
      else if(equal_pop_mem || equal_pre_pop_mem)   pop_pkt_valid <= 0;
      else                                          pop_pkt_valid <= buffer_meta_mem_out_valid;
      pop_pkt_r              <= pop_pkt;
      pop_pkt_valid_r        <= pop_pkt_valid;      
  end

  // ============================= Initialization ==============================
  initial begin
    buffer_meta_cnt          = 0;
    buffer_data_cnt          = 0;
    pkt_insert_ptr           = 0;
    address_pop_ptr          = 0;
    data_pop_ptr             = 0;         
    buffer_data_mem          = '{NUM_BUFFERING{0}};
    buffer_meta_mem          = '{NUM_BUFFERING{0}};
    buffer_meta_mem_out      = 0;
    buffer_meta_mem_out_valid= 0;
    pop_pkt                  = 0;    
    pop_pkt_r                = 0;
    pop_pkt_valid            = 0;  
    pop_pkt_valid_r          = 0;  
  end

endmodule
