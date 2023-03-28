module PIM_ALU_SYN_top(
  clk,
  rst_x,
  HPC_clear_sig,

  req_data,
  DRAM_data,

  src_A_RD_pass,
  src_B_RD_pass,
  dst_C_WR_pass,

  req_MM_vecA_write,

  bank_config,

  PIM_result

);

input                           clk;
input                           rst_x;

input                           HPC_clear_sig;

input  [255:0]                  req_data;
input  [255:0]                  DRAM_data;

input                           src_A_RD_pass;
input                           src_B_RD_pass;
input                           dst_C_WR_pass;

input                           req_MM_vecA_write;

input [27:0]                    bank_config;

output [255:0]                  PIM_result;


reg                          HPC_clear_sig_SYN;

reg [255:0]                  req_data_SYN;
reg [255:0]                  DRAM_data_SYN;

reg                          src_A_RD_pass_SYN;
reg                          src_B_RD_pass_SYN;
reg                          dst_C_WR_pass_SYN;

reg                          req_MM_vecA_write_SYN;

reg [27:0]                   bank_config_SYN;

reg [255:0]                  PIM_result;

wire [255:0]                 PIM_result_SYN;


always @(posedge clk or negedge rst_x) begin
  if (~rst_x) begin
                                                  HPC_clear_sig_SYN       <= 'b0;

                                                  req_data_SYN            <= 'b0;
                                                  DRAM_data_SYN           <= 'b0;

                                                  src_A_RD_pass_SYN       <= 'b0;
                                                  src_B_RD_pass_SYN       <= 'b0;
                                                  dst_C_WR_pass_SYN       <= 'b0;

                                                  req_MM_vecA_write_SYN   <= 'b0;

                                                  bank_config_SYN         <= 'b0;

                                                  PIM_result              <= 'b0;
  end
  else begin
                                                  
                                                  HPC_clear_sig_SYN       <= HPC_clear_sig;

                                                  req_data_SYN            <= req_data;
                                                  DRAM_data_SYN           <= DRAM_data;

                                                  src_A_RD_pass_SYN       <= src_A_RD_pass;
                                                  src_B_RD_pass_SYN       <= src_B_RD_pass;
                                                  dst_C_WR_pass_SYN       <= dst_C_WR_pass;

                                                  req_MM_vecA_write_SYN   <= req_MM_vecA_write;

                                                  //bank_config_SYN         <= bank_config;
                                                  bank_config_SYN         <= 28'h851F;

                                                  PIM_result              <= PIM_result_SYN;
  end
end  

bank_top_GDDR6 U0_BANK_GDDR6_TOP(
      .clk                            (clk                        ),
      .rst_x                          (rst_x                      ),

      .HPC_clear_sig                  (HPC_clear_sig_SYN          ),

      .req_data                       (req_data_SYN               ),
      .DRAM_data                      (DRAM_data_SYN              ),

      .src_A_RD_pass                  (src_A_RD_pass_SYN          ),
      .src_B_RD_pass                  (src_B_RD_pass_SYN          ),
      .dst_C_WR_pass                  (dst_C_WR_pass_SYN          ),

      .req_MM_vecA_write              (req_MM_vecA_write_SYN      ),

      .bank_config_reg                (bank_config_SYN            ),

      .PIM_result                     (PIM_result_SYN             )
    );

endmodule