`timescale 1ps / 1ps

module fifo_arbiter (
  input  logic clk, rst,
  // Configuration Register
  input  logic [$bits(cfr_schd_t)-1:0] cfr_schd_p,
  // User Interface
  input  pkt_t ui_pkt,
  input  logic ui_pkt_valid,
  output logic rowarb_rdy,
  // Data Handler Interface
  input  pkt_t intf_pkt,
  input  logic intf_pkt_retry,
  // Bank Engine Interface
  output pkt_meta_t rowarb_pkt [1:0],
  output logic [1:0] rowarb_pkt_valid,
  input  logic [1:0] bke_rdy,
  // Bank Arbiter Interface
  input  logic bkarb_pkt_valid,
  input  logic bkarb_pkt_ignore,
  input  cmd_t bkarb_cmd,
  input  logic [$clog2(ROWARB_DEPTH)-1:0] bkarb_data_ptr,
  output logic [MASK_WIDTH-1:0] rowarb_mask,
  output logic [DATA_WIDTH-1:0] rowarb_data);

  // ================================ Signal Declarations ===============================
  // Configuration Register
  cfr_schd_t cfr_schd;                                         // Scheduler parameter array
  // Entry Buffer
  pkt_t entry_pkt;                                             // Inbound packet chosen between the UI and Data Handler packets
  logic ui_pkt_req;                                            // Scheduling request for a UI packet
  logic ui_pkt_ack;                                            // Response to ui_pkt_req
  logic intf_pkt_req;                                          // Scheduling request for a Data Handler's "retry" packet
  logic intf_pkt_ack;                                          // Response to intf_pkt_req
  logic [$clog2(PRIO)-1:0]   ui_prio;                          // UI packet priority (used for CAM key)
  logic [ROW_ADDR_WIDTH-1:0] ui_row_addr;                      // UI packet row address (used for CAM key)
  logic [BK_ADDR_WIDTH-1:0]  ui_bk_addr;                       // UI packet bank address (used for CAM key)
  (* DONT_TOUCH = "TRUE" *) logic error_retry_pkt_overflow;    // Retry packets inputted when the memory is full (solution: increase UI_THR)
  // Packet Memory
  (* RAM_STYLE = "BLOCK" *) logic [$bits(pkt_meta_t)-1:0] pkt_mem [ROWARB_DEPTH-1:0];  // Packet Memory Array, stores packet metadata
  logic [$clog2(ROWARB_DEPTH)-1:0] pkt_mem_raddr;              // Packet memory read address
  logic [$clog2(ROWARB_DEPTH)-1:0] pkt_mem_waddr;              // Packet memory write address
  logic pkt_mem_re;                                            // Packet memory read enable
  logic pkt_mem_we;                                            // Packet memory write enable
  logic [$bits(pkt_meta_t)-1:0] pkt_mem_din;                   // Packet memory data in
  logic [$bits(pkt_meta_t)-1:0] pkt_mem_dout;                  // Packet memory data out
  pkt_meta_t pkt_meta;                                         // Packet meta-data extracted from the input packet
  // Data Memory
  (* RAM_STYLE = "BLOCK" *) logic [DATA_WIDTH+MASK_WIDTH-1:0] data_mem [ROWARB_DEPTH-1:0];  // Data Memory Array, stores WRITE data and mask
  logic [$clog2(ROWARB_DEPTH)-1:0] data_mem_raddr;             // Data memory read address
  logic [$clog2(ROWARB_DEPTH)-1:0] data_mem_waddr;             // Data memory write address
  logic data_mem_re;                                           // Data memory read enable
  logic data_mem_we;                                           // Data memory write enable
  logic [DATA_WIDTH+MASK_WIDTH-1:0] data_mem_din;              // Data memory data in
  logic [DATA_WIDTH+MASK_WIDTH-1:0] data_mem_dout;             // Data memory data out
  // Slot Register
  logic slot_set;                                              // A signal for occupying a slot
  logic slot_clr;                                              // A signal for clearing a slot
  logic [$clog2(ROWARB_DEPTH)-1:0] slot_clr_addr;              // Address of a slot to be cleared
  logic [$clog2(ROWARB_DEPTH)-1:0] slot_nxt_addr;              // Address of the next slot to use
  logic [$clog2(ROWARB_DEPTH):0]   slot_cnt;                   // Number of taken memory slots
  logic slot_full;                                             // A flag indicating full occupancy of the slot register
  // Pointer Queues
  logic [$clog2(ROWARB_DEPTH)-1:0] ptr_que_din;                // Packet memory pointer to be added to one of the pointer queues
  logic [$clog2(ROWARB_DEPTH)-1:0] ptr_que_dout [PRIO-2:0];    // Memory pointers from all pointer queues
  logic [PRIO-2:0] ptr_que_empty;                              // Pointer queue empty flags
  logic [PRIO-2:0] ptr_que_wr;                                 // Write enable for each pointer queue
  logic [PRIO-2:0] ptr_que_rd;                                 // Read enable for each pointer queue
  logic [$clog2(PRIO-1):0]    prio_curr;                       // Highest non-empty pointer queue index
  logic pkt_extract;                                           // Signal indicating that a packet (and packet pointer) must be extracted from the memory
  // Packet Queues
  logic pkt_que_inj;                                           // Signal for injecting packet into one of the packet queues (split into pkt_que_wr)
  logic [1:0] pkt_que_wr;                                      // Packet queue write enable signal
  logic [1:0] pkt_que_rd;                                      // Packet queue read enable signal
  logic [1:0] pkt_que_prog_full;                               // Packet queue programmable full flag
  logic [1:0] pkt_que_empty;                                   // Packet queue empty flag
  pkt_meta_t pkt_que_din;                                      // Packet queue data input
  pkt_meta_t pkt_que_dout [1:0];                               // Packet queue data output

  // ============================== Configuration Register ==============================
  assign cfr_schd = cfr_schd_t'(cfr_schd_p);

  // =================================== Entry Buffer ===================================
  entry_buf entry_buf (
    .clk,
    .rst,
    // User Interface
    .ui_pkt,
    .ui_pkt_valid,
    .rowarb_rdy,
    // Data Handler Interface
    .intf_pkt,
    .intf_pkt_retry,
    // Internal (Row Arbiter) Interface
    .entry_pkt,
    .ui_pkt_req,
    .intf_pkt_req,
    .ui_pkt_ack,
    .intf_pkt_ack,
    .ui_prio,
    .ui_row_addr,
    .ui_bk_addr);

  // Acknowleging UI packets if there are empty slots
  always  @(posedge clk, posedge rst)
    if (rst) ui_pkt_ack <= 0;
    else     ui_pkt_ack <= ui_pkt_req && slot_cnt < (ROWARB_DEPTH - ROWARB_DEPTH/4);  // Dedicating 1/4 of internal memory for EDC fail packets

  // Acknowledging Data Handler packets regardless of circumstances
  always  @(posedge clk, posedge rst)
    if (rst) intf_pkt_ack <= 0;
    else     intf_pkt_ack <= intf_pkt_req;

  // Error tracker for debugging
  always @(posedge clk, posedge rst)
    if (rst) error_retry_pkt_overflow <= 0;
    else     error_retry_pkt_overflow <= error_retry_pkt_overflow || (slot_full && intf_pkt_req);

  // =============================== Packet Memory Array ===============================
  always @(posedge clk)
    if (pkt_mem_we) pkt_mem[pkt_mem_waddr] <= pkt_mem_din;

  always @(posedge clk, posedge rst)
    if      (rst)        pkt_mem_dout <= 0;
    else if (pkt_mem_re) pkt_mem_dout <= pkt_mem[pkt_mem_raddr];

  assign pkt_mem_we = intf_pkt_ack || ui_pkt_ack;                // Allow intf_pkt until pkt_mem is full, allow ui_pkt up to UI_THR
  assign pkt_mem_re = pkt_extract;

  assign pkt_mem_waddr = slot_nxt_addr;                          // Write pointer taken from the next empty slot index
  assign pkt_mem_raddr = ptr_que_dout[prio_curr];                // Taking pointer from the highest non-empty pointer queue

  always_comb begin
    pkt_meta = 0;
    pkt_meta.marker   = entry_pkt.marker;
    pkt_meta.bcast    = entry_pkt.bcast;
    pkt_meta.prio     = entry_pkt.prio;
    pkt_meta.bk_addr  = entry_pkt.bk_addr;
    pkt_meta.row_addr = entry_pkt.row_addr;
    pkt_meta.col_addr = entry_pkt.col_addr;
    pkt_meta.req_type = entry_pkt.req_type;
    pkt_meta.data_ptr = pkt_mem_waddr;
  end
  assign pkt_mem_din = pkt_meta;                                 // Packet memory input is composed of the packet metadata fields

  // ================================ Data Memory Array ================================
  always @(posedge clk)
    if (data_mem_we) data_mem[data_mem_waddr] <= data_mem_din;

  always @(posedge clk, posedge rst)
    if      (rst)         data_mem_dout <= 0;
    else if (data_mem_re) data_mem_dout <= data_mem[data_mem_raddr];

  assign data_mem_we = pkt_mem_we;                               // Filling Packet and Data memories simultaneously
  assign data_mem_re = bkarb_pkt_valid && !bkarb_pkt_ignore && (bkarb_cmd >= MRS);  // Reading a data slot when Bank Arbiter selects the packet from it (see cmd_t for a list of commands requiring slot_clr)
  
  assign data_mem_waddr = pkt_mem_waddr;
  assign data_mem_raddr = bkarb_data_ptr;                        // Read address is provided by the Row Arbitter when a WRITE packet traverses to the Data Handler

  assign data_mem_din = {entry_pkt.mask, entry_pkt.data};        // Data memory input is simply packet's data and mask
  assign rowarb_mask  = data_mem_dout[DATA_WIDTH+:MASK_WIDTH];
  assign rowarb_data  = data_mem_dout[0+:DATA_WIDTH];

  // ================================== Slot Register ==================================
  slot_reg #(.DEPTH (ROWARB_DEPTH)) slot_reg (
    .clk,
    .rst,
    .slot_set,
    .slot_nxt_addr,
    .slot_clr,
    .slot_clr_addr,
    .slot_cnt,
    .slot_full);

  assign slot_set      = pkt_mem_we;                             // Occupying a slot when writing a packet to the memory
  assign slot_clr      = data_mem_re;                            // Clearing a slot when data is read from it
  assign slot_clr_addr = data_mem_raddr;                         // 1st clear slot is equal to the data memory read address

  // ================================== Pointer Queues =================================
  genvar i;
  generate
    for (i=0; i<PRIO-1; i++) begin : ptrQue
      xvk_fifo #(
        .WIDTH     ($clog2(ROWARB_DEPTH)),
        .DEPTH     (ROWARB_DEPTH),
        .PROG_FULL (),
        .RAM_TYPE  ("BLOCK"))
      ptr_que (
        .clk,
        .rst,
        .wr_en     (ptr_que_wr    [i]),
        .rd_en     (ptr_que_rd    [i]),
        .din       (ptr_que_din),
        .full      (),
        .empty     (ptr_que_empty [i]),
        .last      (),
        .prog_full (),
        .dout      (ptr_que_dout  [i]));
    end
  endgenerate

  always_comb begin
    ptr_que_wr = 0;
    ptr_que_wr[entry_pkt.prio] = intf_pkt_ack || ui_pkt_ack;
  end

  assign ptr_que_din = slot_nxt_addr;

  // Priority Encoder for picking the highest non-empty pointer queue
  always_comb begin
    prio_curr = PRIO-1;
    for (int idx=0; idx<PRIO-1; idx++)
      if (!ptr_que_empty[idx]) prio_curr = idx;
  end

  always_comb begin
    ptr_que_rd = 0;
    case (prio_curr)
      0, 2 : ptr_que_rd[prio_curr] = !pkt_que_prog_full[0];  // Priorities 0 and 2 are for regular packets, which go to output 0 (Unified Bank Engine)
      1    : ptr_que_rd[prio_curr] = !pkt_que_prog_full[1];  // Prioritiy 1 is for AiM packets, which go to output 1 (AiM Engine)
    endcase
  end

  assign pkt_extract = |ptr_que_rd;  // Extracting packet from the memory if at least one of the priorities is being read

  // ================================== Packet Queues ==================================
  generate
    for (i=0; i<2; i++) begin : pktQue
      // Use this FIFO for shortest latency at the cost of additional resources (~200 LUT, 200 FF)
      xvk_fifo #(
        .WIDTH     ($bits(pkt_meta_t)),
        .DEPTH     (8),
        .PROG_FULL (6),
        .RAM_TYPE  ("BLOCK"))
      pkt_que (
        .clk,
        .rst,
        .wr_en     (pkt_que_wr[i]),
        .rd_en     (pkt_que_rd[i]),
        .din       (pkt_que_din),
        .full      (),
        .empty     (pkt_que_empty[i]),
        .last      (),
        .prog_full (pkt_que_prog_full[i]),
        .dout      (pkt_que_dout[i]));

      // // Use this FIFO to save some resources at the cost of 2 additional clock cycles in latency
      // xpm_fifo_sync #(
      //   .DOUT_RESET_VALUE    ("0"),            // Reset value for read path
      //   .ECC_MODE            ("no_ecc"),       // Enable ECC: en_ecc, no_ecc
      //   .FIFO_MEMORY_TYPE    ("block"),        // Memory type: distributed, block, ultra, auto
      //   .FIFO_READ_LATENCY   (0),              // Number of output register stages in the read data path: 0-10; must be 0 if READ_MODE = fwft
      //   .FIFO_WRITE_DEPTH    (16),             // Number of elements in FIFO: 16-4194304; must be power of two
      //   .FULL_RESET_VALUE    (0),              // Reset values for full, allmost_full and prog_full flags: 0-1
      //   .PROG_EMPTY_THRESH   (5),              // Minimum number of read words for prog_empty: 3-4194301; min value = 5 if READ_MODE = fwft
      //   .PROG_FULL_THRESH    (5),              // Maximum number of write words for prog_full: 5-4194301; min value = 5 + CRC_SYNC_STAGES if READ_MODE = fwft
      //   .RD_DATA_COUNT_WIDTH (5),              // Width of the rd_data_cout: 1-23; must be log2(FIFO_WRITE_DEPTH)+1 if WRITE_DATA_WIDTH = READ_DATA_WIDTH
      //   .READ_DATA_WIDTH     ($bits(pkt_meta_t)),   // Width of the read port: 1-4096; write-to-read width aspect ratio must be 1:1, 1:2, 1:4, 1:8, 8:1, 4:1, 2:1
      //   .READ_MODE           ("fwft"),         // Read Mode: std - standard read more, fwft - first word fall through
      //   .SIM_ASSERT_CHK      (0),              // Simulation messages enabled: 0-1
      //   .USE_ADV_FEATURES    ("0002"),         // Advanced features: see UltaScale Architecture Libraries Guide 2019 Page 40
      //   .WAKEUP_TIME         (0),              // Weakup Time: 0-2; must be set to 0 if FIFO_MEMORY_TYPE = auto
      //   .WR_DATA_COUNT_WIDTH (5),              // Width of the wr_data_count: 1-24; must be log2(FIFO_WRITE_DEPTH)+1
      //   .WRITE_DATA_WIDTH    ($bits(pkt_meta_t)))   // Width of the write port: 1-4096; write-to-read width aspect ratio must be 1:1, 1:2, 1:4, 1:8, 8:1, 4:1, 2:1
      // pkt_buffer (
      //   .almost_empty        (),               // 1-bit out: One more read is left before empty
      //   .almost_full         (),               // 1-bit out: One more write is left before full
      //   .data_valid          (),               // 1-bit out: Valid data is available on dout
      //   .dbiterr             (),               // 1-bit out: EDC decoder detected a double-bit error; FIFO data corrupted
      //   .dout                (pkt_que_dout[i]),        // READ_DATA_WIDTH-bit out: Output data
      //   .empty               (pkt_que_empty[i]),               // 1-bit out: FIFO is empty
      //   .full                (),               // 1-bit out: FIFO is full
      //   .overflow            (),               // 1-bit out: Write request during the previous clock cycle was rejected due to FIFO being full
      //   .prog_empty          (),               // 1-bit out: Programmable empty
      //   .prog_full           (pkt_que_prog_full[i]),               // 1-bit out: Programmable full
      //   .rd_data_count       (),               // RD_DATA_COUNT_WIDTH-bit out: Number of words read from the FIFO
      //   .rd_rst_busy         (),               // 1-bit out: FIFO read domain is in reset
      //   .sbiterr             (),               // 1-bit out: EDC decoder detected and fixed a single-bit error
      //   .underflow           (),               // 1-bit out: Read request during the previous clock cycle was rejected due to FIFO being empty
      //   .wr_ack              (),               // 1-bit out: Write request during the previous clock cycle was successfull
      //   .wr_data_count       (),               // WR_DATA_COUNT_WIDTH-bit out: Number of words written into the FIFO
      //   .wr_rst_busy         (),               // 1-bit out: FIFO write domain is in reset
      //   .din                 (pkt_que_din),            // WRITE_DATA_WIDTH-bit in: Input data
      //   .injectdbiterr       (0),              // 1-bit in: Injects a double bit error if EDC is used on block or ultra RAM
      //   .injectsbiterr       (0),              // 1-bit in: Injects a single bit error if EDC is used on block or ultra RAM
      //   .rd_en               (pkt_que_rd[i]), // 1-bit in: Read enable
      //   .rst                 (rst),            // 1-bit in: Reset synchronous with write clock domain
      //   .sleep               (0),              // 1-bit in: When high, FIFO is in power saving mode
      //   .wr_clk              (clk),            // 1-bit in: Write domain clock
      //   .wr_en               (pkt_que_wr[i]));        // 1-bit in: Write enable

      assign pkt_que_rd[i] = bke_rdy[i];

      // Row Arbiter Output Signals
      assign rowarb_pkt_valid[i] = !pkt_que_empty[i];
      assign rowarb_pkt[i]       = pkt_que_dout[i];
    end

    assign pkt_que_din = pkt_mem_dout;

    always @(posedge clk, posedge rst)
      if (rst) pkt_que_inj <= 0;
      else     pkt_que_inj <= pkt_mem_re;

    always_comb begin
      pkt_que_wr = 0;
      case (pkt_que_din.prio)
        0, 2 : pkt_que_wr[0] = pkt_que_inj;  // Priorities 0 and 2 are for regular packets (Bank Engine)
        1    : pkt_que_wr[1] = pkt_que_inj;  // Priority 1 is for AiM packets (AiM Engine)
      endcase
    end
  endgenerate

  // ================================== Initialization =================================
  initial begin
    // Entry Buffer Signals
    intf_pkt_ack  = 0;
    error_retry_pkt_overflow = 0;
    // Packet Memory Signals
    pkt_mem       = '{ROWARB_DEPTH{0}};
    pkt_mem_dout  = 0;
    // Data Memory Signals
    data_mem      = '{ROWARB_DEPTH{0}};
    data_mem_dout = 0;
    // Packet Queue Signals
    pkt_que_inj   = 0;
  end

endmodule
