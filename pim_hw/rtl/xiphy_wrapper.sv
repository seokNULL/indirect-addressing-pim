`timescale 1ps / 1ps

import aimc_lib::*;

module xiphy_wrapper #(parameter [31:0] CH_IDX = 0) (
  input  logic            clk_div,
  input  logic            rst_div,
  input  logic            clk_rx_fifo,
  input  logic            ub_rst_out,
  input  logic            mmcm_lock,
  input  logic            pll_gate,
  output logic            pll_lock,
  input  logic            clk_riu,
  input  logic            rst_riu,
  // Command Input Interface
  input  logic [7:0]      intf_ck_t,
  input  logic [7:0]      intf_ca [9:0],
  input  logic [7:0]      intf_cabi_n,
  input  logic [7:0]      intf_wck_t,
  // Data Handler Interface
  input  logic            tx_t,
  input  logic            tbyte_in,
  input  logic [7:0]      intf_dq    [15:0],
  input  logic [7:0]      intf_dbi_n [1:0],
  input  logic [7:0]      init_edc   [1:0],
  input  logic [7:0]      top_cke_n,
  output logic [7:0]      phy_dq     [15:0],
  output logic [7:0]      phy_dbi_n  [1:0],
  output logic [7:0]      phy_edc    [1:0],
  // Calibration Handler Interface
  output logic            phy_rdy,
  input  logic            init_done,
  input  logic [3:0][6:0] param_vref_tune,
  input  logic            param_smpl_edge,
  input  logic            param_sync_ordr,
  input  logic [71:0]     param_io_in_del,         // 18 4-bit parameters (16 DQ, 2 EDC)
  input  logic [63:0]     param_io_out_del,        // 16 4-bit parameters (16 DQ)
  // MCS-RIU Interface
  input  logic [3:0]      riu_nibble,              // Nibble select index (UltraScale+: 3-bit nibble index; Versal: 4-bit nibble index)
  input  logic [7:0]      riu_addr,                // RIU_ADDR input (UltraScal+: 6-bit address; Versal: 8-bit address)
  output logic [15:0]     riu_rd_data,
  input  logic            riu_rd_strobe,
  input  logic [15:0]     riu_wr_data,
  input  logic            riu_wr_strobe,
  output logic            riu_valid,               // Combined (&-ed) RIU_RD_VALID output
  // GDDR6 Interface
  output logic            CK_t, CK_c,
  output logic [9:0]      CA,
  output logic            CKE_n,
  output logic            CABI_n,
  output logic            WCK1_t,
  output logic            WCK1_c,
  output logic            WCK0_t,
  output logic            WCK0_c,
  inout  tri   [15:0]     DQ,
  inout  tri   [1:0]      DBI_n,
  inout  tri   [1:0]      EDC);
  
  // ========================= Internal Signals =========================
  logic        clk_pll;                            // BITSLICE_CONTROL/XPHY PLL clock      
  logic [7:0]  riu_addr_r1;                        // RIU_ADDR input buffer (UltraScal+: 6-bit address; Versal: 8-bit address)
  logic [15:0] riu_wr_data_r1;                     // RIU_WR_DATA input buffer
  logic [15:0] riu_rd_data_r0 [8:0];               // Unbuffered RIU_RD_DATA output from all nibbles (UltraScale+: 4 nibbles; Versal: 9 nibbles)
  logic [8:0]  riu_valid_r0;                       // Unbuffered RIU_RD_VALID signals (UltraScale+: 4 byte groups; Versal: 9 nibbles)
  logic        riu_wr_strobe_r1;                   // RIU_WR_EN input buffer
  logic [3:0]  riu_nibble_r1;                      // Nibble address input buffer (UltraScale+: 8 nibbles; Versal: 9 nibbles)
  logic [8:0]  riu_nibble_sel;                     // Decoded nibble address (UltraScale+: 8 nibbles; Versal: 9 nibbles )
  logic [8:0]  riu_nibble_sel_r1;                  // Buffered RIU_NIBBLE_SEL

  // ============================= PHY PLL ==============================
  xiphy_pll #(.PLL_WIDTH(1)) xiphy_pll (
    .clk_div,
    .rst_div,
    .ub_rst_out,
    .mmcm_lock,
    .pll_gate,
    .clk_pll,
    .pll_lock);

  // ====================== Xilinx Native Mode PHY ======================
  `ifdef N1ZYNQ_CONFIG
  xiphy_n1zynq #(.CH_IDX(CH_IDX)) xiphy (
    .clk_pll,
    .clk_div,
    .rst_div,
    .clk_riu,
    .rst_riu,
    .clk_rx_fifo,
    // Command Input Interface
    .intf_ck_t,
    .intf_ca,
    .intf_cabi_n,
    .intf_wck_t,
    // Data Handler Interface
    .tx_t,
    .tbyte_in,
    .intf_dq,
    .intf_dbi_n,
    .init_edc,
    .top_cke_n,
    .phy_dq,
    .phy_dbi_n,
    .phy_edc,
    // Calibration Interface
    .phy_rdy,
    .init_done,
    .param_vref_tune,
    .param_smpl_edge,
    .param_sync_ordr,
    .param_io_in_del,
    .param_io_out_del,
    // MicroBlaze Interface
    .riu_addr       (riu_addr_r1 [5:0]),
    .riu_wr_data    (riu_wr_data_r1),
    .riu_rd_data    (riu_rd_data_r0 [3:0]),
    .riu_valid      (riu_valid_r0 [3:0]),
    .riu_wr_en      (riu_wr_strobe_r1),
    .riu_nibble_sel (riu_nibble_sel_r1 [7:0]),
    // GDDR6 Interface
    .CK_t, 
    .CK_c,
    .CA,
    .CKE_n,
    .CABI_n,
    .WCK1_t, 
    .WCK1_c,
    .WCK0_t, 
    .WCK0_c,
    .DQ,
    .DBI_n,
    .EDC);
  `elsif VCU118_CONFIG
  xiphy_vcu118 #(.CH_IDX(CH_IDX)) xiphy ( 
    .clk_pll,
    .clk_div,
    .rst_div,
    .clk_riu,
    .rst_riu,
    .clk_rx_fifo,
    // Command Input Interface
    .intf_ck_t,
    .intf_ca,
    .intf_cabi_n,
    .intf_wck_t,
    // Data Handler Interface
    .tx_t,
    .tbyte_in,
    .intf_dq,
    .intf_dbi_n,
    .init_edc,
    .top_cke_n,
    .phy_dq,
    .phy_dbi_n,
    .phy_edc,
    // Calibration Interface
    .phy_rdy,
    .init_done,
    .param_vref_tune,
    .param_smpl_edge,
    .param_sync_ordr,
    .param_io_in_del,
    .param_io_out_del,
    // MicroBlaze Interface
    .riu_addr       (riu_addr_r1 [5:0]),
    .riu_wr_data    (riu_wr_data_r1),
    .riu_rd_data    (riu_rd_data_r0 [3:0]),
    .riu_valid      (riu_valid_r0 [3:0]),
    .riu_wr_en      (riu_wr_strobe_r1),
    .riu_nibble_sel (riu_nibble_sel_r1 [7:0]),
    // GDDR6 Interface
    .CK_t, 
    .CK_c,
    .CA,
    .CKE_n,
    .CABI_n,
    .WCK1_t, 
    .WCK1_c,
    .WCK0_t, 
    .WCK0_c,
    .DQ,
    .EDC);
  `elsif ZCU102_CONFIG
  xiphy_zcu102 #(.CH_IDX(CH_IDX)) xiphy ( 
    .clk_pll,
    .clk_div,
    .rst_div,
    .clk_riu,
    .rst_riu,
    .clk_rx_fifo,
    // Command Input Interface
    .intf_ck_t,
    .intf_ca,
    .intf_cabi_n,
    .intf_wck_t,
    // Data Handler Interface
    .tx_t,
    .tbyte_in,
    .intf_dq,
    .intf_dbi_n,
    .init_edc,
    .top_cke_n,
    .phy_dq,
    .phy_dbi_n,
    .phy_edc,
    // Calibration Interface
    .phy_rdy,
    .init_done,
    .param_vref_tune,
    .param_smpl_edge,
    .param_sync_ordr,
    .param_io_in_del,
    .param_io_out_del,
    // MicroBlaze Interface
    .riu_addr       (riu_addr_r1 [5:0]),
    .riu_wr_data    (riu_wr_data_r1),
    .riu_rd_data    (riu_rd_data_r0 [3:0]),
    .riu_valid      (riu_valid_r0 [3:0]),
    .riu_wr_en      (riu_wr_strobe_r1),
    .riu_nibble_sel (riu_nibble_sel_r1 [7:0]),
    // GDDR6 Interface
    .CK_t, 
    .CK_c,
    .CA,
    .CKE_n,
    .CABI_n,
    .WCK1_t, 
    .WCK1_c,
    .WCK0_t, 
    .WCK0_c,
    .DQ,
    .DBI_n,
    .EDC);
  `elsif VCK190_CONFIG
  xiphy_vck190 #(.CH_IDX(CH_IDX)) xiphy ( 
    .clk_pll,
    .clk_div,
    .rst_div,
    .clk_riu,
    .rst_riu,
    .clk_rx_fifo,
    // Command Input Interface
    .intf_ck_t,
    .intf_ca,
    .intf_cabi_n,
    .intf_wck_t,
    // Data Handler Interface
    .tx_t,
    .tbyte_in,
    .intf_dq,
    .intf_dbi_n,
    .init_edc,
    .top_cke_n,
    .phy_dq,
    .phy_dbi_n,
    .phy_edc,
    // Calibration Interface
    .phy_rdy,
    .init_done,
    .param_smpl_edge,
    .param_sync_ordr,
    .param_io_in_del,
    .param_io_out_del,
    // MicroBlaze Interface
    .riu_addr       (riu_addr_r1),
    .riu_wr_data    (riu_wr_data_r1),
    .riu_rd_data    (riu_rd_data_r0),
    .riu_valid      (riu_valid_r0),
    .riu_wr_en      (riu_wr_strobe_r1),
    .riu_nibble_sel (riu_nibble_sel_r1),
    // GDDR6 Interface
    .CK_t, 
    .CK_c,
    .CA,
    .CKE_n,
    .CABI_n,
    .WCK1_t, 
    .WCK1_c,
    .WCK0_t, 
    .WCK0_c,
    .DQ,
    .EDC);
  `endif

  // ======================== MicroBlaze Decoder ========================
  `ifdef ULTRASCALE_CONFIG
    assign riu_valid_r0[8:4] = 5'b11111;  // In UltraScale+, only four validity bits are generated by XPHY (one per byte group)
  `endif

  // Input and output buffers (for better timing analysis)
  always @(posedge clk_riu) begin
    riu_addr_r1      <= riu_addr;
    riu_wr_data_r1   <= riu_wr_data;
    riu_wr_strobe_r1 <= riu_wr_strobe;
    riu_nibble_r1    <= riu_nibble;
  end
  always @(posedge clk_riu) riu_valid <= &riu_valid_r0;

  // Decoder for RIU_NIBBLE_SEL
  always_comb begin
    riu_nibble_sel = 0;
    riu_nibble_sel[riu_nibble] = (riu_rd_strobe||riu_wr_strobe);
  end
  always @(posedge clk_riu) riu_nibble_sel_r1 <= riu_nibble_sel;

  // Output selector for RIU_RD_DATA
  `ifdef ULTRASCALE_CONFIG
  always @(posedge clk_riu) riu_rd_data <= riu_rd_data_r0[riu_nibble_r1[2:1]];  // Skipping riu_nibble_r1[0], since one riu_rd_data is already muxed between two nibbles in UltraScale+
  `elsif VERSAL_CONFIG
  always @(posedge clk_riu) riu_rd_data <= riu_rd_data_r0[riu_nibble_r1];
  `endif

  // ========================== Initialization ==========================
  initial begin
    riu_addr_r1       = 0;
    riu_wr_data_r1    = 0;
    riu_wr_strobe_r1  = 0;
    riu_nibble_r1     = 0;
    riu_valid         = 0;
    riu_nibble_sel_r1 = 0;
    riu_rd_data       = 0;
  end

endmodule
