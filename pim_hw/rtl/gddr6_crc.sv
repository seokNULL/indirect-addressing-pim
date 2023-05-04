`timescale 1ps / 1ps

module gddr6_crc (
  input  logic clk,
  input  logic crc_en,
  input  logic [127:0] crc_i,
  input  logic [7:0]   crc_dbi_n [1:0],
  output logic [7:0]   crc_o [1:0]);
  
  logic [71:0] crc_dq [1:0];

  always @(posedge clk) begin
    if (crc_en) begin
      for (int dq_bit=0; dq_bit<8; dq_bit++) begin
        for (int burst_idx=0; burst_idx<8; burst_idx++) begin
          crc_dq[0][dq_bit*8 + burst_idx] <= crc_i[dq_bit + burst_idx*16];
          crc_dq[1][dq_bit*8 + burst_idx] <= crc_i[8 + dq_bit + burst_idx*16];
        end
      end
      crc_dq[0][71:64] <= crc_dbi_n[0];
      crc_dq[1][71:64] <= crc_dbi_n[1];
    end
  end

  always @(posedge clk) begin
    crc_o[0] <= CRC_72TO8(crc_dq[0]);
    crc_o[1] <= CRC_72TO8(crc_dq[1]);
  end

  function logic [7:0] CRC_72TO8;
    input logic [71:0] D;
    begin
      CRC_72TO8[0] = D[69] ^ D[68] ^ D[67] ^ D[66] ^ D[64] ^ D[63] ^ D[60] ^ D[56] ^ D[54] ^ D[53] ^ D[52] ^ D[50] ^ D[49] ^ D[48] ^ D[45] ^ D[43] ^ D[40] ^ D[39] ^ D[35] ^ D[34] ^ D[31] ^ D[30] ^ D[28] ^ D[23] ^ D[21] ^ D[19] ^ D[18] ^ D[16] ^ D[14] ^ D[12] ^ D[8] ^ D[7] ^ D[6] ^ D[0] ;
      CRC_72TO8[1] = D[70] ^ D[66] ^ D[65] ^ D[63] ^ D[61] ^ D[60] ^ D[57] ^ D[56] ^ D[55] ^ D[52] ^ D[51] ^ D[48] ^ D[46] ^ D[45] ^ D[44] ^ D[43] ^ D[41] ^ D[39] ^ D[36] ^ D[34] ^ D[32] ^ D[30] ^ D[29] ^ D[28] ^ D[24] ^ D[23] ^ D[22] ^ D[21] ^ D[20] ^ D[18] ^ D[17] ^ D[16] ^ D[15] ^ D[14] ^ D[13] ^ D[12] ^ D[9] ^ D[6] ^ D[1] ^ D[0];
      CRC_72TO8[2] = D[71] ^ D[69] ^ D[68] ^ D[63] ^ D[62] ^ D[61] ^ D[60] ^ D[58] ^ D[57] ^ D[54] ^ D[50] ^ D[48] ^ D[47] ^ D[46] ^ D[44] ^ D[43] ^ D[42] ^ D[39] ^ D[37] ^ D[34] ^ D[33] ^ D[29] ^ D[28] ^ D[25] ^ D[24] ^ D[22] ^ D[17] ^ D[15] ^ D[13] ^ D[12] ^ D[10] ^ D[8] ^ D[6] ^ D[2] ^ D[1] ^ D[0];
      CRC_72TO8[3] = D[70] ^ D[69] ^ D[64] ^ D[63] ^ D[62] ^ D[61] ^ D[59] ^ D[58] ^ D[55] ^ D[51] ^ D[49] ^ D[48] ^ D[47] ^ D[45] ^ D[44] ^ D[43] ^ D[40] ^ D[38] ^ D[35] ^ D[34] ^ D[30] ^ D[29] ^ D[26] ^ D[25] ^ D[23] ^ D[18] ^ D[16] ^ D[14] ^ D[13] ^ D[11] ^ D[9] ^ D[7] ^ D[3] ^ D[2] ^ D[1];
      CRC_72TO8[4] = D[71] ^ D[70] ^ D[65] ^ D[64] ^ D[63] ^ D[62] ^ D[60] ^ D[59] ^ D[56] ^ D[52] ^ D[50] ^ D[49] ^ D[48] ^ D[46] ^ D[45] ^ D[44] ^ D[41] ^ D[39] ^ D[36] ^ D[35] ^ D[31] ^ D[30] ^ D[27] ^ D[26] ^ D[24] ^ D[19] ^ D[17] ^ D[15] ^ D[14] ^ D[12] ^ D[10] ^ D[8] ^ D[4] ^ D[3] ^ D[2];
      CRC_72TO8[5] = D[71] ^ D[66] ^ D[65] ^ D[64] ^ D[63] ^ D[61] ^ D[60] ^ D[57] ^ D[53] ^ D[51] ^ D[50] ^ D[49] ^ D[47] ^ D[46] ^ D[45] ^ D[42] ^ D[40] ^ D[37] ^ D[36] ^ D[32] ^ D[31] ^ D[28] ^ D[27] ^ D[25] ^ D[20] ^ D[18] ^ D[16] ^ D[15] ^ D[13] ^ D[11] ^ D[9] ^ D[5] ^ D[4] ^ D[3];
      CRC_72TO8[6] = D[67] ^ D[66] ^ D[65] ^ D[64] ^ D[62] ^ D[61] ^ D[58] ^ D[54] ^ D[52] ^ D[51] ^ D[50] ^ D[48] ^ D[47] ^ D[46] ^ D[43] ^ D[41] ^ D[38] ^ D[37] ^ D[33] ^ D[32] ^ D[29] ^ D[28] ^ D[26] ^ D[21] ^ D[19] ^ D[17] ^ D[16] ^ D[14] ^ D[12] ^ D[10] ^ D[6] ^ D[5] ^ D[4];
      CRC_72TO8[7] = D[68] ^ D[67] ^ D[66] ^ D[65] ^ D[63] ^ D[62] ^ D[59] ^ D[55] ^ D[53] ^ D[52] ^ D[51] ^ D[49] ^ D[48] ^ D[47] ^ D[44] ^ D[42] ^ D[39] ^ D[38] ^ D[34] ^ D[33] ^ D[30] ^ D[29] ^ D[27] ^ D[22] ^ D[20] ^ D[18] ^ D[17] ^ D[15] ^ D[13] ^ D[11] ^ D[7] ^ D[6] ^ D[5];
    end
  endfunction

  initial begin
    crc_dq = {0, 0};
    crc_o = {0, 0};
  end

endmodule
