`timescale 1ps / 1ps

module microblaze_mcs (
  input  logic                      clk_div,
  input  logic                      rst_div,
  input  logic                      clk_riu,
  input  logic                      rst_riu,                   // Reset for the entire RIU clock domain except MCS
  input  logic                      rst_ub_riu,                // Separate reset for MCS (RIU clock domain)
  output logic                      ub_rst_out,                // Soft reset issued by MCS firmware (used for IO Bank PLL)
  // MCS IO Interface
  input logic                       IO_addr_strobe,
  input logic                       IO_read_strobe,
  input logic                       IO_write_strobe,
  input logic  [31:0]               IO_address,
  input logic  [3:0]                IO_byte_enable,
  input logic  [31:0]               IO_write_data,
  output logic [31:0]               IO_read_data,
  output logic                      IO_ready,
  // RIU (XPHY) Interface
  output logic [3:0]                riu_nibble,                // Nibble select (addressing a single HPIO/XPIO bank, so 8 nibbles in UltraScale+ and 9 nibbles in Versal)
  output logic [7:0]                riu_addr,                  // RIU register address (e.g. OELAY control register, etc.); 6-bit in UltraScale+ and 8-bit in Versal
  input  logic [CH_NUM-1:0][15:0]   riu_rd_data,               // Data read from RIU for each channel
  output logic [CH_NUM-1:0]         riu_rd_strobe,
  output logic [15:0]               riu_wr_data,               // Data to be written to RIU
  output logic [CH_NUM-1:0]         riu_wr_strobe,
  input  logic [CH_NUM-1:0]         riu_valid,                 // Combined (&-ed) RIU_RD_VALID responses from Byte Groups (UltraScal+) or XPHY Nibbles (Versal) for each channel
  // Calibration Handler Interface
  input  logic [$clog2(CH_NUM)-1:0] cal_ch_idx,                // Index of the currently addressed channel
  output logic [31:0]               cal_addr,
  input  logic [31:0]               cal_rd_data,
  output logic                      cal_rd_strobe_lvl,
  output logic [31:0]               cal_wr_data,
  output logic                      cal_wr_strobe_lvl,
  input  logic                      cal_rdy_lvl);              // Read/Write response from Calibration Handler);

  // =================================== Local Signals ==================================
  // Reset Infrastructure
  (* DONT_TOUCH = "TRUE" *) logic   rst_div_r1;                // Additional buffer for rst_div
  (* DONT_TOUCH = "TRUE" *) logic   rst_riu_r1;                // Additional buffer for rst_riu
  logic                             rst_div_riuclk;            // rst_div synchronized to clk_riu domain
  logic [15:0]                      fab_rst_pipe;
  logic                             fab_rst;
   logic                             ub_rst_adr_hit;            // Asserted when a soft reset (rst_ub_riu) is issued by firmware using a specific address value
  // Calibration Handler Synchronizers
  logic [$clog2(CH_NUM)-1:0]        mcs_ch_idx;                // Channel index carried over to MCS clock domain (clk_riu)
  logic                             cal_rdy_lvl_riuclk;        // cal_rdy_lvl synchronized to clk_riu
  logic                             cal_rdy_lvl_riuclk_r1;     // Buffers for pulse conversion
  logic                             cal_rdy_lvl_riuclk_r2;
  logic [31:0]                      cal_rd_data_riuclk;        // cal_rd_data synchronized to clk_riu
  logic [31:0]                      cal_rd_data_riuclk_r1;     // cal_rd_data delay buffer to match cal_rdy timing
  logic [31:0]                      IO_write_data_r2;          // MCS write data delay buffer to match cal_wr_strobe_lvl timing
  logic [31:0]                      IO_address_r2;             // MCS address delay buffer to match cal_wr_strobe_lvl/cal_rd_strobe_lvl timings
  logic                             cal_wr_strobe_lvl_riuclk;  // Pulse to level converter reg for cal_wr
  logic                             cal_rd_strobe_lvl_riuclk;  // Pulse to level converter reg for cal_rd
  // RIU Read/Write Response Counters
  logic [CH_NUM-1:0]                riu_wr_strobe_r0;
  logic [CH_NUM-1:0]                riu_rd_strobe_r0;
  logic                             riu_wr_strobe_r1;          // riu_wr_strobe delay buffers to match response arrival timing
  logic                             riu_wr_strobe_r2;
  logic                             riu_wr_strobe_r3;
  logic                             riu_valid_wait;            // Indicates that write response is pending from RIU
  logic                             riu_rd_strobe_r1;          // riu_rd_strobe delay buffers to match response arrival timing
  logic                             riu_rd_strobe_r2;
  logic                             riu_rd_strobe_r3;
  logic                             riu_rd_strobe_r4;
  logic                             riu_rd_strobe_r5;
  logic [CH_NUM-1:0]                riu_valid_r1;
  logic [CH_NUM-1:0][15:0]          riu_rd_data_r1;
  logic [15:0]                      riu_rd_data_r2;
  // Microblaze MCS IOs and MUXes
  logic                             cal_access;                // Asserted when MCS accesses Calibration Handler
  logic                             riu_access;                // Asserted when MCS accesses RIU
  logic                             IO_addr_strobe_vld;
  logic                             IO_addr_strobe_hold;       // Indicates that IO Address Strobe is asserted while fabric logic is still in reset
  logic [31:0]                      IO_read_data_mux;
  logic                             IO_ready_riu_wr;           // MCS IO ready for RIU write
  logic                             IO_ready_riu_rd;           // MCS IO ready for RIU read
  logic                             IO_ready_cal;              // MCS IO ready for Calibration Handler write
  logic                             IO_addr_strobe_vld_r1;     // MCS valid address strobe buffered
  logic                             IO_addr_strobe_r1;         // MCS address strobe buffered
  logic [31:0]                      IO_address_r1;             // MCS output address
  logic [31:0]                      IO_write_data_r1;          // MCS output data
  logic                             IO_write_strobe_r1;        // MCS write strobe buffered
  logic                             IO_read_strobe_r1;         // MCS read strobe buffered

  // =============================== Reset Infrastructure ===============================
  // Local buffering for rst_div and rst_riu resets
  always @(posedge clk_div) rst_div_r1 <= rst_div;
  always @(posedge clk_riu) rst_riu_r1 <= rst_riu;

  // Synchronizing rst_div to clk_riu domain
  xpm_cdc_async_rst #(
    .DEST_SYNC_FF    (2),
    .INIT_SYNC_FF    (1),
    .RST_ACTIVE_HIGH (1))
  rst_div_sync (
    .dest_arst (rst_div_riuclk),
    .dest_clk  (clk_riu),
    .src_arst  (rst_div_r1));

  // Checking the RIU and fabric resets and holding MCS transactions until they are released
  always @(posedge clk_riu) fab_rst_pipe <= {fab_rst_pipe, (rst_riu_r1 || rst_div_riuclk)};

  assign fab_rst = |fab_rst_pipe;

  // Soft reset from MCS firmware
  assign ub_rst_adr_hit = (IO_address_r1 == 32'hEF000000);

  always @(posedge clk_riu) begin
    if (rst_ub_riu)
      ub_rst_out <= 1'b0;
    else if (IO_addr_strobe_r1 && IO_write_strobe_r1 && ub_rst_adr_hit)
      ub_rst_out <= IO_write_data_r1[0];
  end

  // ============================== MCS Core Infrastructure =============================
  // Holding IO address strobe while fabric logic is in reset
  always @(posedge clk_riu) begin
    if(rst_ub_riu)
      IO_addr_strobe_hold <= 1'b0;
    else if (fab_rst && IO_addr_strobe)
      IO_addr_strobe_hold <= 1'b1;
    else if (!fab_rst)
      IO_addr_strobe_hold <= 1'b0;
  end

  assign IO_addr_strobe_vld = fab_rst ? 1'b0 : (IO_addr_strobe || IO_addr_strobe_hold);

  // Buffering all MCS outputs
  always @(posedge clk_riu) begin
    IO_address_r1         <= IO_address;
    IO_addr_strobe_r1     <= IO_addr_strobe;
    IO_addr_strobe_vld_r1 <= IO_addr_strobe_vld;
    IO_write_data_r1      <= IO_write_data;
    IO_write_strobe_r1    <= IO_write_strobe;
    IO_read_strobe_r1     <= IO_read_strobe;
  end

  // Multiplexing MCS input data between RIU and Calibration Handler
  always_comb begin
    riu_access = 1'b0;
    cal_access = 1'b0;
    IO_read_data_mux = 32'd0;

    casez (IO_address_r1)
      // RIU Access (must start with 0xDB)
      32'hDB?????? : begin
        riu_access = 1'b1;
        IO_read_data_mux = {16'h0000, riu_rd_data_r2};
      end
      // Calibration Handler Access (must start with 0xCA)
      32'hCA?????? : begin
        cal_access = 1'b1;
        IO_read_data_mux = cal_rd_data_riuclk_r1;
      end
    endcase
  end

  always @(posedge clk_riu) IO_read_data <= IO_read_data_mux;
  always @(posedge clk_riu) IO_ready     <= (IO_ready_riu_wr || IO_ready_riu_rd || IO_ready_cal);

  // ========================= Calibration Handler Infrastructure =======================
  sync #(
    .SYNC_FF (2),
    .WIDTH   ($clog2(CH_NUM)))
  cal_ch_idx_sync (
    .dest_clk (clk_riu),
    .din      (cal_ch_idx),
    .dout     (mcs_ch_idx));

  // IO ready synchronization to clk_riu domain
  sync #(
    .SYNC_FF (2),
    .WIDTH   (1))
  cal_rdy_sync (
    .dest_clk (clk_riu),
    .din      (cal_rdy_lvl),
    .dout     (cal_rdy_lvl_riuclk));

  // IO ready level to pulse conversion
  always @(posedge clk_riu) begin
    cal_rdy_lvl_riuclk_r1 <= cal_rdy_lvl_riuclk;
    cal_rdy_lvl_riuclk_r2 <= cal_rdy_lvl_riuclk_r1;
  end

  assign IO_ready_cal = cal_rdy_lvl_riuclk_r1 ^ cal_rdy_lvl_riuclk_r2;  // Using combinational XOR to match with IO_read_data timing from Calibration Handler

  // Input data synchronization to clk_riu domain
  sync #(
    .SYNC_FF (2),
    .WIDTH   (32))
  cal_rd_data_sync (
    .dest_clk (clk_riu),
    .din      (cal_rd_data),
    .dout     (cal_rd_data_riuclk));

  always @(posedge clk_riu) cal_rd_data_riuclk_r1 <= cal_rd_data_riuclk;  // Delayed to match IO_ready_cal timing

  // Output data synchronization to clk_div domain
  always @(posedge clk_riu) IO_write_data_r2 <= IO_write_data_r1;         // Delayed to match cal_wr_strobe_lvl timing

  sync #(
    .SYNC_FF (2),
    .WIDTH   (32))
  cal_wr_data_sync (
    .dest_clk (clk_div),
    .din      (IO_write_data_r2),
    .dout     (cal_wr_data));

  // Address synchronization to clk_div domain
  always @(posedge clk_riu) IO_address_r2 <= IO_address_r1;               // Delayed to match cal_wr_strobe_lvl timing

  sync #(
    .SYNC_FF (2),
    .WIDTH   (32))
  cal_addr_sync (
    .dest_clk (clk_div),
    .din      (IO_address_r2),
    .dout     (cal_addr));

  // Write/Read strobe pulse to level conversion and synchronization to clk_div domain
  always @(posedge clk_riu, posedge rst_riu)
    if (rst_riu)
      cal_wr_strobe_lvl_riuclk <= 0;
    else if (IO_write_strobe_r1 && IO_addr_strobe_vld_r1 && cal_access)
      cal_wr_strobe_lvl_riuclk <= !cal_wr_strobe_lvl_riuclk;

  always @(posedge clk_riu, posedge rst_riu)
    if (rst_riu)
      cal_rd_strobe_lvl_riuclk <= 0;
    else if (IO_read_strobe_r1 && IO_addr_strobe_vld_r1 && cal_access)
      cal_rd_strobe_lvl_riuclk <= !cal_rd_strobe_lvl_riuclk;

  sync #(
    .SYNC_FF (2),
    .WIDTH   (1))
  cal_wr_strobe_sync (
    .dest_clk (clk_div),
    .din      (cal_wr_strobe_lvl_riuclk),
    .dout     (cal_wr_strobe_lvl));

  sync #(
    .SYNC_FF (2),
    .WIDTH   (1))
  cal_rd_strobe_sync (
    .dest_clk (clk_div),
    .din      (cal_rd_strobe_lvl_riuclk),
    .dout     (cal_rd_strobe_lvl));

  // ================================= RIU Infrastructure ===============================
  always_comb begin
    riu_wr_strobe_r0 = 0;
    riu_wr_strobe_r0[mcs_ch_idx] = IO_write_strobe_r1 && IO_addr_strobe_vld_r1 && riu_access;
  end

  always_comb begin
    riu_rd_strobe_r0 = 0;
    riu_rd_strobe_r0[mcs_ch_idx] = IO_read_strobe_r1 && IO_addr_strobe_vld_r1 && riu_access;
  end

  always @(posedge clk_riu, posedge rst_riu) begin
    if (rst_riu) begin
      riu_wr_strobe <= 0;
      riu_rd_strobe <= 0;
    end
    else begin
      riu_wr_strobe <= riu_wr_strobe_r0;
      riu_rd_strobe <= riu_rd_strobe_r0;
    end
  end

  // Buffering output data and addresses
  always @(posedge clk_riu) begin
    riu_wr_data <= IO_write_data_r1 [15:0];
    riu_addr    <= IO_address_r1 [11:4];
    riu_nibble  <= IO_address_r1 [15:12];
  end

  // Buffering input data and validity signal
  always @(posedge clk_riu) begin
    riu_valid_r1   <= riu_valid;                            // Combined RIU_RD_VALID buffer for all channels
    riu_rd_data_r1 <= riu_rd_data;                          // Combined data buffer for all-channels
    riu_rd_data_r2 <= riu_rd_data_r1[mcs_ch_idx];           // Post-channel-mux buffer for the selected channel data
  end

  // Waiting for RIU write to finish
  always @(posedge clk_riu) begin
    riu_wr_strobe_r1 <= |riu_wr_strobe;                     // 1 clk delay: Input address buffer in PHY
    riu_wr_strobe_r2 <= riu_wr_strobe_r1;                   // 2 clk delay: RIU_RD_VALID deassertion upon failed write
    riu_wr_strobe_r3 <= riu_wr_strobe_r2;                   // 3 clk delay: RIU_RD_VALID buffer at the output of PHY
  end

  always @(posedge clk_riu) begin
    if      (riu_wr_strobe_r3) riu_valid_wait <= 1'b1;      // 3 clk delay: RIU_RD_VALID buffer at the input of this module
    else if (IO_ready_riu_wr)  riu_valid_wait <= 1'b0;
  end

  assign IO_ready_riu_wr = riu_valid_wait && riu_valid_r1[mcs_ch_idx];  // If write fails, riu_valid_r1 is deassert before riu_valid_wait is asserted

  // Waiting for RIU read to finish
  always @(posedge clk_riu) begin
    riu_rd_strobe_r1 <= |riu_rd_strobe;                     // 1 clk delay: Input address buffer in PHY
    riu_rd_strobe_r2 <= riu_rd_strobe_r1;                   // 2 clk delay: Data output on RIU_RD_DATA
    riu_rd_strobe_r3 <= riu_rd_strobe_r2;                   // 3 clk delay: RIU_RD_DATA buffer at the output of PHY
    riu_rd_strobe_r4 <= riu_rd_strobe_r3;                   // 4 clk delay: Per-channel RIU_RD_DATA buffer at the input of this module
    riu_rd_strobe_r5 <= riu_rd_strobe_r4;                   // 5 clk delay: Final buffer after channel MUX
  end

  assign IO_ready_riu_rd = riu_rd_strobe_r5;                // Read is always performed regardless of RIU_RD_VALID, so simply passing it to MCS

  // ================================== Initialization ==================================
  initial begin
    // Reset Infrastructure
    rst_div_r1               = 0;
    rst_riu_r1               = 0;
    fab_rst_pipe             = 0;
    ub_rst_out               = 0;
    // MCS Infrastructure
    IO_addr_strobe_hold      = 0;
    IO_address_r1            = 0;
    IO_addr_strobe_r1        = 0;
    IO_addr_strobe_vld_r1    = 0;
    IO_write_data_r1         = 0;
    IO_write_strobe_r1       = 0;
    IO_read_strobe_r1        = 0;
    IO_read_data             = 0;
    IO_ready                 = 0;
    // Calibration Handler Infrastructure
    cal_rdy_lvl_riuclk_r1    = 0;
    cal_rdy_lvl_riuclk_r2    = 0;
    cal_rd_data_riuclk_r1    = 0;
    IO_write_data_r1         = 0;
    IO_address_r2            = 0;
    cal_wr_strobe_lvl_riuclk = 0;
    cal_rd_strobe_lvl_riuclk = 0;
    // RIU Infrastructure
    riu_wr_strobe            = 0;
    riu_rd_strobe            = 0;
    riu_wr_data              = 0;
    riu_addr                 = 0;
    riu_nibble               = 0;
    riu_wr_strobe_r1         = 0;
    riu_wr_strobe_r2         = 0;
    riu_wr_strobe_r3         = 0; 
    riu_valid_wait           = 0;
    riu_rd_strobe_r1         = 0;
    riu_rd_strobe_r2         = 0;
    riu_rd_strobe_r3         = 0;
    riu_rd_strobe_r4         = 0;
    riu_rd_strobe_r5         = 0;
  end


//  (* keep = "true", mark_debug = "true" *)  reg                       debug_IO_addr_strobe;
//  (* keep = "true", mark_debug = "true" *)  reg                       debug_IO_read_strobe;
//  (* keep = "true", mark_debug = "true" *)  reg                       debug_IO_write_strobe;
//  (* keep = "true", mark_debug = "true" *)  reg  [31:0]               debug_IO_address;
//  (* keep = "true", mark_debug = "true" *)  reg  [3:0]                debug_IO_byte_enable;
//  (* keep = "true", mark_debug = "true" *)  reg  [31:0]               debug_IO_write_data;


//    always @(posedge clk_riu)
//    if (rst_ub_riu) begin
//                     debug_IO_addr_strobe          <='b0;       
//                     debug_IO_read_strobe          <='b0;       
//                     debug_IO_write_strobe         <='b0;        
//                     debug_IO_address              <='b0;   
//                     debug_IO_byte_enable          <='b0;       
//                     debug_IO_write_data           <='b0;      
//    end
//    else begin
//                     debug_IO_addr_strobe          <=IO_addr_strobe;       
//                     debug_IO_read_strobe          <=IO_read_strobe;       
//                     debug_IO_write_strobe         <=IO_write_strobe;        
//                     debug_IO_address              <=IO_address;   
//                     debug_IO_byte_enable          <=IO_byte_enable;       
//                     debug_IO_write_data           <=IO_write_data;                   
//    end

endmodule
