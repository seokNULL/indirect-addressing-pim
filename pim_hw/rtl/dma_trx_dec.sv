`timescale 1ps / 1ps

import axi_lib::*;
import aimc_lib::*;

module dma_trx_dec (
  input  logic clk,
  input  logic rst,
  // Parameter Interface
  input  addr_map_t ADDR_MAP,
  // AXI Bridge Interface
  output logic tdec_rdy,
  input  logic axbr_pgen_pkt_valid,
  input  trx_t axbr_pgen_pkt,
  // DMA Core Interface
  input  logic dcore_rdy,
  input  logic payload_op,
  output logic tdec_pkt_valid,
  output logic tdec_pkt_isrd,
  output addr_range_t tdec_addr_range,
  output logic [GPR_ADDR_WIDTH-1:0] tdec_gpr_addr,
  output logic [GPR_ADDR_WIDTH-1:0] tdec_gpr_addr_1,
  output logic [CFR_ADDR_WIDTH-1:0] tdec_cfr_addr,
  output logic [CH_NUM-1:0]         tdec_ch_mask,
  output logic [CH_ADDR_WIDTH-1:0]  tdec_ch_addr,
  output logic [BK_ADDR_WIDTH-1:0]  tdec_bk_addr,
  output logic [ROW_ADDR_WIDTH-1:0] tdec_row_addr,
  output logic [COL_ADDR_WIDTH-1:0] tdec_col_addr,
  output logic [MASK_WIDTH-1:0]     tdec_data_mask,
  output logic [DATA_WIDTH-1:0]     tdec_data,
  output aim_op_t                   tdec_isr_op,
  output logic [9:0]                tdec_isr_op_size,
  output logic                      tdec_isr_tcast,
  output logic [15:0]               tdec_isr_relu_slp,
  output logic [1:0]                tdec_isr_inc_ord,
  output logic                      tdec_isr_use_gpr,
  output logic                      tdec_isr_thr_idx);

  // =============================== Signal Declarations ===============================
  // Virtual-to-Physical Mapping
  logic [CH_NUM-1:0]         axbr_ch_mask;           // DRAM channel mask decoded from virtual address
  logic [CH_ADDR_WIDTH-1:0]  axbr_ch_addr;           // DRAM channel address decoded from virtual address
  logic [BK_ADDR_WIDTH-1:0]  axbr_bk_addr;           // DRAM bank address decoded from virtual address
  logic [ROW_ADDR_WIDTH-1:0] axbr_row_addr;          // DRAM row address decoded from virtual address
  logic [COL_ADDR_WIDTH-1:0] axbr_col_addr;          // DRAM column address decoded from virtual address
  // TRX Packet Decoder
  addr_range_t               tdec_addr_range_nxt;    // Specifies which range (DRAM, GPR, CFR, ISR) the packet is addressed to
  logic                      tdec_pkt_isrd_nxt;      // Flag indicating that memory request is read request
  logic [GPR_ADDR_WIDTH-1:0] tdec_gpr_addr_nxt;      // Primary GPR address extracted from trx packet address or ISR instruction
  logic [GPR_ADDR_WIDTH-1:0] tdec_gpr_addr_1_nxt;    // Secondary GPR address extracted from ISR instruction
  logic [CFR_ADDR_WIDTH-1:0] tdec_cfr_addr_nxt;      // CFR address extracted from trx packet addres
  logic [CH_NUM-1:0]         tdec_ch_mask_nxt;       // DRAM channel mask passed to DMA core
  logic [CH_ADDR_WIDTH-1:0]  tdec_ch_addr_nxt;       // DRAM channel address passed to DMA core
  logic [BK_ADDR_WIDTH-1:0]  tdec_bk_addr_nxt;       // DRAM bank address passed to DMA core
  logic [ROW_ADDR_WIDTH-1:0] tdec_row_addr_nxt;      // DRAM row address passed to DMA core
  logic [COL_ADDR_WIDTH-1:0] tdec_col_addr_nxt;      // DRAM column address passed to DMA core
  logic [MASK_WIDTH-1:0]     tdec_data_mask_nxt;     // DRAM data mask passed to DMA core
  logic [DATA_WIDTH-1:0]     tdec_data_nxt;          // DRAM data passed to DMA core
  aim_op_t                   tdec_isr_op_nxt;        // ISR opreation code
  logic [9:0]                tdec_isr_op_size_nxt;   // ISR operation size
  logic                      tdec_isr_tcast_nxt;     // Use type casting (fp32->bf16) during ISR write
  logic [15:0]               tdec_isr_relu_slp_nxt;  // Leaky ReLU slope to be programmed to Mode Registers
  logic [1:0]                tdec_isr_inc_ord_nxt;   // ISR address increment order during write
  logic                      tdec_isr_use_gpr_nxt;   // Flag indicating if GPR is involved in ISR operation
  logic                      tdec_isr_thr_idx_nxt;   // AiM thread index (used during ISR access)

  // =========================== Virtual-to-Physical Mapping ===========================
  always_comb begin
    axbr_ch_addr  = 0;
    axbr_bk_addr  = 0;
    axbr_row_addr = 0;
    axbr_col_addr = 0;

    case (ADDR_MAP)
      RoChBaCo : begin
        axbr_row_addr = axbr_pgen_pkt.addr[(15+CH_ADDR_WIDTH)+:14];
        axbr_ch_addr  = axbr_pgen_pkt.addr[15+:CH_ADDR_WIDTH];
        axbr_bk_addr  = axbr_pgen_pkt.addr[11+:4];
        axbr_col_addr = axbr_pgen_pkt.addr[5+:6];
      end
      RoCoBaCh : begin
        axbr_row_addr = axbr_pgen_pkt.addr[(15+CH_ADDR_WIDTH)+:14];
        axbr_col_addr = axbr_pgen_pkt.addr[(9+CH_ADDR_WIDTH)+:6];
        axbr_bk_addr  = axbr_pgen_pkt.addr[(5+CH_ADDR_WIDTH)+:4];
        axbr_ch_addr  = axbr_pgen_pkt.addr[5+:CH_ADDR_WIDTH];
      end
      ChRoBaCo : begin
        axbr_ch_addr  = axbr_pgen_pkt.addr[29+:CH_ADDR_WIDTH];
        axbr_row_addr = axbr_pgen_pkt.addr[15+:14];
        axbr_bk_addr  = axbr_pgen_pkt.addr[11+:4];
        axbr_col_addr = axbr_pgen_pkt.addr[5+:6];
      end
      ChRoCoBa : begin
        axbr_ch_addr  = axbr_pgen_pkt.addr[29+:CH_ADDR_WIDTH];
        axbr_row_addr = axbr_pgen_pkt.addr[15+:14];
        axbr_col_addr = axbr_pgen_pkt.addr[9+:6];
        axbr_bk_addr  = axbr_pgen_pkt.addr[5+:4];
      end
      /*
      New decoding schemes go here
      */
    endcase
  end

  // Composing channel mask from address
  always_comb begin
    axbr_ch_mask = 0;
    axbr_ch_mask[axbr_ch_addr] = 1'b1;
  end

  // ================================ TRX Packet Decoder ===============================
  // Assigning all decoder registers their "next" values
  always @(posedge clk, posedge rst)
    if (rst) begin
      tdec_pkt_valid <= 0;
    end
    else begin
      tdec_pkt_valid <= tdec_pkt_valid_nxt;
    end

  always @(posedge clk) begin
    if (axbr_pgen_pkt_valid && tdec_rdy) begin
      tdec_addr_range   <= tdec_addr_range_nxt;
      tdec_gpr_addr     <= tdec_gpr_addr_nxt;
      tdec_gpr_addr_1   <= tdec_gpr_addr_1_nxt;
      tdec_cfr_addr     <= tdec_cfr_addr_nxt;
      tdec_ch_mask      <= tdec_ch_mask_nxt;
      tdec_ch_addr      <= tdec_ch_addr_nxt;
      tdec_bk_addr      <= tdec_bk_addr_nxt;
      tdec_row_addr     <= tdec_row_addr_nxt;
      tdec_col_addr     <= tdec_col_addr_nxt;
      tdec_pkt_isrd     <= tdec_pkt_isrd_nxt;
      tdec_data_mask    <= tdec_data_mask_nxt;
      tdec_data         <= tdec_data_nxt;
      tdec_isr_op       <= tdec_isr_op_nxt;
      tdec_isr_op_size  <= tdec_isr_op_size_nxt;
      tdec_isr_tcast    <= tdec_isr_tcast_nxt;
      tdec_isr_relu_slp <= tdec_isr_relu_slp_nxt;
      tdec_isr_inc_ord  <= tdec_isr_inc_ord_nxt;
      tdec_isr_use_gpr  <= tdec_isr_use_gpr_nxt;
      tdec_isr_thr_idx  <= tdec_isr_thr_idx_nxt;
    end
  end

  // Readiness and validity signals
  assign tdec_pkt_valid_nxt = (axbr_pgen_pkt_valid && tdec_rdy) || (tdec_pkt_valid && !dcore_rdy);
  assign tdec_rdy = (!tdec_pkt_valid || tdec_addr_range != ISR_RANGE || payload_op) && dcore_rdy;

  // Deriving address range type from trx packet address
  always_comb begin
    tdec_addr_range_nxt = DRAM_RANGE;
    if (axbr_pgen_pkt.addr >= GPR_ADDR_0 && axbr_pgen_pkt.addr <= GPR_ADDR_1) tdec_addr_range_nxt = GPR_RANGE;
    if (axbr_pgen_pkt.addr >= CFR_ADDR_0 && axbr_pgen_pkt.addr <= CFR_ADDR_1) tdec_addr_range_nxt = CFR_RANGE;
    if (axbr_pgen_pkt.addr >= ISR_ADDR_0 && axbr_pgen_pkt.addr <= ISR_ADDR_1) tdec_addr_range_nxt = ISR_RANGE;
  end

  // Data, mask, and request type are passed "as is"
  assign tdec_pkt_isrd_nxt  = axbr_pgen_pkt.is_rd;
  assign tdec_data_mask_nxt = axbr_pgen_pkt.mask;
  assign tdec_data_nxt      = axbr_pgen_pkt.data;

  // Physical DRAM addresses depend on the address range, can be either decoded addresses or taken from the data (for AiM instructions)
  always_comb begin
    tdec_isr_op_nxt       = tdec_isr_op;
    tdec_isr_op_size_nxt  = tdec_isr_op_size;
    tdec_isr_tcast_nxt    = tdec_isr_tcast;
    tdec_isr_relu_slp_nxt = tdec_isr_relu_slp;
    tdec_isr_inc_ord_nxt  = tdec_isr_inc_ord;
    tdec_isr_use_gpr_nxt  = tdec_isr_use_gpr;
    tdec_gpr_addr_nxt     = tdec_gpr_addr;
    tdec_gpr_addr_1_nxt   = tdec_gpr_addr_1;
    tdec_isr_thr_idx_nxt  = tdec_isr_thr_idx;
    tdec_ch_mask_nxt      = tdec_ch_mask;
    tdec_ch_addr_nxt      = tdec_ch_addr;
    tdec_bk_addr_nxt      = tdec_bk_addr;
    tdec_row_addr_nxt     = tdec_row_addr;
    tdec_col_addr_nxt     = tdec_col_addr;
    tdec_cfr_addr_nxt     = tdec_cfr_addr;

    case (tdec_addr_range_nxt)
      DRAM_RANGE : begin
        tdec_ch_mask_nxt  = axbr_ch_mask;
        tdec_ch_addr_nxt  = axbr_ch_addr;
        tdec_bk_addr_nxt  = axbr_bk_addr;
        tdec_row_addr_nxt = axbr_row_addr;
        tdec_col_addr_nxt = axbr_col_addr;
      end
      GPR_RANGE : begin
        tdec_gpr_addr_nxt = (axbr_pgen_pkt.addr-GPR_ADDR_0) >> 5;       // One GPR address points to 2**5 = 32 bytes
      end
      CFR_RANGE : begin
        tdec_cfr_addr_nxt = (axbr_pgen_pkt.addr-CFR_ADDR_0) >> 5;       // One CFR address points to 2**5 = 32 bytes
      end
      ISR_RANGE : begin
        tdec_isr_op_nxt       = aim_op_t'(axbr_pgen_pkt.data[63:59]);   // Casting to aim_op_t type
        tdec_isr_op_size_nxt  = axbr_pgen_pkt.data[55:46];
        tdec_isr_tcast_nxt    = axbr_pgen_pkt.data[58];
        tdec_isr_relu_slp_nxt = axbr_pgen_pkt.data[57:42];
        tdec_isr_inc_ord_nxt  = axbr_pgen_pkt.data[57:56];
        tdec_isr_use_gpr_nxt  = axbr_pgen_pkt.data[45];
        tdec_gpr_addr_1_nxt   = axbr_pgen_pkt.data[24+:GPR_ADDR_WIDTH];
        tdec_isr_thr_idx_nxt  = axbr_pgen_pkt.data[32];
        tdec_bk_addr_nxt      = axbr_pgen_pkt.data[23:20];
        tdec_row_addr_nxt     = axbr_pgen_pkt.data[19:6];
        tdec_col_addr_nxt     = axbr_pgen_pkt.data[5:0];

        if (tdec_isr_op_nxt == ISR_WR_SBK || tdec_isr_op_nxt == ISR_RD_SBK) begin   // ISR_WR(RD)_SBK use unique data field arrangement
          tdec_ch_addr_nxt  = axbr_pgen_pkt.data[44:42];
          tdec_ch_mask_nxt  = 0;
          tdec_ch_mask_nxt[tdec_ch_addr_nxt] = 1'b1;
          tdec_gpr_addr_nxt = tdec_gpr_addr_1_nxt;
        end
        else begin
          tdec_ch_mask_nxt = axbr_pgen_pkt.data[31:24];
          tdec_ch_addr_nxt = 0;
          for (int i=CH_NUM-1; i>=0; i--)
            if (tdec_ch_mask_nxt[i]) tdec_ch_addr_nxt = i;
            
          tdec_gpr_addr_nxt = axbr_pgen_pkt.data[6+:GPR_ADDR_WIDTH];
        end
      end
    endcase
  end

  // ================================== Initialization =================================
  initial begin
    tdec_pkt_valid    = 0;
    tdec_addr_range   = DRAM_RANGE;
    tdec_gpr_addr     = 0;
    tdec_gpr_addr_1   = 0;
    tdec_cfr_addr     = 0;
    tdec_ch_mask      = 0;
    tdec_ch_addr      = 0;
    tdec_bk_addr      = 0;
    tdec_row_addr     = 0;
    tdec_col_addr     = 0;
    tdec_pkt_isrd     = 0;
    tdec_data_mask    = 0;
    tdec_data         = 0;
    tdec_isr_op       = ISR_WR_SBK;
    tdec_isr_op_size  = 0;
    tdec_isr_tcast    = 0;
    tdec_isr_relu_slp = 0;
    tdec_isr_inc_ord  = 0;
    tdec_isr_use_gpr  = 0;
    tdec_isr_thr_idx  = 0;
  end

endmodule
