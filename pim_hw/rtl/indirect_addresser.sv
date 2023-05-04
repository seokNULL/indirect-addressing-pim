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
// wire [31:0] desc_addr_h;
// wire [31:0] desc_addr_l;
// wire [31:0] desc_pim_opcode;
//     assign desc_addr_l = i_read_data_r[32*1-1: 32*0];
//     assign desc_addr_h = i_read_data_r[32*2-1: 32*1];
//     assign desc_pim_opcode = i_read_data_r[32*8-1:32*7];

// wire is_read_descr;
//     assign is_read_descr = (desc_addr_h[31:16] == 16'h0000) && 
//                            (desc_addr_h[15:0]  == 16'h0004) && 
//                            ((desc_addr_l[5:0]  == 6'b000011)||(desc_addr_l[5:0]   == 6'b000101)) &&
//                            (desc_addr_l[23:20] ==4'b1???) &&
//                            (desc_addr_l[31:24] ==8'h00);
// wire is_desc_A;
// wire is_desc_B;
// wire is_desc_C;
//     assign is_desc_A = is_read_descr && desc_pim_opcode[1];
//     assign is_desc_B = is_read_descr && desc_pim_opcode[2];
//     assign is_desc_C = is_read_descr && desc_pim_opcode[3];


// wire is_indirect;
// wire is_offset_immediate;
// wire is_offset_register;
//     assign is_indirect = is_read_descr &&  i_PIM_dev_working && i_read_data_r[0];
//     assign is_offset_immediate = is_read_descr &&  i_PIM_dev_working && i_read_data_r[1];
//     assign is_offset_register = is_read_descr &&  i_PIM_dev_working && i_read_data_r[2];

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


//Indirect address calculation
// reg [31:0] offset_in;
// always @(*) begin
//     if(is_offset_immediate && is_desc_A )           offset_in = i_read_data_r[32*3-1 :32*2];
//     else if(is_offset_immediate && is_desc_B )      offset_in = i_read_data_r[32*3-1 :32*2];
//     else if(is_offset_immediate && is_desc_C )      offset_in = i_read_data_r[32*5-1 :32*4];
//     else if(is_offset_register  && is_desc_B )      offset_in = i_read_data_r[32*3-1 :32*2];    
//     else                                            offset_in = 'b0;
// end

// reg [31:0] base_in;
// always @(*) begin
//     if(is_offset_immediate && is_desc_A)           base_in = args_reg_A;
//     else if(is_offset_immediate && is_desc_B)      base_in = args_reg_B;
//     else if(is_offset_immediate && is_desc_C)      base_in = args_reg_C;
//     else if(is_offset_register)                    base_in = args_reg_B;
//     else                                           base_in = 'b0;
// end

//Output signal generation
    assign o_args_reg_A = args_reg_A;
    assign o_args_reg_B = args_reg_B;
    assign o_args_reg_C = args_reg_C;
    

endmodule