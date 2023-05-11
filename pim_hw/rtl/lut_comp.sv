module PIM_lut_comp
(
    clk, 
    rst_x,

    i_acc_offset, 
    i_acc_idx,
    i_data,

    o_lut_result,
    o_lut_result_enable
);

input           clk;
input           rst_x;

input [63:0]    i_acc_offset;        // 16 Accs x 4-bit
input [3:0]     i_acc_idx;        // 16 Accs 
input [255:0]   i_data;              // Latched data from memory

output [15:0]   o_lut_result;        // searched data from i_data
output [15:0]   o_lut_result_enable; // which acc's value need to be updated

(* keep = "true", mark_debug = "true" *)reg [3:0]   lut_col_in;
reg [255:0] i_data_r;
reg [63:0]  i_acc_offset_r;

always @(posedge clk or negedge rst_x) begin
  if(~rst_x)                  i_data_r <='b0;
  else                        i_data_r <= i_data;
end

always @(posedge clk or negedge rst_x) begin
  if(~rst_x)                  i_acc_offset_r <='b0;
  else                        i_acc_offset_r <= i_acc_offset;
end


always@(*) begin
  case(i_acc_idx) // synopsys parallel_case full_case
      4'b0000 : lut_col_in = i_acc_offset_r[4*1-1:4*0];
      4'b0001 : lut_col_in = i_acc_offset_r[4*2-1:4*1];
      4'b0010 : lut_col_in = i_acc_offset_r[4*3-1:4*2];
      4'b0011 : lut_col_in = i_acc_offset_r[4*4-1:4*3];
      4'b0100 : lut_col_in = i_acc_offset_r[4*5-1:4*4];
      4'b0101 : lut_col_in = i_acc_offset_r[4*6-1:4*5];
      4'b0110 : lut_col_in = i_acc_offset_r[4*7-1:4*6];
      4'b0111 : lut_col_in = i_acc_offset_r[4*8-1:4*7];
      4'b1000 : lut_col_in = i_acc_offset_r[4*9-1:4*8];
      4'b1001 : lut_col_in = i_acc_offset_r[4*10-1:4*9];
      4'b1010 : lut_col_in = i_acc_offset_r[4*11-1:4*10];
      4'b1011 : lut_col_in = i_acc_offset_r[4*12-1:4*11];
      4'b1100 : lut_col_in = i_acc_offset_r[4*13-1:4*12];
      4'b1101 : lut_col_in = i_acc_offset_r[4*14-1:4*13];
      4'b1110 : lut_col_in = i_acc_offset_r[4*15-1:4*14];
      4'b1111 : lut_col_in = i_acc_offset_r[4*16-1:4*15];
  endcase
end

(* keep = "true", mark_debug = "true" *)reg [15:0] searched_data;
always @(*) begin
  case(lut_col_in)
    4'b0000: searched_data = i_data_r[16*1-1:16*0];
    4'b0001: searched_data = i_data_r[16*2-1:16*1];
    4'b0010: searched_data = i_data_r[16*3-1:16*2];
    4'b0011: searched_data = i_data_r[16*4-1:16*3];
    4'b0100: searched_data = i_data_r[16*5-1:16*4];
    4'b0101: searched_data = i_data_r[16*6-1:16*5];
    4'b0110: searched_data = i_data_r[16*7-1:16*6];
    4'b0111: searched_data = i_data_r[16*8-1:16*7];
    4'b1000: searched_data = i_data_r[16*9-1:16*8];
    4'b1001: searched_data = i_data_r[16*10-1:16*9];
    4'b1010: searched_data = i_data_r[16*11-1:16*10];
    4'b1011: searched_data = i_data_r[16*12-1:16*11];
    4'b1100: searched_data = i_data_r[16*13-1:16*12];
    4'b1101: searched_data = i_data_r[16*14-1:16*13];
    4'b1110: searched_data = i_data_r[16*15-1:16*14];
    4'b1111: searched_data = i_data_r[16*16-1:16*15];
  endcase
end

reg [15:0] acc_out_enable;
always@(*) begin
  case(i_acc_idx) // synopsys parallel_case full_case
      4'b0000 : acc_out_enable = 16'b0000000000000001;
      4'b0001 : acc_out_enable = 16'b0000000000000010;
      4'b0010 : acc_out_enable = 16'b0000000000000100;
      4'b0011 : acc_out_enable = 16'b0000000000001000;
      4'b0100 : acc_out_enable = 16'b0000000000010000;
      4'b0101 : acc_out_enable = 16'b0000000000100000;
      4'b0110 : acc_out_enable = 16'b0000000001000000;
      4'b0111 : acc_out_enable = 16'b0000000010000000;
      4'b1000 : acc_out_enable = 16'b0000000100000000;
      4'b1001 : acc_out_enable = 16'b0000001000000000;
      4'b1010 : acc_out_enable = 16'b0000010000000000;
      4'b1011 : acc_out_enable = 16'b0000100000000000;
      4'b1100 : acc_out_enable = 16'b0001000000000000;
      4'b1101 : acc_out_enable = 16'b0010000000000000;
      4'b1110 : acc_out_enable = 16'b0100000000000000;
      4'b1111 : acc_out_enable = 16'b1000000000000000;
  endcase
end

    assign o_lut_result = searched_data;
    assign o_lut_result_enable = acc_out_enable;

endmodule