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
    input logic [255:0] i_reg_LUT_data[15:0],
    input logic        i_HPC_clear,
    // input logic        i_orde_axbr_pkt_valid,

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
    // assign w_buffer_data_mem = buffer_data_mem[data_pop_ptr_next];
    assign w_buffer_data_mem = icnt_orde_pkt.data;

// (* keep = "true", mark_debug = "true" *)reg [255:0] w_buffer_data_mem_r;
// always@(posedge clk,  posedge rst )begin
//   if(rst)               w_buffer_data_mem_r <= 'b0;
//   else                  w_buffer_data_mem_r <= w_buffer_data_mem;
// end

  assign bus_desc_addr_l = w_buffer_data_mem[32*1-1: 32*0];
  assign bus_desc_addr_h = w_buffer_data_mem[32*2-1: 32*1];
  assign bus_desc_pim_opcode = w_buffer_data_mem[32*8-1:32*7];    

// /* Additional logic for preventing DMA prefetch
reg [27:0] current_desc_addr;
reg [27:0] next_desc_addr;

wire is_read_desc;
  assign is_read_desc = (bus_desc_addr_h[31:16] == 16'h0000) && 
                          (bus_desc_addr_h[15:0]  == 16'h0004) && 
                          ((bus_desc_addr_l[5:0]  == 6'b000011)||(bus_desc_addr_l[5:0]   == 6'b000101)) &&
                          (bus_desc_addr_l[23:20] ==  'b1???) &&
                          (bus_desc_addr_l[31:24] ==8'h00);
wire is_next_desc_enable;
  // assign is_next_desc_enable = (is_read_desc && (bus_desc_addr_l[31:4]==next_desc_addr))?1'b1:1'b0;
  assign is_next_desc_enable = is_read_desc;

// always @(posedge clk, posedge rst)begin
//   if(rst | i_HPC_clear)begin
//                           current_desc_addr              <=28'h008_0000;
//                           next_desc_addr                 <=28'h008_0004;
//   end
//   else if(is_next_desc_enable)begin
//                           current_desc_addr              <= current_desc_addr + 28'h000_0004; 
//                           next_desc_addr                 <= next_desc_addr + 28'h000_0004;
//   end
// end

/*FPGA latching...
descr_enable needs to be set 1 between is_next_desc ~ data_pop, timing margin can be existed*/

// reg descr_enable;
// always @(*) begin
  // if(rst)                             descr_enable <=1'b0;
  // if(is_next_desc_enable)        descr_enable <=1'b1;
  // else if(descr_enable && data_pop)   descr_enable <=1'b0;
  // else if(descr_enable && !data_pop)  descr_enable <=1'b1;  
  // else                                descr_enable <=1'b0;
// end
wire descr_enable;
  assign descr_enable = is_next_desc_enable;
// reg descr_enable_r;
// always @(posedge clk, posedge rst)begin
//   if(rst)                 descr_enable_r <='b0; 
//   else                    descr_enable_r <=descr_enable;
// end

// (* keep = "true", mark_debug = "true" *)reg descr_enable_r;


wire is_desc_A;
wire is_desc_B;
wire is_desc_C;
    assign is_desc_A = descr_enable && bus_desc_pim_opcode[1];
    assign is_desc_B = descr_enable && bus_desc_pim_opcode[2];
    assign is_desc_C = descr_enable && bus_desc_pim_opcode[3];
    // assign is_desc_A = descr_enable_r && bus_desc_pim_opcode[1];
    // assign is_desc_B = descr_enable_r && bus_desc_pim_opcode[2];
    // assign is_desc_C = descr_enable_r && bus_desc_pim_opcode[3];
wire is_indirect;
wire is_immediate;
wire is_register;
    assign is_indirect = descr_enable && bus_desc_addr_l[0];
    assign is_immediate = descr_enable && bus_desc_addr_l[1];
    assign is_register = descr_enable && bus_desc_addr_l[2];
    // assign is_indirect = descr_enable_r && bus_desc_addr_l[0];
    // assign is_immediate = descr_enable_r && bus_desc_addr_l[1];
    // assign is_register = descr_enable_r && bus_desc_addr_l[2];

`ifdef SUPPORT_LUT_DATAPATH
reg  [255:0] lut_x_mem;
wire [3:0]   acc_index;
wire [3:0]   bank_index;
  assign acc_index =  bus_desc_pim_opcode[24:21];
  assign bank_index = bus_desc_pim_opcode[28:25];


always@(*)begin
  if(is_indirect&&is_register) begin
    //Bank group 0~3, Bank 0
    if     (bank_index==4'b0000)       lut_x_mem = i_reg_LUT_data[0];
    else if(bank_index==4'b0100)       lut_x_mem = i_reg_LUT_data[1];
    else if(bank_index==4'b1000)       lut_x_mem = i_reg_LUT_data[2];
    else if(bank_index==4'b1100)       lut_x_mem = i_reg_LUT_data[3];
    //Bank group 0~3, Bank 1
    else if(bank_index==4'b0001)       lut_x_mem = i_reg_LUT_data[4];
    else if(bank_index==4'b0101)       lut_x_mem = i_reg_LUT_data[5];
    else if(bank_index==4'b1001)       lut_x_mem = i_reg_LUT_data[6];
    else if(bank_index==4'b1101)       lut_x_mem = i_reg_LUT_data[7];
    //Bank group 0~3, Bank 2
    else if(bank_index==4'b0010)       lut_x_mem = i_reg_LUT_data[8];
    else if(bank_index==4'b0110)       lut_x_mem = i_reg_LUT_data[9];
    else if(bank_index==4'b1010)       lut_x_mem = i_reg_LUT_data[10];
    else if(bank_index==4'b1110)       lut_x_mem = i_reg_LUT_data[11];
    //Bank group 0~3, Bank 3
    else if(bank_index==4'b0011)       lut_x_mem = i_reg_LUT_data[12];
    else if(bank_index==4'b0111)       lut_x_mem = i_reg_LUT_data[13];
    else if(bank_index==4'b1011)       lut_x_mem = i_reg_LUT_data[14];
    else if(bank_index==4'b1111)       lut_x_mem = i_reg_LUT_data[15];
  end
  else                                  lut_x_mem ='b0;
end


reg [11:0] lut_offset_in;
always @(*) begin
  if(is_indirect&&is_register) begin
    if(acc_index == 4'b0000)       lut_offset_in = lut_x_mem[(16*1-1):(16*0)+4];
    else if(acc_index == 4'b0001)  lut_offset_in = lut_x_mem[(16*2-1):(16*1)+4];
    else if(acc_index == 4'b0010)  lut_offset_in = lut_x_mem[(16*3-1):(16*2)+4];
    else if(acc_index == 4'b0011)  lut_offset_in = lut_x_mem[(16*4-1):(16*3)+4];
    else if(acc_index == 4'b0100)  lut_offset_in = lut_x_mem[(16*5-1):(16*4)+4];
    else if(acc_index == 4'b0101)  lut_offset_in = lut_x_mem[(16*6-1):(16*5)+4];
    else if(acc_index == 4'b0110)  lut_offset_in = lut_x_mem[(16*7-1):(16*6)+4];
    else if(acc_index == 4'b0111)  lut_offset_in = lut_x_mem[(16*8-1):(16*7)+4];
    else if(acc_index == 4'b1000)  lut_offset_in = lut_x_mem[(16*9-1):(16*8)+4];
    else if(acc_index == 4'b1001)  lut_offset_in = lut_x_mem[(16*10-1):(16*9)+4];
    else if(acc_index == 4'b1010)  lut_offset_in = lut_x_mem[(16*11-1):(16*10)+4];
    else if(acc_index == 4'b1011)  lut_offset_in = lut_x_mem[(16*12-1):(16*11)+4];
    else if(acc_index == 4'b1100)  lut_offset_in = lut_x_mem[(16*13-1):(16*12)+4];
    else if(acc_index == 4'b1101)  lut_offset_in = lut_x_mem[(16*14-1):(16*13)+4];
    else if(acc_index == 4'b1110)  lut_offset_in = lut_x_mem[(16*15-1):(16*14)+4];
    else if(acc_index == 4'b1111)  lut_offset_in = lut_x_mem[(16*16-1):(16*15)+4];
  end
  else                             lut_offset_in ='b0;
end
`endif 

//Indirect address calculation
reg [31:0] offset_in;
reg [31:0] base_in;
always @(*) begin
    if(is_indirect && is_desc_A  && is_immediate)           offset_in = w_buffer_data_mem[32*3-1 :32*2];
    else if(is_indirect && is_desc_B && is_immediate)       offset_in = w_buffer_data_mem[32*3-1 :32*2];
    else if(is_indirect && is_desc_C && is_immediate)       offset_in = w_buffer_data_mem[32*5-1 :32*4];
    `ifdef SUPPORT_LUT_DATAPATH
    else if(is_indirect && is_desc_B && is_register)        offset_in = {15'b0, lut_offset_in, 5'b00000};
    `endif
    else                                                    offset_in = 'b0;
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

wire [31:0] indirect_address;
  // assign indirect_address = is_indirect ? offset_in | base_in : 'b0;
  assign indirect_address = is_indirect ? (offset_in + base_in) : 'b0;

// wire [255:0] modified_buffer_data_mem;
reg [255:0] tmp_indirect_data_mem;
reg [255:0] tmp_indirect_data_mem_r;
always @(*) begin
  if(is_indirect) begin
    if(is_desc_A | is_desc_B)       tmp_indirect_data_mem = {w_buffer_data_mem[32*8-1:32*3], indirect_address, w_buffer_data_mem[32*2-1:32*0]};
    else if(is_desc_C)              tmp_indirect_data_mem = {w_buffer_data_mem[32*8-1:32*5], indirect_address, w_buffer_data_mem[32*4-1:32*0]};
  end                                   
  else                              tmp_indirect_data_mem = icnt_orde_pkt.data;
end

// always @(posedge clk, posedge rst)begin
//   if(rst)                 tmp_indirect_data_mem_r <='b0; 
//   else                    tmp_indirect_data_mem_r <=tmp_indirect_data_mem;
// end

// reg pkt_insert_valid_r;//Timing Latch
// always@(posedge clk,  posedge rst )begin
//   if(rst)               pkt_insert_valid_r <= 'b0;
//   else                  pkt_insert_valid_r <= pkt_insert_valid;
// end

`endif


  always @(posedge clk) begin
      if(pkt_insert_valid) begin 
        pkt_insert_ptr                  <=  pkt_insert_ptr + 1;
        buffer_meta_mem[pkt_insert_ptr] <=  {icnt_orde_pkt_rd_type,icnt_orde_pkt_ch_addr,icnt_orde_pkt.bk_addr,icnt_orde_pkt.row_addr,icnt_orde_pkt.col_addr};
        buffer_data_mem[pkt_insert_ptr] <=  tmp_indirect_data_mem;
        // buffer_data_mem[pkt_insert_ptr] <=  icnt_orde_pkt.data;
      end
      // if(pkt_insert_valid_r) begin 
      //   buffer_data_mem[pkt_insert_ptr] <=  descr_enable ? tmp_indirect_data_mem :icnt_orde_pkt.data;
      // end
      
      if(address_pop)                              buffer_meta_mem_out       <= buffer_meta_mem[address_pop_ptr];
      if(address_pop)                              buffer_meta_mem_out_valid <= buffer_meta_cnt > 0;
      else if(equal_pop_mem || equal_pre_pop_mem)  buffer_meta_mem_out_valid <= buffer_meta_mem_out_valid;
      else if(buffer_meta_mem_out_valid)           buffer_meta_mem_out_valid <= 0;
      buffer_data_mem_out  <= buffer_data_mem[data_pop_ptr_next];
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


//Debug signal generation
(* keep = "true", mark_debug = "true" *)reg         debug_orde_descr_enable;
(* keep = "true", mark_debug = "true" *)reg         debug_orde_is_desc_A;
(* keep = "true", mark_debug = "true" *)reg         debug_orde_is_desc_B;
(* keep = "true", mark_debug = "true" *)reg         debug_orde_is_desc_C;
(* keep = "true", mark_debug = "true" *)reg         debug_orde_is_indirect;
(* keep = "true", mark_debug = "true" *)reg         debug_orde_is_immediate;
(* keep = "true", mark_debug = "true" *)reg         debug_orde_is_register;
(* keep = "true", mark_debug = "true" *)reg [31:0]   debug_orde_offset_in;
(* keep = "true", mark_debug = "true" *)reg [31:0]   debug_orde_base_in;
(* keep = "true", mark_debug = "true" *)reg [31:0]  debug_orde_indirect_address;
(* keep = "true", mark_debug = "true" *)reg [255:0]  debug_orde_tmp_indirect_data_mem;
(* keep = "true", mark_debug = "true" *)reg [255:0]  debug_buffer_data_mem_out;

// (* keep = "true", mark_debug = "true" *) reg [27:0] debug_current_desc_addr;
// (* keep = "true", mark_debug = "true" *) reg [27:0] debug_next_desc_addr;
(* keep = "true", mark_debug = "true" *) reg        debug_is_next_desc_enable;
(* keep = "true", mark_debug = "true" *) reg        debug_is_read_descr;

(* keep = "true", mark_debug = "true" *) reg        debug_icnt_orde_pkt_valid;

(* keep = "true", mark_debug = "true" *) reg        debug_data_pop;

(* keep = "true", mark_debug = "true" *)reg         debug_pkt_insert_valid;
(* keep = "true", mark_debug = "true" *)reg [$clog2(NUM_BUFFERING)-1:0] debug_pkt_insert_ptr;
(* keep = "true", mark_debug = "true" *)reg [$clog2(NUM_BUFFERING)-1:0] debug_data_pop_ptr_next;
always@(posedge clk,  posedge rst )begin
  if(rst) begin                 
                        debug_orde_descr_enable               <='b0;                       
                        debug_orde_is_desc_A                  <='b0;                     
                        debug_orde_is_desc_B                  <='b0;                     
                        debug_orde_is_desc_C                  <='b0;                     
                        debug_orde_is_indirect                <='b0;                       
                        debug_orde_is_immediate               <='b0;                       
                        debug_orde_is_register                <='b0;                       
            
                        debug_orde_offset_in                  <='b0;                  
                        debug_orde_base_in                    <='b0;                  
                        debug_orde_indirect_address           <='b0;                 
                        debug_orde_tmp_indirect_data_mem      <='b0;                           

                        // debug_current_desc_addr               <='b0;
                        // debug_next_desc_addr                  <='b0; 
                        debug_is_next_desc_enable             <='b0;
                        debug_is_read_descr                   <='b0;
                        debug_icnt_orde_pkt_valid             <='b0;   
                        debug_data_pop                        <='b0;

                        debug_pkt_insert_valid                <='b0;     
                        debug_pkt_insert_ptr                  <='b0;      
                        debug_data_pop_ptr_next               <='b0;
                        debug_buffer_data_mem_out             <='b0;

  end
  else begin
                        debug_orde_descr_enable               <= descr_enable;
                        debug_orde_is_desc_A                  <= is_desc_A;
                        debug_orde_is_desc_B                  <= is_desc_B;
                        debug_orde_is_desc_C                  <= is_desc_C;
                        debug_orde_is_indirect                <= is_indirect;
                        debug_orde_is_immediate               <= is_immediate;
                        debug_orde_is_register                <= is_register;

                        debug_orde_offset_in                  <= offset_in;
                        debug_orde_base_in                    <= base_in;
                        debug_orde_indirect_address           <= indirect_address;
                        debug_orde_tmp_indirect_data_mem      <= tmp_indirect_data_mem;


                        // debug_current_desc_addr               <=current_desc_addr;
                        // debug_next_desc_addr                  <=next_desc_addr;
                        debug_is_next_desc_enable             <=is_next_desc_enable;
                        debug_is_read_descr                   <=is_read_desc;

                        debug_icnt_orde_pkt_valid             <=icnt_orde_pkt_valid;
                        debug_data_pop                        <=data_pop;

                        debug_pkt_insert_valid                <=pkt_insert_valid;     
                        debug_pkt_insert_ptr                  <=pkt_insert_ptr;                              
                        debug_data_pop_ptr_next               <=data_pop_ptr_next;
                        debug_buffer_data_mem_out             <=buffer_data_mem_out;
  end            
  
end


endmodule
