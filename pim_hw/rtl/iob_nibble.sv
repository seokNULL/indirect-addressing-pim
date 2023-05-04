`timescale 1ps/1ps

//  Type  Function
//  ----------------------------
//  0 :   N/A
//  1 :   Single ended output
//  2 :   Single ended input
//  3 :   Single ended bi-directional IO
//  4 :   N/A
//  5 :   Differential output
//  6 :   Diffrential input
//  7 :   Diffrential bi-directional IO

module iob_nibble #(
  parameter [8:0]           NIBBLE_EN       = {9{1'b1}},
  parameter [8:0][5:0][2:0] IOBTYPE         = {9{3'd0, 3'd1, 3'd2, 3'd3, 3'd3, 3'd2}},
  parameter [8:0]           USE_VREF        = {9{1'b1}},
  parameter                 USE_DYN_DCI     = "TRUE",
  parameter                 USE_IBUFDISABLE = "FALSE")
(
  input  logic [8:0][5:0] tx_o,            // TX output data
  input  logic [8:0][5:0] tx_t_out,        // TX tristate control data
  output logic [8:0][5:0] rx_d,            // RX input data
  input  logic [8:0][5:0] ib_pin,          // Pin interface for input buffers
  output logic [8:0][5:0] ob_pin,          // Pin interface for output buffers
  inout  tri   [8:0][5:0] iob_pin,         // Pin interface for bidirectional buffers (Nibble 8)
  input  logic [8:0][5:0] dyn_dci,         // Dynamic DCI from XPHY
  input  logic [8:0][5:0] ibuf_disable);   // IBUF disable from XPHY

  // ====================== XPIO_VREF Instantiation ======================
  wire [8:0] vref;
  genvar i, ii;
  generate
    for (i=0; i<9; i++) begin : xphyVref
      if (NIBBLE_EN[i] == 1'b1 && USE_VREF[i] == 1'b1)
        XPIO_VREF #(
          .ISTANDARD ("POD12"),
          .VREF_NIB  ("VREF_FABRIC"))
        xpio_vref (
          .FABRIC_VREF_TUNE (10'b0101100110),  // Setting VREF to 70% of VCCO (in Versal VREF must actually be set to 0.5 of the desired value, so the programmed value here is 35%)
          .VREF             (vref[i]));
    end
  endgenerate
  
  // ========================= IOB Instantiation =========================
  generate
    for (i=0; i<9; i++) begin : IoNibble
      if (NIBBLE_EN[i]) begin
        for (ii=0; ii<6; ii++) begin : NibbleSlice
          case (IOBTYPE[i][ii])
            // Single Ended Output
            3'd1 : begin
              OBUF OBUF(
                .I (tx_o   [i][ii]),
                .O (ob_pin [i][ii]));
              assign rx_d[i][ii] = '0;
            end
            // Single Ended Input
            3'd2 : begin
              IBUFE3 #(
                .SIM_DEVICE      ("VERSAL_AI_CORE"),
                .SIM_INPUT_BUFFER_OFFSET (0),
                .USE_IBUFDISABLE (USE_IBUFDISABLE))
              IBUF (
                .I               (ib_pin       [i][ii]),
                .IBUFDISABLE     (ibuf_disable [i][ii]),
                .O               (rx_d         [i][ii]),
                .VREF            (vref         [i]),
                .OSC_EN          (1'b0),
                .OSC             (4'b0000));
            end
            // Single Ended IO
            3'd3 : begin
              IOBUFE3 #(
                .SIM_DEVICE      ("VERSAL_AI_CORE"),
                .SIM_INPUT_BUFFER_OFFSET (0),
                .USE_IBUFDISABLE (USE_IBUFDISABLE))
              IOBUF (
                .I               (tx_o         [i][ii]),
                .IBUFDISABLE     (ibuf_disable [i][ii]),
                .T               (tx_t_out     [i][ii]),
                .O               (rx_d         [i][ii]),
                .IO              (iob_pin      [i][ii]),
                .VREF            (vref         [i]),
                .DCITERMDISABLE  ((USE_DYN_DCI == "TRUE") ? dyn_dci[i][ii] : 1'b0),
                .OSC_EN          (1'b0),
                .OSC             (4'b0000));
            end
            // Differential Output
            3'd5 : begin
              if (ii%2 == 0) begin   // Generate for even nibble slices only
                OBUFDS OBUFDS (
                  .I  (tx_o   [i][ii]),
                  .O  (ob_pin [i][ii]),
                  .OB (ob_pin [i][ii+1]));
                assign rx_d[i][ii] = '0;
              end
            end
            // Differential Input
            3'd6 : begin
              if (ii%2 == 0) begin   // Generate for even nibble slices only
                IBUFDS IBUFDS (
                  .O  (rx_d   [i][ii]),
                  .I  (ib_pin [i][ii]),
                  .IB (ib_pin [i][ii+1]));
              end
            end
            // Differential IO
            3'd7 : begin 
              if (ii%2 == 0) begin   // Generate for even nibble slices only
                IOBUFDS IO_BUFDS (
                  .I   (tx_o     [i][ii]),
                  .T   (tx_t_out [i][ii]),
                  .O   (rx_d     [i][ii]),
                  .IO  (iob_pin  [i][ii]),
                  .IOB (iob_pin  [i][ii+1]));
              end
            end
            default: begin
              assign rx_d[i][ii] = '0;
              // No IO buffer!
            end
          endcase
        end
      end
    end
  endgenerate

endmodule


