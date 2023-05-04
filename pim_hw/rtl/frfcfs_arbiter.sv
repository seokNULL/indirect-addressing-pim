`timescale 1ps / 1ps

module frfcfs_arbiter (
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
  output pkt_meta_t rowarb_pkt [2**BK_ADDR_WIDTH:0],
  output logic [2**BK_ADDR_WIDTH:0] rowarb_pkt_valid,
  input  logic [2**BK_ADDR_WIDTH:0] bke_rdy,
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
  logic [$clog2(ROWARB_DEPTH)-1:0] ptr_que_din;                // Next memory pointer to add to the queue; the same for all pointer FIFOs
  logic [NUM_RAQ-1:0][$clog2(ROWARB_DEPTH)-1:0] ptr_que_dout;  // Memory pointers from all pointer queues
  logic [NUM_RAQ-1:0] ptr_que_empty;                           // Pointer queue empty flags
  logic [NUM_RAQ-1:0] ptr_que_full;                            // Pointer queue full flags
  logic [NUM_RAQ-1:0] ptr_que_last;                            // Pointer queue has one element left
  logic [NUM_RAQ-1:0] ptr_que_prog_full;                       // Pointer queue programmable full threshold flags
  logic [NUM_RAQ-1:0] ptr_que_wr;                              // Write enable for each pointer queue
  logic [NUM_RAQ-1:0] ptr_que_rd;                              // Read enable for each pointer queue
  logic [NUM_RAQ-1:0] ptr_que_rd_last;                         // Reading the last entry when write is not asserted
  logic ptr_que_avlb;                                          // Indicates that at least one pointer queue is available
  logic [$clog2(NUM_RAQ)-1:0] nxt_empty_ptr_que;               // Index of the next empty pointer queue
  logic [$clog2(NUM_RAQ)-1:0] store_ptr_que;                   // Index of the pointer queue to store the pointer (either next empty or the one selected by CAM)
  logic [NUM_RAQ-2:0]         ptr_que_ignore;                  // Register for marking pointer queues to be ignored
  logic [$clog2(NUM_RAQ)-1:0] ptr_que_rd_addr;                 // Pointer queue index selected from the chosen bank queue
  logic [5:0] ptr_que_starve_cnt [NUM_RAQ-1:0];                // Starvation counters for each of the pointer queues
  logic       ptr_que_starve     [NUM_RAQ-1:0];                // Starvation flags for pointer queues
  // Pointer CAM
  typedef struct packed {
    logic [$clog2(PRIO)-1:0]   prio;                           // Input packet priority
    logic [BK_ADDR_WIDTH-1:0]  bk_addr;                        // Input packet bank address
    logic [ROW_ADDR_WIDTH-1:0] row_addr;                       // Input packet row address
  } cam_key_t;
  logic [$clog2(NUM_RAQ)-1:0] cam_wr_addr;                     // Address used for writing data to CAM
  logic     cam_we;                                            // CAM write enable signal
  cam_key_t cam_din;                                           // Data to be written to CAM
  logic     cam_se;                                            // CAM search enable signal (looking for cam_key among CAM data)
  logic     cam_se_d;
  cam_key_t cam_key;                                           // A key to be compared with CAM contents during search
  logic     cam_match;                                         // Flag that is asserted upon a match following cam_se
  logic [$clog2(NUM_RAQ)-1:0] cam_match_addr;                  // An address of the match (only meaningful when cam_se is asserted)
  logic [NUM_RAQ-2:0] cam_ignore;                              // Indicates which CAM slots must be ignored to let the queues get exhausted (derived from ptr_que_ignore)
  // Supply Queues
  logic [$clog2(NUM_RAQ)+BK_ADDR_WIDTH-1:0] supply_que_din;    // Next ptr_que pointer to add to the queue; the same for all priority FIFOs
  logic [$clog2(NUM_RAQ)+BK_ADDR_WIDTH-1:0] supply_que_dout [PRIO-2:0];  // ptr_que pointers from all priority queues
  logic [PRIO-2:0] supply_que_empty;                           // Priority queue empty flags
  logic [PRIO-2:0] supply_que_wr;                              // Write enable for each priority queue
  logic [PRIO-2:0] supply_que_rd;                              // Read enable for each priority queue
  // Bank Queues
  logic [2**BK_ADDR_WIDTH-1:0] bk_que_wr        [PRIO-2:0];    // Bank queue write enable signal
  logic [2**BK_ADDR_WIDTH-1:0] bk_que_wr_nxt    [PRIO-2:0];
  logic [2**BK_ADDR_WIDTH-1:0] bk_que_rd        [PRIO-2:0];    // Bank queue read enable signal
  logic [$clog2(NUM_RAQ)-1:0]  bk_que_din       [PRIO-2:0];    // Bank queue data input
  logic [2**BK_ADDR_WIDTH-1:0] bk_que_empty     [PRIO-2:0];    // Bank queue empty flag
  logic [2**BK_ADDR_WIDTH-1:0] bk_que_last      [PRIO-2:0];    // Bank queue "one entry left" flag
  logic [2**BK_ADDR_WIDTH-1:0] bk_que_prog_full [PRIO-2:0];    // Bank queue rpogrammable full flag
  logic [BK_ADDR_WIDTH-1:0]    bk_que_idx       [PRIO-2:0];    // Bank queue index selected from the supply queue in the same priority
  logic [BK_ADDR_WIDTH-1:0]    bk_que_idx_nxt   [PRIO-2:0];
  logic [2**BK_ADDR_WIDTH-1:0][$clog2(NUM_RAQ)-1:0] bk_que_dout [PRIO-2:0];  // Bank queue data output
  // Round Robin
  logic [PRIO-2:0]            rr_add;                          // Add entry signal
  logic [BK_ADDR_WIDTH-1:0]   rr_add_val [PRIO-2:0];           // Entry to be added with rr_add
  logic [PRIO-2:0]            rr_rmv;                          // Remove the current entry signal
  logic [PRIO-2:0]            rr_nxt;                          // Next entry signal
  logic [BK_ADDR_WIDTH-1:0]   rr_idx     [PRIO-2:0];           // Current entry index
  logic [BK_ADDR_WIDTH-1:0]   rr_idx_d   [PRIO-2:0];         
  logic [$clog2(PRIO-1):0]    prio_curr;                       // Highest non-empty priority level
  logic [PRIO-2:0]            prio_rd, prio_rd_d;              // Read enable signals for each priority
  logic [$clog2(NUM_RAQ)-1:0] prio_dout  [PRIO-1:0];           // Data outputs from the chosen bank queues for each priority
  logic pkt_extract;                                           // Signal indicating that a packet (and packet pointer) must be extracted from the memory
  // Packet Queues
  logic pkt_que_inj;                                           // Signal for injecting packet into one of the packet queues (split into pkt_que_wr)
  logic [2**BK_ADDR_WIDTH:0] pkt_que_wr;                       // Packet queue write enable signal
  logic [2**BK_ADDR_WIDTH:0] pkt_que_rd;                       // Packet queue read enable signal
  logic [2**BK_ADDR_WIDTH:0] pkt_que_prog_full;                // Packet queue programmable full flag
  logic [2**BK_ADDR_WIDTH:0] pkt_que_empty;                    // Packet queue empty flag
  pkt_meta_t pkt_que_din;                                      // Packet queue data input
  pkt_meta_t pkt_que_dout [2**BK_ADDR_WIDTH:0];                // Packet queue data output

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

  // Acknowleging UI packets if there is either a CAM match or an empty queue available
  assign ui_pkt_ack = !slot_full && cam_se_d && (cam_match || ptr_que_avlb);

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
  assign pkt_mem_raddr = ptr_que_dout[ptr_que_rd_addr];

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
  assign data_mem_re = bkarb_pkt_valid && !bkarb_pkt_ignore && (bkarb_cmd >= MRS);    // Reading a data slot when Bank Arbiter selects the packet from it (see cmd_t for a list of commands requiring slot_clr)
  
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

  assign slot_set      = pkt_mem_we;                                     // Occupying a slot when writing a packet to the memory
  assign slot_clr      = data_mem_re;                                    // Clearing a slot when data is read from it
  assign slot_clr_addr = data_mem_raddr;                                 // 1st clear slot is equal to the data memory read address

  // =================================== Pointer CAM ===================================
  xvk_cam #(
    .CAM_WIDTH ($bits(cam_key_t)),
    .CAM_DEPTH (NUM_RAQ-1))
  ptr_cam (
    .clk,
    .rst,
    .cam_wr_addr,
    .cam_we,
    .cam_din,
    .cam_key,
    .cam_se,
    .cam_ignore,
    .cam_match,
    .cam_match_addr);

  always_comb begin
    cam_key.bk_addr  = ui_bk_addr;
    cam_key.row_addr = 0;
    cam_key.prio     = 0;
    
    if (cfr_schd.ROW_POLICY == FRFCFS) begin
      cam_key.row_addr = ui_row_addr;
      cam_key.prio     = ui_prio;
    end
    else if (cfr_schd.ROW_POLICY == FIFO) begin
      cam_key.row_addr = 0;                                              // Preventing FRFCFS arbitration by setting all row addresses in the CAM key to zero
      if (ui_prio == 2 || ui_prio == 0) cam_key.prio = 0;                // Removing PRIO=2 for FIFO scheduling
      else                              cam_key.prio = ui_prio;
    end
  end

  assign cam_se = ui_pkt_req;                                            // Search for each standard/aim input; "retry" inputs automatically go to a dedicated pointer queue
  assign cam_ignore = ptr_que_ignore;                                    // Ignoring CAM slots for queues that have reached the full status

  always @(posedge clk, posedge rst)
    if      (rst)    cam_din <= 0;
    else if (cam_se) cam_din <= cam_key;                                 // Preparing to write the key every time we search the CAM (in case of fail)

  always @(posedge clk, posedge rst)
    if (rst) cam_se_d <= 0;
    else     cam_se_d <= cam_se;                                         // Delaying the search enable bit for tracking search pass/fail

  assign cam_we = !slot_full && cam_se_d && ptr_que_avlb && !cam_match;  // Write a new entry if there is no match and at least one pointer queue available and slots are not full
  assign cam_wr_addr = nxt_empty_ptr_que;                                // Writing the key to the address corresponding to the next selected pointer queue

  // ================================== Pointer Queues =================================
  genvar i, k;
  generate
    for (i=0; i<NUM_RAQ; i++) begin : ptrQue
      xvk_fifo #(
        .WIDTH     ($clog2(ROWARB_DEPTH)),
        .DEPTH     (RAQ_DEPTH_DEFAULT),
        .PROG_FULL (RAQ_DEPTH_DEFAULT-2),                                // Need to terminate the queue 2 cycles before it's full to provide time for CAM to start ignoring it
        .RAM_TYPE  ("DISTRIBUTED"))
      ptr_que (
        .clk,
        .rst,
        .wr_en     (ptr_que_wr        [i]),
        .rd_en     (ptr_que_rd        [i]),
        .din       (ptr_que_din),
        .full      (ptr_que_full      [i]),
        .empty     (ptr_que_empty     [i]),
        .last      (ptr_que_last      [i]),
        .prog_full (ptr_que_prog_full [i]),
        .dout      (ptr_que_dout      [i]));

      assign ptr_que_rd_last[i] = ptr_que_last[i] && ptr_que_rd[i] && !ptr_que_wr[i];

      // Pointer Queue Starvation
      always @(posedge clk, posedge rst)
        if      (rst)                                                       ptr_que_starve_cnt[i] <= 0;
        else if ((ptr_que_wr[i] && !ptr_que_starve[i]) || ptr_que_empty[i]) ptr_que_starve_cnt[i] <= ptr_que_empty[i] ? 0 : ptr_que_starve_cnt[i] + 1'b1;
      assign ptr_que_starve[i] = ptr_que_starve_cnt[i] == cfr_schd.EXH_THR-2;  // "-2" required to compensate for internal delays until starvation is noticed
    end
  endgenerate
  // defparam ptrQue[NUM_RAQ-1].ptr_que.DEPTH = RAQ_DEPTH_RETRY;  // Use this line for setting a different depth for the Retry Queue

  // Ignoring queues after they get full; no new pointers are written until the queues are completely exhausted
  always @(posedge clk, posedge rst)
    if (rst) ptr_que_ignore <= 0;
    else begin
      for (int idx=0; idx<NUM_RAQ-1; idx++) begin
        if (ptr_que_prog_full[idx]||ptr_que_starve[idx]) ptr_que_ignore[idx] <= 1'b1;
        if (ptr_que_empty[idx])                          ptr_que_ignore[idx] <= 1'b0;
      end
    end

  always @(posedge clk, posedge rst)
    if      (rst)        ptr_que_avlb <= 1;
    else if (ui_pkt_req) ptr_que_avlb <= |(ptr_que_empty[NUM_RAQ-2:0] & ~ptr_que_wr[NUM_RAQ-2:0]);  // A queue will be available at the next cycle if it's empty now and its write enable signal is not asserted

  // Priority Encoder for selecting the next empty pointer queue
  prio_enc #(.WIDTH(NUM_RAQ-1)) prio_enc (
    .clk,
    .rst,
    .prioenc_in  (ptr_que_empty[NUM_RAQ-2:0]&(~ptr_que_wr[NUM_RAQ-2:0])),  // Pointer queue NUM_RAQ-1 is used for "retry" packets so it's not included in the rotation
    .prioenc_out (nxt_empty_ptr_que));

  // Selecting a queue and storing the pointer
  assign ptr_que_din   = slot_nxt_addr;
  assign store_ptr_que = cam_match ? cam_match_addr : nxt_empty_ptr_que;

  always_comb begin
    ptr_que_wr = 0;
    ptr_que_wr[store_ptr_que] = ui_pkt_ack;
    ptr_que_wr[NUM_RAQ-1]     = intf_pkt_ack;  // The last queue is dedicated to "retry" packets
  end

  // Reading from a pointer queue selected by one of the bank queues
  always @(posedge clk)
    ptr_que_rd_addr <= prio_dout[prio_curr];

  always_comb begin
    ptr_que_rd = 0;
    ptr_que_rd[ptr_que_rd_addr] = pkt_extract;
  end

  // ================================== Supply Queues ==================================
  generate
    for (i=0; i<PRIO-1; i++) begin : suppQue
      xvk_fifo #(
        .WIDTH     ($clog2(NUM_RAQ)+BK_ADDR_WIDTH),
        .DEPTH     (2*NUM_RAQ),
        .PROG_FULL (),
        .RAM_TYPE  ("BLOCK"))
      supply_que (
        .clk,
        .rst,
        .wr_en     (supply_que_wr    [i]),
        .rd_en     (supply_que_rd    [i]),
        .din       (supply_que_din),
        .full      (),
        .empty     (supply_que_empty [i]),
        .last      (),
        .prog_full (),
        .dout      (supply_que_dout  [i]));

      assign supply_que_rd[i] = |bk_que_wr_nxt[i];
    end
  endgenerate

  always_comb begin
    supply_que_wr = 0;
    supply_que_wr[entry_pkt.prio] = intf_pkt_ack || (ui_pkt_ack && ptr_que_empty[store_ptr_que]);  // Only adding UI queues with the first packets, but "retry" queue is added with each packet
  end

  assign supply_que_din = {(intf_pkt_ack ? NUM_RAQ-1 : store_ptr_que), entry_pkt.bk_addr};         // Priority queue data is the index of the currently selecetd pointer queue

  generate
    for (i=0; i<PRIO-1; i++) begin : prioLvl
      // ================================= Bank Queues =================================
      // Bank Queues (PRIO=0, PRIO=2)
      if (i != 1) begin
        for (k=0; k<2**BK_ADDR_WIDTH; k++) begin : bkQue  
          xvk_fifo #(
            .WIDTH     ($clog2(NUM_RAQ)),
            .DEPTH     (4),
            .PROG_FULL (3),
            .RAM_TYPE  ("DISTRIBUTED"))
          bk_que (
            .clk,
            .rst,
            .wr_en     (bk_que_wr        [i][k]),
            .rd_en     (bk_que_rd        [i][k]),
            .din       (bk_que_din       [i]),
            .full      (),
            .empty     (bk_que_empty     [i][k]),
            .last      (bk_que_last      [i][k]),
            .prog_full (bk_que_prog_full [i][k]),
            .dout      (bk_que_dout      [i][k]));
        end

        always @(posedge clk, posedge rst)
          if (rst) begin
            bk_que_din[i] <= 0;
            bk_que_idx[i] <= 0;
          end
          else begin
            bk_que_din[i] <= supply_que_dout[i][BK_ADDR_WIDTH+:$clog2(NUM_RAQ)];
            bk_que_idx[i] <= supply_que_dout[i][BK_ADDR_WIDTH-1:0];
          end

        assign bk_que_idx_nxt[i] = supply_que_dout[i][BK_ADDR_WIDTH-1:0];

        always @(posedge clk, posedge rst)
          if (rst) bk_que_wr[i] <= 0;
          else     bk_que_wr[i] <= bk_que_wr_nxt[i];

        always_comb begin
          bk_que_wr_nxt[i] = 0;  // Using ..._nxt instaed of bk_que_wr to add a pipeline stage between the supply and bk queues (comb locig path between them is otherwise long)
          bk_que_wr_nxt[i][bk_que_idx_nxt[i]] = !supply_que_empty[i] && !bk_que_prog_full[i][bk_que_idx_nxt[i]];
        end
        always_comb begin
          bk_que_rd[i] = 0;      // "Retry" queue is read every time a pointer is taken, other queues are read to exhaustion (one entry left and not currently written)
          bk_que_rd[i][rr_idx_d[i]] = prio_rd_d[i] && (ptr_que_rd_last[ptr_que_rd_addr] || ptr_que_rd[NUM_RAQ-1]);
        end
      end

      // Bank Queue (PRIO=1 aka AiM Queue)
      else begin
        xvk_fifo #(
          .WIDTH     ($clog2(NUM_RAQ)),
          .DEPTH     (4),
          .PROG_FULL (3),
          .RAM_TYPE  ("DISTRIBUTED"))
        aim_que (
          .clk,
          .rst,
          .wr_en     (bk_que_wr        [1][0]),
          .rd_en     (bk_que_rd        [1][0]),
          .din       (bk_que_din       [1]),
          .full      (),
          .empty     (bk_que_empty     [1][0]),
          .last      (bk_que_last      [1][0]),
          .prog_full (bk_que_prog_full [1][0]),
          .dout      (bk_que_dout      [1][0]));

        for (k=1; k<2**BK_ADDR_WIDTH; k++) begin : aimQue  // Filling unused variables with zeros to reduce the number of warnings
          assign bk_que_wr_nxt    [1][k] = 0;
          assign bk_que_rd        [1][k] = 0;
          assign bk_que_empty     [1][k] = 1;
          assign bk_que_last      [1][k] = 0;
          assign bk_que_prog_full [1][k] = 0;
          assign bk_que_dout      [1][k] = 0;
        end

        always @(posedge clk, posedge rst)
          if (rst) bk_que_din[1] <= 0;
          else     bk_que_din[1] <= supply_que_dout[1][BK_ADDR_WIDTH+:$clog2(NUM_RAQ)];

        assign bk_que_idx    [1] = 0;  // Queue index is irrelevant for PRIO=1, since there is only one bank queue
        assign bk_que_idx_nxt[1] = 0;

        always @(posedge clk, posedge rst)
          if (rst) bk_que_wr[1] <= 0;
          else     bk_que_wr[1] <= bk_que_wr_nxt[1];

        always_comb begin
          bk_que_wr_nxt[1] = 0;
          bk_que_wr_nxt[1][0] = !supply_que_empty[1] && !bk_que_prog_full[1][0];
        end
        always_comb begin
          bk_que_rd[1] = 0;
          bk_que_rd[1][0] = prio_rd_d[1] && (ptr_que_rd_last[ptr_que_rd_addr] || ptr_que_rd[NUM_RAQ-1]);
        end
      end

      // ================================= Round Robin =================================
      // Round Robin Counter (PRIO=0, PRIO=2)
      if (i != 1) begin
        round_robin #(
          .DEPTH      (2**BK_ADDR_WIDTH)) 
        round_robin (
          .clk,
          .rst,
          .rr_add     (rr_add[i]),
          .rr_add_val (rr_add_val[i]),
          .rr_rmv     (rr_rmv[i]),
          .rr_nxt     (rr_nxt[i]),
          .rr_idx     (rr_idx[i]));

        assign rr_add     [i] = |bk_que_wr[i];
        assign rr_add_val [i] = bk_que_idx[i];
        assign rr_rmv     [i] = bk_que_empty[i][rr_idx[i]];
        assign rr_nxt     [i] = prio_rd[i];  // Only rotate when packet is accepted by the packet queue (force waiting, reissues EDC fail packets faster)
        // assign rr_nxt     [i] = (prio_curr == i);  // If packet cannot be issued to the packet queue, skip this bank and rotate to the next (use if EDC is not used)
        assign prio_rd    [i] = (prio_curr == i) && !bk_que_empty[i][rr_idx[i]] && !bk_que_rd[i][rr_idx[i]] && !(pkt_que_prog_full[rr_idx[i]] && !bke_rdy[rr_idx[i]]);  // Read a queue in the chosen priority
        assign prio_dout  [i] = bk_que_dout[i][rr_idx[i]];                                                                                                              // Output of the chosen Bank Queue
      end

      // Round Robin Counter (PRIO=1 aka AiM)
      else begin
        assign rr_add     [1] = 0;
        assign rr_add_val [1] = 0;
        assign rr_rmv     [1] = 0;
        assign rr_nxt     [1] = 0;
        assign rr_idx     [1] = 0;
        assign prio_rd    [1] = (prio_curr == 1) && !bk_que_rd[1][0] && !(pkt_que_prog_full[2**BK_ADDR_WIDTH] && !bke_rdy[2**BK_ADDR_WIDTH]);  // PRIO=1 packets are always directed to the AIM Engine
        assign prio_dout  [1] = bk_que_dout[1][0];                                                                                             // There is only one Bank Queue for PRIO=1
      end

      always @(posedge clk)
        rr_idx_d[i] <= rr_idx[i];   // Delaying round-robin result for synchronization with bk_que_rd signal
    end
    assign prio_dout [PRIO-1] = 0;  // Bank Queue output value for a dummy priority which is selected when no packets are present
  endgenerate

  // Priority Encoder for picking the highest non-empty priority queue
  always_comb begin
    prio_curr = PRIO-1;
    for (int idx=0; idx<PRIO-1; idx++)
      if (|(~bk_que_empty[idx])) prio_curr = idx;
  end

  always @(posedge clk, posedge rst)
    if (rst) prio_rd_d <= 0;
    else     prio_rd_d <= prio_rd;

  assign pkt_extract = |prio_rd_d;  // Extracting packet from the memory if at least one of the priorities is being read

  // ================================== Packet Queues ==================================
  generate
    for (i=0; i<2**BK_ADDR_WIDTH+1; i++) begin : pktQue
      // Use this FIFO for shortest latency at the cost of additional resources (~200 LUT, 200 FF)
      xvk_fifo #(
        .WIDTH     ($bits(pkt_meta_t)),
        .DEPTH     (4),
        .PROG_FULL (2),
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
      if (pkt_que_din.prio == 1) pkt_que_wr[2**BK_ADDR_WIDTH]    = pkt_que_inj;  // ! WARNING ! AiM packets are segregated based on the PRIO INDEX! Make sure the index doesn't change from "1"
      else                       pkt_que_wr[pkt_que_din.bk_addr] = pkt_que_inj;
    end
  endgenerate

  // ================================== Initialization =================================
  initial begin
    // Entry Buffer Signals
    intf_pkt_ack       = 0;
    error_retry_pkt_overflow = 0;
    // Packet Memory Signals
    pkt_mem            = '{ROWARB_DEPTH{0}};
    pkt_mem_dout       = 0;
    // Data Memory Signals
    data_mem           = '{ROWARB_DEPTH{0}};
    data_mem_dout      = 0;
    // Pointer Queue Signals
    ptr_que_ignore     = 0;
    ptr_que_avlb       = 1;
    ptr_que_rd_addr    = 0;
    ptr_que_starve_cnt = '{NUM_RAQ{0}};
    // Pointer CAM Signals
    cam_din            = 0;
    cam_se_d           = 0;
    // Packet Queue Signals
    pkt_que_inj        = 0;
    // Bank Queue Signals
    bk_que_din         = '{(PRIO-1){0}};
    bk_que_idx         = '{(PRIO-1){0}};
    bk_que_wr          = '{(PRIO-1){0}};
    rr_idx_d           = '{(PRIO-1){0}};
  end

endmodule
