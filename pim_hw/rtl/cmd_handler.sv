`timescale 1ps / 1ps

module cmd_handler (
  input  logic clk,
  input  logic rst,
  // Configuration Register
  input  logic [$bits(cfr_mode_t)-1:0] cfr_mode_p,
  // Input Packet
  input  pkt_t pkt,
  input  cmd_t cmd,
  input  logic pkt_valid,
  // Initializer/Calibration Interface
  input  logic ck_en,
  input  logic wck_en, 
  output logic intf_rdy,
  // PHY Interface
  output logic [7:0] intf_ck_t,
  output logic [7:0] intf_wck_t,
  output logic [7:0] intf_cke_n,
  output logic [7:0] intf_ca [9:0],
  output logic [7:0] intf_cabi_n);

  // ====================================== Local Signals =======================================
  // Configuration Register
  cfr_mode_t  cfr_mode;                     // Mode Register parameter array
  // Command-Address Interface Signals
  logic [9:0] ca_r, ca_f;                   // CA states on rising and falling CK edges
  logic [9:0] ca_r_prv, ca_f_prv;           // CA states from a previous clock cycle
  logic       cabi_n;                       // Bit replicated on the CABI_n line
  // Input Packet Signals
  logic [COL_ADDR_WIDTH-1:0] pkt_col_addr;  // Column address extracted from the packet
  logic [BK_ADDR_WIDTH-1:0]  pkt_bk_addr;   // Bank address extracted from the packet
  logic [ROW_ADDR_WIDTH-1:0] pkt_row_addr;  // Row address extracted from the packet
  logic [MASK_WIDTH-1:0]     pkt_mask;      // Packet data mask used with WDM commands

  // ================================== Configuration Register ==================================
  assign cfr_mode = cfr_mode_t'(cfr_mode_p);

  // ========================================= Unpacking ========================================
  assign pkt_col_addr = pkt.col_addr;
  assign pkt_bk_addr  = pkt.bk_addr;
  assign pkt_row_addr = pkt.row_addr;

  always @(posedge clk, posedge rst)
    if      (rst)                     pkt_mask <= 0;
    // else if (pkt_valid && cmd == WDM) pkt_mask <= {<<{~pkt.mask}};  // Reversing bit order, since data is passed to DRAM from LSB to MSB, but mask starts from MSB
    else if (pkt_valid && cmd == WDM) pkt_mask <= ~pkt.mask;  // Reversing bit order, since data is passed to DRAM from LSB to MSB, but mask starts from MSB
    else                              pkt_mask <= 0;          // Constantly resetting to regular NOP1 (easier to read waveforms like this)

  // ============================== TX Serializer Input Generation ==============================
  assign intf_rdy = 1'b1;  // This bit will be used to support masked operations, such as WSM, WDM

  // Interface Clock Generation
  always @(posedge clk, posedge rst)
    if (rst) begin
      intf_ck_t  <= 8'b0000_0000;
      intf_wck_t <= 8'b0000_0000;
    end
    else begin
      intf_ck_t  <= ck_en  ? 8'b0000_1111 : 8'b0000_0000;
      intf_wck_t <= wck_en ? 8'b0101_0101 : 8'b0000_0000;
    end
  
  always @(posedge clk, posedge rst)
    if (rst) begin
      intf_ca[0]  <= 8'h00;
      intf_ca[1]  <= 8'h00;
      intf_ca[2]  <= 8'h00;
      intf_ca[3]  <= 8'h00;
      intf_ca[4]  <= 8'h00;
      intf_ca[5]  <= 8'h00;
      intf_ca[6]  <= 8'h00;
      intf_ca[7]  <= 8'h00;
      intf_ca[8]  <= 8'h00;
      intf_ca[9]  <= 8'h00;
      intf_cabi_n <= 8'hFF;
    end
    else begin
      intf_ca[0]  <= {{2{ca_r[0]}}, {4{ca_f_prv[0]}}, {2{ca_r_prv[0]}}};
      intf_ca[1]  <= {{2{ca_r[1]}}, {4{ca_f_prv[1]}}, {2{ca_r_prv[1]}}};
      intf_ca[2]  <= {{2{ca_r[2]}}, {4{ca_f_prv[2]}}, {2{ca_r_prv[2]}}};
      intf_ca[3]  <= {{2{ca_r[3]}}, {4{ca_f_prv[3]}}, {2{ca_r_prv[3]}}};
      intf_ca[4]  <= {{2{ca_r[4]}}, {4{ca_f_prv[4]}}, {2{ca_r_prv[4]}}};
      intf_ca[5]  <= {{2{ca_r[5]}}, {4{ca_f_prv[5]}}, {2{ca_r_prv[5]}}};
      intf_ca[6]  <= {{2{ca_r[6]}}, {4{ca_f_prv[6]}}, {2{ca_r_prv[6]}}};
      intf_ca[7]  <= {{2{ca_r[7]}}, {4{ca_f_prv[7]}}, {2{ca_r_prv[7]}}};
      intf_ca[8]  <= {{2{ca_r[8]}}, {4{ca_f_prv[8]}}, {2{ca_r_prv[8]}}};
      intf_ca[9]  <= {{2{ca_r[9]}}, {4{ca_f_prv[9]}}, {2{ca_r_prv[9]}}};
      intf_cabi_n <= {8{cabi_n }};
    end

  // ================================ Command-to-CA[9:0] Mapping ================================
  always @(posedge clk, posedge rst)
    if (rst) begin
      ca_r_prv = 10'b00_0000_0000;
      ca_f_prv = 10'b00_0000_0000;
    end
    else begin
      ca_r_prv = ca_r;
      ca_f_prv = ca_f;
    end

  initial begin
    ca_r_prv = 0;
    ca_f_prv = 0;
  end

  always_comb begin
    // ca_r = {2'b11, pkt_mask[8+:4], pkt_mask[12+:4]/*pkt_mask[15:8]*/};  // Applying data mask as NOP after WDM (normally, pkt_mask is reset to zero)
    // ca_f = {2'b11, pkt_mask[0+:4], pkt_mask[4+:4] /*pkt_mask[7:0]*/ };
    ca_r = {2'b11, pkt_mask[7:0]};  // Applying data mask as NOP after WDM (normally, pkt_mask is reset to zero)
    ca_f = {2'b11, pkt_mask[15:8]};

    if (pkt_valid) begin
      case (cmd)
        NOP1 : begin
          ca_r = 10'b11_0000_0000;
          ca_f = 10'b11_0000_0000;
        end

        WCK2CK : begin    // WCK2CK is not a real command, so just applying NOP values
          ca_r = 10'b11_0000_0000;
          ca_f = 10'b11_0000_0000;
        end

        ACT : begin
          ca_r = {2'b00, pkt_bk_addr[3:0], pkt_row_addr[3:0]};
          ca_f = {pkt_row_addr[13:4]};
        end

        PREPB : begin
          ca_r = {2'b10, pkt_bk_addr[3:0], 4'b0000};
          ca_f = 10'b00_0000_0000;
        end

        PREAB : begin
          ca_r = 10'b10_0000_0000;
          ca_f = 10'b00_0001_0000;
        end

        RD : begin
          ca_r = {2'b11, pkt_bk_addr[3:0], pkt_col_addr[3:0]};
          ca_f = {2'b01, 6'b00_0010, pkt_col_addr[5:4]};
        end

        WOM : begin
          ca_r = {2'b11, pkt_bk_addr[3:0], pkt_col_addr[3:0]};
          ca_f = {2'b00, 6'b00_0010, pkt_col_addr[5:4]};
        end

        WDM : begin
          ca_r = {2'b11, pkt_bk_addr[3:0], pkt_col_addr[3:0]};
          ca_f = {2'b00, 6'b10_0010, pkt_col_addr[5:4]};
        end

        REFPB : begin
          ca_r = {2'b10, pkt_bk_addr[3:0], 4'b0000};
          ca_f = 10'b01_0000_0000;
        end

        REFAB : begin
          ca_r = 10'b10_0000_0000;
          ca_f = 10'b01_0001_0000;
        end

        MRS : begin
          ca_r = {2'b10, pkt_bk_addr[3:0], pkt_row_addr[3:0]};
          ca_f = {2'b10, pkt_row_addr[11:4]};
        end

        MRS_TEMP : begin
          ca_r = {2'b10, pkt_bk_addr[3:0], pkt_row_addr[3:0]};
          ca_f = {2'b10, pkt_row_addr[11:4]};
        end

        LDFF : begin
          ca_r = {2'b11, pkt_bk_addr[3:0], pkt_row_addr[3:0]};
          ca_f = {4'b0110, pkt_row_addr[9:4]};
        end

        WRTR : begin
          ca_r = 10'b11_0000_0000;
          ca_f = 10'b00_1100_1000;
        end

        RDTR : begin
          ca_r = 10'b11_0000_0000;
          ca_f = 10'b01_1100_1000;
        end

        CONF : begin // special CA configuration that is applied during RESET_n deassertion
          ca_r = 10'b000_1_00_00_00;
          ca_f = 10'b000_1_00_00_00;
        end

        // <<< AiM Commands Start Here >>>

        MACSB : begin
          ca_r = {2'b11, pkt_bk_addr[3:0], pkt_col_addr[3:0]};
          ca_f = {2'b01, 6'b0101_10, pkt_col_addr[5:4]};
        end

        RDCP : begin
          ca_r = {2'b11, pkt_bk_addr[3:0], pkt_col_addr[3:0]};
          ca_f = {2'b01, 6'b1111_10, pkt_col_addr[5:4]};
        end

        WRCP : begin
          ca_r = {2'b11, pkt_bk_addr[3:0], pkt_col_addr[3:0]};
          ca_f = {2'b00, 6'b1111_10, pkt_col_addr[5:4]};
        end

        NDME : begin
          ca_r = {2'b10, 4'd13, cfr_mode.RELU_MAX, cfr_mode.BK_BCAST};
          ca_f = {2'b10, 1'b1, cfr_mode.AFM, 4'b0000};
        end

        NDMX : begin
          ca_r = {2'b10, 4'd13, cfr_mode.RELU_MAX, cfr_mode.BK_BCAST};
          ca_f = {2'b10, 1'b0, cfr_mode.AFM, 4'b0000};
        end

        WRGB : begin
          ca_r = {2'b11, 4'b0000, pkt_col_addr[3:0]};
          ca_f = {2'b00, 6'b1101_10, pkt_col_addr[5:4]};
        end

        WRBIAS : begin
          ca_r = {10'b11_0000_0000};
          ca_f = {10'b00_1111_1000};
        end

        RDMAC : begin
          ca_r = {10'b11_0000_0000};
          ca_f = {10'b01_1111_1000};
        end

        RDAF : begin
          ca_r = {10'b11_0000_0000};
          ca_f = {10'b01_1101_1000};
        end

        ACT4 : begin
          ca_r = {2'b01, 2'b00, pkt_bk_addr[1:0], pkt_row_addr[3:0]};
          ca_f = {pkt_row_addr[13:4]};
        end

        ACT16 : begin
          ca_r = {2'b01, 4'b1000, pkt_row_addr[3:0]};
          ca_f = {pkt_row_addr[13:4]};
        end

        ACTAF4 : begin
          ca_r = {4'b0101, pkt_bk_addr[1:0], 6'b00_0000};
          ca_f = {10'b00_0000_0000};
        end

        ACTAF16 : begin
          ca_r = {10'b01_1100_0000};
          ca_f = {10'b00_0000_0000};
        end

        MACAB : begin
          ca_r = {2'b11, 4'b0000, pkt_col_addr[3:0]};
          ca_f = {2'b01, 6'b0111_10, pkt_col_addr[5:4]};
        end

        WRBK : begin
          ca_r = {2'b11, 4'b0000, pkt_col_addr[3:0]};
          ca_f = {2'b00, 6'b1101_10, pkt_col_addr[5:4]};
        end

        EWMUL : begin
          ca_r = {2'b11, pkt_bk_addr[3:0], pkt_col_addr[3:0]};
          ca_f = {2'b01, 6'b0100_10, pkt_col_addr[5:4]};
        end

        AF : begin
          ca_r = {10'b11_0000_0000};
          ca_f = {10'b01_1101_1000};
        end
      endcase
    end
  end

  assign cabi_n = 1'b1;     // CABI_n is unused (temporarily)

  assign intf_cke_n = 1'b0; // Not using it for any commands (added to support CAT in the future)

  initial begin
    intf_ck_t   = 8'h00;
    intf_wck_t  = 8'h00;
    intf_ca[0]  = 8'h00;
    intf_ca[1]  = 8'h00;
    intf_ca[2]  = 8'h00;
    intf_ca[3]  = 8'h00;
    intf_ca[4]  = 8'h00;
    intf_ca[5]  = 8'h00;
    intf_ca[6]  = 8'h00;
    intf_ca[7]  = 8'h00;
    intf_ca[8]  = 8'h00;
    intf_ca[9]  = 8'h00;
    intf_cabi_n = 8'hFF;
    pkt_mask    = 0;
  end

endmodule
