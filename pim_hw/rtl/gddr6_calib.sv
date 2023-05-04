`timescale 1ps / 1ps

module gddr6_calib (
  input  logic clk,
  input  logic rst,
  output logic [CH_NUM-1:0]           cal_done,
  output logic [CH_NUM-1:0]           cal_ref_stop,                        // Requests to stop refresh operations in each controller
  input  logic [CH_NUM-1:0]           ref_idle,                            // Refresh handler status from each controller
  // Initialization Handler Interface
  input  logic [CH_NUM-1:0]           init_done,
  // Interconnect Interface (for Pattern Generator)
  output logic                        cal_ui_ctrl,
  input  logic                        icnt_rdy,
  output logic                        pgen_pkt_valid,
  output pkt_t                        pgen_pkt,
  // MCS Interface
  output logic [$clog2(CH_NUM)-1:0]   cal_ch_idx,
  input  logic [31:0]                 cal_addr,
  output logic [31:0]                 cal_rd_data,
  input  logic                        cal_rd_strobe_lvl,
  input  logic [31:0]                 cal_wr_data,
  input  logic                        cal_wr_strobe_lvl,
  output logic                        cal_rdy_lvl,
  // Calibration Parameter Interface
  output logic [CH_NUM-1:0][3:0][6:0] param_vref_tune,
  output logic [CH_NUM-1:0]           param_smpl_edge,                     // Selects PLL clock edge for data capture (0:Rising, 1:Falling)
  output logic [CH_NUM-1:0]           param_sync_ordr,                     // Selects which synchronization FIFO or pipe is written first when crossing data from PHY to the controller
  output logic [CH_NUM-1:0][18*4-1:0] param_io_in_del,                     // Adds 0-15 RX FIFO clock cycles delay during data capture (per line)
  output logic [CH_NUM-1:0][16*4-1:0] param_io_out_del,                    // Adds 0-15 RX FIFO clock cycles delay during data output (per line)
  output logic [CH_NUM-1:0][2:0]      param_rl_del,                        // Adds 0-7 clock cycle delay for expected data in Data Handler
  // Command Handler Interface
  output logic [CH_NUM-1:0]           cal_ck_en,
  output logic [CH_NUM-1:0]           cal_wck_en,
  output pkt_t                        cal_pkt,
  output cmd_t                        cal_cmd,
  output logic [CH_NUM-1:0]           cal_pkt_valid,
  input  logic [CH_NUM-1:0]           aimc_cal_rdy,
  // Data Handler Interface
  input  logic [CH_NUM-1:0]           aimc_cal_pkt_valid,
  input  pkt_t                        aimc_cal_pkt [CH_NUM-1:0],
  input  logic [CH_NUM-1:0][31:0]     aimc_cal_edc,
  input  logic [CH_NUM-1:0]           aimc_temp_valid,
  input  logic [CH_NUM-1:0][7:0]      aimc_temp_data);

  // =============================== Signal Declarations ==============================
  // Initial Delay Values
  localparam [0:0] SAMP_INI = 0;                                           // Selects PLL clock edge for data capture (0:Rising, 1:Falling)
  localparam [0:0] SYNC_INI = 1;                                           // Selects which synchronization FIFO or pipe is written first when crossing data from PHY to the controller
  localparam [3:0] IDEL_INI = 4'd4;                                        // Adds 0-15 RX FIFO clock cycles delay during data capture (per line)
  localparam [3:0] ODEL_INI = 4'd8;                                        // Adds 0-15 RX FIFO clock cycles delay during data output (per line)
  localparam [2:0] RL_INI   = 3'd0;                                        // Adds 0-7 clock cycle delay for expected data in Data Handler
  // Responses to MCS Commands
  localparam [31:0] SUCCESS = 32'h01234567;
  localparam [31:0] FAIL    = 32'hFFFFFFFF;

  // Type Definitions
  typedef enum logic [4:0] {STATUS_REG=0, CH_IDX_REG, OREG_REG, IREG_REG, WCK2CK_REG, WCKSHIFT_REG, RDTR_REG, WRTR_REG, DELAY_REG, PTNGEN_REG, EXIT_TR_REG, UNKNOWN_REG} cal_reg_t;
  typedef enum logic [3:0] {FSM_INIT=0, FSM_IDLE, FSM_RD_REG, FSM_WCK2CK, FSM_WCKSHIFT, FSM_WCK2CK_EXIT, FSM_RDTR, FSM_WRTR, FSM_EXIT, FSM_PTNGEN, FSM_ERROR} state_t;

  // MCS Communication Infrastructure
  logic [15:0]                        cal_reg_addr;
  cal_reg_t                           cal_reg;                             // Decoded MCS command
  logic                               cal_rd_strobe_lvl_d;                 // MCS read strobe delayed 1 clk (for edge detection)
  logic                               cal_wr_strobe_lvl_d;                 // MCS write strobe delayed 1 clk (for edge detection)
  logic                               mcs_rd;                              // Pulse indicating MCS read request
  logic                               mcs_wr;                              // Pulse indicating MCS write request
  logic                               cal_rdy_lvl_nxt;                     // Ready response signal to MCS
  logic                               cal_rd_data_we;
  logic [31:0]                        cal_rd_data_nxt;
  logic [31:0]                        cal_addr_d;                          // MCS address delayed 1 clk for better synthesis timing
  logic [31:0]                        cal_wr_data_d;                       // MCS data delayed 1 clk for better synthesis timing
  // Command Handler Signals
  logic                               cal_wck_en_nxt;
  logic                               cal_pkt_valid_nxt;
  pkt_t                               cal_pkt_nxt;
  cmd_t                               cal_cmd_nxt;
  // Input Data Buffers
  logic [CH_NUM-1:0]                  aimc_cal_pkt_valid_r1;
  logic                               aimc_cal_pkt_valid_r2;
  logic [CH_NUM-1:0]                  aimc_temp_valid_r1;
  logic                               aimc_temp_valid_r2;
  pkt_t                               aimc_cal_pkt_r1 [CH_NUM-1:0];
  pkt_t                               aimc_cal_pkt_r2;
  logic [CH_NUM-1:0][31:0]            aimc_cal_edc_r1;
  logic [31:0]                        aimc_cal_edc_r2;
  logic [CH_NUM-1:0][7:0]             aimc_temp_data_r1;
  logic [7:0]                         aimc_temp_data_r2;
  // Internal Memory Registers
  logic [3:0]                         oreg_page_addr;                      // Page address in imem/omem (0x0-0x5), corresponds to burst index
  logic [3:0]                         oreg_dword_addr;                     // Dword address in imem/omem (0x0-0x8), corresponds to position within burst
  logic                               oreg_dword_we;
  logic [31:0]                        oreg_dword_din;
  logic [31:0]                        oreg_dword_dout;
  logic [287:0]                       oreg_page_dout;
  logic [3:0]                         ireg_page_addr;
  logic [3:0]                         ireg_dword_addr;
  logic                               ireg_page_we;
  logic [31:0]                        ireg_dword_dout;
  logic [287:0]                       ireg_page_din;
  logic [9:0]                         del_reg_addr;                        // Delay register address
  logic                               del_reg_we;                          // Master delay write enable signal
  logic [CH_NUM-1:0]                  param_smpl_edge_nxt;
  logic [CH_NUM-1:0]                  param_sync_ordr_nxt;
  logic [CH_NUM-1:0][2:0]             param_rl_del_nxt;
  logic [CH_NUM-1:0][31:0]            del_reg_data;                        // Data passed to the MCS after reading a delay register
  logic [CH_NUM-1:0][33:0][3:0]       param_io_del_array, param_io_del_array_nxt;  // IO iput delays for 16 DQ and 2 EDC lines, IO output delays for 16 DQ
  logic [7:0]                         temp_data_r1;                        // Register storing temperature data for MCS read-out
  // Calibration FSM Signals
  state_t                             state, state_nxt;                    // Main calibration module state
  logic [1:0]                         step, step_nxt;                      // General use counter for sequentially performing steps in each FSM state
  logic [1:0]                         mrs_step, mrs_step_nxt;              // Step counter specifically used in issue_mrs() task
  logic [$clog2(CH_NUM)-1:0]          ch_idx, ch_idx_nxt;                  // Currently selected channel index
  dram_time_t                         wait_cnt, wait_cnt_nxt;
  dram_time_t                         wait2rd, wait2rd_nxt;
  dram_time_t                         wait2wr, wait2wr_nxt;
  logic                               mrs_done;
  logic                               wait_done;
  logic [3:0]                         ld_brst_cnt, ld_brst_cnt_nxt;        // Burst counter during LDFF and WRTR
  logic [3:0]                         ld_cmd_cnt, ld_cmd_cnt_nxt;          // Command counter for loading a single burst during LDFF and WRTR
  logic                               ld_done;                             // Indicates that DQ/DBI_n FIFO in DRAM is fully loaded
  logic [3:0]                         ld_step, ld_step_nxt;
  logic [3:0]                         rdtr_brst_cnt, rdtr_brst_cnt_nxt;
  logic                               rdtr_done;                           // Indicates that all RDTR commands have been issued
  logic [3:0]                         rdtr_step, rdtr_step_nxt;
  logic [3:0]                         brst_last, brst_last_nxt;            // Index of the last burst used during training (0-5)
  logic [3:0]                         ireg_page_cnt, ireg_page_cnt_nxt;
  logic                               intf_pkt_valid_rd;                   // aimc_cal_pkt_valid signal with write responses filtered
  // Flags
  logic [CH_NUM-1:0]                  wck2ck_on, wck2ck_on_nxt;            // Indicates that the DRAM is in WCK2CK training state (must exit via MRS)
  logic                               wck_byte_sel;                        // Byte selected for WCK shifting
  logic [CH_NUM-1:0][1:0][1:0]        wck_shift_mr, wck_shift_mr_nxt;      // WCK Quad Shift MR values for Byte 0 and Byte 1
  logic [CH_NUM-1:0]                  cal_done_nxt;                        // Indicates that calibration is finished
  logic [CH_NUM-1:0]                  cal_done_r0;                         // Register chain that the implementation tool can use to mitigate high fan-out
  logic [CH_NUM-1:0]                  cal_done_r1;
  logic [CH_NUM-1:0]                  cal_done_r2;
  logic [CH_NUM-1:0]                  cal_ref_stop_nxt;
  logic [CH_NUM-1:0]                  cal_ref_stop_r0;
  logic [CH_NUM-1:0]                  cal_ref_stop_r1;
  logic [CH_NUM-1:0]                  cal_ref_stop_r2;
  logic                               rdtr_pend, rdtr_pend_nxt;            // Indicates that RDTR is pending after WCK2CK exit sequence
  logic                               wrtr_pend, wrtr_pend_nxt;            // Indicates that WRTR is pending after WCK2CK exit sequence
  logic                               exit_pend, exit_pend_nxt;            // Indicates that training EXIT is pending after WCK2CK exit sequence
  logic                               rdtr_done_pend, rdtr_done_pend_nxt;  // Indicates that the last data from RDTR is received and rdtr_done can be issued
  logic                               bk_act, bk_act_nxt;                  // Indicates that a bank is activated
  // Pattern Generator Signals
  logic                               cal_pgen_start;                      // Signal for initiating pattern generation
  logic [31:0]                        march_len, march_len_nxt;            // Number of packets to issue during the march
  logic                               cal_ui_ctrl_nxt;                     // Indicator signal for driving Scheduler input from the Calibration Handler
  logic [11:0]                        pgen_rd_ptr, pgen_rd_ptr_nxt;        // Pattern Generator memory pointer
  logic [287:0]                       pgen_dout;                           // Data otput from the Pattern Generator
  logic                               pgen_done;                           // Pattern completion signal from the Pattern Generator
  logic [511:0]                       param;                               // Pattern Generator parameters passed from the Calibration Handler
  logic [3:0]                         param_addr;                          // Address for selecting a 32-bit parameter
  logic                               param_we;                            // Write enable signal for parameter register

reg [3:0]         debug_state;

  // ============================== Constant Assignments ==============================
  assign cal_ck_en       = {CH_NUM{1'b1}};
  assign param_vref_tune = {(CH_NUM*4){7'b0011000}};                       // Setting all VREF to constant 70% of VCC

  // =============================== MCS Command Capture ==============================
  // Storing previous strobe states
  always @(posedge clk) begin
    cal_rd_strobe_lvl_d <= cal_rd_strobe_lvl;
    cal_wr_strobe_lvl_d <= cal_wr_strobe_lvl;
  end

  always @(posedge clk, posedge rst)
    if (rst) begin
      mcs_rd <= 0;
      mcs_wr <= 0;
    end
    else begin
      mcs_rd <= (cal_rd_strobe_lvl != cal_rd_strobe_lvl_d) && (cal_addr[31:24] == 8'hCA);
      mcs_wr <= (cal_wr_strobe_lvl != cal_wr_strobe_lvl_d) && (cal_addr[31:24] == 8'hCA);
    end

  always @(posedge clk) begin
    cal_addr_d    <= cal_addr;
    cal_wr_data_d <= cal_wr_data;
  end

  assign cal_reg_addr = cal_addr_d[19:4];

  // Decoding input command
  always_comb begin
    casex (cal_reg_addr)
      16'h000? : cal_reg = STATUS_REG;               // RD    0x000[H]   : Reports status of the block selected by [H]
      16'h0010 : cal_reg = CH_IDX_REG;               // RD/WR 0x0010     : Sets and reports the selected channel index
      16'h10?? : cal_reg = OREG_REG;                 // RD/WR 0x10[X][Y] : Reads/Writes 32 bits from/to the output memory position 0x[X][Y] (X:0x0-0x5, Y:0x0-0x7)
      16'h11?? : cal_reg = IREG_REG;                 // RD    0x11[X][Y] : Reads 32 bits from the input memory position 0x[X][Y] (X:0x0-0x5, Y:0x0-0x8)
      16'h2000 : cal_reg = WCK2CK_REG;               // RD    0x2000     : Enters WCK2CK training (if required) and reports EDC values
      16'h201? : cal_reg = WCKSHIFT_REG;             // RD/WR 0x201[B]   : Writes or reports WCK Quad Shift (MR10, OP4-OP7) value for Byte [B]
      16'h300? : cal_reg = RDTR_REG;                 // RD    0x300[N]   : Performs RDTR training [N] times (0x1-0x6) and reports when done
      16'h400? : cal_reg = WRTR_REG;                 // RD    0x400[N]   : Performs WRTR training [N] times (0x1-0x6) and reports when done
      16'hD??? : cal_reg = DELAY_REG;                // RD/WR 0xD[LL][R] : Controls coarse delays, [R]=0x0: sampling delay (0-1), 0x1: capture sequence (0-1), 0x2: RL delay (0-3)
      16'hE??? : cal_reg = PTNGEN_REG;               // RD/WR 0xE0[P][I] : Accesses Pattern Generator, [P] is parameter address, [I] is an instruction
      16'hFFFF : cal_reg = EXIT_TR_REG;              // RD    0xFFFF     : Sets cal_done_r0 flag to 1 and reports when done
      default  : cal_reg = UNKNOWN_REG;
    endcase
  end

  // ================================= Delay Registers ================================
  always_comb begin
    del_reg_data           = 0;
    param_smpl_edge_nxt    = param_smpl_edge;
    param_sync_ordr_nxt    = param_sync_ordr;
    param_io_del_array_nxt = param_io_del_array;
    param_rl_del_nxt       = param_rl_del;

    case (del_reg_addr[3:0])
      4'h0 : begin
        del_reg_data = {30'd0, param_smpl_edge[ch_idx]};
        if (del_reg_we) param_smpl_edge_nxt[ch_idx] = cal_wr_data_d[0];
      end
      4'h1 : begin
        del_reg_data = {30'd0, param_sync_ordr[ch_idx]};
        if (del_reg_we) param_sync_ordr_nxt[ch_idx] = cal_wr_data_d[0];
      end
      4'h2 : begin
        del_reg_data = {28'd0, param_io_del_array[ch_idx][del_reg_addr[9:4]]};
        if (del_reg_we) param_io_del_array_nxt[ch_idx][del_reg_addr[9:4]][3:0] = cal_wr_data_d[3:0];
      end
      4'h3 : begin
        del_reg_data = {29'd0, param_rl_del[ch_idx]};
        if (del_reg_we) param_rl_del_nxt[ch_idx] = cal_wr_data_d[2:0];
      end
    endcase
  end

  always @(posedge clk, posedge rst)
    if (rst) begin
      param_smpl_edge    <= {CH_NUM{SAMP_INI}};
      param_sync_ordr    <= {CH_NUM{SYNC_INI}};
      param_io_del_array <= {CH_NUM{{16{ODEL_INI}}, {18{IDEL_INI}}}};
      param_rl_del       <= {CH_NUM{RL_INI}};
    end
    else begin
      param_smpl_edge    <= param_smpl_edge_nxt;
      param_sync_ordr    <= param_sync_ordr_nxt;
      param_io_del_array <= param_io_del_array_nxt;
      param_rl_del       <= param_rl_del_nxt;
    end

  always_comb begin
    for (int ch=0; ch<CH_NUM; ch++) begin
      for (int idx=0; idx<18; idx++) param_io_in_del [ch][idx*4+:4] = param_io_del_array[ch][idx][3:0];
      for (int idx=0; idx<16; idx++) param_io_out_del[ch][idx*4+:4] = param_io_del_array[ch][idx+18][3:0];
    end
  end

  // =============================== Pattern Generator ================================
  generate
    if (PTNGEN_EN == "TRUE") begin
      calib_ptngen calib_ptngen (
        .clk,
        .rst,
        // Calibration Handler Interface
        .cal_pgen_start,
        .param,
        .march_len,
        .pgen_rd_ptr,
        .pgen_dout,
        .pgen_done,
        // Scheduler Interface
        .sched_rdy (icnt_rdy),
        .pgen_pkt_valid,
        .pgen_pkt,
        // Data Handler Interface
        .aimc_cal_pkt_valid (aimc_cal_pkt_valid_r2),
        .aimc_cal_pkt       (aimc_cal_pkt_r2));
    end
    else begin
      assign pgen_dout      = {288{1'b0}};
      assign pgen_done      = 1'b1;
      assign pgen_pkt_valid = 1'b0;
      assign pgen_pkt       = {$bits(pkt_t){1'b0}};
    end
  endgenerate

  always @(posedge clk)
    if (param_we) param[param_addr*32+:32] <= cal_wr_data_d;

  // ============================= Calibration Handler FSM ============================
  // Broadcast channel index
  always @(posedge clk, posedge rst)
    if (rst) cal_ch_idx <= 0;
    else     cal_ch_idx <= ch_idx;

  // Register chain for cal_done
  always @(posedge clk, posedge rst)
    if (rst) begin
      cal_done_r1 <= 0;
      cal_done_r2 <= 0;
      cal_done    <= 0;
    end
    else begin
      cal_done_r1 <= cal_done_r0;
      cal_done_r2 <= cal_done_r1;
      cal_done    <= cal_done_r2;
    end

  // Register chain for cal_ref_stop
  always @(posedge clk, posedge rst)
    if (rst) begin
      cal_ref_stop_r1 <= 0;
      cal_ref_stop_r2 <= 0;
      cal_ref_stop    <= 0;
    end
    else begin
      cal_ref_stop_r1 <= cal_ref_stop_r0;
      cal_ref_stop_r2 <= cal_ref_stop_r1;
      cal_ref_stop    <= cal_ref_stop_r2;
    end

  // Input buffers for validity signals from all channels
  always @(posedge clk, posedge rst)
    if (rst) begin
      aimc_cal_pkt_valid_r1 <= 0;
      aimc_cal_pkt_valid_r2 <= 0;
    end
    else begin
      aimc_cal_pkt_valid_r1 <= aimc_cal_pkt_valid;
      aimc_cal_pkt_valid_r2 <= aimc_cal_pkt_valid_r1 [ch_idx];
    end

  always @(posedge clk, posedge rst)
    if (rst) begin
      aimc_temp_valid_r1 <= 0;
      aimc_temp_valid_r2 <= 0;
    end
    else begin
      aimc_temp_valid_r1 <= aimc_temp_valid;
      aimc_temp_valid_r2 <= aimc_temp_valid_r1 [ch_idx];
    end

  // Input buffers for data signals from all channels
  always @(posedge clk) begin
    aimc_cal_pkt_r1   <= aimc_cal_pkt;
    aimc_cal_pkt_r2   <= aimc_cal_pkt_r1 [ch_idx];
  end

  always @(posedge clk) begin
    aimc_cal_edc_r1   <= aimc_cal_edc;
    aimc_cal_edc_r2   <= aimc_cal_edc_r1 [ch_idx];
  end
  
  always @(posedge clk) begin
    aimc_temp_data_r1 <= aimc_temp_data;
    aimc_temp_data_r2 <= aimc_temp_data_r1 [ch_idx];
  end

  assign intf_pkt_valid_rd = aimc_cal_pkt_valid_r2 && (aimc_cal_pkt_r2.req_type == TR_READ);

  // Output Training Data Register (issued with LDFF, WRTR)
  calib_mem oreg (
    .clk        (clk),
    .page_we    (1'b0),
    .dword_we   (oreg_dword_we),
    .page_addr  (oreg_page_addr),
    .dword_addr (oreg_dword_addr),
    .dword_din  (oreg_dword_din),
    .dword_dout (oreg_dword_dout),
    .page_din   ({288{1'b0}}),
    .page_dout  (oreg_page_dout));

  // Input Training Data Register (captured during RDTR)
  calib_mem ireg (
    .clk        (clk),
    .page_we    (ireg_page_we),
    .dword_we   (1'b0),
    .page_addr  (ireg_page_addr),
    .dword_addr (ireg_dword_addr),
    .dword_din  ({32{1'b0}}),
    .dword_dout (ireg_dword_dout),
    .page_din   (ireg_page_din),
    .page_dout  ());

  // MCS Interface
  always @(posedge clk, posedge rst)
    if (rst) cal_rdy_lvl <= 0;
    else     cal_rdy_lvl <= cal_rdy_lvl_nxt;

  always @(posedge clk)
    if (cal_rd_data_we) cal_rd_data <= cal_rd_data_nxt;

  // Command Handler Interface
  always @(posedge clk, posedge rst)
    if (rst) begin
      cal_wck_en    <= {CH_NUM{1'b1}};
      cal_pkt_valid <= {CH_NUM{1'b0}};
    end
    else begin
      cal_wck_en    [ch_idx] <= cal_wck_en_nxt;
      cal_pkt_valid [ch_idx] <= cal_pkt_valid_nxt;
    end

  // Temperature Monitor
  always @(posedge clk, posedge rst)
    if      (rst)                temp_data_r1 <= 0;
    else if (aimc_temp_valid_r2) temp_data_r1 <= aimc_temp_data_r2;

  always @(posedge clk) begin
    cal_pkt <= cal_pkt_nxt;
    cal_cmd <= cal_cmd_nxt;
  end 

  // Calibration FSM Signals
  always @(posedge clk, posedge rst)
    if (rst) begin
      state         <= FSM_INIT;
      step          <= 0;
      mrs_step      <= 0;
      ch_idx        <= 0;
      ld_brst_cnt   <= 0;
      ld_cmd_cnt    <= 0;
      ld_step       <= 0;
      rdtr_brst_cnt <= 0;
      rdtr_step     <= 0;
      brst_last     <= 0;
      ireg_page_cnt <= 0;
    end
    else begin
      state         <= state_nxt;
      step          <= step_nxt;
      mrs_step      <= mrs_step_nxt;
      ch_idx        <= ch_idx_nxt;
      ld_brst_cnt   <= ld_brst_cnt_nxt;
      ld_cmd_cnt    <= ld_cmd_cnt_nxt;
      ld_step       <= ld_step_nxt;
      rdtr_brst_cnt <= rdtr_brst_cnt_nxt;
      rdtr_step     <= rdtr_step_nxt;
      brst_last     <= brst_last_nxt;
      ireg_page_cnt <= ireg_page_cnt_nxt;
    end

  // Flags and Registers
  always @(posedge clk, posedge rst)
    if (rst) begin
      cal_done_r0     <= 0;
      cal_ref_stop_r0 <= 0;
      wck2ck_on       <= 0;
      wck_shift_mr    <= 0;
      rdtr_pend       <= 0;
      wrtr_pend       <= 0;
      exit_pend       <= 0;
      bk_act          <= 0;
      rdtr_done_pend  <= 0;
    end
    else begin
      cal_done_r0     <= cal_done_nxt;
      cal_ref_stop_r0 <= cal_ref_stop_nxt;
      wck2ck_on       <= wck2ck_on_nxt;
      wck_shift_mr    <= wck_shift_mr_nxt;
      rdtr_pend       <= rdtr_pend_nxt;
      wrtr_pend       <= wrtr_pend_nxt;
      exit_pend       <= exit_pend_nxt;
      bk_act          <= bk_act_nxt;
      rdtr_done_pend  <= rdtr_done_pend_nxt;
    end

  // Pattern Generator Signals
  always @(posedge clk, posedge rst)
    if (rst) begin
      cal_ui_ctrl <= 0;
      pgen_rd_ptr <= 0;
    end
    else begin
      cal_ui_ctrl <= cal_ui_ctrl_nxt;
      pgen_rd_ptr <= pgen_rd_ptr_nxt;
    end

  always @(posedge clk) march_len <= march_len_nxt;

  // Delay Counter
  always @(posedge clk, posedge rst)
    if (rst) wait_cnt <= 0;
    else     wait_cnt <= wait_cnt_nxt;

  assign wait_done = (wait_cnt == 1);

  always @(posedge clk, posedge rst)
    if (rst) begin
      wait2rd <= 0;
      wait2wr <= 0;
    end
    else begin
      wait2rd <= wait2rd_nxt;
      wait2wr <= wait2wr_nxt;
    end
  //
  //        (             )
  //         `--(_   _)--'
  //              Y-Y
  //             /@@ \
  //            /     \
  //            `--'.  \             ,
  //                |   `.__________/)
  //    Calibration Handler FSM Starts Here
  //
  always_comb begin
    // MCS Communication
    cal_rd_data_we        = 0;
    cal_rdy_lvl_nxt       = cal_rdy_lvl;
    cal_rd_data_nxt       = FAIL;                 // Default READ response is FAIL
    // Command Handler Signals
    cal_wck_en_nxt        = cal_wck_en[ch_idx];
    cal_pkt_nxt           = 0;
    cal_cmd_nxt           = NOP1;
    cal_pkt_valid_nxt     = 0;
    // Internal Memory Signals
    oreg_page_addr        = 0;
    oreg_dword_addr       = 0;
    oreg_dword_din        = cal_wr_data_d;
    oreg_dword_we         = 0;
    ireg_page_addr        = 0;
    ireg_dword_addr       = 0;
    ireg_page_din         = {aimc_cal_edc_r2, aimc_cal_pkt_r2.data};
    ireg_page_we          = 0;
    // Calibration FSM Signals
    state_nxt             = state;
    step_nxt              = step;
    mrs_step_nxt          = mrs_step;
    ch_idx_nxt            = ch_idx;
    wait_cnt_nxt          = (wait_cnt == 0) ? 0 : wait_cnt - 1'b1;
    wait2rd_nxt           = (wait2rd  == 0) ? 0 : wait2rd  - 1'b1;
    wait2wr_nxt           = (wait2wr  == 0) ? 0 : wait2wr  - 1'b1;
    mrs_done              = 0;
    ld_brst_cnt_nxt       = 0;
    ld_cmd_cnt_nxt        = 0;
    ld_done               = 0;
    ld_step_nxt           = ld_step;
    rdtr_brst_cnt_nxt     = 0;
    rdtr_done             = 0;
    rdtr_step_nxt         = rdtr_step;
    brst_last_nxt         = brst_last;
    ireg_page_cnt_nxt     = 0;
    // Flags
    cal_done_nxt          = cal_done_r0;
    cal_ref_stop_nxt      = cal_ref_stop_r0;
    wck2ck_on_nxt         = wck2ck_on;
    wck_byte_sel          = 0;
    wck_shift_mr_nxt      = wck_shift_mr;
    rdtr_pend_nxt         = rdtr_pend;
    wrtr_pend_nxt         = wrtr_pend;
    exit_pend_nxt         = exit_pend;
    rdtr_done_pend_nxt    = rdtr_done_pend;
    bk_act_nxt            = bk_act;
    // Pattern Generator Signals
    march_len_nxt         = march_len;
    cal_pgen_start        = 0;
    cal_ui_ctrl_nxt       = cal_ui_ctrl;
    pgen_rd_ptr_nxt       = pgen_rd_ptr;
    param_addr            = 0;
    param_we              = 0;
    // Delay Signals
    del_reg_addr          = cal_addr_d[13:4];
    del_reg_we            = 0;

    case (state)
      // [Initialization State] - No training commands are allowed
      FSM_INIT : begin
        if (mcs_rd || mcs_wr) begin
          cal_rd_data_we  = mcs_rd;
          cal_rdy_lvl_nxt = ~cal_rdy_lvl;         // Accepting both MCS read and write commands; FAIL returned upon read
        end
        if (&init_done) state_nxt = FSM_IDLE;
      debug_state = FSM_INIT;
      end
 
      // [Idle State] - All training commands are allowed
      FSM_IDLE : begin
        if (CALIB_BYPASS == "TRUE") cal_done_nxt = {CH_NUM{1'b1}};

        if (mcs_rd || mcs_wr) begin
          case (cal_reg)
            STATUS_REG : begin
              cal_rd_data_we  = 1;
              case (cal_reg_addr[3:0])
                4'h0 : cal_rd_data_nxt = SUCCESS;
                4'h1 : cal_rd_data_nxt = {{(32-CH_NUM){1'b0}}, cal_done_r1};
                4'h2 : cal_rd_data_nxt = {24'd0, temp_data_r1};
                default : cal_rd_data_nxt = FAIL;
              endcase
              cal_rdy_lvl_nxt = ~cal_rdy_lvl;
            end
            CH_IDX_REG : begin
              cal_rd_data_nxt = 32'd0;
              cal_rd_data_nxt[$clog2(CH_NUM)-1:0] = ch_idx;
              if (mcs_wr) ch_idx_nxt = cal_wr_data_d[$clog2(CH_NUM)-1:0];
              else        cal_rd_data_we  = 1;
              cal_rdy_lvl_nxt = ~cal_rdy_lvl;
            end
            OREG_REG : begin
              oreg_page_addr  = cal_addr_d[11:8];
              oreg_dword_addr = cal_addr_d[7:4];
              if (mcs_wr) begin
                oreg_dword_we   = 1;              // Enable memory input in case of WRITE
                cal_rd_data_we  = 1;
                cal_rdy_lvl_nxt = ~cal_rdy_lvl;   // Changing rdy level to indicate that command has been received
              end
              else begin
                state_nxt = FSM_RD_REG;           // Switching to a separate state to wait for OREG data in case of READ
                step_nxt  = 0;                    // Step 0 corresponds to OREG in FSM_RD_REG
              end
            end
            IREG_REG : begin
              // Note: Write to IREG from MCS is not allowed
              ireg_page_addr  = cal_addr_d[11:8];
              ireg_dword_addr = cal_addr_d[7:4];
              // cal_rd_data_nxt = ireg_dword_dout;  // MCS read data register programmed using OREG data
              // cal_rd_data_we  = 1;
              // cal_rdy_lvl_nxt = ~cal_rdy_lvl;     // Changing rdy level to indicate that command has been received
              state_nxt       = FSM_RD_REG;       // Switching to a separate state to wait for IREG data
              step_nxt        = 1;                // Step 1 corresponds to IREG in FSM_RD_REG
            end
            WCK2CK_REG : begin
              state_nxt = FSM_WCK2CK;
            end
            WCKSHIFT_REG : begin
              wck_byte_sel         = cal_reg_addr[0];
              cal_rd_data_nxt[3:0] = wck_shift_mr[ch_idx];
              if (mcs_wr) begin
                wck_shift_mr_nxt[ch_idx][wck_byte_sel] = cal_wr_data_d[1:0];
                state_nxt                              = FSM_WCKSHIFT;
              end
              else begin
                cal_rd_data_we  = 1;
                cal_rdy_lvl_nxt = ~cal_rdy_lvl;
              end
            end
            RDTR_REG : begin
              if (wck2ck_on[ch_idx]) state_nxt = FSM_WCK2CK_EXIT;
              else                   state_nxt = FSM_RDTR;
              rdtr_pend_nxt = 1;
              brst_last_nxt = (cal_reg_addr[3:0] - 1'b1 > 4'd5) ? 4'd5 : (cal_reg_addr[3:0] - 1'b1);  // Making sure we don't get out of the 1-6 region
            end
            WRTR_REG : begin
              if (wck2ck_on[ch_idx]) state_nxt = FSM_WCK2CK_EXIT;
              else                   state_nxt = FSM_WRTR;
              wrtr_pend_nxt = 1;
              brst_last_nxt = (cal_reg_addr[3:0] - 1'b1 > 4'd5) ? 4'd5 : (cal_reg_addr[3:0] - 1'b1);  // Making sure we don't get out of the 1-6 region
            end
            DELAY_REG : begin
              del_reg_we      = mcs_wr;           // If write, enable memory input
              cal_rd_data_nxt = del_reg_data;
              cal_rd_data_we  = 1;
              cal_rdy_lvl_nxt = ~cal_rdy_lvl;     // Changing rdy level to indicate that command has been received
            end
            EXIT_TR_REG : begin
              if (wck2ck_on[ch_idx]) state_nxt = FSM_WCK2CK_EXIT;
              else                   state_nxt = FSM_EXIT;
              exit_pend_nxt = 1;
            end
            PTNGEN_REG : begin
              if (PTNGEN_EN == "TRUE") begin
                case (cal_reg_addr[3:0])
                  4'h0 : begin
                    state_nxt       = FSM_PTNGEN;
                    march_len_nxt   = cal_wr_data_d[31:0];
                    cal_ui_ctrl_nxt = 1;
                  end
                  4'h1 : begin
                    ireg_page_we    = 1;
                    pgen_rd_ptr_nxt = cal_wr_data_d[0] ? pgen_rd_ptr + 1'b1 : pgen_rd_ptr;  // Increment the pointer if data passed with the command is "1", otherwise, stay at the same pointer
                    cal_rdy_lvl_nxt = ~cal_rdy_lvl;
                  end
                  4'h2 : begin
                    pgen_rd_ptr_nxt = cal_wr_data_d[15:0];
                    cal_rdy_lvl_nxt = ~cal_rdy_lvl;
                  end
                  4'h3 : begin
                    cal_rd_data_we  = mcs_rd;
                    param_addr      = cal_addr_d[11:8];
                    param_we        = mcs_wr;
                    cal_rd_data_nxt = param[param_addr*32+:32];
                    cal_rdy_lvl_nxt = ~cal_rdy_lvl;
                  end
                  default : begin
                    cal_rd_data_we  = mcs_rd;
                    cal_rdy_lvl_nxt = ~cal_rdy_lvl;
                  end
                endcase
              end
              else begin
                cal_rd_data_we  = 1;
                cal_rdy_lvl_nxt = ~cal_rdy_lvl;
              end
            end
            default : begin
              cal_rd_data_we  = 1;
              cal_rdy_lvl_nxt = ~cal_rdy_lvl;
            end
          endcase
        end
        debug_state = FSM_IDLE;
      end

      // [OREG/IREG Read State]
      FSM_RD_REG : begin
        case (step)
          0 : cal_rd_data_nxt = oreg_dword_dout;
          1 : cal_rd_data_nxt = ireg_dword_dout;
        endcase
        cal_rd_data_we  = 1;
        cal_rdy_lvl_nxt = ~cal_rdy_lvl;     // Changing rdy level to indicate that command has been received
        state_nxt       = FSM_IDLE;
        step_nxt        = 0;
      debug_state = FSM_RD_REG;
      end

      // [WCK2CK Training State]
      FSM_WCK2CK : begin
        // When WCK2CK is ON, run one iteration of EDC capture
        if (wck2ck_on[ch_idx]) begin
          case (step)
            0 : begin
              step_nxt             = 1;
              cal_pkt_valid_nxt    = 1;
              cal_pkt_nxt.req_type = TR_READ;
              cal_cmd_nxt          = WCK2CK;
              // wait_cnt_nxt    = 20;    // Temporary value of 20 clock cycles; fine-tune this to match the minimum delay necessary for capturing EDC
            end
            1 : begin
              // if (wait_done) begin
              if (intf_pkt_valid_rd) begin
                step_nxt        = 0;
                state_nxt       = FSM_IDLE;
                cal_rd_data_we  = 1;
                cal_rd_data_nxt = aimc_cal_edc_r2;
                cal_rdy_lvl_nxt = ~cal_rdy_lvl;
              end
            end
          endcase
        end
        // If WCK2CK is OFF, run WCK2CK ENTRY sequence
        else begin
          case (step)
            0 : begin
              step_nxt       = 1;
              cal_wck_en_nxt = 0;
              wait_cnt_nxt   = max_val((ck_adj(cfr_time_init.tWCK2MRS)-1), 1);  // Not allowing values < 2*tCK (need to skip state 1 if such values required)
            end
            1 : begin
              if (wait_done) begin
                // MR10 OP8 - WCK2CK (JEDEC Page 27)
                issue_mrs(.MR(4'hA), .A({2'b00, 1'b0, 1'b1, wck_shift_mr[ch_idx][1], wck_shift_mr[ch_idx][0], 4'b0000}), .tDEL(cfr_time_init.tMRSTWCK + 2));  // "+2" required to compensate for command path through Command Handler and PHY
                if (mrs_done) begin
                  step_nxt       = 2;
                  cal_wck_en_nxt = 1;
                  wait_cnt_nxt   = max_val((ck_adj(cfr_time_init.tWCK2TR)-1), 1); // Not allowing values < 2*tCK (need to skip state 3 if such values required)
                end
              end
            end
            2 : begin
              if (wait_done) begin
                step_nxt              = 0;
                wck2ck_on_nxt[ch_idx] = 1;
              end
            end
          endcase
        end
      debug_state = FSM_WCK2CK;
      end

      // [WCK Quad Shift MRS Programming State]
      FSM_WCKSHIFT : begin
        issue_mrs(.MR(4'hA), .A({2'b00, 1'b0, wck2ck_on[ch_idx], wck_shift_mr[ch_idx][1], wck_shift_mr[ch_idx][0], 4'b0000}), .tDEL(cfr_time_init.tMOD));  // MR10 OP4-OP7 - WCK2CK (JEDEC Page 27)
        if (mrs_done) begin
          state_nxt       = FSM_IDLE;
          cal_rdy_lvl_nxt = ~cal_rdy_lvl;
        end
      debug_state = FSM_WCKSHIFT;        
      end

      // [WCK2CK Training Exit State]
      FSM_WCK2CK_EXIT : begin
        issue_mrs(.MR(4'hA), .A({2'b00, 1'b0, 1'b0, wck_shift_mr[ch_idx][1], wck_shift_mr[ch_idx][0], 4'b0000}), .tDEL(cfr_time_init.tMOD));  // MR10 OP8 - WCK2CK (JEDEC Page 27)
        if (mrs_done) begin
          step_nxt      = 0;
          wck2ck_on_nxt = 0;
          if      (rdtr_pend) state_nxt = FSM_RDTR;
          else if (wrtr_pend) state_nxt = FSM_WRTR;
          else if (exit_pend) state_nxt = FSM_EXIT;
          else                state_nxt = FSM_ERROR;
        end
      debug_state = FSM_WCK2CK_EXIT;             
      end

      // [Read Training State]
      FSM_RDTR : begin
        case (step)
          0 : begin
            issue_ldff();
            if (ld_done) step_nxt = bk_act ? 3 : 1;
          end
          1 : begin
            cal_cmd_nxt = ACT;
            if (aimc_cal_rdy) begin
              cal_pkt_valid_nxt = 1;
              wait_cnt_nxt      = max_val((ck_adj(cfr_time_init.tRCDRTR)-1), 1);  // Not allowing values < 2*tCK (need to skip state 2 if such values required)
              step_nxt          = 2;
              bk_act_nxt        = 1;
            end
          end
          2 : begin
            if (wait_done) step_nxt = 3;  // Cannot switch to state 3 from state 1 directly, since issue_rdtr uses "wait_done" variable
          end
          3 : begin
            issue_rdtr();
            if (rdtr_done) begin
              step_nxt         = 0;
              state_nxt        = FSM_IDLE;
              cal_rd_data_we   = 1;
              cal_rd_data_nxt  = SUCCESS;
              cal_rdy_lvl_nxt  = ~cal_rdy_lvl;
              rdtr_pend_nxt    = 0;
            end
          end
        endcase
        debug_state = FSM_RDTR;  
      end

      // [Write Training State]
      FSM_WRTR : begin
        case (step)
          0 : begin
            if (bk_act) begin
              step_nxt = 2;
            end
            else begin
              cal_cmd_nxt = ACT;
              if (aimc_cal_rdy) begin
                cal_pkt_valid_nxt = 1;
                wait_cnt_nxt      = max_val((ck_adj(cfr_time_init.tRCDRTR)-1), 1);  // Not allowing values < 2*tCK (need to skip state 2 if such values required)
                step_nxt          = 1;
                bk_act_nxt        = 1;
              end
            end
          end
          1 : begin
            if (wait_done) step_nxt = 2;  // Cannot switch to state 2 from state 0 directly, since issue_wrtr uses "wait_done" variable
          end
          2 : begin
            issue_wrtr();
            if (ld_done) step_nxt = 3;
          end
          3 : begin
            issue_rdtr();
            if (rdtr_done) begin
              step_nxt         = 0;
              state_nxt        = FSM_IDLE;
              cal_rd_data_we   = 1;
              cal_rd_data_nxt  = SUCCESS;
              cal_rdy_lvl_nxt  = ~cal_rdy_lvl;
              wrtr_pend_nxt    = 0;
            end
          end
        endcase
        debug_state = FSM_WRTR;          
      end

      // [Training Entry/Exit State]
      FSM_EXIT : begin
        case (step)
          0 : begin
            if (!cal_done_r0[ch_idx]) begin
              step_nxt = 2;                                                     // Going to step 2 immediately if exiting; stopping refresh first if entering
            end
            else begin
              cal_ref_stop_nxt[ch_idx] = 1;                                     // Requesting Refresh Handler to return to idle state (for training re-entry)
              step_nxt = 1;
            end
            wait_cnt_nxt = 3;                                                   // Need to wait for ref_idle to fully propagate to avoid misinterpreting refresh handler's state
          end
          1 : begin
            if (wait_done && ref_idle[ch_idx]) begin
              cal_done_nxt[ch_idx] = 0;                                         // Deasserting cal_done after making sure that refresh handler is idle
              wait_cnt_nxt         = 3;                                         // Need to wait for cal_done to propagate to make sure that PHY entry circuits have switched to calibration handler
              step_nxt             = 2;
            end
          end
          2 : begin
            // if (bk_act || cal_done_r0[ch_idx]) begin                         // Precharging when exiting the training with active banks (timing guaranteed) or when reentering (timing not guaranteed)
              if (aimc_cal_rdy[ch_idx] && wait_done) begin
                cal_cmd_nxt       = PREAB;
                cal_pkt_valid_nxt = 1;
                wait_cnt_nxt      = max_val((ck_adj(cfr_time_init.tRP)-1), 1);  // Not allowing values < 2*tCK (need to skip state 2 if such values required)
                step_nxt          = 3;
                bk_act_nxt        = 0;
              end
            // end
            // else begin 
            //   step_nxt = 1;
            //   wait_cnt_nxt = 1;
            // end
          end
          3 : begin
            if (wait_done) begin
              state_nxt                = FSM_IDLE;
              cal_done_nxt[ch_idx]     = !cal_ref_stop[ch_idx];                  // Refresh stop indicates calibration re-rentry, cal_done should then stay at 0
              cal_ref_stop_nxt[ch_idx] = 0;
              cal_rd_data_we           = 1;
              cal_rd_data_nxt          = SUCCESS;
              cal_rdy_lvl_nxt          = ~cal_rdy_lvl;
              exit_pend_nxt            = 0;
              step_nxt                 = 0;
            end
          end
        endcase
        debug_state = FSM_EXIT;                 
      end

      // [Pattern Generator Control State]
      FSM_PTNGEN : begin
        case (step)
          0 : begin
            cal_pgen_start = 1'b1;
            step_nxt       = 1;
          end
          1 : begin
            if (pgen_done) begin
              state_nxt       = FSM_IDLE;
              cal_rdy_lvl_nxt = ~cal_rdy_lvl;
              cal_ui_ctrl_nxt = 1'b0;
              step_nxt        = 0;
            end
          end
        endcase
        debug_state = FSM_PTNGEN;             
      end

      // [Error State] - Should never happen
      FSM_ERROR: begin
        /* Nothing to do here */
      debug_state = FSM_ERROR;             
      end
          
    endcase
  end

  // ================================= Local Tasks ====================================
  function dram_time_t max_val;
    input dram_time_t a, b;
    begin
      max_val = (a > b) ? a : b;
    end
  endfunction

  task issue_mrs;
    input logic [3:0]  MR;
    input logic [11:0] A;
    input dram_time_t tDEL;    // Time to wait after issuing an MRS command
    begin
      cal_cmd_nxt          = MRS;
      cal_pkt_nxt.bk_addr  = MR;
      cal_pkt_nxt.row_addr = A;

      case (mrs_step)
        0 : begin
          if (aimc_cal_rdy) begin
            mrs_step_nxt      = 1;
            cal_pkt_valid_nxt = 1;
            wait_cnt_nxt      = max_val((ck_adj(tDEL)-1), 1);  // Not allowing values < 2*tCK (need to skip state 1 if such values required)
          end
        end
        1 : begin
          if (wait_done) begin
            mrs_done     = 1;
            mrs_step_nxt = 0;
          end
        end
      endcase
    end
  endtask

  task issue_ldff;
    begin
      oreg_page_addr       = ld_brst_cnt;               // OREG page corresponds to burst index
      oreg_dword_addr      = {1'b0, ld_cmd_cnt[3:1]};   // Two LDFF commands required for transferring data from one dword
      cal_pkt_nxt.req_type = TR_WRITE;
      cal_cmd_nxt          = LDFF;
      cal_pkt_nxt.bk_addr  = ld_cmd_cnt;
      cal_pkt_nxt.row_addr = {4'd0, ld_cmd_cnt[0]?oreg_dword_dout[16+:10]:oreg_dword_dout[0+:10]};  // For even ld_cmd_cnt values, we take LSB part of OREG dwrod
      ld_cmd_cnt_nxt       = ld_cmd_cnt;                // Default value in the main FSM is zero, so adding this line here to make ld_cmd_cnt state sticky while running issue_ldff
      ld_brst_cnt_nxt      = ld_brst_cnt;               // Similar to ld_cmd_cnt_nxt, making this counter sticky (keep the state unless explicitly updated)

      case (ld_step)
        0 : begin
          ld_step_nxt = 1;                              // Waiting one clock cycle for OREG to be read (will have 1 CK gaps because of this, but it's not important for training)
        end
        1 : begin
          if (aimc_cal_rdy) begin
            ld_step_nxt       = 2;
            cal_pkt_valid_nxt = 1;
            wait_cnt_nxt      = max_val((ck_adj(cfr_time_init.tLTLTR)-1), 1);  // Not allowing values < 2*tCK (need to skip state 1 if such values required)
          end
        end
        2 : begin
          if (wait_done) begin
            ld_step_nxt     = 0;
            ld_cmd_cnt_nxt  = ld_cmd_cnt + 1'b1;
            ld_brst_cnt_nxt = ld_brst_cnt + (ld_cmd_cnt == 4'hF);
            ld_done         = (ld_brst_cnt == brst_last) && (ld_cmd_cnt == 4'hF);
          end
        end
      endcase
    end
  endtask

  task issue_wrtr;
    begin
      oreg_page_addr       = ld_brst_cnt + (ck_adj(cfr_time_init.tCCD) < 2);   // OREG page corresponds to burst index; OREG is pipelined, so need to stay ahead of the index when tCCD is 1 system clock cycle (CK_DIV2)
      cal_pkt_nxt.req_type = TR_WRITE;
      cal_cmd_nxt          = WRTR;
      cal_pkt_nxt.data     = oreg_page_dout[255:0];
      ld_brst_cnt_nxt      = ld_brst_cnt;                                      // Making counter sticky for the time of this task (keep the state unless explicitly updated)

      case (ld_step)
        0 : begin
          if (aimc_cal_rdy && wait2wr == 0) begin
            ld_brst_cnt_nxt   = ld_brst_cnt + 1'b1;
            cal_pkt_valid_nxt = 1;
            wait_cnt_nxt      = ck_adj(cfr_time_init.tCCD) - 1;
            wait2rd_nxt       = ck_adj(cfr_time_init.tWTRTR) - 1;

            if (wait_cnt_nxt == 0) ld_done = (ld_brst_cnt_nxt > brst_last);    // Condition required for "CK_DIV2", when tCCD = 2 results in wait_cnt_nxt = 0
            else ld_step_nxt = 1;
          end
        end
        1 : begin
          if (wait_done) begin
            ld_step_nxt = 0;
            ld_done     = (ld_brst_cnt > brst_last);
          end
        end
      endcase
    end
  endtask

  task issue_rdtr;
    begin
      ireg_page_addr       = ireg_page_cnt;             // Using rdtr_brst_cnt when loading IREG with data from DRAM
      ireg_page_we         = intf_pkt_valid_rd;
      cal_pkt_nxt.req_type = TR_READ;
      cal_cmd_nxt          = RDTR;
      rdtr_brst_cnt_nxt    = rdtr_brst_cnt;             // Making counter sticky for the time of this task (keep the state unless explicitly updated)
      ireg_page_cnt_nxt    = ireg_page_cnt + intf_pkt_valid_rd;

      // When the last packet arrives, assert a "pending" flag to let the system know to switch from this task ASAP
      if (ireg_page_cnt == brst_last && intf_pkt_valid_rd) rdtr_done_pend_nxt = 1;

      case (rdtr_step)
        0 : begin
          if (aimc_cal_rdy && wait2rd == 0) begin
            cal_pkt_valid_nxt = 1;
            wait_cnt_nxt      = ck_adj(cfr_time_init.tCCD) - 1;
            wait2wr_nxt       = ck_adj(cfr_time_init.tRTW) - 1;
            // wait_cnt_nxt      = max_val((cfr_time_init.tCCD-1), 1);  // Not allowing values < 2*tCK (need to skip state 1 if such values required)

            if (wait_cnt_nxt == 0) begin                // Condition required for "CK_DIV2", when tCCD = 2 results in wait_cnt_nxt = 0
              rdtr_brst_cnt_nxt = rdtr_brst_cnt + 1'b1;
              if (rdtr_brst_cnt_nxt > brst_last) rdtr_step_nxt = 2;
            end
            else begin
              rdtr_step_nxt = 1;
            end
          end
        end
        1 : begin
          if (wait_done) begin
            if (rdtr_brst_cnt == brst_last) begin
              rdtr_step_nxt = 2;
              rdtr_brst_cnt_nxt = rdtr_brst_cnt;
            end
            else begin
              rdtr_step_nxt = 0;
              rdtr_brst_cnt_nxt = rdtr_brst_cnt + 1'b1;
            end
          end
        end
        2 : begin
          // Waiting for the last RDTR burst to arrive
          if (rdtr_done_pend) begin
            rdtr_step_nxt         = 0;
            rdtr_done             = 1;
            rdtr_done_pend_nxt = 0;
          end
        end
      endcase
    end
  endtask

  function automatic logic [31:0] ck_adj;
    input logic [31:0] t;
    begin
      if (GLOBAL_CLK == "CK_DIV2") ck_adj = (t >> 1) + t[0];  // Rounding up
      else                         ck_adj = t;
    end
  endfunction

  // ================================= Initialization =================================
  initial begin
    // MCS Communication
    cal_rd_strobe_lvl_d   = 0;
    cal_wr_strobe_lvl_d   = 0;
    cal_rd_data           = FAIL;
    cal_rdy_lvl           = 0;
    mcs_rd                = 0;
    mcs_wr                = 0;
    cal_addr_d            = 0;
    cal_wr_data_d         = 0;
    // Command Handler Signals
    cal_pkt_valid         = 0;
    cal_pkt               = 0;
    cal_cmd               = NOP1;
    cal_wck_en            = {CH_NUM{1'b1}};
    // Input Data Buffers
    aimc_cal_pkt_valid_r1 = 0;
    aimc_cal_pkt_valid_r2 = 0;
    aimc_temp_valid_r1    = 0;
    aimc_temp_valid_r2    = 0;
    aimc_cal_pkt_r1       = '{CH_NUM{0}};
    aimc_cal_pkt_r2       = 0;
    aimc_cal_edc_r1       = 0;
    aimc_cal_edc_r2       = 0;
    aimc_temp_data_r1     = 0;
    aimc_temp_data_r2     = 0;
    // Data Handler Signals
    temp_data_r1          = 0;
    // Delay Registers
    param_smpl_edge       = {CH_NUM{SAMP_INI}};
    param_sync_ordr       = {CH_NUM{SYNC_INI}};
    param_io_del_array    = {CH_NUM{{16{ODEL_INI}}, {18{IDEL_INI}}}};
    param_rl_del          = {CH_NUM{RL_INI}};
    // Calibration FSM
    state                 = FSM_IDLE;
    step                  = 0;
    mrs_step              = 0;
    ch_idx                = 0;
    cal_ch_idx            = 0;
    wait_cnt              = 0;
    wait2rd               = 0;
    wait2wr               = 0;
    ld_brst_cnt           = 0;
    ld_cmd_cnt            = 0;
    ld_step               = 0;
    rdtr_brst_cnt         = 0;
    rdtr_step             = 0;
    ireg_page_cnt         = 0;
    // Flags
    cal_done_r0           = 0;
    cal_done_r1           = 0;
    cal_done_r2           = 0;
    cal_done              = 0;
    cal_ref_stop_r0       = 0;
    cal_ref_stop_r1       = 0;
    cal_ref_stop_r2       = 0;
    cal_ref_stop          = 0;
    wck2ck_on             = 0;
    wck_shift_mr          = 0;
    rdtr_pend             = 0;
    wrtr_pend             = 0;
    exit_pend             = 0;
    bk_act                = 0;
    rdtr_done_pend        = 0;
    // Pattern Generatro Signals
    march_len             = 0;
    cal_ui_ctrl           = 0;
    pgen_rd_ptr           = 0;
    param                 = 0;
  end
 
 reg               debug_mcs_rd;
 reg               debug_mcs_wr;
 reg [15:0]        debug_cal_reg_addr;
 reg [CH_NUM-1:0]  debug_cal_done_nxt;
 reg               debug_mcs_rd_strob;
 reg               debug_mcs_wr_strob;
 reg [7:0]         debug_mcs_addr;

   always @(posedge clk, posedge rst)
   if (rst) begin
                    debug_mcs_rd                      <='b0; 
                    debug_mcs_wr                      <='b0; 
                    debug_cal_reg_addr                <='b0;
                    debug_cal_done_nxt                <='b0;
                    
                    debug_mcs_rd_strob                <='b0;  
                    debug_mcs_wr_strob                <='b0;  
                    debug_mcs_addr                    <='b0; 
   end
   else begin
                    debug_mcs_rd                      <=mcs_rd;
                    debug_mcs_wr                      <=mcs_wr;
                    debug_cal_reg_addr                <=cal_reg_addr;
                    debug_cal_done_nxt                <=cal_done_nxt;
                    debug_mcs_rd_strob                <= (cal_rd_strobe_lvl != cal_rd_strobe_lvl_d);
                    debug_mcs_wr_strob                <= (cal_wr_strobe_lvl != cal_wr_strobe_lvl_d);
                    debug_mcs_addr                    <= (cal_addr[31:24] == 8'hCA);                    
   end

endmodule