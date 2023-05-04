`timescale 1ns / 1ps
import aimc_lib::*;
module util_mon (
  input  logic clk,
  input  logic rst,
  input  cmd_t cmd,
  input  logic cmd_valid,
  input  logic mon_upd,
  output logic [7:0][5:0] aimc_ca_util);  // Reporting eight 6-bit CA utilization values

  // =========================== Signal Declarations ===========================
  // ! WARNING ! With counter increments of 100 and 4 ns clock period, 32-bit counters can only reliably operate within 171 ms window

  localparam [7:0] CNT_INC = GLOBAL_CLK == "CK_DIV1" ? 100 : 50;  // With CK_DIV2, each command corresponds to one actual command (50%) and one NOP (50%) instead of just one command (100%)

  struct packed {
    logic [31:0] write;      // Counter for WRITE commands: WOM, WDM, WRGB, WRBIAS, WRBK
    logic [31:0] read;       // Counter for READ commands: RD, RDMAC, RDAF
    logic [31:0] comp;       // Counter for COMPUTE commands: MACSB, MAC4B, MACAB, AF, EWMUL, RDCP, WRCP
    logic [31:0] opcl;       // Counter for OPEN/CLOSE commands: ACT, ACT4, ACT16, ACTAF4, ACTAF16, PREPB, PREAB, NDM(MRS)
    logic [31:0] refr;       // Counter for REFRESH commands: REFPB, REFAB, TEMP(MRS)
    logic [31:0] other;      // Counter for OTHER commands: MRS
  } util_cnt, util_cnt_nxt;

  // ========================== Utilization Counters ===========================
  always @(posedge clk, posedge rst)
    if (rst) util_cnt <= 0;
    else     util_cnt <= util_cnt_nxt;

  always_comb begin
    util_cnt_nxt = util_cnt;

    if (mon_upd) begin
      util_cnt_nxt = 0;
    end
    else if (cmd_valid) begin
      case (cmd)
        WOM, WDM, WRGB, WRBIAS, WRBK                                : util_cnt_nxt.write = util_cnt.write + CNT_INC;
        RD, RDMAC, RDAF                                             : util_cnt_nxt.read  = util_cnt.read  + CNT_INC;
        MACSB, MAC4B, MACAB, AF, EWMUL, RDCP, WRCP                  : util_cnt_nxt.comp  = util_cnt.comp  + CNT_INC;
        ACT, ACT4, ACT16, ACTAF4, ACTAF16, NDME, NDMX, PREPB, PREAB : util_cnt_nxt.opcl  = util_cnt.opcl  + CNT_INC;
        REFPB, REFAB, MRS_TEMP                                      : util_cnt_nxt.refr  = util_cnt.refr  + CNT_INC;
        NOP1                                                        : util_cnt_nxt       = util_cnt;
        default                                                     : util_cnt_nxt.other = util_cnt.other + CNT_INC;
      endcase
    end
  end

  always @(posedge clk, posedge rst)
    if (rst) begin
      aimc_ca_util <= 0;
    end
    else begin
      aimc_ca_util[7] <= (util_cnt.write >> AVG_SHIFT);
      aimc_ca_util[6] <= (util_cnt.read  >> AVG_SHIFT);
      aimc_ca_util[5] <= (util_cnt.comp  >> AVG_SHIFT);
      aimc_ca_util[4] <= (util_cnt.opcl  >> AVG_SHIFT);
      aimc_ca_util[3] <= (util_cnt.refr  >> AVG_SHIFT);
      aimc_ca_util[2] <= (util_cnt.other >> AVG_SHIFT);
      aimc_ca_util[1] <= 0;              // Reserved
      aimc_ca_util[0] <= 0;              // Reserved
    end

  // ============================== Initialization =============================
  initial begin
    util_cnt = 0;
    aimc_ca_util = 0;
  end

endmodule
