`timescale 1ps / 1ps

import axi_lib::*;
import aimc_lib::*;


module axi_bridge (
  input  logic clk,
  input  logic rst,
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
  // DMA Packet Generator Interface
  input  logic pgen_axbr_rdy,                       // DMA Packet Generator ready
  output logic axbr_pgen_pkt_valid,                 // Validity signal for AXI-DMA Bridge's trx_t packet
  output trx_t axbr_pgen_pkt,                       // AXI-DMA Bridge's trx_t packet
//  input  logic pgen_busy,
  // Ordering Engine Interface

  `ifdef  SUPPORT_INDIRECT_ADDRESSING
  output  logic [31:0] o_args_reg_A,
  output  logic [31:0] o_args_reg_B,
  output  logic [31:0] o_args_reg_C,
  `endif

  output logic axbr_orde_rdy,                       // AXI-DMA Bridge ready
  input  logic orde_axbr_pkt_valid,                 // Ordering Engine response packet validity signal
  input  trx_t orde_axbr_pkt);                      // Response packet from Ordering Engine (converted to trx_t type)

  // =============================== Signal Declarations ===============================
  // AXI4: Write Address Channel
  logic [AXI_ADDR_WIDTH-1:0]  axi_awaddr;
  logic axi_awready;
  logic aw_wrap_en;                                 // Determines wrap boundary and enables wrapping  (Write Address Channel)  
  logic [31:0] aw_wrap_size;                        // Size of the write transfer, the write address wraps to a lower address if upper address limit is reached
  logic axi_awv_awr_flag;                           // Flag marking the presence of write address valid
  logic [7:0] axi_awlen_cntr;                       // Internal write address counter to keep track of beats in a burst transaction
  logic [1:0] axi_awburst;
  logic [7:0] axi_awlen;
  // AXI4: Write Data Channel
  logic axi_wready;
  // AXI4: Write Data Response Channel
  logic [1:0] axi_bresp;
  // logic [AXI_BUSER_WIDTH-1:0] axi_buser;
  logic axi_bvalid;
  // AXI4: Read Address Channel
  logic axi_arready;
  logic [7:0] axi_rqlen_cntr;                       // Internal read address counter to keep track of beats in a burst transaction
  logic [7:0] rd_len_cntr;                          // Internal read address counter to count beats in a read response transaction
  logic [1:0] axi_arburst;
  logic [7:0] axi_rqlen;
  logic [AXI_ADDR_WIDTH-1:0] axi_rqaddr;
  logic axi_rqvalid;
  // AXI4: Read Data Channel
  logic [AXI_DATA_WIDTH-1:0] axi_rdata;
  logic [1:0] axi_rresp;
  logic axi_rlast;
  // logic [AXI_RUSER_WIDTH-1:0] axi_ruser;
  logic axi_rvalid;
  logic [7:0] arlen_out;

  logic rd_en, wr_en;
  logic prog_full;

  //  Delay Write Response Signal until DCORE will be idle (pgen_axbr_rdy is high )
  logic axi_awvalid_int;

  logic [15:0] req_in_cntr;  // incoming request counter
  logic [15:0] req_out_cntr; // outgoing request counter

  assign s_axi_awready = axi_awready;
  assign s_axi_wready  = axi_wready;
  assign s_axi_arready = axi_arready;
  assign s_axi_bvalid  = axi_bvalid;
  assign s_axi_bresp   = axi_bresp;
  assign s_axi_rvalid  = axi_rvalid;
  assign s_axi_rdata   = axi_rdata;
  assign s_axi_rresp   = axi_rresp;
  assign s_axi_rlast   = axi_rlast;
  assign axbr_orde_rdy = s_axi_rready;

  `ifdef SUPPORT_INDIRECT_ADDRESSING
  assign  o_args_reg_A = w_args_reg_A;
  assign  o_args_reg_B = w_args_reg_B;
  assign  o_args_reg_C = w_args_reg_C;

  `endif
  // =============================== Read Address Channel ==============================

  // Implement axi_arready generation
  // axi_arready is asserted for one clk clock cycle when
  // s_axi_arvalid is asserted. axi_awready is 
  // de-asserted when reset (active low) is asserted. 
  // The read address is also latched when s_axi_arvalid is 
  // asserted. axi_araddr is reset to zero on reset assertion.

  assign axi_rresp = 2'b00;

  always @(posedge clk, posedge rst)
    if (rst) axi_arready <= 0;
    else     axi_arready <= (~axi_arready && s_axi_arvalid && ~axi_awv_awr_flag && ~axi_rqvalid && pgen_axbr_rdy && !prog_full);

  // Implement axi_rqaddr latching. (read request address which is divided for each beat of burst)
  // This process is used to latch the address when both 
  // s_axi_arvalid and s_axi_rvalid are valid. 

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      axi_rqaddr     <= 0;
      axi_rqlen_cntr <= 0;
      axi_rqlen      <= 0;
      axi_rqvalid    <= 0;
    end
    else if (pgen_axbr_rdy && !prog_full) begin
      if (~axi_arready && s_axi_arvalid && ~axi_awv_awr_flag && ~axi_rqvalid) begin
        // address latching 
        axi_rqaddr     <= s_axi_araddr[AXI_ADDR_WIDTH-1:0];  
        axi_rqlen      <= s_axi_arlen;     
        // start address of transfer
        axi_rqlen_cntr <= 0;
        axi_rqvalid    <= 1;
      end   
      else if (axi_rqlen_cntr < axi_rqlen) begin
        axi_rqlen_cntr <= axi_rqlen_cntr + 1;
        // The read address for all the beats in the transaction are increments by arsize
        axi_rqaddr[AXI_ADDR_WIDTH-1:ADDR_LSB] <= axi_rqaddr[AXI_ADDR_WIDTH-1:ADDR_LSB] + 1;
        //rqaddr aligned to 4 byte boundary
        axi_rqaddr[ADDR_LSB-1:0] <= {ADDR_LSB{1'b0}};
        axi_rqvalid <= 1;
      end
      else if (axi_rqlen_cntr == axi_rqlen) begin
        axi_rqvalid <= 0;
        axi_rqaddr  <= 0;
      end
    end
    else begin
        // axi_rqvalid <= 0;
        // axi_rqaddr <= 0;
    end
  end

  // ============================== Write Address Channel ==============================

  // Implement axi_awready generation
  // axi_awready is asserted for one clk clock cycle when both
  // s_axi_awvalid and s_axi_wvalid are asserted. axi_awready is
  // de-asserted when reset is low.
  always @(posedge clk, posedge rst)
    begin
      if (rst) begin
        axi_awready      <= 1'b0;
        axi_awv_awr_flag <= 1'b0;
        axi_awvalid_int  <= 1'b0;
      end else begin    
        // TODO when both read and write address is valid, process read first
        if (~axi_awvalid_int && ~axi_awready && s_axi_awvalid && ~axi_awv_awr_flag && ~s_axi_arvalid && ~axi_rqvalid && pgen_axbr_rdy) begin 
          // slave is ready to accept an address and associated control signals         
          //axi_awready       <= 1'b1;
          axi_awv_awr_flag  <= 1'b1; 
          axi_awvalid_int   <= 1'b1;
          // used for generation of bresp() and bvalid
        end else if (s_axi_wlast && axi_wready && axi_awv_awr_flag) begin
          // preparing to accept next address after current write burst tx completion         
          axi_awv_awr_flag  <= 1'b0;
        end else if (~axi_awready && axi_awvalid_int && !axi_awv_awr_flag && pgen_axbr_rdy) begin
          axi_awready       <= 1'b1;  
        end else if(axi_awready) begin 
          axi_awvalid_int <= 1'b0;
          axi_awready     <= 1'b0;
        end else begin
          axi_awready     <= 1'b0;
        end
      end 
    end 

  // Implement axi_awaddr latching
  // This process is used to latch the address when both 
  // s_axi_awvalid and s_axi_wvalid are valid. 

  always @(posedge clk, posedge rst)
  begin
    if (rst) begin
      axi_awaddr     <= 0;
      axi_awlen_cntr <= 0;
      axi_awburst    <= 0;
      axi_awlen      <= 0;
    end else begin    
      if (~axi_awvalid_int && !axi_awready && s_axi_awvalid && !axi_awv_awr_flag && ~s_axi_arvalid && ~axi_rqvalid && pgen_axbr_rdy) begin  

        // address latching 
         axi_awaddr    <= s_axi_awaddr[AXI_ADDR_WIDTH - 1:0];  
         axi_awburst   <= s_axi_awburst; 
         axi_awlen     <= s_axi_awlen;     
        // start address of transfer
        axi_awlen_cntr <= 0;
      end else if((axi_awlen_cntr <= axi_awlen) && axi_wready && s_axi_wvalid && pgen_axbr_rdy) begin
            axi_awlen_cntr <= axi_awlen_cntr + 1;

            // TODO remove other burst modes
            case (axi_awburst)
              2'b00: // fixed burst
              // The write address for all the beats in the transaction are fixed
                begin
                  axi_awaddr <= axi_awaddr;          
                  //for awsize = 4 bytes (010)
                end   
              2'b01: //incremental burst
              // The write address for all the beats in the transaction are increments by awsize
                begin
                  axi_awaddr[AXI_ADDR_WIDTH-1:ADDR_LSB] <= axi_awaddr[AXI_ADDR_WIDTH-1:ADDR_LSB] + 1;
                  //awaddr aligned to 4 byte boundary
                  axi_awaddr[ADDR_LSB-1:0] <= {ADDR_LSB{1'b0}};   
                  //for awsize = 4 bytes (010)
                end   
              2'b10: //Wrapping burst
              // The write address wraps when the address reaches wrap boundary 
                if (aw_wrap_en)
                  begin
                    axi_awaddr <= (axi_awaddr - aw_wrap_size); 
                  end
                else 
                  begin
                    axi_awaddr[AXI_ADDR_WIDTH-1:ADDR_LSB] <= axi_awaddr[AXI_ADDR_WIDTH-1:ADDR_LSB] + 1;
                    axi_awaddr[ADDR_LSB-1:0]  <= {ADDR_LSB{1'b0}}; 
                  end                      
              default: //reserved (incremental burst for example)
                begin
                  axi_awaddr <= axi_awaddr[AXI_ADDR_WIDTH-1:ADDR_LSB] + 1;
                  //for awsize = 4 bytes (010)
                end
            endcase              
          end
      end 
  end       

  // ================================ Write Date Channel ===============================
  // Implement axi_wready generation
  // axi_wready is asserted for one clk clock cycle when both
  // s_axi_awvalid and s_axi_wvalid are asserted. axi_wready is 
  // de-asserted when reset is low. 

  //always @(posedge clk, posedge rst)
  //begin
  //  if (rst) begin
  //      axi_wready <= 1'b0;
  //    end 
  //  else
  //    begin    
  //      if ( ~axi_wready && s_axi_wvalid && axi_awv_awr_flag && pgen_axbr_rdy)
  //        begin
  //          // slave can accept the write data
  //          axi_wready <= 1'b1;
  //      end else if (s_axi_wlast && axi_wready) begin
  //      //else if (~axi_awv_awr_flag)
  //        axi_wready <= 1'b0;
  //      end
  //  end 
  //end       
  assign axi_wready =  s_axi_wvalid && axi_awv_awr_flag && pgen_axbr_rdy;
  // ============================== Write Response Channel =============================
  // Implement write response logic generation

  // The write response and response valid signals are asserted by the slave 
  // when axi_wready, s_axi_wvalid, axi_wready and s_axi_wvalid are asserted.  
  // This marks the acceptance of address and indicates the status of 
  // write transaction.

    // BRESP
  // 0b00 : OKAY (Normal Access Success)
  // 0b01 : EXOKEAY (Exclusive Access Success)
  // 0b10 : SLVERR (Slave Error)
  // 0b11 : DECERR (Decoder Error)
  always @(posedge clk, posedge rst)
  begin
    if (rst) begin
        axi_bvalid <= 0;
        axi_bresp  <= 2'b0;
        // axi_buser  <= 0; // Currently, not used. 
    end else begin          
        if (axi_awready && ~axi_bvalid/*axi_awv_awr_flag && axi_wready && s_axi_wvalid && ~axi_bvalid && s_axi_wlast*/) begin
            axi_bvalid <= 1'b1;
            axi_bresp  <= 2'b0; 
            // 'OKAY' response 
        end else begin
          if (s_axi_bready && axi_bvalid) begin 
            //check if bready is asserted while bvalid is high) 
            //(there is a possibility that bready is always asserted high)            
            axi_bvalid <= 1'b0; 
          end  
        end
      end
   end   

  // ================================ Pack axbr_pgen_pkt ===============================
  
  wire         is_PIM_result;
  wire [255:0] PIM_result_to_DRAM;

  always_comb
  begin
    if (axi_rqvalid == 1'b1) begin
      axbr_pgen_pkt.is_rd = 1'b1;
      axbr_pgen_pkt.addr  = axi_rqaddr;
      axbr_pgen_pkt.data  = '{default:0};
      axbr_pgen_pkt.mask  = '{default:0};
      axbr_pgen_pkt_valid = 1'b1;
    end
    else if (s_axi_wvalid == 1'b1) begin
      axbr_pgen_pkt.is_rd = 1'b0;
      axbr_pgen_pkt.addr  = axi_awaddr;
      //axbr_pgen_pkt.data  = s_axi_wdata;
      axbr_pgen_pkt.data  = is_PIM_result ? PIM_result_to_DRAM : s_axi_wdata;
      for ( int i = 0; i < 16; i++)
      begin
        axbr_pgen_pkt.mask[i] = s_axi_wstrb[2*i] | s_axi_wstrb[2*i+1];
      end
      if (s_axi_wstrb == 0) begin
        axbr_pgen_pkt_valid = 1'b0;
      end
      else begin
        axbr_pgen_pkt_valid = axi_wready && pgen_axbr_rdy;
      end
    end
    else begin
      axbr_pgen_pkt = '{default:0};
      axbr_pgen_pkt_valid  = 1'b0;
    end
  end

`ifdef SUPPORT_INDIRECT_ADDRESSING
  wire           w_PIM_dev_working;
  wire           w_HPC_clear;

  (* keep = "true", mark_debug = "true" *)wire [31:0]    w_args_reg_A;
  (* keep = "true", mark_debug = "true" *)wire [31:0]    w_args_reg_B;
  (* keep = "true", mark_debug = "true" *)wire [31:0]    w_args_reg_C;
`endif
  // ============================= Read Response Forwarding ============================

  assign axi_rvalid = orde_axbr_pkt_valid;
  assign axi_rdata = orde_axbr_pkt.data;



  // generate axi_rlast signal
  assign axi_rlast = rd_en;

  always @(posedge clk, posedge rst)
  begin
    if (rst)
    begin
      rd_len_cntr <= 0;
    end
    else if (orde_axbr_pkt_valid && axbr_orde_rdy)
    begin 
      rd_len_cntr <= (rd_len_cntr == arlen_out) ? 0 : (rd_len_cntr + 1'b1);
    end
  end

  assign wr_en = s_axi_arvalid && axi_arready;
  assign rd_en = (rd_len_cntr == arlen_out) && orde_axbr_pkt_valid && axbr_orde_rdy && s_axi_rready && !fifo_empty;


  // incoming request counter
  always @(posedge clk, posedge rst)
  begin
    if (rst) begin
      req_in_cntr <= 0;
    end else begin          
        if (s_axi_arvalid && axi_arready) begin
            req_in_cntr <= req_in_cntr + 1;
        end
      end
   end   

    // out going request counter
    always @(posedge clk, posedge rst)
    begin
    if (rst) begin
      req_out_cntr <= 0;
    end else begin          
        if ( axi_rqvalid ) begin
            req_out_cntr <= req_out_cntr + 1;
        end 
      end
    end

  xpm_fifo_sync #(
          .DOUT_RESET_VALUE    ("0"),
          .ECC_MODE            ("no_ecc"),
          .FIFO_MEMORY_TYPE    ("distributed"),
          .FIFO_READ_LATENCY   (0),
          .FIFO_WRITE_DEPTH    (32),
          .FULL_RESET_VALUE    (0),
          .PROG_EMPTY_THRESH   (5),
          .PROG_FULL_THRESH    (27),
          .RD_DATA_COUNT_WIDTH (5),
          .READ_DATA_WIDTH     (8), // burst length (0~255)
          .READ_MODE           ("fwft"),
          .SIM_ASSERT_CHK      (0),
          .USE_ADV_FEATURES    ("0002"),
          .WAKEUP_TIME         (0),
          .WR_DATA_COUNT_WIDTH (5),
          .WRITE_DATA_WIDTH    (8))
  rresp_que (
          .almost_empty        (),
          .almost_full         (),
          .data_valid          (),
          .dbiterr             (),
          .dout                (arlen_out),
          .empty               (fifo_empty),
          .full                (fifo_full),
          .overflow            (),
          .prog_empty          (),
          .prog_full           (prog_full),
          .rd_data_count       (),
          .rd_rst_busy         (),
          .sbiterr             (),
          .underflow           (),
          .wr_ack              (),
          .wr_data_count       (),
          .wr_rst_busy         (),
          .din                 (s_axi_arlen),
          .injectdbiterr       (0),
          .injectsbiterr       (0),
          .rd_en               (rd_en),
          .rst                 (rst),
          .sleep               (0),
          .wr_clk              (clk),
          .wr_en               (wr_en));

  // ================================== Initialization =================================
  initial begin
    axi_arready      = 1'b0;
    // axi_rresp        = 0;
    // axi_rlast        = 1'b0;
    axi_rqaddr       = 0;
    axi_rqlen_cntr   = 0;
    axi_rqlen        = 0;
    axi_rqvalid      = 0;
    axi_awready      = 1'b0;
    axi_awv_awr_flag = 1'b0;
    axi_awaddr       = 0;
    axi_awlen_cntr   = 0;
    axi_awburst      = 0;
    axi_awlen        = 0;
    axi_wready       = 1'b0;
    axi_bvalid       = 0;
    axi_bresp        = 2'b0;
  end

// ======================================================================================================================================
// ======================================================================================================================================
// ======================================================================================================================================
// ======================================================================================================================================
// ======================================================================================================================================
// ======================================================================================================================================
// ======================================================================================================================================
// ======================================================================================================================================

//PIM device porting
    wire         read_en;
    wire         write_en;
    wire [31:0]  addr_in;
    wire [255:0] data_in;
    wire         rd_data_valid;
    wire [255:0] data_bus_from_memory;

    assign read_en              = (axi_rqvalid == 1'b1);
    assign write_en             = (s_axi_wvalid && s_axi_wready);
    assign addr_in              = read_en ? axi_rqaddr : (write_en ? axi_awaddr : 32'b0);
    assign data_in              = write_en ? s_axi_wdata : 256'b0;
    assign rd_data_valid        = s_axi_rvalid && s_axi_rready;
    assign data_bus_from_memory = rd_data_valid ? axi_rdata : 256'b0;


    (* keep = "true", mark_debug = "true" *)reg [255:0] data_in_debug;

    always @(posedge clk, posedge rst) begin
      if (rst)                data_in_debug <= 'b0;
      else                    data_in_debug <= data_in;
    end

    (* keep = "true", mark_debug = "true" *) reg         read_en_debug;
    (* keep = "true", mark_debug = "true" *) reg         write_en_debug;
    (* keep = "true", mark_debug = "true" *) reg [31:0]  addr_in_debug;
    (* keep = "true", mark_debug = "true" *) reg         rd_data_valid_debug;
    (* keep = "true", mark_debug = "true" *) reg [255:0] data_bus_from_memory_debug;

    always @(posedge clk, posedge rst) begin
      if (rst) begin
                    read_en_debug <= 'b0;
                    write_en_debug <= 'b0;
                    addr_in_debug <= 'b0;
                    data_in_debug <= 'b0;
                    rd_data_valid_debug <= 'b0;
                    data_bus_from_memory_debug <= 'b0;
      end 
      else begin    
                    read_en_debug <= read_en;
                    write_en_debug <= write_en;
                    addr_in_debug <= addr_in;
                    data_in_debug <= data_in;
                    rd_data_valid_debug <= rd_data_valid;
                    data_bus_from_memory_debug <= data_bus_from_memory;
      end
    end



    Device_top U0_DEVICE 
    (
        .clk                                  (clk                      ),
        .rst_x                                (!rst                     ),
    
        //input
        .read_en                              (read_en                  ),
        .write_en                             (write_en                 ),
        .addr_in                              (addr_in                  ),
        // .data_in                              (data_in                  ),
    
        .rd_data_valid                        (rd_data_valid),
        .data_bus_from_memory                 (data_bus_from_memory     ),

        `ifdef SUPPORT_INDIRECT_ADDRESSING
            // .i_indirect_addr                   (w_indirect_addr),
            // .i_indirect_addr_valid             (bus_is_read_descr_r),
            .o_PIM_dev_working                 (w_PIM_dev_working),
            .o_HPC_clear                       (w_HPC_clear),
            // .o_desc_range_valid                (w_desc_range_valid),
        `endif


        //PIM result for DRAM write (output)
        .is_PIM_result                        (is_PIM_result            ),
        .PIM_result_to_DRAM                   (PIM_result_to_DRAM       )
    );

`ifdef SUPPORT_INDIRECT_ADDRESSING
  PIM_indirect_address U0_INDIRECT_ADDRESSOR
  (
    .clk                                     (clk),
    .rst_x                                   (!rst),

    .i_write_en                              (write_en), 
    .i_addr                                  (addr_in),
    .i_write_data                            (data_in),

    .i_PIM_dev_working                       (w_PIM_dev_working),
    .i_HPC_clear                             (w_HPC_clear),

    .o_args_reg_A                            (w_args_reg_A),
    .o_args_reg_B                            (w_args_reg_B),
    .o_args_reg_C                            (w_args_reg_C)
  );
`endif

endmodule
