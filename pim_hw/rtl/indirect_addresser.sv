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
    o_args_reg_C
);

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


localparam MM_INDIRECT_ARGS_A = 32'h0000_1000;
localparam MM_INDIRECT_ARGS_B = 32'h0000_2000;
localparam MM_INDIRECT_ARGS_C = 32'h0000_3000;

 
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



//Output signal generation
    assign o_args_reg_A = args_reg_A;
    assign o_args_reg_B = args_reg_B;
    assign o_args_reg_C = args_reg_C;
    

endmodule