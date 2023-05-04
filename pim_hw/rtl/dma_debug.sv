`timescale 1ps / 1ps

import aimc_lib::*;

module dma_debug (  
  input  logic clk,
  input  logic rst,
  // AXI4 Write Data Probe
  input  logic s_axi_wvalid,
  input  logic s_axi_wready,
  input  logic [31:0]  s_axi_awaddr,
  input  logic [255:0] s_axi_wdata,
  // AiM DMA Interface
  input  logic dbg_cmd_valid,
  input  logic [5:0] dbg_cmd,
  input  logic dbg_re,
  input  logic [DBG_ADDR_WIDTH-1:0] dbg_addr,
  output logic [DATA_WIDTH-1:0] dbg_dout);

  // =============================== Signal Declarations ===============================
  localparam DBG_ENTRY_BYTES  = 5;                                         // Signle debug entry width in BYTES
  localparam DBG_SDATA_WIDTH  = 7;                                         // Supplementary data width in each debug entry (5-bit ISR instruction, 1-bit request, 1-bit response)
  localparam DBG_TSTAMP_WDITH = 8*DBG_ENTRY_BYTES - DBG_SDATA_WIDTH;       // Timestamp width in each debug entry
  localparam DBG_ENTRY_SLOTS  = DATA_WIDTH/(8*DBG_ENTRY_BYTES);            // Number of debug entry slots per DATA_WIDTH

  // Debugger FSM Signals
  enum logic {DBG_IDLE=0, DBG_RECORD} dbg_state,      dbg_state_nxt;       // Debugger FSM state descriptor variable
  logic [DBG_TSTAMP_WDITH-1:0]        dbg_time,       dbg_time_nxt;        // Time counter register
  logic [$clog2(DBG_ENTRY_SLOTS)-1:0] dbg_entry_slot, dbg_entry_slot_nxt;  // Debug data slot pointer
  logic [DBG_ENTRY_BYTES*8-1:0]       dbg_entry,      dbg_entry_nxt;       // Single debug data entry
  logic                               inc_addr,       inc_addr_nxt;        // Request for incrementing address
  // AXI Signals
  logic axi_ack_wait, axi_ack_wait_nxt;                                    // Asserted when AXI request is asserted without acknowledgement; indicates "waiting" state
  logic pkt_is_isr;                                                        // Indicator for the transcation being an ISR transaction
  aim_op_t isr_op;                                                         // ISR instruction
  logic [4:0] isr_op_code;                                                 // Code stored in the recording. Equals to ISR except when passing write data following ISR_WR_SBK, ISR_WR_GPR, ISR_WR_GB instructions
  logic wr_from_host;                                                      // Indicator that write data is coming from the host instead of GPR
  logic [10:0] wr_data_cnt;                                                // Counter used for write data following ISR_WR_SBK, ISR_WR_GPR, ISR_WR_GB instructions
  logic axi_req;                                                           // AXI master request asserted for a single cycle per transaction
  logic axi_ack;                                                           // AXI slave acknowledgement asserted for a single cycle per transcation
  // Internal RAM Signals
  logic dbg_mem_en;
  logic dbg_mem_re, dbg_mem_re_nxt;
  logic dbg_mem_we;
  logic [DBG_ADDR_WIDTH-1:0] dbg_mem_addr, dbg_mem_addr_nxt;
  logic [DATA_WIDTH/8-1:0]   dbg_mem_mask, dbg_mem_mask_nxt;
  logic [DATA_WIDTH-1:0]     dbg_mem_din;
  logic [DATA_WIDTH-1:0]     dbg_mem_dout;

  // ================================== Internal RAM ===================================
  xpm_memory_spram #(
    .ADDR_WIDTH_A        (DBG_ADDR_WIDTH),
    .AUTO_SLEEP_TIME     (0),
    .BYTE_WRITE_WIDTH_A  (8),
    .CASCADE_HEIGHT      (0),
    .ECC_MODE            ("no_ecc"),
    .MEMORY_INIT_FILE    ("none"),
    .MEMORY_INIT_PARAM   ("0"),
    .MEMORY_OPTIMIZATION ("true"),
    .MEMORY_PRIMITIVE    ("ultra"),
    .MEMORY_SIZE         (2**DBG_ADDR_WIDTH*DATA_WIDTH),
    .MESSAGE_CONTROL     (0),
    .READ_DATA_WIDTH_A   (DATA_WIDTH),
    .READ_LATENCY_A      (1),
    .READ_RESET_VALUE_A  ("0"),
    .RST_MODE_A          ("SYNC"),
    .SIM_ASSERT_CHK      (0),
    .USE_MEM_INIT        (1),
    .WAKEUP_TIME         ("disable_sleep"),
    .WRITE_DATA_WIDTH_A  (DATA_WIDTH),
    .WRITE_MODE_A        ("read_first"))
  dbg_mem (
    .dbiterra            (),
    .douta               (dbg_mem_dout),
    .sbiterra            (),
    .addra               (dbg_mem_addr),
    .clka                (clk),
    .dina                (dbg_mem_din),
    .ena                 (dbg_mem_en),
    .injectdbiterra      (1'b0),
    .injectsbiterra      (1'b0),
    .regcea              (1'b1),
    .rsta                (rst),
    .sleep               (1'b0),
    .wea                 (dbg_mem_mask));

  assign dbg_mem_en = dbg_mem_we || dbg_mem_re;
  assign dbg_mem_we = |dbg_mem_mask;             // Mask acts as a "per-byte" write-enable signal

  always_comb begin
    dbg_mem_din = 0;
    dbg_mem_din[0+:DBG_ENTRY_SLOTS*DBG_ENTRY_BYTES*8] = {DBG_ENTRY_SLOTS{dbg_entry}};  // Repeating the same entry over the entire slot, since mask will select the correct one anyways
  end

  assign dbg_dout = dbg_mem_dout;

  // =================================== AXI Decoder ===================================
  assign pkt_is_isr   = (s_axi_awaddr >= ISR_ADDR_0 && s_axi_awaddr <= ISR_ADDR_1);    // Asserted if the current write transaction is an ISR transaction
  assign isr_op       = aim_op_t'(s_axi_wdata[63:59]);
  assign isr_op_code  = wr_data_cnt == 0 ? isr_op : 5'h1F;                             // Using the maximum instruction index for indicating write data
  assign wr_from_host = !s_axi_wdata[45];

  always @(posedge clk, posedge rst)
    if (rst) 
      wr_data_cnt <= 0;
    else if (wr_data_cnt != 0 && axi_ack)
      wr_data_cnt <= wr_data_cnt - 1'b1;
    else if (pkt_is_isr && axi_ack && ((isr_op==ISR_WR_SBK && wr_from_host) || (isr_op==ISR_WR_GB && wr_from_host) || isr_op==ISR_WR_GPR))
      wr_data_cnt <= s_axi_wdata[55:46] + 1'b1;                                       // Actual packet count is OPSIZE + 1

  assign axi_req = s_axi_wvalid && !axi_ack_wait;                                     // Master request signal; asserted for a single cycle per transaction
  assign axi_ack = s_axi_wready && s_axi_wvalid;                                      // Slave respose signal; asserted for a single cycle per transaction

  // =================================== Debugger FSM ==================================
  always @(posedge clk, posedge rst)
    if (rst) begin
      // Debugger FSM
      dbg_state      <= DBG_IDLE;
      dbg_time       <= 0;
      axi_ack_wait   <= 0;
      dbg_entry_slot <= 0;
      dbg_entry      <= 0;
      inc_addr       <= 0;
      // Internal RAM
      dbg_mem_re     <= 0;
      dbg_mem_addr   <= 0;
      dbg_mem_mask   <= 0;
    end
    else begin
      // Debugger FSM
      dbg_state      <= dbg_state_nxt;
      dbg_time       <= dbg_time_nxt;
      axi_ack_wait   <= axi_ack_wait_nxt;
      dbg_entry_slot <= dbg_entry_slot_nxt;
      dbg_entry      <= dbg_entry_nxt;
      inc_addr       <= inc_addr_nxt;
      // Internal RAM
      dbg_mem_re     <= dbg_mem_re_nxt;
      dbg_mem_addr   <= dbg_mem_addr_nxt;
      dbg_mem_mask   <= dbg_mem_mask_nxt;
    end

  always_comb begin
    // default: Debugger FSM
    dbg_state_nxt      = dbg_state;
    dbg_time_nxt       = dbg_time;
    axi_ack_wait_nxt   = axi_ack_wait;
    inc_addr_nxt       = 0;
    // default: Internal RAM
    dbg_mem_addr_nxt   = dbg_mem_addr;
    dbg_mem_re_nxt     = 0;
    dbg_mem_mask_nxt   = 0;
    dbg_entry_slot_nxt = dbg_entry_slot;
    dbg_entry_nxt      = 0;

    case (dbg_state)
      DBG_IDLE : begin
        dbg_mem_re_nxt   = dbg_re;     // To prevent collisions, only allowing read in the IDLE state
        dbg_mem_addr_nxt = dbg_addr;
        axi_ack_wait_nxt = 0;
      end

      DBG_RECORD : begin
        dbg_time_nxt     = dbg_time + 1'b1;                                              // Continuously incrementing the timer
        axi_ack_wait_nxt = s_axi_wvalid ? !s_axi_wready : axi_ack_wait;
        if (inc_addr) dbg_mem_addr_nxt = dbg_mem_addr + 1'b1;

        if ((axi_req || axi_ack) && (pkt_is_isr || wr_data_cnt != 0)) begin
          dbg_entry_nxt = {axi_req, axi_ack, isr_op_code, dbg_time};              
          dbg_mem_mask_nxt = {DBG_ENTRY_BYTES{1'b1}} << DBG_ENTRY_BYTES*dbg_entry_slot;  // Only allow writing entry to a specific slot

          if (dbg_entry_slot == DBG_ENTRY_SLOTS-1) begin                                 // Switch to the next slot and, if all slots for the address are filled, to the next address
            dbg_entry_slot_nxt = 0;
            inc_addr_nxt       = 1;                                                      // Indicates that address should be incremented in two cycles
            if (dbg_mem_addr == 2**DBG_ADDR_WIDTH-1) dbg_state_nxt = DBG_IDLE;           // If all addresses have been filled, switch to IDLE to prevent overwriting
          end
          else begin
            dbg_entry_slot_nxt = dbg_entry_slot + 1'b1;
          end
        end
      end
    endcase

    // Executing commands regardless of the state
    if (dbg_cmd_valid) begin
      case (dbg_cmd)
        6'h00 : begin                  // CMD = 0x00 : Start/resume recording
          dbg_state_nxt = DBG_RECORD;
        end
        6'h01 : begin                  // CMD = 0x01 : Stop recording
          dbg_state_nxt = DBG_IDLE;
        end
        6'h02 : begin                  // CMD = 0x02 : Reset timer and memory pointer
          dbg_time_nxt       = 0;
          dbg_mem_addr_nxt   = 0;
          dbg_entry_slot_nxt = 0;
        end
        default : begin                // RESERVED
          /*NONE*/
        end
      endcase
    end
  end

  // ================================== Initialization =================================
  initial begin
    // AXI Signals
    wr_data_cnt    = 0;
    // Debugger FSM
    dbg_state      = DBG_IDLE;
    dbg_time       = 0;
    axi_ack_wait   = 0;
    dbg_entry_slot = 0;
    dbg_entry      = 0;
    inc_addr       = 0;
    // Internal RAM
    dbg_mem_re     = 0;
    dbg_mem_addr   = 0;
    dbg_mem_mask   = 0;
  end

endmodule
