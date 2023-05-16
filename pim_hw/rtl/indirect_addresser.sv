module PIM_indirect_address
(
    clk, 
    rst_x,

    i_write_en, 
    i_addr,
    i_write_data,

    i_PIM_dev_working,
    i_HPC_clear,
    // i_desc_range_valid,

    o_args_reg_A,
    o_args_reg_B,
    o_args_reg_C,
    o_args_reg_LUT_x
);

localparam MM_INDIRECT_ARGS_A = 32'h0000_1000;
localparam MM_INDIRECT_ARGS_B = 32'h0000_2000;
localparam MM_INDIRECT_ARGS_C = 32'h0000_3000;

localparam MM_INDIRECT_ARGS_LUT_X = 23'b 000_0000_0000_0000_0100_0000; //0000_80??


input           clk;
input           rst_x;

input           i_write_en;
input [31:0]    i_addr;
input [255:0]   i_write_data;

input           i_PIM_dev_working;
input           i_HPC_clear;


output [31:0]   o_args_reg_A;
output [31:0]   o_args_reg_B;
output [31:0]   o_args_reg_C;
output [255:0]  o_args_reg_LUT_x[15:0];


genvar i;
reg [255:0] i_write_data_r; //FPGA timing latch
always @ (posedge clk or negedge rst_x)begin
    if(~rst_x)      i_write_data_r <='b0;
    else            i_write_data_r <=i_write_data;
end
//Generation valid signal for indirect addressing calculation

// Added logic for generate indirect address
(* keep = "true", mark_debug = "true" *) wire req_MM_args_A;
(* keep = "true", mark_debug = "true" *) wire req_MM_args_B;
(* keep = "true", mark_debug = "true" *) wire req_MM_args_C;

(* keep = "true", mark_debug = "true" *) reg req_MM_args_A_r;
(* keep = "true", mark_debug = "true" *) reg req_MM_args_B_r;
(* keep = "true", mark_debug = "true" *) reg req_MM_args_C_r;

    assign req_MM_args_A = ((i_addr[31:0] == MM_INDIRECT_ARGS_A) && i_write_en) ? 1'b1: 1'b0;
    assign req_MM_args_B = ((i_addr[31:0] == MM_INDIRECT_ARGS_B) && i_write_en) ? 1'b1: 1'b0;
    assign req_MM_args_C = ((i_addr[31:0] == MM_INDIRECT_ARGS_C) && i_write_en) ? 1'b1: 1'b0;

always @ (posedge clk or negedge rst_x) begin
    if(~rst_x) begin
                   req_MM_args_A_r <= 1'b0;
                   req_MM_args_B_r <= 1'b0;
                   req_MM_args_C_r <= 1'b0;
    end
    else begin
                   req_MM_args_A_r <= req_MM_args_A;
                   req_MM_args_B_r <= req_MM_args_B;
                   req_MM_args_C_r <= req_MM_args_C;
    end
end



(* keep = "true", mark_debug = "true" *)reg [31:0] args_reg_A;
(* keep = "true", mark_debug = "true" *)reg [31:0] args_reg_B;
(* keep = "true", mark_debug = "true" *)reg [31:0] args_reg_C;

always @(posedge clk or negedge rst_x) begin
    if(~rst_x) begin
            args_reg_A         <='b0;
            args_reg_B         <='b0;
            args_reg_C         <='b0;
    end
    else if(i_HPC_clear)begin
            args_reg_A         <='b0;
            args_reg_B         <='b0;
            args_reg_C         <='b0;            
    end
    // else if(req_MM_args)begin
    else if(req_MM_args_A_r)begin
            args_reg_A         <=i_write_data_r[32*1-1: 32*0];            
    end    
    else if(req_MM_args_B_r)begin
            args_reg_B         <=i_write_data_r[32*1-1: 32*0];            
    end    
    else if(req_MM_args_C_r)begin
            args_reg_C         <=i_write_data_r[32*1-1: 32*0];            
    end            
end


wire [1:0] req_bg;
wire [1:0] req_bk;
    assign req_bg = i_addr[8:7];
    assign req_bk = i_addr[6:5];

(* keep = "true", mark_debug = "true" *)wire req_MM_LUT_X;
assign req_MM_LUT_X = ((i_addr[31:9] == MM_INDIRECT_ARGS_LUT_X) && i_write_en) ? 1'b1: 1'b0;

reg  [16-1:0] lut_bank_access;
wire [16-1:0] lut_wr_cmd;
(* keep = "true", mark_debug = "true" *)reg  [16-1:0] lut_wr_cmd_r;
always@(*) begin
  case({req_bg,req_bk}) // synopsys parallel_case full_case
      4'b0000 : lut_bank_access = 16'b0000000000000001;
      4'b0001 : lut_bank_access = 16'b0000000000000010;
      4'b0010 : lut_bank_access = 16'b0000000000000100;
      4'b0011 : lut_bank_access = 16'b0000000000001000;
      4'b0100 : lut_bank_access = 16'b0000000000010000;
      4'b0101 : lut_bank_access = 16'b0000000000100000;
      4'b0110 : lut_bank_access = 16'b0000000001000000;
      4'b0111 : lut_bank_access = 16'b0000000010000000;
      4'b1000 : lut_bank_access = 16'b0000000100000000;
      4'b1001 : lut_bank_access = 16'b0000001000000000;
      4'b1010 : lut_bank_access = 16'b0000010000000000;
      4'b1011 : lut_bank_access = 16'b0000100000000000;
      4'b1100 : lut_bank_access = 16'b0001000000000000;
      4'b1101 : lut_bank_access = 16'b0010000000000000;
      4'b1110 : lut_bank_access = 16'b0100000000000000;
      4'b1111 : lut_bank_access = 16'b1000000000000000;
  endcase
end
generate 
  for(i = 0; i < 16; i = i + 1) begin: LUT_BANK_ACCESS
    assign lut_wr_cmd[i] = i_PIM_dev_working && req_MM_LUT_X && (lut_bank_access[i]) ? 1'b1 : 1'b0;
  end
endgenerate
always @(posedge clk or negedge rst_x) begin
    if(~rst_x)                              lut_wr_cmd_r <= 'b0;
    else                                    lut_wr_cmd_r <= lut_wr_cmd;
end

(* RAM_STYLE = "BLOCK" *) logic [DATA_WIDTH-1:0]          buffer_lut_x_mem [16-1:0];

generate
    for(i=0; i<16; i=i+1)begin: GEN_BUFFER_X
        always @(posedge clk or negedge rst_x) begin
            if(~rst_x)                              buffer_lut_x_mem[i] <= 'b0;
            else if(i_HPC_clear)                    buffer_lut_x_mem[i] <= 'b0;
            else if(lut_wr_cmd_r[i])                buffer_lut_x_mem[i] <= i_write_data_r;
        end
    end
endgenerate


(* keep = "true", mark_debug = "true" *)reg [255:0]  debug_bank0_x;
(* keep = "true", mark_debug = "true" *)reg [255:0]  debug_bank15_x;
always @(posedge clk or negedge rst_x) begin
    if(~rst_x)    begin
                                           debug_bank0_x    <='b0;
                                           debug_bank15_x   <='b0;
    end
    else  begin
                                           debug_bank0_x    <= buffer_lut_x_mem[0];
                                           debug_bank15_x   <= buffer_lut_x_mem[15];
    end

end


//Output signal generation
    assign o_args_reg_A = args_reg_A;
    assign o_args_reg_B = args_reg_B;
    assign o_args_reg_C = args_reg_C;

generate
  for(i=0;i<16;i=i+1) begin: ASSIGN_LUT_X
    assign o_args_reg_LUT_x[i]= buffer_lut_x_mem[i];
  end
endgenerate
    


endmodule