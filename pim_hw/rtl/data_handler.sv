`timescale 1ps / 1ps

import aimc_lib::*;

module data_handler (
  input  logic        clk,
  input  logic        rst,
  input  logic        cal_done,
  // Configuration Register
  input  logic [$bits(cfr_mode_t)-1:0] cfr_mode_p,
  input  logic [$bits(cfr_time_t)-1:0] cfr_time_p,
  input  logic [$bits(cfr_schd_t)-1:0] cfr_schd_p,
  // Initializer/Scheduler/Caibration Interface
  input  pkt_t        pkt,
  input  cmd_t        cmd,
  input  logic        pkt_valid,
  output logic        intf_pkt_retry,
  input  logic [2:0]  param_rl_del,
  output logic        temp_valid,
  output logic [7:0]  temp_data,
  // UI Interface
  output logic        intf_pkt_valid,
  output pkt_t        intf_pkt,
  output logic [31:0] intf_edc,
  // PHY Interface
  output logic        dq_tri,
  output logic [7:0]  intf_dq    [15:0],
  output logic [7:0]  intf_dbi_n [1:0],
  input  logic [7:0]  phy_dq     [15:0],
  input  logic [7:0]  phy_dbi_n  [1:0],
  input  logic [7:0]  phy_edc    [1:0]);
  
  // ==================================== Signal Definitions ====================================
  localparam int WL_LOC_MAX      = WL_MAX;
  localparam int WL_LOC_MIN      = WL_MIN;
  // "+2" due to CA delay in odel_block, "+2" due to CA OSERDES, "+3" due to DQ/EDC ISERDES, "+2" due to DQ/EDC delay in idel_block
  localparam int RL_LOC_MAX      = RL_MAX + 9;
  // "+2" due to CA delay in odel_block, "+2" due to CA OSERDES, "+3" due to EDC ISERDES, "+2" due to EDC delay in idel_block, "-2" due to internal CRC module delay (total delay will catch up because of this)
  localparam int CRCWL_LOC_MAX   = WL_LOC_MAX + CRCWL_MAX + 9;
  // All delays compensated for in RL_LOC_MAX
  localparam int CRCRL_LOC_MAX   = RL_LOC_MAX + CRCRL_MAX;
  // Need to provide sufficient pipe length for EXECUTE commands to wait until previous WRITE and READ EDC is gathered before issuing responses
  localparam int EXECL_LOC_MAX   = CRCRL_LOC_MAX + 1;
  // "+2" due to CA delay in odel_block, "+2" due to CA OSERDES, "+3" due to DQ ISERDES", +2" due to DQ delay in idel_block, "+1" due to delay in this block (some delays are compensated in data handler ard are not stated)
  localparam int tWRIDON_LOC_MAX = tWRIDON_MAX + 10;

  // Configuration Register
  cfr_mode_t        cfr_mode;
  cfr_time_t        cfr_time;
  cfr_schd_t        cfr_schd;
  // Local Delay Values
  logic [$clog2(WL_LOC_MAX)-1:0]      WL_LOC;
  logic [$clog2(RL_LOC_MAX)-1:0]      RL_LOC;
  logic [$clog2(CRCWL_LOC_MAX)-1:0]   CRCWL_LOC;
  logic [$clog2(CRCRL_LOC_MAX)-1:0]   CRCRL_LOC;
  logic [$clog2(tWRIDON_LOC_MAX)-1:0] tWRIDON_LOC;
  // Write Command Signals
  logic [127:0]     dq_r        [1:0];                       // 2 clock cycles worth of DQ data
  logic             dq_tri_r    [3:0];                       // 4 clock cycles worth of DQ turn-around bits
  logic [127:0]     dq_r_pipe   [WL_LOC_MAX-1:0];            // DQ data pipe for WL delay
  logic             dq_tri_pipe [WL_LOC_MAX-3:0];            // DQ turn around bit pipe for WL delay
  logic             wr_cmd;                                  // Write command indicator
  // Read Command Signals
  logic             rd_cmd;                                  // Read command indicator
  logic [127:0]     dq_data_pipe [CRCRL_MAX-1:0];
  logic [$clog2(CRCRL_MAX)-1:0] dq_data_pipe_idx;            // Index for inserting data into dq_data_pipe
  // Execite Command Signals
  logic             exec_cmd;                                // Execute command indicator
  // Temperature Read Signals
  logic             rd_temp_cmd;                             // Read temperature command indicator
  logic             rd_temp_pipe [tWRIDON_LOC_MAX-1:0];      // Shift register for tracking tWRIDON timing druing temperature read
  logic [7:0]       temp_data_0;                             // Temperature data pre-buffered
  logic             temp_valid_0;                            // Temperature valid signal pre-buffered
  // EDC Signals
  logic             edc_enabled;                             // Flag indicating that EDC is enabled
  logic             wr_edc_pipe   [CRCWL_LOC_MAX-1:0];       // Shift register for tracking EDC timing during WRITE
  logic             rd_edc_pipe   [CRCRL_LOC_MAX-1:0];       // Shift register for tracking EDC timing during READ
  logic             exec_edc_pipe [EXECL_LOC_MAX-1:0];       // Shift register for EXECUTE commands (pretending to be WRITE to avoid collisions with nearby commands)
  logic [$clog2(CRCWL_LOC_MAX)-1:0] wr_edc_pipe_last;        // Delay remaining for the latest WRITE (required for checking how much to wait for EXECUTE commands)
  logic [$clog2(CRCRL_LOC_MAX)-1:0] rd_edc_pipe_last;        // Delay remaining for the latest READ (required for checking how much to wait for EXECUTE commands)
  logic [$clog2(EXECL_LOC_MAX)-1:0] exec_edc_pipe_last;      // Delay remaining for the latest EXECUTE (required for checking how much to wait for EXECUTE commands)
  logic [$clog2(CRCWL_LOC_MAX)-1:0] wr_edc_pipe_idx;
  logic [$clog2(CRCRL_LOC_MAX)-1:0] rd_edc_pipe_idx;
  logic [$clog2(EXECL_LOC_MAX)-1:0] exec_edc_pipe_idx, exec_edc_pipe_idx_new, exec_edc_pipe_idx_store;
  logic             edc_front_valid;                         // Marks CRC output for the front part of the burst
  logic             edc_back_valid;                          // Marks CRC output for the back part of the burst, Read signal for Packet Buffer
  logic [127:0]     crc_i;                                   // Data for calculating 72-to-8 CRC
  logic [7:0]       crc_dbi_n   [1:0];                       // DBI for calculating 72-to-8 CRC
  logic [7:0]       crc_o       [1:0];                       // CRC calulation result
  logic             edc_comp, edc_comp_d;                    // EDC data comparison results
  logic             crc_en;                                  // CRC module is active only when crc_en is asserted
  logic [15:0]      edc_data;                                // Unpacked EDC data
  logic [15:0]      edc_data_pipe [1:0];                     // Register for storing both Frong and Tail parts of the EDC burst
  logic             edc_ignore_front;                        // Flag to ignore EDC data for execute requests
  logic             edc_ignore_back;
  // Packet Buffer Signals
  logic             pkt_buf_wr;                              // Packet buffer write enable signal
  logic             pkt_buf_rd;                              // Packet buffer read enable signal
  pkt_t             pkt_buf_din;                             // Packet buffer input data
  pkt_t             pkt_buf_dout, pkt_buf_dout_d;            // Packet buffer output data and its delayed version (required since data is pulled from the buffer early)
  pkt_t             intf_pkt_nxt;                            // Next state for the outbound packet
  logic [127:0]     dq_data;                                 // Unpacked DQ data
  logic [255:0]     intf_pkt_data;                           // Buffer for temporarily holding full data for the outbound packet
  // Delay Registers
  logic [2:0]       param_rl_del_d;                          // Additioanl RL delay buffered locally
  logic             rd_cmd_pipe      [7:0];                  // Pipe for adding extra delay to read commands
  logic             wr_cmd_pipe      [7:0];                  // Pipe for adding extra delay to write commands
  logic             exec_cmd_pipe    [7:0];                  // Pipe for adding extra delay to execute commands
  logic             rd_temp_cmd_pipe [7:0];                  // Pipe for adding extra delay to read temperature commands

  // ============================================================================================
  //                                        CONFIGURATION                              
  // ============================================================================================
  // Configuration Register
  assign cfr_mode = cfr_mode_t'(cfr_mode_p);
  assign cfr_time = cfr_time_t'(cfr_time_p);
  assign cfr_schd = cfr_schd_t'(cfr_schd_p);

  // Local Delay Values
  assign WL_LOC      = cfr_mode.WL;
  assign RL_LOC      = cfr_mode.RL + 9;
  assign CRCWL_LOC   = WL_LOC + cfr_mode.CRCWL + 9;
  assign CRCRL_LOC   = RL_LOC + cfr_mode.CRCRL;
  assign tWRIDON_LOC = cfr_time.tWRIDON + 10; 

  // Local buffering for Calibration Handler's parameters
  always @(posedge clk, posedge rst)
    if (rst) param_rl_del_d <= 0;
    else     param_rl_del_d <= param_rl_del;

  // ============================================================================================
  //                                     WRITE PACKET HANDLER                                 
  // ============================================================================================
  // Write is initiated when an input command is one of WRITE commands
  always @(posedge clk, posedge rst)
    if (rst) wr_cmd_pipe[0] <= 0;
    else     wr_cmd_pipe[0] <= pkt_valid && ((cmd == WDM) || (cmd == WRTR) || (cmd == WRGB) || (cmd == WRBIAS) || (cmd == WRBK));

  genvar i;
  generate
    for (i=1; i<8; i++) begin : wrCmdPipe
      always @(posedge clk, posedge rst)
        if (rst) wr_cmd_pipe[i] <= 0;
        else     wr_cmd_pipe[i] <= wr_cmd_pipe[i-1];
    end
  endgenerate

  assign wr_cmd = wr_cmd_pipe[param_rl_del_d];  // Delaying write commands by RL_DEL since we need to read EDC for writes as well

  // This 4-bit shift register ensures that DQ is driven for 4 M.C. clock cycles (= 4 CK) during WRITE: preamble (1), data (2), postamble (1)
  always @(posedge clk, posedge rst)
    if (rst) begin
      dq_tri_r[0] <= 1'b1;
      dq_tri_r[1] <= 1'b1;
      dq_tri_r[2] <= 1'b1;
      dq_tri_r[3] <= 1'b1;
    end
    else if (wr_cmd_pipe[0]) begin
      dq_tri_r[0] <= 1'b0;
      dq_tri_r[1] <= 1'b0;
      dq_tri_r[2] <= 1'b0;
      dq_tri_r[3] <= 1'b0;
    end
    else begin
      dq_tri_r[0] <= dq_tri_r[1];
      dq_tri_r[1] <= dq_tri_r[2];
      dq_tri_r[2] <= dq_tri_r[3];
      dq_tri_r[3] <= 1'b1;
    end

  // Splitting 256-bit input data into 2 parts that will be sequentially passed to the DQ
  always @(posedge clk, posedge rst)
    if (rst) begin
      dq_r[0] <= 0;
      dq_r[1] <= 0;
    end
    else if (wr_cmd_pipe[0]) begin
      dq_r[0] <= pkt_buf_din.data[128*0 +: 128];
      dq_r[1] <= pkt_buf_din.data[128*1 +: 128];
    end
    else begin
      dq_r[0] <= dq_r[1];
      dq_r[1] <= {128{1'b1}};
    end
  
  generate
    // Waiting for WL before applying data to DQ OSERDES.
    // Note: dq_tri would normally be delayed 1 CK more than dq_r, because dq_r must be passed to PHY and prepared in advanced 
    // (it waits out the remaining time in serializers), however it is delayed 1 CK more, since we also need the preamble.
    for (i=0; i<WL_LOC_MAX-2; i++) begin : dqTriPipe
      always @(posedge clk, posedge rst)
        if (rst) dq_tri_pipe[i] <= 1'b1;
        else     dq_tri_pipe[i] <= (i >= WL_LOC-3) ? dq_tri_r[0] : dq_tri_pipe[i+1];
    end

    
    for (i=0; i<WL_LOC_MIN-1; i++) begin : dqWritePipe0           // Constant part of shift register
      always @(posedge clk, posedge rst)
        if (rst) dq_r_pipe[i] <= 0;
        else     dq_r_pipe[i] <= dq_r_pipe[i+1];
    end
    for (i=WL_LOC_MIN-1; i<WL_LOC_MAX; i++) begin : dqWritePipe1  // Configurable part of shift register
      always @(posedge clk, posedge rst)
        if (rst) dq_r_pipe[i] <= 0;
        else     dq_r_pipe[i] <= (i >= WL_LOC-1) ? dq_r[0] : dq_r_pipe[i+1];
    end
  endgenerate

  // ================================= OSERDES Data Constructor =================================
  // The controller starts driving DQ when data reaches the end of the WL pipe
  assign dq_tri = ~dq_tri_pipe[0]; 

  always @(posedge clk, posedge rst) begin
    for (int dq_bit=0; dq_bit<16; dq_bit++) begin
      for (int burst_idx=0; burst_idx<8; burst_idx++) begin
        if (rst) intf_dq[dq_bit][burst_idx] <= 0;
        else     intf_dq[dq_bit][burst_idx] <= dq_r_pipe[1][16*burst_idx+dq_bit];
      end
    end
  end

  always_comb begin
    for (int idx=0; idx<2; idx++) begin
      intf_dbi_n[idx] = 8'hFF;
    end
  end

  // ============================================================================================
  //                                     READ PACKET HANDLER                                 
  // ============================================================================================
  // Read is initiated when the incoming command is one of READ commands
  always @(posedge clk, posedge rst)
    if (rst) rd_cmd_pipe[0] <= 0;
    else     rd_cmd_pipe[0] <= pkt_valid && ((cmd == RD) || (cmd == RDTR) || (cmd == WCK2CK) || (cmd == RDMAC) || (cmd == RDAF));

  // Additional calibration delay line
  generate
    for (i=1; i<8; i++) begin : rdCmdPipe
      always @(posedge clk, posedge rst)
        if (rst) rd_cmd_pipe[i] <= 0;
        else     rd_cmd_pipe[i] <= rd_cmd_pipe[i-1];
    end
  endgenerate

  assign rd_cmd = rd_cmd_pipe[param_rl_del_d];

  // Unpacking input data
  always_comb
    for (int dq_bit=0; dq_bit<16; dq_bit++) begin
      for (int burst_idx=0; burst_idx<8; burst_idx++) begin
        dq_data[16*burst_idx+dq_bit] = phy_dq[dq_bit][burst_idx];
      end
    end

  // Delaying captured data until EDC values are captured and compared with the local CRC code
  assign dq_data_pipe_idx = edc_enabled ? (cfr_mode.CRCRL-1) : 1;  // Insterting to the very end if no CRCRL wait is necessary

  generate
    for (i=0; i<CRCRL_MAX; i++) begin : dqReadPipe
      always @(posedge clk, posedge rst)
        if      (rst)                   dq_data_pipe[i] <= 0;
        else if (i >= dq_data_pipe_idx) dq_data_pipe[i] <= dq_data;
        else                            dq_data_pipe[i] <= dq_data_pipe[i+1];
    end
  endgenerate

  // ============================================================================================
  //                                   EXECUTE PACKET HANDLER                                 
  // ============================================================================================
  always @(posedge clk, posedge rst)
    if (rst) exec_cmd_pipe[0] <= 0;
    else     exec_cmd_pipe[0] <= pkt_valid && ((cmd == MACSB) || (cmd == MACAB) || (cmd == AF) || (cmd == EWMUL) || (cmd == RDCP) || (cmd == WRCP) || (cmd == MRS && pkt.req_type == DO_MRS));

  // Additional calibration delay line
  generate
    for (i=1; i<8; i++) begin : ExecCmdPipe
      always @(posedge clk, posedge rst)
        if (rst) exec_cmd_pipe[i] <= 0;
        else     exec_cmd_pipe[i] <= exec_cmd_pipe[i-1];
    end
  endgenerate

  assign exec_cmd = exec_cmd_pipe[param_rl_del_d];  // Delaying the same amount as READ and WRITE commands to avoid FIFO reading collisions

  // ============================================================================================
  //                                   TEMPERATURE READ HANDLER                                 
  // ============================================================================================
  // Temperature read is initiated when the incoming command is MRS_TEMP
  always @(posedge clk, posedge rst)
    if (rst) rd_temp_cmd_pipe[0] <= 0;
    else     rd_temp_cmd_pipe[0] <= pkt_valid & ((cmd == MRS_TEMP) && pkt.row_addr[7:6] == 2'b10);

  // Additional calibration delay line
  generate
    for (i=1; i<8; i++) begin : rdTempCmdPipe
      always @(posedge clk, posedge rst)
        if (rst) rd_temp_cmd_pipe[i] <= 0;
        else     rd_temp_cmd_pipe[i] <= rd_temp_cmd_pipe[i-1];
    end
  endgenerate

  assign rd_temp_cmd = rd_temp_cmd_pipe[param_rl_del_d];

  // Buffering temperature data
  always @(posedge clk)
    if (rd_temp_pipe[1]) temp_data_0 <= dq_data[7:0];

  generate
    for (i=0; i<tWRIDON_LOC_MAX; i++) begin : rdTempPipe
      always @(posedge clk, posedge rst)
        if      (rst)                rd_temp_pipe[i] <= 0;
        else if (i >= tWRIDON_LOC-1) rd_temp_pipe[i] <= rd_temp_cmd;
        else                         rd_temp_pipe[i] <= rd_temp_pipe[i+1];
    end
  endgenerate

  // assign temp_valid = rd_temp_pipe[0];
  assign temp_valid_0 = rd_temp_pipe[0];

  // Double-buffering the temperature output to slightly releaf the routing on the FPGA
  always @(posedge clk, posedge rst)
    if (rst) begin
      temp_data  <= 0;
      temp_valid <= 0;
    end
    else begin
      temp_data  <= temp_data_0;
      temp_valid <= temp_valid_0;
    end
  // ============================================================================================
  //                                        EDC HANDLER                                 
  // ============================================================================================
  assign edc_enabled = cal_done && cfr_schd.EDC_EN;

  // ================================= EDC Delay Shift Registers ================================
  // If EDC is disabled, WRITE still needs to wait until preceeding READ packets are processed (8 cycle difference between READ and WRITE is sufficient)
  assign wr_edc_pipe_idx   = edc_enabled ? (CRCWL_LOC - 1) : (CRCRL_LOC - cfr_mode.CRCRL - 8 - 1);
  // "+2" due to internal buffering (with EDC this delay is hidden behind CRC calculation)
  assign rd_edc_pipe_idx   = edc_enabled ? (CRCRL_LOC - 1) : (CRCRL_LOC - cfr_mode.CRCRL - 1);
  // Entry index calculated every time based on other commands in the pipeline (e.g. to avoid pulling EXEC response while still waiting for WRITE EDC)
  assign exec_edc_pipe_idx = exec_cmd ? exec_edc_pipe_idx_new : exec_edc_pipe_idx_store;

  generate
    for (i=0; i<CRCWL_LOC_MAX; i++) begin : wrEdcPipe
      always @(posedge clk, posedge rst)
        if      (rst)                  wr_edc_pipe[i] <= 0;
        else if (i >= wr_edc_pipe_idx) wr_edc_pipe[i] <= wr_cmd;
        else                           wr_edc_pipe[i] <= wr_edc_pipe[i+1];
    end

    for (i=0; i<CRCRL_LOC_MAX; i++) begin : rdEdcPipe
      always @(posedge clk, posedge rst)
        if      (rst)                  rd_edc_pipe[i] <= 0;
        else if (i >= rd_edc_pipe_idx) rd_edc_pipe[i] <= rd_cmd;
        else                           rd_edc_pipe[i] <= rd_edc_pipe[i+1];
    end

    for (i=0; i<EXECL_LOC_MAX; i++) begin : execEdcPipe
      always @(posedge clk, posedge rst)
        if      (rst)                    exec_edc_pipe[i] <= 0;
        else if (i >= exec_edc_pipe_idx) exec_edc_pipe[i] <= exec_cmd;
        else                             exec_edc_pipe[i] <= exec_edc_pipe[i+1];
    end
  endgenerate

  // Keeping track of the index of the last pipeline command in each category
  always @(posedge clk, posedge rst)
    if (rst) begin
      wr_edc_pipe_last   <= 0;
      rd_edc_pipe_last   <= 0;
      exec_edc_pipe_last <= 0;
    end
    else begin
      wr_edc_pipe_last   <= wr_cmd   ? wr_edc_pipe_idx       : (wr_edc_pipe_last   > 0 ? wr_edc_pipe_last   - 1'b1 : 0);
      rd_edc_pipe_last   <= rd_cmd   ? rd_edc_pipe_idx       : (rd_edc_pipe_last   > 0 ? rd_edc_pipe_last   - 1'b1 : 0);
      exec_edc_pipe_last <= exec_cmd ? exec_edc_pipe_idx_new : (exec_edc_pipe_last > 0 ? exec_edc_pipe_last - 1'b1 : 0);
    end

  always @(posedge clk)
    if (exec_cmd) exec_edc_pipe_idx_store <= exec_edc_pipe_idx_new;

  // Calculating the entry index for the next EXEC command
  always_comb begin
    if (wr_edc_pipe_last > rd_edc_pipe_last)
      if (wr_edc_pipe_last > exec_edc_pipe_last) exec_edc_pipe_idx_new = wr_edc_pipe_last   + 1'b1;
      else                                       exec_edc_pipe_idx_new = exec_edc_pipe_last + 1'b1;
    else
      if (rd_edc_pipe_last > exec_edc_pipe_last) exec_edc_pipe_idx_new = rd_edc_pipe_last   + 1'b1;
      else                                       exec_edc_pipe_idx_new = exec_edc_pipe_last + 1'b1;
  end

  // CRC enable signal for avoiding unecessary switching activity
  assign crc_en = edc_enabled && (wr_edc_pipe[1] || wr_edc_pipe[0] || rd_edc_pipe[1] || rd_edc_pipe[0]); 
  
  // ====================================== CRC Calculation =====================================
  always_comb begin
    if      (wr_edc_pipe[0]) crc_i = pkt_buf_dout.data[255:128];
    else if (wr_edc_pipe[1]) crc_i = pkt_buf_dout.data[127:0];
    else                     crc_i = (cfr_mode.CRCRL == 2) ? dq_data : dq_data_pipe[2];  // For CRCRL == 2, dq_data_pipe[2] doesn't exist, so passing dq_data directly (input to dq_data_pipe)
  end

  assign crc_dbi_n[1] = 8'hFF;
  assign crc_dbi_n[0] = 8'hFF;

  gddr6_crc gddr6_crc (
    .clk       (clk),
    .crc_en    (crc_en),
    .crc_i     (crc_i),
    .crc_dbi_n (crc_dbi_n),
    .crc_o     (crc_o));

  assign edc_comp = edc_enabled ? (crc_o == phy_edc) : 0;

  // Delaying EDC comparison result to have both fron and tail available at the next cycle
  always @(posedge clk) edc_comp_d <= edc_comp;

  // EDC comparison results from both front and tail parts of the burst must be "1"; asserted together with intf_pkt_valid
  always @(posedge clk, posedge rst)
    if (rst) intf_pkt_retry <= 0;
    else     intf_pkt_retry <= edc_enabled && edc_back_valid && !edc_ignore_back && !(edc_comp_d && edc_comp);

  // ===================================== Storing EDC Data =====================================
  // Unpacking EDC data
  always_comb
    for (int edc_bit=0; edc_bit<2; edc_bit++) begin
      for (int burst_idx=0; burst_idx<8; burst_idx++) begin
        edc_data[2*burst_idx+edc_bit] = phy_edc[edc_bit][burst_idx];
      end
    end

  // Pushing EDC data into a pipe for later using it when constructing the memory response packet
  always @(posedge clk) begin
    edc_data_pipe[1] <= edc_data;
    edc_data_pipe[0] <= edc_data_pipe[1];
  end

  // ============================================================================================
  //                                          PACKET BUFFER                                 
  // ============================================================================================
  xpm_fifo_sync #(
    .DOUT_RESET_VALUE    ("0"),            // Reset value for read path
    .ECC_MODE            ("no_ecc"),       // Enable ECC: en_ecc, no_ecc
    .FIFO_MEMORY_TYPE    ("block"),        // Memory type: distributed, block, ultra, auto
    .FIFO_READ_LATENCY   (0),              // Number of output register stages in the read data path: 0-10; must be 0 if READ_MODE = fwft
    .FIFO_WRITE_DEPTH    (16),             // Number of elements in FIFO: 16-4194304; must be power of two
    .FULL_RESET_VALUE    (0),              // Reset values for full, allmost_full and prog_full flags: 0-1
    .PROG_EMPTY_THRESH   (5),              // Minimum number of read words for prog_empty: 3-4194301; min value = 5 if READ_MODE = fwft
    .PROG_FULL_THRESH    (7),              // Maximum number of write words for prog_full: 5-4194301; min value = 5 + CRC_SYNC_STAGES if READ_MODE = fwft
    .RD_DATA_COUNT_WIDTH (5),              // Width of the rd_data_cout: 1-23; must be log2(FIFO_WRITE_DEPTH)+1 if WRITE_DATA_WIDTH = READ_DATA_WIDTH
    .READ_DATA_WIDTH     ($bits(pkt_t)),   // Width of the read port: 1-4096; write-to-read width aspect ratio must be 1:1, 1:2, 1:4, 1:8, 8:1, 4:1, 2:1
    .READ_MODE           ("fwft"),         // Read Mode: std - standard read more, fwft - first word fall through
    .SIM_ASSERT_CHK      (0),              // Simulation messages enabled: 0-1
    .USE_ADV_FEATURES    ("0000"),         // Advanced features: see UltaScale Architecture Libraries Guide 2019 Page 40
    .WAKEUP_TIME         (0),              // Weakup Time: 0-2; must be set to 0 if FIFO_MEMORY_TYPE = auto
    .WR_DATA_COUNT_WIDTH (5),              // Width of the wr_data_count: 1-24; must be log2(FIFO_WRITE_DEPTH)+1
    .WRITE_DATA_WIDTH    ($bits(pkt_t)))   // Width of the write port: 1-4096; write-to-read width aspect ratio must be 1:1, 1:2, 1:4, 1:8, 8:1, 4:1, 2:1
  pkt_buffer (
    .almost_empty        (),               // 1-bit out: One more read is left before empty
    .almost_full         (),               // 1-bit out: One more write is left before full
    .data_valid          (),               // 1-bit out: Valid data is available on dout
    .dbiterr             (),               // 1-bit out: EDC decoder detected a double-bit error; FIFO data corrupted
    .dout                (pkt_buf_dout),   // READ_DATA_WIDTH-bit out: Output data
    .empty               (),               // 1-bit out: FIFO is empty
    .full                (),               // 1-bit out: FIFO is full
    .overflow            (),               // 1-bit out: Write request during the previous clock cycle was rejected due to FIFO being full
    .prog_empty          (),               // 1-bit out: Programmable empty
    .prog_full           (),               // 1-bit out: Programmable full
    .rd_data_count       (),               // RD_DATA_COUNT_WIDTH-bit out: Number of words read from the FIFO
    .rd_rst_busy         (),               // 1-bit out: FIFO read domain is in reset
    .sbiterr             (),               // 1-bit out: EDC decoder detected and fixed a single-bit error
    .underflow           (),               // 1-bit out: Read request during the previous clock cycle was rejected due to FIFO being empty
    .wr_ack              (),               // 1-bit out: Write request during the previous clock cycle was successfull
    .wr_data_count       (),               // WR_DATA_COUNT_WIDTH-bit out: Number of words written into the FIFO
    .wr_rst_busy         (),               // 1-bit out: FIFO write domain is in reset
    .din                 (pkt_buf_din),    // WRITE_DATA_WIDTH-bit in: Input data
    .injectdbiterr       (1'b0),           // 1-bit in: Injects a double bit error if EDC is used on block or ultra RAM
    .injectsbiterr       (1'b0),           // 1-bit in: Injects a single bit error if EDC is used on block or ultra RAM
    .rd_en               (pkt_buf_rd),     // 1-bit in: Read enable
    .rst                 (rst),            // 1-bit in: Reset synchronous with write clock domain
    .sleep               (1'b0),           // 1-bit in: When high, FIFO is in power saving mode
    .wr_clk              (clk),            // 1-bit in: Write domain clock
    .wr_en               (pkt_buf_wr));    // 1-bit in: Write enable

  assign pkt_buf_wr  = wr_cmd_pipe[0] || rd_cmd_pipe[0] || exec_cmd_pipe[0];
  assign pkt_buf_rd  = wr_edc_pipe[0] || rd_edc_pipe[0] || exec_edc_pipe[0];  // Pulling the data immediately after it's required for CRC to prepare the next data for CCD=2
  always @(posedge clk) pkt_buf_din <= pkt;

  always @(posedge clk)
    if (pkt_buf_rd) pkt_buf_dout_d <= pkt_buf_dout;        // Delaying output packet one clock cycle due to its early pull from pkt_buf

  // edc_..._valid marks CRC output for the front/back part of the burst
  always @(posedge clk, posedge rst)
    if (rst) begin
      edc_front_valid <= 0;
      edc_back_valid  <= 0;
    end
    else begin
      edc_front_valid <= pkt_buf_rd;
      edc_back_valid  <= edc_front_valid;
    end

  // EDC ignore signals for EXECUTE commands
  always @(posedge clk, posedge rst)
    if (rst) begin
      edc_ignore_front <= 0;
      edc_ignore_back  <= 0;
    end
    else begin
      edc_ignore_front <= exec_edc_pipe[0];
      edc_ignore_back  <= edc_ignore_front;
    end

  // Prestoring outbound packet data into a buffer (taken from FIFO in case of WRITE and DQ in case of READ)
  always @(posedge clk)
    if (edc_front_valid) begin
      case (pkt_buf_dout_d.req_type)
        READ, READ_SBK, READ_AF, READ_MAC, TR_READ : intf_pkt_data <= {dq_data_pipe[1], dq_data_pipe[0]};
        default                                    : intf_pkt_data <= pkt_buf_dout_d.data;
      endcase
      // intf_pkt_data <= (pkt_buf_dout_d.req_type == READ) ? {dq_data_pipe[1], dq_data_pipe[0]} : pkt_buf_dout_d.data;
    end

  always_comb begin
    intf_pkt_nxt      = pkt_buf_dout_d;
    intf_pkt_nxt.data = intf_pkt_data;
  end

  // The packet is valid at the output register following edc_back_valid
  always @(posedge clk, posedge rst)
    if (rst) intf_pkt_valid <= 0;
    else     intf_pkt_valid <= edc_back_valid && (!cfr_schd.LOOP_EN || intf_pkt_nxt.req_type < DO_MACSB || intf_pkt_nxt.col_addr == 0);  // If looping is enabled, only issue response on COL=0 for DO_MACSB and higher request types

  always @(posedge clk)
    if (edc_back_valid) begin
      intf_pkt <= intf_pkt_nxt;
    end

  assign intf_edc = {edc_data_pipe[1], edc_data_pipe[0]};

  // ============================================================================================
  //                                        INITIALIZATION                                 
  // ============================================================================================
  initial begin
    // Write Handler
    dq_r               = '{2{128'd0}};
    dq_r_pipe          = '{WL_LOC_MAX{128'd0}};
    intf_dq            = '{16{8'd0}};
    dq_tri_r           = '{4{1'b1}};
    dq_tri_pipe        = '{(WL_LOC_MAX-2){1'b1}};
    // Read Handler
    dq_data_pipe       = '{CRCRL_MAX{128'd0}};
    // Temperature Read Handler
    rd_temp_pipe       = '{tWRIDON_LOC_MAX{1'b0}};
    temp_data          = 0;
    temp_data_0        = 0;
    temp_valid         = 0;
    // Output Packet Constructor
    edc_front_valid    = 0;
    edc_back_valid     = 0;
    intf_pkt_valid     = 0;
    intf_pkt           = 0;
    // intf_edc           = 0;
    pkt_buf_din        = 0;
    pkt_buf_dout_d     = 0;
    intf_pkt_data      = 0;
    // EDC Handler
    wr_edc_pipe        = '{CRCWL_LOC_MAX{1'b0}};
    rd_edc_pipe        = '{CRCRL_LOC_MAX{1'b0}};
    exec_edc_pipe      = '{EXECL_LOC_MAX{1'b0}};
    wr_edc_pipe_last   = 0;
    rd_edc_pipe_last   = 0;
    exec_edc_pipe_last = 0;
    exec_edc_pipe_idx_store = 1;
    edc_comp_d         = 0;
    intf_pkt_retry     = 0;
    // Delay Register
    param_rl_del_d     = 0;
    rd_cmd_pipe        = '{8{0}};
    wr_cmd_pipe        = '{8{0}};
    exec_cmd_pipe      = '{8{0}};
    rd_temp_cmd_pipe   = '{8{0}};
  end

  //debug
/*
  (* dont_touch = "true", mark_debug = "true" *) reg rd_cmd_pipe0_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg rd_cmd_pipe1_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg rd_cmd_pipe2_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg rd_cmd_pipe3_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg rd_cmd_pipe4_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg rd_cmd_pipe5_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg rd_cmd_pipe6_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg rd_cmd_pipe7_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg pkt_valid_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [5:0] cmd_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg [2:0] param_rl_del_d_debug;
  (* dont_touch = "true", mark_debug = "true" *) reg       rd_cmd_debug;

  always @(posedge clk, posedge rst)
  if (rst) begin
      rd_cmd_pipe0_debug <= 'b0;
      rd_cmd_pipe1_debug <= 'b0;
      rd_cmd_pipe2_debug <= 'b0;
      rd_cmd_pipe3_debug <= 'b0;
      rd_cmd_pipe4_debug <= 'b0;
      rd_cmd_pipe5_debug <= 'b0;
      rd_cmd_pipe6_debug <= 'b0;
      rd_cmd_pipe7_debug <= 'b0;
      pkt_valid_debug <= 'b0;
      cmd_debug <= 'b0;
      param_rl_del_d_debug <= 'b0;
      rd_cmd_debug <= 'b0;
  end
  else begin
      rd_cmd_pipe0_debug <= rd_cmd_pipe[0];
      rd_cmd_pipe1_debug <= rd_cmd_pipe[1];
      rd_cmd_pipe2_debug <= rd_cmd_pipe[2];
      rd_cmd_pipe3_debug <= rd_cmd_pipe[3];
      rd_cmd_pipe4_debug <= rd_cmd_pipe[4];
      rd_cmd_pipe5_debug <= rd_cmd_pipe[5];
      rd_cmd_pipe6_debug <= rd_cmd_pipe[6];
      rd_cmd_pipe7_debug <= rd_cmd_pipe[7];
      pkt_valid_debug <= pkt_valid;
      cmd_debug <= cmd;
      param_rl_del_d_debug <= param_rl_del_d;
      rd_cmd_debug <= rd_cmd;
  end
*/

endmodule