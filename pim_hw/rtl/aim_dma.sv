`timescale 1ps / 1ps

import axi_lib::*;
import aimc_lib::*;

module aim_dma (
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
  // Diagnostic Monitor Interface
  input  logic mon_upd,
  output logic [31:0] pkt_latency,
  // Configuration Register
  output logic [$bits(cfr_mode_t)-1:0] cfr_mode_p,
  output logic [$bits(cfr_time_t)-1:0] cfr_time_p,
  output logic [$bits(cfr_refr_t)-1:0] cfr_refr_p,
  output logic [$bits(cfr_schd_t)-1:0] cfr_schd_p,
  // AXI4: Write Address Channel
  input  logic [AXI_ID_WIDTH-1:0] s_axi_awid,       // Write Address ID
  input  logic [AXI_ADDR_WIDTH-1:0] s_axi_awaddr,   // Write address   
  input  logic [7:0] s_axi_awlen,                   // Burst length. The burst length gives the exact number of transfers in a burst
  input  logic [2:0] s_axi_awsize,                  // Burst size. This signal indicates the size of each transfer in the burst 
  input  logic [1:0] s_axi_awburst,                 // Burst type. The burst type and the size information, determine how the address for each transfer within the burst is calculated.
  input  logic s_axi_awlock,                        // Lock type. Provides additional information about the atomic characteristics of the transfer.
  input  logic [3:0] s_axi_awcache,                 // Memory type. This signal indicates how transactions are required to progress through a system.
  input  logic [2:0] s_axi_awprot,                  // Protection type. This signal indicates the privilege and security level of the transaction, and whether the transaction is a data access or an instruction access.
  input  logic [3:0] s_axi_awqos,                   // Quality of Service, QoS identifier sent for each write transaction.
  input  logic [3:0] s_axi_awregion,                // Region identifier. Permits a single physical interface on a slave to be used for multiple logical interfaces.
  input  logic s_axi_awvalid,                       // Write address valid. This signal indicates that // the channel is signaling valid write address and control information.
  output logic s_axi_awready,                       // Write address ready. This signal indicates that the slave is ready to accept an address and associated control signals.
  // AXI4: Write Data Channel
  input  logic [AXI_DATA_WIDTH-1:0] s_axi_wdata,    // Write Data
  input  logic [AXI_DATA_WIDTH/8-1:0] s_axi_wstrb,  // Write strobes. This signal indicates which byte lanes hold valid data. There is one write strobe bit for each eight bits of the write data bus.
  input  logic s_axi_wlast,                         // Write last. This signal indicates the last transfer in a write burst.
  input  logic s_axi_wvalid,                        // Write valid. This signal indicates that valid write data and strobes are available.
  output logic s_axi_wready,                        // Write ready. This signal indicates that the slave can accept the write data.
  // AXI4: Write Response Channel
  output logic [AXI_ID_WIDTH-1:0] s_axi_bid,        // Response ID tag. This signal is the ID tag of the write response.
  output logic [1:0] s_axi_bresp,                   // Write response. This signal indicates the status of the write transaction.
  output logic s_axi_bvalid,                        // Write response valid. This signal indicates that the channel is signaling a valid write response.
  input  logic s_axi_bready,                        // Response ready. This signal indicates that the master can accept a write response.
  // AXI4: Read Address Channel
  input  logic [AXI_ID_WIDTH-1:0] s_axi_arid,       // Read address ID. This signal is the identification tag for the read address group of signals.
  input  logic [AXI_ADDR_WIDTH-1:0] s_axi_araddr,   // Read address. This signal indicates the initial address of a read burst transaction.
  input  logic [7:0] s_axi_arlen,                   // Burst length. The burst length gives the exact number of transfers in a burst
  input  logic [2:0] s_axi_arsize,                  // Burst size. This signal indicates the size of each transfer in the burst
  input  logic [1:0] s_axi_arburst,                 // Burst type. The burst type and the size information, determine how the address for each transfer within the burst is calculated.
  input  logic s_axi_arlock,                        // Lock type. Provides additional information about the atomic characteristics of the transfer.
  input  logic [3:0] s_axi_arcache,                 // Memory type. This signal indicates how transactions are required to progress through a system.
  input  logic [2:0] s_axi_arprot,                  // Protection type. This signal indicates the privilege and security level of the transaction, and whether the transaction is a data access or an instruction access.
  input  logic [3:0] s_axi_arqos,                   // Quality of Service, QoS identifier sent for each read transaction.
  input  logic [3:0] s_axi_arregion,                // Region identifier. Permits a single physical interface on a slave to be used for multiple logical interfaces.
  input  logic s_axi_arvalid,                       // Write address valid. This signal indicates that the channel is signaling valid read address and control information.
  output logic s_axi_arready,                       // Read address ready. This signal indicates that the slave is ready to accept an address and associated control signals.
  // AXI4: Read Data Channel
  output logic [AXI_ID_WIDTH-1:0] s_axi_rid,        // Read ID tag. This signal is the identification tag for the read data group of signals generated by the slave.
  output logic [AXI_DATA_WIDTH-1:0] s_axi_rdata,    // Read Data
  output logic [1:0] s_axi_rresp,                   // Read response. This signal indicates the status of the read transfer.
  output logic s_axi_rlast,                         // Read last. This signal indicates the last transfer in a read burst.
  output logic s_axi_rvalid,                        // Read valid. This signal indicates that the channel is signaling the required read data.
  input  logic s_axi_rready,                        // Read ready. This signal indicates that the master can accept the read data and response information. 
  // AiM Interconnect Interface
  input  logic icnt_rdy,
  output logic dma_pkt_valid,
  output pkt_t dma_pkt,
  output logic [CH_NUM-1:0] dma_pkt_ch_mask,
  output logic dma_rdy,
  input  logic icnt_dma_pkt_valid,
  input  pkt_t icnt_dma_pkt,
  input  logic [CH_ADDR_WIDTH-1:0] icnt_dma_pkt_ch_addr);

  // =============================== Signal Declarations ===============================
  // AXI Bridge
  logic axbr_orde_rdy;                              // AXI Bridge ready signal
  logic axbr_pgen_pkt_valid;                        // Validity signal for AXI Bridge's trx_t packet
  trx_t axbr_pgen_pkt;                              // AXI Bridge's trx_t packet
  // DMA Packet Generator
  logic pgen_axbr_rdy;                              // DMA Packet Generator ready for packets from AXI bridge
  logic pgen_orde_pkt_valid;
  pkt_t pgen_orde_pkt;
  logic [CH_ADDR_WIDTH-1:0] pgen_orde_pkt_ch_addr;
  logic pgen_icnt_pkt_valid;
  pkt_t pgen_icnt_pkt;
  // logic [CH_ADDR_WIDTH-1:0] pgen_icnt_pkt_ch_addr;
  logic [CH_NUM-1:0] pgen_icnt_pkt_ch_mask;
  logic pgen_orde_rdy;                              // Pattern generator ready flag for response packets from ordering engine
  // DMA Register
  pkt_t dreg_orde_pkt;                              // DMA register packet (GPR, CFR)
  logic dreg_orde_pkt_valid;                        // DMA register packet valid flag (GPR, CFR)
  // Ordering Engine
  logic orde_pgen_rdy;
  logic orde_icnt_rdy;
  logic orde_axbr_pkt_valid;
  trx_t orde_axbr_pkt;
  logic orde_dreg_rdy;                              // Ordering engine ready flag for DMA register
  logic orde_pgen_pkt_valid;                        // Packet valid flag for response packet to packet generator
  pkt_t orde_pgen_pkt;                              // Response packet to packet generator
  logic icnt_orde_pkt_valid;
  pkt_t icnt_orde_pkt;
  logic [CH_ADDR_WIDTH-1:0] icnt_orde_pkt_ch_addr;
  // RISC-V DMA
  logic rv_axbr_rdy;                                // RISC-V DMA ready flag for AXI Brige
  logic rv_axbr_pkt_valid;                          // RISC-V DMA packet valid flag for AXI Bridge
  trx_t rv_axbr_pkt;                                // RISC-V DMA packet for AXI Bridge
  logic rv_icnt_rdy;                                // RISC-V DMA ready flag for Interconnect
  logic icnt_rv_pkt_valid;                          // Interconnect packet valid flag for RISC-V DMA
  pkt_t icnt_rv_pkt;                                // Interconnect packet for RISC-V DMA
  logic [CH_ADDR_WIDTH-1:0] icnt_rv_pkt_ch_addr;    // Interconnect packet channel address for RISC-V DMA
  logic rv_icnt_pkt_valid;                          // RISC-V DMA packet valid flag for Interconnect
  pkt_t rv_icnt_pkt;                                // RISC-V DMA packet for Interconnect
  logic [CH_ADDR_WIDTH-1:0] rv_icnt_pkt_ch_addr;    // RISC-V DMA packet channel address for Interconnect
  // In-Flight Packet Counter
  logic [15:0] pkt_cnt;                             // Register for counting number of in-flight packets
  logic pkt_cnt_inc;                                // Counter increment signal
  logic pkt_cnt_dec;                                // Counter decrement signal
  logic infl_empty;                                 // Flag indicating that there are no in-flight packets
  // Latency Monitor
  logic resp_pkt_valid; 
  logic resp_sink_rdy;  
  logic resp_pkt_marker;

`ifdef SUPPORT_INDIRECT_ADDRESSING
  logic [31:0] o_args_reg_A;
  logic [31:0] o_args_reg_B;
  logic [31:0] o_args_reg_C;
    `ifdef SUPPORT_LUT_DATAPATH
      logic         o_lut_load_x_sig;
      logic [255:0] o_lut_load_x_data;
    `endif
`endif
  // =================================== AXI Bridge ====================================
  axi_bridge axi_bridge (
    .clk,
    .rst,
    // AXI4: Write Address Channel
    .s_axi_awid,
    .s_axi_awaddr,
    .s_axi_awlen,
    .s_axi_awsize,
    .s_axi_awburst,
    .s_axi_awlock,
    .s_axi_awcache,
    .s_axi_awprot,
    .s_axi_awqos,
    .s_axi_awregion,
    .s_axi_awvalid,
    .s_axi_awready,
    // AXI4: Write Data Channel
    .s_axi_wdata,
    .s_axi_wstrb,
    .s_axi_wlast,
    .s_axi_wvalid,
    .s_axi_wready,
    // AXI4: Write Response Channel
    .s_axi_bid,
    .s_axi_bresp,
    .s_axi_bvalid,
    .s_axi_bready,
    // AXI4: Read Address Channel
    .s_axi_arid,
    .s_axi_araddr,
    .s_axi_arlen,
    .s_axi_arsize,
    .s_axi_arburst,
    .s_axi_arlock,
    .s_axi_arcache,
    .s_axi_arprot,
    .s_axi_arqos,
    .s_axi_arregion,
    .s_axi_arvalid,
    .s_axi_arready,
    // AXI4: Read Data Channel
    .s_axi_rid,
    .s_axi_rdata,
    .s_axi_rresp,
    .s_axi_rlast,
    .s_axi_rvalid,
    .s_axi_rready,
    // DMA Packet Generator Interface
    .pgen_axbr_rdy,
    .axbr_pgen_pkt_valid,
    .axbr_pgen_pkt,
    // Ordering Engine Interface

    `ifdef SUPPORT_INDIRECT_ADDRESSING
      .o_args_reg_A,
      .o_args_reg_B,
      .o_args_reg_C,
      `ifdef SUPPORT_LUT_DATAPATH
      .o_lut_load_x_sig,
      .o_lut_load_x_data,
      `endif
    `endif
    .axbr_orde_rdy,
    .orde_axbr_pkt_valid,
    .orde_axbr_pkt);

  generate
    if (RISCV_DMA == "FALSE") begin : dmaRTL
      // ============================ DMA Packet Generator =============================
      dma_pgen dma_pgen (
        .clk,
        .rst,
        // QDR II+ Clocks and Interface
        .qdrii_clk_n,
        .qdrii_clk_p,
        .sys_rst,
        .qdrii_D,
        .qdrii_K_p,
        .qdrii_K_n,
        .qdrii_BW_n,
        .qdrii_RPS_n,
        .qdrii_WPS_n,
        .qdrii_DOFF_n,
        .qdrii_SA,
        .qdrii_Q,
        .qdrii_CQ_p,
        .qdrii_CQ_n,
        // Latency Monitor Interface
        .mon_upd,
        .pkt_latency,
        .resp_pkt_valid,
        .resp_sink_rdy,
        .resp_pkt_marker,
        // AXI4 Write Data Probe
        .s_axi_wvalid,
        .s_axi_wready,
        .s_axi_awaddr,
        .s_axi_wdata,
        // Configuration Register
        .cfr_mode_p,
        .cfr_time_p,
        .cfr_refr_p,
        .cfr_schd_p,
        // In-Flight Packet Counter
        .infl_empty,
        // AXI Bridge Interface (in)
        .pgen_axbr_rdy,
        .axbr_pgen_pkt_valid,
        .axbr_pgen_pkt,
        // Ordering Engine Interface (out)
        .orde_pgen_rdy,
        .pgen_orde_pkt_valid,
        .pgen_orde_pkt,
        .pgen_orde_pkt_ch_addr,
        // Ordering Engine Interface (DMA register out)
        .orde_dreg_rdy,
        .dreg_orde_pkt_valid,
        .dreg_orde_pkt,
        // Ordering Engine Interface (in)
        .pgen_orde_rdy,
        .orde_pgen_pkt_valid,
        .orde_pgen_pkt,
        // AiM Interconnect Interface (out)
        .icnt_rdy,
        .pgen_icnt_pkt_valid,
        .pgen_icnt_pkt,
        .pgen_icnt_pkt_ch_mask);

      assign dma_pkt_valid   = pgen_icnt_pkt_valid;
      assign dma_pkt         = pgen_icnt_pkt;
      assign dma_pkt_ch_mask = pgen_icnt_pkt_ch_mask;
      // Latency Monitor
      assign resp_pkt_valid  = icnt_orde_pkt_valid;
      assign resp_sink_rdy   = orde_icnt_rdy;
      assign resp_pkt_marker = icnt_orde_pkt.marker;

      // =============================== Ordering Engine ===============================
   ordr_engine ordr_engine (
        .clk,
        .rst,
        // DMA Packet Generator Interface (in)
        .orde_pgen_rdy,
        .pgen_orde_pkt_valid,
        `ifdef XILINX_SIMULATOR
        .pgen_orde_pkt_marker(pgen_orde_pkt.marker),
        .pgen_orde_pkt_bcast(pgen_orde_pkt.bcast),
        .pgen_orde_pkt_prio(pgen_orde_pkt.prio),
        .pgen_orde_pkt_req_type(pgen_orde_pkt.req_type),
        .pgen_orde_pkt_bk_addr(pgen_orde_pkt.bk_addr),
        .pgen_orde_pkt_row_addr(pgen_orde_pkt.row_addr),
        .pgen_orde_pkt_col_addr(pgen_orde_pkt.col_addr),
        .pgen_orde_pkt_mask(pgen_orde_pkt.mask),
        .pgen_orde_pkt_data(pgen_orde_pkt.data),                   
        `else
        .pgen_orde_pkt,
        `endif        
        .pgen_orde_pkt_ch_addr,
        // DMA Packet Generator Interface (out)
        .pgen_orde_rdy,
        .orde_pgen_pkt_valid,
        `ifdef XILINX_SIMULATOR
        .orde_pgen_pkt_marker     (orde_pgen_pkt.marker    ),
        .orde_pgen_pkt_bcast    (orde_pgen_pkt.bcast   ),
        .orde_pgen_pkt_prio     (orde_pgen_pkt.prio    ),
        .orde_pgen_pkt_req_type (orde_pgen_pkt.req_type),
        .orde_pgen_pkt_bk_addr  (orde_pgen_pkt.bk_addr ),
        .orde_pgen_pkt_row_addr (orde_pgen_pkt.row_addr),
        .orde_pgen_pkt_col_addr (orde_pgen_pkt.col_addr),
        .orde_pgen_pkt_mask     (orde_pgen_pkt.mask    ),
        .orde_pgen_pkt_data     (orde_pgen_pkt.data    ),                   
        `else
        .orde_pgen_pkt,
        `endif        
        // DMA Register Interface (in)
        .orde_dreg_rdy,
        .dreg_orde_pkt_valid,
        `ifdef XILINX_SIMULATOR
        .dreg_orde_pkt_marker     (dreg_orde_pkt.marker),
        .dreg_orde_pkt_bcast    (dreg_orde_pkt.bcast),
        .dreg_orde_pkt_prio     (dreg_orde_pkt.prio),
        .dreg_orde_pkt_req_type (dreg_orde_pkt.req_type),
        .dreg_orde_pkt_bk_addr  (dreg_orde_pkt.bk_addr),
        .dreg_orde_pkt_row_addr (dreg_orde_pkt.row_addr),
        .dreg_orde_pkt_col_addr (dreg_orde_pkt.col_addr),
        .dreg_orde_pkt_mask     (dreg_orde_pkt.mask),
        .dreg_orde_pkt_data     (dreg_orde_pkt.data),                   
        `else
        .dreg_orde_pkt,
        `endif         
        // AiM Interconnect Interface (in)
        .orde_icnt_rdy,
        .icnt_orde_pkt_valid,
        `ifdef XILINX_SIMULATOR
        .icnt_orde_pkt_marker     (icnt_orde_pkt.marker),
        .icnt_orde_pkt_bcast    (icnt_orde_pkt.bcast),
        .icnt_orde_pkt_prio     (icnt_orde_pkt.prio),
        .icnt_orde_pkt_req_type (icnt_orde_pkt.req_type),
        .icnt_orde_pkt_bk_addr  (icnt_orde_pkt.bk_addr),
        .icnt_orde_pkt_row_addr (icnt_orde_pkt.row_addr),
        .icnt_orde_pkt_col_addr (icnt_orde_pkt.col_addr),
        .icnt_orde_pkt_mask     (icnt_orde_pkt.mask),
        .icnt_orde_pkt_data     (icnt_orde_pkt.data),                   
        `else
        .icnt_orde_pkt,
        `endif           
        .icnt_orde_pkt_ch_addr,
        // AXI Bridge Interface (out)
        .axbr_orde_rdy,
        .orde_axbr_pkt_valid,
        `ifdef XILINX_SIMULATOR
        .orde_axbr_pkt_is_rd (orde_axbr_pkt.is_rd),
        .orde_axbr_pkt_addr  (orde_axbr_pkt.addr ),
        .orde_axbr_pkt_mask  (orde_axbr_pkt.mask ),
        .orde_axbr_pkt_data  (orde_axbr_pkt.data )
        `else
          `ifdef SUPPORT_INDIRECT_ADDRESSING
          .i_args_reg_A(o_args_reg_A),
          .i_args_reg_B(o_args_reg_B),
          .i_args_reg_C(o_args_reg_C),
            `ifdef SUPPORT_LUT_DATAPATH
              .i_lut_load_x_sig (o_lut_load_x_sig),
              .i_lut_load_x_data(o_lut_load_x_data), 
            `endif
          `endif
        .orde_axbr_pkt
        `endif                   
        );      


      assign dma_rdy               = orde_icnt_rdy;
      assign icnt_orde_pkt_valid   = icnt_dma_pkt_valid;
      assign icnt_orde_pkt         = icnt_dma_pkt;
      assign icnt_orde_pkt_ch_addr = icnt_dma_pkt_ch_addr;
    end
  endgenerate

  // ============================ In-Flight Packet Counter =============================
  always @(posedge clk, posedge rst)
    if      (rst)                     pkt_cnt <= 0;
    else if (pkt_cnt_inc^pkt_cnt_dec) pkt_cnt <= pkt_cnt_inc ? (pkt_cnt + 1'b1) : (pkt_cnt - 1'b1);

  assign pkt_cnt_inc = dma_pkt_valid && icnt_rdy;      // Packet is pushed to interconnect
  assign pkt_cnt_dec = icnt_dma_pkt_valid && dma_rdy;  // Packet is pulled from interconnect
  assign infl_empty  = pkt_cnt == 0;

  initial pkt_cnt = 0;

endmodule
