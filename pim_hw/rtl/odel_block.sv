`timescale 1ps / 1ps

module odel_block (
  input  logic clk_div,
  input  logic rst_div,
  // Calibration Interface
  input  logic [16*4-1:0] param_io_out_del,  // 16 values for DQ0-DQ15
  // Command Input Interface
  input  logic [7:0] intf_ck_t,
  input  logic [7:0] intf_ca    [9:0],
  input  logic [7:0] intf_cabi_n,
  input  logic [7:0] intf_wck_t,
  // Data Handler Interface
  input  logic       tbyte_in,
  input  logic       tx_t,
  input  logic [7:0] intf_dq    [15:0],
  input  logic [7:0] intf_dbi_n [1:0],
  input  logic [7:0] init_edc   [1:0],
  input  logic [7:0] top_cke_n,
  // Delayed Command Input Signals
  output logic [7:0] intf_ck_t_d,
  output logic [7:0] intf_ca_d    [9:0],
  output logic [7:0] intf_cabi_n_d,
  output logic [7:0] intf_wck_t_d,
  // Delayed Data Handler Signals
  output logic       tbyte_in_d,
  output logic       tx_t_d,
  output logic [7:0] intf_dq_d    [15:0],
  output logic [7:0] intf_dbi_n_d [1:0],
  output logic [7:0] init_edc_d   [1:0],
  output logic [7:0] top_cke_n_d);

  // ============================= Internal Signals =============================
  // First register stage signals
  logic [7:0]      intf_ck_t_0;
  logic [7:0]      intf_ca_0 [9:0];
  logic [7:0]      intf_cabi_n_0;
  logic [7:0]      intf_wck_t_0;
  logic            tbyte_in_0;
  logic            tx_t_0;
  logic [7:0]      init_edc_0 [1:0];
  logic [7:0]      intf_dbi_n_0 [1:0];
  logic [7:0]      top_cke_n_0;
  // Programmable delay signals
  logic [4:0][7:0] intf_dq_pipe  [15:0];        // The only programmable pipe is for DQ, other signals are statically delayed one clock cycle (eight WCK edges)
  logic [23:0]     intf_dq_array [15:0];        // Data pipe concatenated into a single packed array, used for taking an 8-bit part based on the dalay value
  logic [3:0]      param_io_out_del_r1 [15:0];  // IO output delay buffered locally

  // =============================== Static Delays ==============================
  always @(posedge clk_div) begin
    // First register stage (compensating for dq delay in data handler)
    intf_ck_t_0   <= intf_ck_t;
    intf_cabi_n_0 <= intf_cabi_n;
    intf_wck_t_0  <= intf_wck_t;
    tbyte_in_0    <= tbyte_in;
    tx_t_0        <= tx_t;
    top_cke_n_0   <= top_cke_n;
    for (int idx=0; idx<10; idx++) intf_ca_0[idx]    <= intf_ca[idx];
    for (int idx=0; idx<2; idx++)  init_edc_0[idx]   <= init_edc[idx];
    for (int idx=0; idx<2; idx++)  intf_dbi_n_0[idx] <= intf_dbi_n[idx];
    // Sedcond register stage (compensating for intf_dq_d delay from intf_dq_array)
    intf_ck_t_d   <= intf_ck_t_0;
    intf_cabi_n_d <= intf_cabi_n_0;
    intf_wck_t_d  <= intf_wck_t_0;
    tbyte_in_d    <= tbyte_in_0;
    tx_t_d        <= tx_t_0;
    top_cke_n_d   <= top_cke_n_0;
    for (int idx=0; idx<10; idx++) intf_ca_d[idx]    <= intf_ca_0[idx];
    for (int idx=0; idx<2; idx++)  init_edc_d[idx]   <= init_edc_0[idx];
    for (int idx=0; idx<2; idx++)  intf_dbi_n_d[idx] <= intf_dbi_n_0[idx];   // Need to make a pipe for DBI_n (like for DQ) if DBI is used
  end

  // always @(posedge clk_div)
  //   for (int idx=0; idx<16; idx++)
  //     param_io_out_del_r1[idx] <= param_io_out_del[idx*4+:4];

  // ========================= Programmable Delay Pipes =========================
  genvar l, i;
  generate
    for (l=0; l<16; l++) begin : dqFamily
      xpm_cdc_array_single #(                        // With this syncronizer, PHY will source "garbage" during parameter transition period, but it should't hurt the operation
        .DEST_SYNC_FF   (2),
        .INIT_SYNC_FF   (0),
        .SIM_ASSERT_CHK (0),
        .SRC_INPUT_REG  (0),
        .WIDTH          (4))
      io_out_del_sync (
        .src_clk        (),                          // Don't need src_clk if SRC_INPUT_REG = 0
        .dest_clk       (clk_div),
        .src_in         (param_io_out_del[l*4+:4]),
        .dest_out       (param_io_out_del_r1[l]));

      assign intf_dq_pipe[l][0] = intf_dq[l];
      // Data Delay Pipe
      for (i=1; i<3; i++) begin : dqPipe
        always @(posedge clk_div)
          intf_dq_pipe[l][i] <= intf_dq_pipe[l][i-1];
      end
      // Selecting Data from Pipe
      for (i=0; i<3; i++) assign intf_dq_array[l][i*8+:8] = intf_dq_pipe[l][2-i];
      always @(posedge clk_div) intf_dq_d[l] <= intf_dq_array[l][(16-param_io_out_del_r1[l])+:8];
    end
  endgenerate

  // ============================== Initialization ==============================
  initial begin
    intf_ck_t_0        = 0;
    intf_cabi_n_0      = 0;
    intf_wck_t_0       = 0;
    tbyte_in_0         = 0;
    tx_t_0             = 0;
    top_cke_n_0        = 0;
    intf_ca_0          = '{10{0}};
    init_edc_0         = '{2{0}};
    intf_dbi_n_0       = '{2{0}};
    param_io_out_del_r1 = '{16{4'd8}};
    intf_ck_t_d        = 0;
    intf_cabi_n_d      = 0;
    intf_wck_t_d       = 0;
    tbyte_in_d         = 0;
    tx_t_d             = 0;
    top_cke_n_d        = 0;
    intf_ca_d          = '{10{0}};
    init_edc_d         = '{2{0}};
    intf_dbi_n_d       = '{2{0}};
    intf_dq_pipe[15:1] = '{15{0}};
  end

endmodule
