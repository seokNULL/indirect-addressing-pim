`timescale 1ps / 1ps

import axi_lib::*;
import aimc_lib::*;

module dma_pgen (
  input  logic clk,
  input  logic rst,
  // QDR II+ Clocks and Interface
  input  logic qdrii_clk_n,
  input  logic qdrii_clk_p,
  input  logic sys_rst,
  output logic [17:0] qdrii_D,
  output logic qdrii_K_p,
  output logic qdrii_K_n,
  output logic [1:0] qdrii_BW_n,
  output logic qdrii_RPS_n,
  output logic qdrii_WPS_n,
  output logic qdrii_DOFF_n,
  output logic [20:0] qdrii_SA,
  input  logic [17:0] qdrii_Q,
  input  logic qdrii_CQ_p,
  input  logic qdrii_CQ_n,
  // Latency Monitor
  input  logic mon_upd,
  output logic [31:0] pkt_latency,
  input  logic resp_pkt_valid,
  input  logic resp_sink_rdy,
  input  logic resp_pkt_marker,
  // AXI4 Write Data Probe
  input  logic s_axi_wvalid,
  input  logic s_axi_wready,
  input  logic [31:0]  s_axi_awaddr,
  input  logic [255:0] s_axi_wdata,
  // Configuration Register
  output logic [$bits(cfr_mode_t)-1:0] cfr_mode_p,
  output logic [$bits(cfr_time_t)-1:0] cfr_time_p,
  output logic [$bits(cfr_refr_t)-1:0] cfr_refr_p,
  output logic [$bits(cfr_schd_t)-1:0] cfr_schd_p,
  // In-Flight Packet Counter
  input  logic infl_empty,
  // AXI Bridge Interface (in)
  output logic pgen_axbr_rdy,
  input  logic axbr_pgen_pkt_valid,
  input  trx_t axbr_pgen_pkt,
  // Ordering Engine Interface (out)
  input  logic orde_pgen_rdy,
  output logic pgen_orde_pkt_valid,
  output pkt_t pgen_orde_pkt,
  output logic [CH_ADDR_WIDTH-1:0] pgen_orde_pkt_ch_addr,
  // Orderign Engine Interface (GPR out)
  input  logic orde_dreg_rdy,
  output logic dreg_orde_pkt_valid,
  output pkt_t dreg_orde_pkt,
  // Ordering Engine Interface (in)
  output logic pgen_orde_rdy,
  input  logic orde_pgen_pkt_valid,
  input  pkt_t orde_pgen_pkt,
  // AiM Interconnect Interface (out)
  input  logic icnt_rdy,
  output logic pgen_icnt_pkt_valid,
  output pkt_t pgen_icnt_pkt,
  output logic [CH_NUM-1:0] pgen_icnt_pkt_ch_mask);

  // =============================== Signal Declarations ===============================
  // TRX Decoder
  addr_map_t ADDR_MAP;                                                  // DRAM address Map
  logic                      tdec_rdy;                                  // Trx decoder ready flag
  logic                      tdec_pkt_valid;                            // Trx decoder packet ready flag
  logic                      tdec_pkt_isrd;                             // Trx decoder packet is read packet
  addr_range_t               tdec_addr_range;                           // Address range type (DRAM, GPR, CFR, ISR)
  logic [GPR_ADDR_WIDTH-1:0] tdec_gpr_addr;                             // Primary GPR address
  logic [GPR_ADDR_WIDTH-1:0] tdec_gpr_addr_1;                           // Secondary GPR address (used for element-wise addition)
  logic [CFR_ADDR_WIDTH-1:0] tdec_cfr_addr;                             // CFR address
  logic [CH_NUM-1:0]         tdec_ch_mask;                              // DRAM channel mask
  logic [CH_ADDR_WIDTH-1:0]  tdec_ch_addr;                              // DRAM channel address
  logic [BK_ADDR_WIDTH-1:0]  tdec_bk_addr;                              // DRAM bank address
  logic [ROW_ADDR_WIDTH-1:0] tdec_row_addr;                             // DRAM row address
  logic [COL_ADDR_WIDTH-1:0] tdec_col_addr;                             // DRAM column address
  logic [MASK_WIDTH-1:0]     tdec_data_mask;                            // DRAM data mask (only used for write commands)
  logic [DATA_WIDTH-1:0]     tdec_data;                                 // DRAM data (only used for write commands)
  aim_op_t                   tdec_isr_op;                               // ISR operation code (only used during ISR access)
  logic [9:0]                tdec_isr_op_size;                          // ISR operation size (only used during ISR access)
  logic                      tdec_isr_tcast;                            // Use type casting (fp32->bf16) during ISR write
  logic [15:0]               tdec_isr_relu_slp;                         // Leaky ReLU slope (bfloat16 value)
  logic [1:0]                tdec_isr_inc_ord;                          // ISR address increment order during write
  logic                      tdec_isr_use_gpr;                          // ISR operation requires GPR access (only used during ISR access)
  logic                      tdec_isr_thr_idx;                          // AiM thread index (used during ISR access)
  // General Purpose Register (GPR)
  logic [GPR_ADDR_WIDTH-1:0] gpr_addr;                                  // GPR address
  logic gpr_we;                                                         // GPR write enable signal
  logic gpr_re;                                                         // GPR read enable signal
  logic gpr_en;                                                         // Overall GPR enable signal (must be asserted with either gpr_we or gpr_re)
  logic [DATA_WIDTH/8-1:0] gpr_mask;                                    // GPR input data mask
  logic [DATA_WIDTH-1:0]   gpr_din;                                     // GPR input data
  logic [DATA_WIDTH-1:0]   gpr_dout;                                    // GPR output data
  enum logic [1:0] {GPR_DATA_TDEC=0, GPR_DATA_TCAST, 
                    GPR_DATA_ORDE, GPR_DATA_EWADD} gpr_din_sel, gpr_din_sel_nxt;  // GPR input data selector
  logic [1:0] gpr_cmd, gpr_cmd_nxt;                                     // Command passed to QDR II+ GPR (00: WRITE single range, 01: READ single range, 10: WRITE double range, 11: READ double range)
  logic [9:0] gpr_opsize, gpr_opsize_nxt;                               // Operation size passed to QDR II+ GPR
  logic gpr_ca_full;                                                    // QDR II+ GPR CA input FIFO full flag
  logic gpr_ca_wr;                                                      // Write enable for QDR II+ GPR CA FIFO
  logic gpr_din_full;                                                   // QDR II+ GPR DIN input FIFO full flag
  logic gpr_din_afull;                                                  // QDR II+ GPR DIN input FIFO "almost full" flag
  logic gpr_din_wr;                                                     // Write enable for QDR II+ GPR DIN FIFO
  logic gpr_dout_empty;                                                 // QDR II+ GPR DOUT output FIFO empty flag
  logic gpr_dout_rd;                                                    // Read enable for QDR II+ GPR DOUT FIFO
  logic [15:0] gpr_rd_cntr;
  logic [15:0] gpr_rd_cntr_nxt;
  // Configuration Register (CFR)
  logic [CFR_ADDR_WIDTH-1:0] cfr_addr, cfr_addr_nxt;
  logic cfr_we;
  logic cfr_re;
  logic [DATA_WIDTH/8-1:0]      cfr_mask, cfr_mask_nxt;
  logic [DATA_WIDTH-1:0]        cfr_din, cfr_din_nxt;
  logic [DATA_WIDTH-1:0]        cfr_dout;
  logic [$bits(cfr_adma_t)-1:0] cfr_adma_p;
  cfr_mode_t cfr_mode;
  cfr_adma_t cfr_adma;
  // Instruction Set Register (ISR)
  logic                      isr_tcast,         isr_tcast_nxt;          // ISR fp32->bf16 type cast request
  logic                      isr_tcast_rdy_val, isr_tcast_rdy_val_nxt;  // Value of the ISR op counter LSB at which type casted data should be sent to memory (differs between even and odd OPSIZE)
  logic [1:0]                isr_inc_ord,       isr_inc_ord_nxt;        // ISR address increment style, 00: COL-then-ROW, 01: COL-then-BK, 10: CH-then-COL, 11: RESERVED
  logic [9:0]                isr_op_size,       isr_op_size_nxt;        // ISR operation size
  logic [9:0]                isr_op_cnt,        isr_op_cnt_nxt;         // ISR operation counter based on the OPSIZE field
  logic [GPR_ADDR_WIDTH-1:0] isr_gpr_addr,      isr_gpr_addr_nxt;       // GPR addressed passed in the ISR instruction
  logic [CH_ADDR_WIDTH-1:0]  isr_ch_addr,       isr_ch_addr_nxt;        // ISR DRAM channel address
  logic [CH_NUM-1:0]         isr_ch_mask,       isr_ch_mask_nxt;        // ISR DRAM channel mask
  logic [BK_ADDR_WIDTH-1:0]  isr_bk_addr,       isr_bk_addr_nxt;        // ISR DRAM bank address
  logic [ROW_ADDR_WIDTH-1:0] isr_row_addr,      isr_row_addr_nxt;       // ISR DRAM row address
  logic [COL_ADDR_WIDTH-1:0] isr_col_addr,      isr_col_addr_nxt;       // ISR DRAM column address
  logic                      copy_dir,          copy_dir_nxt;           // Copy direction for ISR_COPY_... instructions
  // Element-Wise Adder
  logic ewadd_a_full = 1'b0;                                            // Full flag from A operand queue
  logic ewadd_a_wr;                                                     // Write enable signal for A operand queue
  logic [DATA_WIDTH-1:0] ewadd_a_din;                                   // A operand array
  logic ewadd_b_full = 1'b0;                                            // Full flag from B operand queue
  logic ewadd_b_wr;                                                     // Write enable signal for B operand queue
  logic [DATA_WIDTH-1:0] ewadd_b_din;                                   // B operand array
  logic ewadd_c_empty = 1'b1;                                           // Empty flag from EWADD result queue
  logic ewadd_c_rd;                                                     // Read enable signal for EWADD result queue
  logic [DATA_WIDTH-1:0] ewadd_c_dout = 'b0;                            // EWADD result
  logic ewadd_in_sel, ewadd_in_sel_nxt;                                 // Selector signal for writing ewadd operands
  logic [GPR_ADDR_WIDTH-1:0] isr_a_addr, isr_a_addr_nxt;                // Operand A address counter
  logic [GPR_ADDR_WIDTH-1:0] isr_b_addr, isr_b_addr_nxt;                // Operand B address counter
  logic [GPR_ADDR_WIDTH-1:0] isr_c_addr, isr_c_addr_nxt;                // EWADD result address counter
  logic [9:0]                isr_c_cnt, isr_c_cnt_nxt;                  // Dedicated EWADD operation counter
  // Latency Monitor
  logic pkt_marker;                                                     // Signal for marking packets for latency monitoring
  logic [7:0]  latency_min;                                             // Minimum latency registered during read-out period
  logic [7:0]  latency_max;                                             // Maximum latency registered during read-out period
  logic [15:0] latency_pkt_cnt;                                         // Number of packets used for latency registrion during read-out period
  // DMA Debugger
  logic gpr_is_dbg, gpr_is_dbg_nxt;                                     // Signal for directing GPR read requests to the debugger
  logic dbg_cmd_valid;                                                  // Validity signal for the debugger commands
  logic [1:0] dbg_cmd;                                                  // Debugger command
  logic dbg_re;                                                         // Read enable signal for the debugger memory
  logic [DATA_WIDTH-1:0] dbg_dout;                                      // Debugger memory data output
  // FP32-BF16 Type Casting
  logic tcast_store;
  logic [DATA_WIDTH-1:0] tcast_fp32;
  logic [DATA_WIDTH-1:0] tcast_bf16;
  // DMA Core
  typedef enum logic [4:0] {DCORE_IDLE=0, DCORE_RD_GPR, DCORE_WR_GPR, DCORE_RD_CFR, DCORE_WR_CFR, DCORE_CFR_MRS, DCORE_WR_SBK_GPR,
                            DCORE_WR_SBK_HOST, DCORE_WR_HBK, DCORE_WR_GB_GPR, DCORE_WR_GB_HOST, DCORE_WR_BIAS, DCORE_WR_AFLUT,
                            DCORE_RD_MAC, DCORE_RD_AF, DCORE_COPY, DCORE_MAC_SBK, DCORE_MAC_HBK, DCORE_MAC_ABK,
                            DCORE_AF, DCORE_EWMUL, DCORE_EWADD_QDRII, DCORE_EWADD_BLOCK, DCORE_RD_SBK} dcore_state_t;
  dcore_state_t dcore_state, dcore_state_nxt;                           // DMA core state
  logic dcore_rdy, dcore_rdy_nxt;                                       // DMA core ready flag
  logic payload_op_nxt, payload_op;                                     // Indicator for ISR operations that are waiting for payload (e.g. ISR_WR_SBK_HOST)
  logic [1:0] step, step_nxt;                                           // Auxiliary state variable for sequential sub-operation execution
  logic pgen_orde_rdy_nxt;

  // GDDR6/AiM Mode Registers
  logic [ROW_ADDR_WIDTH-1:0] mr0_op;                                    // OPCODE for MR0, using 14 bits instaed of 11 since it is passed as a row address
  logic [ROW_ADDR_WIDTH-1:0] mr4_op;                                    // OPCODE for MR4, using 14 bits instaed of 11 since it is passed as a row address
  logic [ROW_ADDR_WIDTH-1:0] mr13_op;                                   // OPCODE for MR13, using 14 bits instaed of 11 since it is passed as a row address
  logic [2:0]                mr13_afm,      mr13_afm_nxt;               // MR13[10:8], Activation Function Mode
  logic [ROW_ADDR_WIDTH-1:0] mr14_op;                                   // OPCODE for MR14, using 14 bits instaed of 11 since it is passed as a row address
  logic                      mr14_thrd,     mr14_thrd_nxt;              // MR14[0], AiM Thread Index
  logic [ROW_ADDR_WIDTH-1:0] mr15_op;                                   // OPCODE for MR15, using 14 bits instead of 11 since it is passed as a row address
  logic [15:0]               mr15_relu_slp, mr15_relu_slp_nxt;          // MR15[11:6], Leaky ReLU Slope (bfloat16 value)
  logic [1:0]                mr15_page,     mr15_page_nxt;              // MR15[5:4], Page Index used for programming Leaky ReLU Slope in multiple interations
  logic                      curr_thrd,     curr_thrd_nxt;              // Thread index currently set in the AiM
  // Exit Queue
  struct packed {
    logic dest;                                                         // Exit queue packet destination, 0: DRAM, 1: ORDE
    logic isrd;                                                         // Exit queue packet is a read packet
    logic [CH_NUM-1:0] ch_mask;                                         // Exit queue packet channel mask or channel address (depends on the context)
    pkt_t pkt;                                                          // Exit queue packet
  } exit_que_din, exit_que_dout;                                        // Exit queue data input and output
  logic exit_que_wr;                                                    // Exit queue write enable signal
  logic exit_que_rd;                                                    // Exit queue read enable signal
  logic exit_que_empty;                                                 // Exit queue empty flag
  logic exit_que_pfull;                                                 // Exit queue programmable full flag
  enum logic [1:0] {EXIT_DATA_TDEC=0, EXIT_DATA_GPR, 
                    EXIT_DATA_CFR, EXIT_DATA_TCAST} exit_que_din_sel, exit_que_din_sel_nxt;  // Exit queue packet input data selector

  // =================================== TRX Decoder ===================================
  dma_trx_dec dma_trx_dec (
    .clk,
    .rst,
    // Parameter Interface
    .ADDR_MAP,
    // AXI Bridge Interface
    .tdec_rdy,
    .axbr_pgen_pkt_valid,
    .axbr_pgen_pkt,
    // DMA Core Interface
    .dcore_rdy,
    .payload_op,
    .tdec_pkt_valid,
    .tdec_pkt_isrd,
    .tdec_addr_range,
    .tdec_gpr_addr,
    .tdec_gpr_addr_1,
    .tdec_cfr_addr,
    .tdec_ch_mask,
    .tdec_ch_addr,
    .tdec_bk_addr,
    .tdec_row_addr,
    .tdec_col_addr,
    .tdec_data_mask,
    .tdec_data,
    .tdec_isr_op,
    .tdec_isr_op_size,
    .tdec_isr_tcast,
    .tdec_isr_relu_slp,
    .tdec_isr_inc_ord,
    .tdec_isr_use_gpr,
    .tdec_isr_thr_idx);

  assign ADDR_MAP = cfr_adma.ADDR_MAP;
  assign pgen_axbr_rdy = tdec_rdy;

  // ========================= General Purpose Register (GPR) ==========================
  genvar i;
  generate
    if (GPR_STYLE == "BLOCK") begin
      xpm_memory_spram #(
        .ADDR_WIDTH_A        (GPR_ADDR_WIDTH),
        .AUTO_SLEEP_TIME     (0),
        .BYTE_WRITE_WIDTH_A  (8),                      // Byte-wide mask used
        .CASCADE_HEIGHT      (0),
        .ECC_MODE            ("no_ecc"),
        .MEMORY_INIT_FILE    ("none"),
        .MEMORY_INIT_PARAM   ("0"),
        .MEMORY_OPTIMIZATION ("true"),
        .MEMORY_PRIMITIVE    ("ultra"),
        .MEMORY_SIZE         (2**GPR_ADDR_WIDTH*256),  // Memory array size in bits (assuming 32-byte access granularity)
        .MESSAGE_CONTROL     (0),
        .READ_DATA_WIDTH_A   (256),                    // Assuming 32-byte access granularity (the same as in DRAM)
        .READ_LATENCY_A      (1),
        .READ_RESET_VALUE_A  ("0"),
        .RST_MODE_A          ("SYNC"),
        .SIM_ASSERT_CHK      (0),
        .USE_MEM_INIT        (1),
        .WAKEUP_TIME         ("disable_sleep"),
        .WRITE_DATA_WIDTH_A  (256),
        .WRITE_MODE_A        ("read_first"))
      gpr_mem (
        .dbiterra            (),
        .douta               (gpr_dout),
        .sbiterra            (),
        .addra               (gpr_addr),
        .clka                (clk),
        .dina                (gpr_din),
        .ena                 (gpr_en),
        .injectdbiterra      (1'b0),
        .injectsbiterra      (1'b0),
        .regcea              (1'b1),
        .rsta                (rst),
        .sleep               (1'b0),
        .wea                 (gpr_mask));

      assign gpr_en = gpr_re || gpr_we;

      // Signals unused in BLOCK GPR
      assign gpr_ca_full    = 0;
      assign gpr_din_full   = 0;
      assign gpr_din_afull  = 0;
      assign gpr_dout_empty = 0;

      // Dummy QDR II+ Output Buffers (to stop the implementation tool from complaining)
      OBUFDS OBUFDS_K    (.I (0), .O (qdrii_K_p), .OB (qdrii_K_n));

      OBUF   OBUF_RPS_n  (.O (qdrii_RPS_n),  .I (1));
      OBUF   OBUF_WPS_n  (.O (qdrii_WPS_n),  .I (1));
      OBUF   OBUF_DOFF_n (.O (qdrii_DOFF_n), .I (1));
      for (i=0; i<18; i++)
        OBUF OBUF_D    (.O (qdrii_D[i]),    .I (0));
      for (i=0; i<2; i++)
        OBUF OBUF_BW_n (.O (qdrii_BW_n[i]), .I (1));
      for (i=0; i<21; i++)
        OBUF OBUF_SA   (.O (qdrii_SA[i]),   .I (0));
    end
  endgenerate

  // WARNING: "gpr_din" is a very lare multiplexer, use additional pipe registers if it keeps failing the timing
  always_comb begin
    case (gpr_din_sel)
      default : begin
        gpr_din = tdec_data;
        for (int i=0; i<DATA_WIDTH/8; i=i+2) begin      // Using one mask bit for two data bytes
          gpr_mask[i]   = gpr_we && tdec_data_mask[i/2];
          gpr_mask[i+1] = gpr_we && tdec_data_mask[i/2];
        end
      end
      GPR_DATA_TCAST : begin
        gpr_din  = tcast_bf16;
        gpr_mask = GPR_STYLE == "QDRII" ? {(DATA_WIDTH/8){1'b1}} : {(DATA_WIDTH/8){gpr_we}};
      end
      GPR_DATA_ORDE : begin
        gpr_din  = orde_pgen_pkt.data;
        gpr_mask = GPR_STYLE == "QDRII" ? {(DATA_WIDTH/8){1'b1}} : {(DATA_WIDTH/8){gpr_we}};
      end
      GPR_DATA_EWADD : begin
        //gpr_din  = ewadd_c_dout;
        gpr_din  = 'b0;
        gpr_mask = GPR_STYLE == "QDRII" ? {(DATA_WIDTH/8){1'b1}} : {(DATA_WIDTH/8){gpr_we}};
      end
    endcase
  end

  // ========================== Configuration Register (CFR) ===========================
  config_reg config_reg (
    .clk,
    .rst,
    .cfr_we,
    .cfr_re,
    .cfr_addr (cfr_re ? tdec_cfr_addr : cfr_addr),
    .cfr_mask,
    .cfr_din,
    .cfr_dout,
    .cfr_mode_p,
    .cfr_time_p,
    .cfr_refr_p,
    .cfr_schd_p,
    .cfr_adma_p);

  assign cfr_mode = cfr_mode_t'(cfr_mode_p);
  assign cfr_adma = cfr_adma_t'(cfr_adma_p);

  // ============================= FP32-BF16 Type Casting ==============================
  fp32_bf16 fp32_bf16 (
    .clk,
    .store  (tcast_store),
    .fp32_i (tcast_fp32),
    .bf16_o (tcast_bf16));

  assign tcast_fp32 = tdec_data;

  // =================================== Exit Queue ====================================
  xpm_fifo_sync #(
    .DOUT_RESET_VALUE    ("0"),
    .ECC_MODE            ("no_ecc"),
    .FIFO_MEMORY_TYPE    ("block"),
    .FIFO_READ_LATENCY   (0),
    .FIFO_WRITE_DEPTH    (16),
    .FULL_RESET_VALUE    (0),
    .PROG_EMPTY_THRESH   (5),
    .PROG_FULL_THRESH    (11),
    .RD_DATA_COUNT_WIDTH (),
    .READ_DATA_WIDTH     ($bits(pkt_t)+CH_NUM+2),
    .READ_MODE           ("fwft"),
    .SIM_ASSERT_CHK      (0),
    .USE_ADV_FEATURES    ("0002"),  // USE_AD_FEATURES[1] enables programmable full threshold
    .WAKEUP_TIME         (0),
    .WR_DATA_COUNT_WIDTH (),
    .WRITE_DATA_WIDTH    ($bits(pkt_t)+CH_NUM+2))
  exit_que (
    .almost_empty        (),
    .almost_full         (),
    .data_valid          (),
    .dbiterr             (),
    .dout                (exit_que_dout),
    .empty               (exit_que_empty),
    .full                (),
    .overflow            (),
    .prog_empty          (),
    .prog_full           (exit_que_pfull),
    .rd_data_count       (),
    .rd_rst_busy         (),
    .sbiterr             (),
    .underflow           (),
    .wr_ack              (),
    .wr_data_count       (),
    .wr_rst_busy         (),
    .din                 (exit_que_din),
    .injectdbiterr       (1'b0),
    .injectsbiterr       (1'b0),
    .rd_en               (exit_que_rd),
    .rst                 (rst),
    .sleep               (1'b0),
    .wr_clk              (clk),
    .wr_en               (exit_que_wr));

    assign exit_que_rd  = !exit_que_empty && ((!exit_que_dout.isrd && icnt_rdy) || (exit_que_dout.dest ? orde_dreg_rdy : (icnt_rdy && orde_pgen_rdy)));  // If WRITE, only care about icnt_rdy, if READ, look at icnt for dram and orde for dreg packets
    // Output packet validity signals
    assign pgen_orde_pkt_valid   = !exit_que_empty && exit_que_dout.isrd && (exit_que_dout.dest ? orde_dreg_rdy : icnt_rdy);
    assign pgen_icnt_pkt_valid   = !exit_que_empty && (!exit_que_dout.isrd || (!exit_que_dout.dest && orde_pgen_rdy));        // If READ, assert interconnect valid (exit_que_dout.dest=0) only when ordering engine can accept ordering request (orde_pgen_rdy=1)
    assign dreg_orde_pkt_valid   = !exit_que_empty && exit_que_dout.isrd && exit_que_dout.dest;                               // Assert dma reg outbound packet validity if ordering engine is ready to receive ordering request
    // Output packet constructor
    assign pgen_orde_pkt         = exit_que_dout.pkt;                         // Duplicating exit queue packet to all outputs: interconnect, orde request input, orde data input (gpr, cfr)
    assign pgen_orde_pkt_ch_addr = exit_que_dout.ch_mask[CH_ADDR_WIDTH-1:0];  // Also duplicating exit queue channel address
    assign pgen_icnt_pkt         = exit_que_dout.pkt;
    assign pgen_icnt_pkt_ch_mask = exit_que_dout.ch_mask;                     // Using pgen_icnt_pkt_ch_mask for carrying both channel address and mask (depends on the situation)
    assign dreg_orde_pkt         = exit_que_dout.pkt;

  // =============================== Element-Wise Adder ================================
//  ewadd ewadd (
//    .clk,
//    .rst,
//    .a_que_full  (ewadd_a_full),
//    .a_que_wr    (ewadd_a_wr),
//    .a_que_din   (ewadd_a_din),
//    .b_que_full  (ewadd_b_full),
//    .b_que_wr    (ewadd_b_wr),
//    .b_que_din   (ewadd_b_din),
//    .c_que_rd    (ewadd_c_rd),
//    .c_que_empty (ewadd_c_empty),
//    .c_que_dout  (ewadd_c_dout));

  assign ewadd_a_din = gpr_dout;  // Both A and B operands are passed from the GPR
  assign ewadd_b_din = gpr_dout;

  // ================================= Latency Monitor =================================
  generate
    if (LATENCY_MON_EN == "TRUE") begin
      latency_mon latency_mon (
        .clk,
        .rst,
        .pkt_marker,
        .req_pkt_valid,
        .req_sink_rdy,
        .resp_pkt_valid,
        .resp_sink_rdy,
        .resp_pkt_marker,
        .mon_upd,
        .latency_min,
        .latency_max,
        .latency_pkt_cnt);

      assign req_pkt_valid = exit_que_wr && !exit_que_din.dest;  // "dest = 0" means packet is sent to the Interconnect
      assign req_sink_rdy  = exit_que_wr && !exit_que_din.dest;
      assign pkt_latency   = {latency_min, latency_max, latency_pkt_cnt};
    end
    else if (LATENCY_MON_EN == "FALSE") begin
      assign pkt_marker    = 0;
      assign pkt_latency   = 0;
    end
  endgenerate

  // ================================== DMA Debugger ===================================
  generate
    if (DMA_DEBUG_EN == "TRUE") begin
      dma_debug dma_debug (
        .clk,
        .rst,
        // AXI4 Write Data Probe
        .s_axi_wvalid,
        .s_axi_wready,
        .s_axi_awaddr,
        .s_axi_wdata,
        // AiM DMA Interface
        .dbg_cmd_valid,
        .dbg_cmd,
        .dbg_re,
        .dbg_addr (gpr_addr[DBG_ADDR_WIDTH-1:0]),
        .dbg_dout);
    end
    else if (DMA_DEBUG_EN == "FALSE") begin
      assign dbg_dout_valid = 0;
      assign dbg_dout = 0;
    end
  endgenerate

  // ===================================================================================
  //                                      DMA Core 
  // ===================================================================================
  always @(posedge clk, posedge rst)
    if (rst) begin
      // DMA Core Control
      dcore_state       <= DCORE_IDLE;
      dcore_rdy         <= 1;
      step              <= 0;
      pgen_orde_rdy     <= 0;
      payload_op        <= 0;
      gpr_rd_cntr       <= 0;
      // General Purpose Register (GPR)
      gpr_din_sel       <= GPR_DATA_TDEC;
      gpr_cmd           <= 0;
      gpr_opsize        <= 0;
      // Instruction Set Register (ISR)
      isr_tcast         <= 0;
      isr_tcast_rdy_val <= 0;
      isr_inc_ord       <= 0;
      isr_op_size       <= 0;
      isr_op_cnt        <= 0;
      isr_gpr_addr      <= 0;
      isr_ch_addr       <= 0;
      isr_ch_mask       <= 0;
      isr_bk_addr       <= 0;
      isr_row_addr      <= 0;
      isr_col_addr      <= 0;
      copy_dir          <= 0;
      // Element-Wise Adder
      ewadd_in_sel      <= 0;
      isr_a_addr        <= 0;
      isr_b_addr        <= 0;
      isr_c_addr        <= 0;
      isr_c_cnt         <= 0;
      // DMA Debugger
      gpr_is_dbg        <= 0;
      // GDDR6/AiM Mode Registers
      mr13_afm          <= 0;
      mr14_thrd         <= 0;
      mr15_relu_slp     <= 0;
      mr15_page         <= 0;
      curr_thrd         <= 0;
      // Exit Queue
      exit_que_din_sel  <= EXIT_DATA_TDEC;
    end
    else begin
      // DMA Core Control
      dcore_state       <= dcore_state_nxt;
      dcore_rdy         <= dcore_rdy_nxt;
      step              <= step_nxt;
      pgen_orde_rdy     <= pgen_orde_rdy_nxt;
      payload_op        <= payload_op_nxt;
      gpr_rd_cntr       <= gpr_rd_cntr_nxt;
      // General Purpose Register (GPR)
      gpr_din_sel       <= gpr_din_sel_nxt;
      gpr_cmd           <= gpr_cmd_nxt;
      gpr_opsize        <= gpr_opsize_nxt;
      // Instruction Set Register (ISR)
      isr_tcast         <= isr_tcast_nxt;
      isr_tcast_rdy_val <= isr_tcast_rdy_val_nxt;
      isr_inc_ord       <= isr_inc_ord_nxt;
      isr_op_size       <= isr_op_size_nxt;
      isr_op_cnt        <= isr_op_cnt_nxt;
      isr_gpr_addr      <= isr_gpr_addr_nxt;
      isr_ch_mask       <= isr_ch_mask_nxt;
      isr_ch_addr       <= isr_ch_addr_nxt;
      isr_bk_addr       <= isr_bk_addr_nxt;
      isr_row_addr      <= isr_row_addr_nxt;
      isr_col_addr      <= isr_col_addr_nxt;
      copy_dir          <= copy_dir_nxt;
      // Element-Wise Adder
      ewadd_in_sel      <= ewadd_in_sel_nxt;
      isr_a_addr        <= isr_a_addr_nxt;
      isr_b_addr        <= isr_b_addr_nxt;
      isr_c_addr        <= isr_c_addr_nxt;
      isr_c_cnt         <= isr_c_cnt_nxt;
      // DMA Debugger
      gpr_is_dbg        <= gpr_is_dbg_nxt;
      // GDDR6/AiM Mode Registers
      mr13_afm          <= mr13_afm_nxt;
      mr14_thrd         <= mr14_thrd_nxt;
      mr15_relu_slp     <= mr15_relu_slp_nxt;
      mr15_page         <= mr15_page_nxt;
      curr_thrd         <= curr_thrd_nxt;
      // Exit Queue
      exit_que_din_sel  <= exit_que_din_sel_nxt;
    end

  // Configuration Register (CFR)
  always @(posedge clk) begin
    cfr_addr <= cfr_addr_nxt;
    cfr_mask <= cfr_mask_nxt;
    cfr_din  <= cfr_din_nxt;
  end

  always_comb begin
    //
    //              |\      _,,,---,,_
    //        ZZZzz /,`.-'`'    -.  ;-;;,_
    //             |,4-  ) )-,_. ,\ (  `'-'
    //            '---''(_/--'  `-'\_)
    //      Default DMA Core Value Initialization
    //
    // default: DMA Core Control
    dcore_state_nxt       = dcore_state;
    dcore_rdy_nxt         = dcore_rdy;
    step_nxt              = step;
    pgen_orde_rdy_nxt     = pgen_orde_rdy;
    payload_op_nxt        = payload_op;
    // default: General Purpose Register (GPR)
    gpr_re                = 0;
    gpr_we                = 0;
    gpr_addr              = tdec_gpr_addr;
    gpr_din_sel_nxt       = gpr_din_sel;

    gpr_cmd_nxt           = gpr_cmd;
    gpr_opsize_nxt        = gpr_opsize;
    gpr_ca_wr             = 0;
    gpr_dout_rd           = 0;
    gpr_rd_cntr_nxt       = gpr_rd_cntr;
    // default: Configuration Register (CFR)
    cfr_re                = 0;
    cfr_we                = 0;
    cfr_addr_nxt          = cfr_addr;
    cfr_mask_nxt          = cfr_mask;
    cfr_din_nxt           = cfr_din;
    // default: Instruction Set Register (ISR)
    isr_tcast_nxt         = isr_tcast;
    isr_tcast_rdy_val_nxt = isr_tcast_rdy_val;
    isr_inc_ord_nxt       = isr_inc_ord;
    isr_op_size_nxt       = isr_op_size;
    isr_op_cnt_nxt        = isr_op_cnt;
    isr_gpr_addr_nxt      = isr_gpr_addr;
    isr_ch_addr_nxt       = isr_ch_addr;
    isr_ch_mask_nxt       = isr_ch_mask;
    isr_bk_addr_nxt       = isr_bk_addr;
    isr_row_addr_nxt      = isr_row_addr;
    isr_col_addr_nxt      = isr_col_addr;
    copy_dir_nxt          = copy_dir;
    // default : Element-Wise Adder
    ewadd_a_wr            = 0;
    ewadd_b_wr            = 0;
    ewadd_c_rd            = 0;
    ewadd_in_sel_nxt      = ewadd_in_sel;
    isr_a_addr_nxt        = isr_a_addr;
    isr_b_addr_nxt        = isr_b_addr;
    isr_c_addr_nxt        = isr_c_addr;
    isr_c_cnt_nxt         = isr_c_cnt;
    // default: DMA Debugger
    gpr_is_dbg_nxt        = DMA_DEBUG_EN == "TRUE" ? gpr_is_dbg : 0;
    dbg_cmd_valid         = 0;
    dbg_cmd               = 0;
    dbg_re                = 0;
    // default: FP32->BF16 Type Casting
    tcast_store           = 0;
    // default: GDDR6/AiM Mode Registers
    mr0_op                = {ROW_ADDR_WIDTH{1'b0}};
    mr0_op[2:0]           = (cfr_mode.WL == 8) ? 0 : cfr_mode.WL;
    mr0_op[6:3]           = cfr_mode.RL - 5;
    mr4_op                = {ROW_ADDR_WIDTH{1'b0}};
    mr4_op[3:0]           = EDC_Hold;
    mr4_op[6:4]           = (cfr_mode.CRCWL > 14) ? (cfr_mode.CRCWL - 15) : (cfr_mode.CRCWL - 7);
    mr4_op[8:7]           = (cfr_mode.CRCRL == 4) ? 0 : cfr_mode.CRCRL;
    mr4_op[9]             = RCRCmr4;
    mr4_op[10]            = WCRCmr4;
    mr4_op[11]            = EDC_Inv;
    mr13_afm_nxt          = mr13_afm;
    mr13_op               = {ROW_ADDR_WIDTH{1'b0}};
    mr13_op[10:8]         = cfr_mode.AFM;
    mr13_op[3:1]          = cfr_mode.RELU_MAX;
    mr13_op[0]            = cfr_mode.BK_BCAST;
    mr14_thrd_nxt         = mr14_thrd;
    mr14_op               = {ROW_ADDR_WIDTH{1'b0}};
    mr14_op[8]            = cfr_mode.EWMUL_BG;
    mr14_op[0]            = mr14_thrd;
    mr15_relu_slp_nxt     = mr15_relu_slp;
    mr15_page_nxt         = mr15_page;
    mr15_op               = {ROW_ADDR_WIDTH{1'b0}};
    mr15_op[5:4]          = mr15_page;
    curr_thrd_nxt         = curr_thrd;
    // default: Exit Queue
    exit_que_din            = 0;
    exit_que_din.pkt.marker = pkt_marker;
    case (exit_que_din_sel)                                 // Explicitly multiplexing data field here to reduce the number of infered 256-bit muxes in the FSM
      EXIT_DATA_TDEC  : begin
        exit_que_din.pkt.data = tdec_data;
        exit_que_din.pkt.mask = tdec_data_mask;
      end
      EXIT_DATA_GPR   : begin
        exit_que_din.pkt.data = gpr_is_dbg ? dbg_dout : gpr_dout;
        exit_que_din.pkt.mask = {MASK_WIDTH{1'b1}};
      end
      EXIT_DATA_CFR   : begin
        exit_que_din.pkt.data = cfr_dout;
        exit_que_din.pkt.mask = 0;
      end
      EXIT_DATA_TCAST : begin
        exit_que_din.pkt.data = tcast_bf16;
        exit_que_din.pkt.mask = {MASK_WIDTH{1'b1}};         // Mask is not allowed when type casting is used
      end
    endcase
    exit_que_wr = 0;
    exit_que_din_sel_nxt = exit_que_din_sel;
    //
    //             .
    //            ":"
    //          ___:____     |"\/"|
    //        ,'        `.    \  /
    //        |  O        \___/  |
    //      ~^~^~^~^~^~^~^~^~^~^~^~^~
    //     DMA Core FSM Code Starts Here
    //
    case (dcore_state)
      DCORE_IDLE : begin
        dcore_rdy_nxt  = !exit_que_pfull;                   // Accepting packets as long as there is space in the exit queue

        if (tdec_pkt_valid && dcore_rdy) begin
          case (tdec_addr_range)
            DRAM_RANGE : begin
              exit_que_wr               = dcore_rdy;
              exit_que_din.dest         = 0;                // "0" sends packet to the interconnect (DRAM)
              exit_que_din.isrd         = tdec_pkt_isrd;
              exit_que_din.ch_mask      = tdec_ch_addr;
              exit_que_din.pkt.req_type = tdec_pkt_isrd ? READ : WRITE;
              exit_que_din.pkt.bk_addr  = tdec_bk_addr;
              exit_que_din.pkt.row_addr = tdec_row_addr;
              exit_que_din.pkt.col_addr = tdec_col_addr;
              exit_que_din.pkt.mask     = tdec_data_mask;
            end
          endcase
        end
      end
    endcase
  end

  // ================================== Initialization =================================
  initial begin
    // DMA Core Signals
    dcore_state       = DCORE_IDLE;
    dcore_rdy         = 1;
    step              = 0;
    pgen_orde_rdy     = 0;
    payload_op        = 0;
    // General Purpose Register (GPR)
    gpr_din_sel       = GPR_DATA_TDEC;
    gpr_cmd           = 0;
    gpr_opsize        = 0;
    // Configuration Register (CFR)
    cfr_addr          = 0;
    cfr_mask          = 0;
    cfr_din           = 0;
    // Instruction Set Register
    isr_tcast         = 0;
    isr_tcast_rdy_val = 0;
    isr_inc_ord       = 0;
    isr_op_size       = 0;
    isr_op_cnt        = 0;
    isr_gpr_addr      = 0;
    isr_ch_mask       = 0;
    isr_ch_addr       = 0;
    isr_bk_addr       = 0;
    isr_row_addr      = 0;
    isr_col_addr      = 0;
    copy_dir          = 0;
    // Element-Wise Adder
    ewadd_in_sel      = 0;
    isr_a_addr        = 0;
    isr_b_addr        = 0;
    isr_c_addr        = 0;
    isr_c_cnt         = 0;
    // DMA Debugger
    gpr_is_dbg        = 0;
    // GDDR6/AiM Mode Registers
    mr13_afm          = 0;
    mr14_thrd         = 0;
    mr15_relu_slp     = 0;
    mr15_page         = 0;
    curr_thrd         = 0;
    // Exit Queue
    exit_que_din_sel  = EXIT_DATA_TDEC;
  end



  //debug reg
/*  
  (* dont_touch = "true", mark_debug = "true" *) reg [4:0] dcore_state_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg       dcore_rdy_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg       payload_op_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg       pgen_orde_rdy_nxt_debug;

  (* dont_touch = "true", mark_debug = "true" *) reg       tdec_rdy_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg       tdec_pkt_isrd_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg       tdec_pkt_valid_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [1:0] tdec_addr_range_debug;

  (* dont_touch = "true", mark_debug = "true" *) reg [CH_ADDR_WIDTH-1:0]  tdec_ch_addr_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [BK_ADDR_WIDTH-1:0]  tdec_bk_addr_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [ROW_ADDR_WIDTH-1:0] tdec_row_addr_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [COL_ADDR_WIDTH-1:0] tdec_col_addr_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [MASK_WIDTH-1:0]     tdec_data_mask_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [DATA_WIDTH-1:0]     tdec_data_debug;

  (* dont_touch = "true", mark_debug = "true" *) reg exit_que_wr_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg exit_que_rd_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg exit_que_empty_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg exit_que_pfull_debug;



  always @(posedge clk, posedge rst)
    if (rst) begin
        dcore_state_debug <= 'b0;
        dcore_rdy_debug <= 'b0;
        payload_op_debug <= 'b0;
        pgen_orde_rdy_nxt_debug <= 'b0;

        tdec_rdy_debug <= 'b0;
        tdec_pkt_isrd_debug <= 'b0;
        tdec_pkt_valid_debug <= 'b0;
        tdec_addr_range_debug <= 'b0;

        tdec_ch_addr_debug <= 'b0;
        tdec_bk_addr_debug <= 'b0;
        tdec_row_addr_debug <= 'b0;
        tdec_col_addr_debug <= 'b0;
        tdec_data_mask_debug <= 'b0;
        tdec_data_debug <= 'b0;

        exit_que_wr_debug <= 'b0;
        exit_que_rd_debug <= 'b0;
        exit_que_empty_debug <= 'b0;
        exit_que_pfull_debug <= 'b0;
    end
    else begin
        dcore_state_debug <= dcore_state;
        dcore_rdy_debug <= dcore_rdy;
        payload_op_debug <= payload_op;
        pgen_orde_rdy_nxt_debug <= pgen_orde_rdy_nxt;

        tdec_rdy_debug <= tdec_rdy;
        tdec_pkt_isrd_debug <= tdec_pkt_isrd;
        tdec_pkt_valid_debug <= tdec_pkt_valid;
        tdec_addr_range_debug <= tdec_addr_range;

        tdec_ch_addr_debug <= tdec_ch_addr;
        tdec_bk_addr_debug <= tdec_bk_addr;
        tdec_row_addr_debug <= tdec_row_addr;
        tdec_col_addr_debug <= tdec_col_addr;
        tdec_data_mask_debug <= tdec_data_mask;
        tdec_data_debug <= tdec_data;

        exit_que_wr_debug <= exit_que_wr;
        exit_que_rd_debug <= exit_que_rd;
        exit_que_empty_debug <= exit_que_empty;
        exit_que_pfull_debug <= exit_que_pfull;
    end
*/

endmodule
