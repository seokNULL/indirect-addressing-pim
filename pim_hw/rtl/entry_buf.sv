`timescale 1ps / 1ps

module entry_buf (
  input  logic clk, rst,
  // User Interface
  input  pkt_t ui_pkt,
  input  logic ui_pkt_valid,
  output logic rowarb_rdy,
  // Data Handler Interface
  input  pkt_t intf_pkt,
  input  logic intf_pkt_retry,
  // Internal (Row Arbiter) Interface
  output pkt_t entry_pkt,
  output logic ui_pkt_req,
  output logic intf_pkt_req,
  input  logic ui_pkt_ack,
  input  logic intf_pkt_ack,
  output logic [$clog2(PRIO)-1:0]   ui_prio,
  output logic [ROW_ADDR_WIDTH-1:0] ui_row_addr,
  output logic [BK_ADDR_WIDTH-1:0]  ui_bk_addr);

  // ================================== Local Signals ==================================
  // UI Packet Buffer
  logic req_is_buf;                  // When asserted, CAM key (ui_prio, ui_row_addr, ui_bk_addr) is passed from the buffer instead of the input
  pkt_t ui_pkt_nxt;                  // UI packet with some parameters adjusted (prio, row_addr, bk_addr) for AiM packets
  pkt_t ui_pkt_d;                    // UI packet buffer
  logic ui_pkt_d_empty;              // UI packet buffer is empty
  // Data Handler Buffer
  pkt_t intf_pkt_d, intf_pkt_d_nxt;  // Data Handler packet buffer
  logic intf_pkt_retry_d;            // Delayed request signal for scheduling Data Handler packet
  // // Internal Interface
  // logic [9:0] idx_count;   // Counter used for indexing the packets

  // ================================ UI Packet Buffer =================================
  always @(posedge clk, posedge rst)
    if      (rst)                      ui_pkt_d_empty <= 1;
    else if (ui_pkt_ack||ui_pkt_valid) ui_pkt_d_empty <= !ui_pkt_valid;

  always_comb begin
    ui_pkt_nxt = ui_pkt;
    if      (ui_pkt.req_type > WRITE) ui_pkt_nxt.prio = 1;  // Enforcing PRIO=1 on AiM packets (specified by req_type > WRITE) since it is later used to identify them
    else if (ui_pkt.prio == 1)        ui_pkt_nxt.prio = 0;  // Safeguard against receiving conventional READ or WRITE packets with the dedicated AiM priority (PRIO=1)
  end

  always @(posedge clk)
    if (ui_pkt_valid && rowarb_rdy) ui_pkt_d <= ui_pkt_nxt;

  assign req_is_buf = !ui_pkt_d_empty && !ui_pkt_ack;

  // Packet metadata used as a CAM key (for AIM requests, setting banks and rows to zero, so that they are referred to the same CAM slots)
  always_comb begin
    ui_prio     = ui_pkt_nxt.prio;
    ui_row_addr = (ui_pkt.req_type > WRITE) ? 0 : ui_pkt_nxt.row_addr;  // For AIM requests, setting banks and rows to zero, so that they are referred to the same CAM slots
    ui_bk_addr  = (ui_pkt.req_type > WRITE) ? 0 : ui_pkt_nxt.bk_addr;

    if (req_is_buf) begin
      ui_prio     = ui_pkt_d.prio;
      ui_row_addr = (ui_pkt_d.req_type > WRITE) ? 0 : ui_pkt_d.row_addr;
      ui_bk_addr  = (ui_pkt_d.req_type > WRITE) ? 0 : ui_pkt_d.bk_addr;
    end
  end

  // =========================== Data Handler Packet Buffer ============================
  always_comb begin
    intf_pkt_d_nxt = intf_pkt;
    intf_pkt_d_nxt.prio = (intf_pkt.req_type > WRITE) ? 1 : PRIO-2;  // Not raising priority of reissued AiM packets since they are later segregated based on PRIO value
  end
  always @(posedge clk)
    if (intf_pkt_retry) intf_pkt_d <= intf_pkt_d_nxt;

  always @(posedge clk, posedge rst)
    if (rst) intf_pkt_retry_d <= 0;
    else     intf_pkt_retry_d <= intf_pkt_retry;

  // ======================== Internal Interface (Row Arbiter) =========================
  // // Packet index counter
  // always @(posedge clk, posedge rst)
  //   if      (rst)                      idx_count <= 0;
  //   else if (ui_pkt_ack||intf_pkt_ack) idx_count <= idx_count + 1'b1;

  // Selecting between UI and Data Handler packets
  always_comb begin
    entry_pkt = intf_pkt_retry_d ? intf_pkt_d : ui_pkt_d;
    // entry_pkt.index = idx_count;
  end

  assign ui_pkt_req   = !intf_pkt_retry && (ui_pkt_valid || !rowarb_rdy);  // Request a CAM look-up if an input is active or there is a lingering request and no acknowledgement
  assign intf_pkt_req = intf_pkt_retry;

  // ==================== External Interface (UI and Data Handler)  ====================
  assign rowarb_rdy = (ui_pkt_d_empty || ui_pkt_ack);  // Accepting requests when the buffer is empty or currently reading data from the buffer

  // ================================== Initialization =================================
  initial begin
    // UI Packet Buffer
    ui_pkt_d_empty = 1;
    ui_pkt_d = 0;
    // Data Handler Buffer
    intf_pkt_d = 0;
    intf_pkt_retry_d = 0;
    // // Internal Interface
    // idx_count = 0;
  end

endmodule
