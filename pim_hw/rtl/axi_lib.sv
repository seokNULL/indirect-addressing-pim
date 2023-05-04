`timescale 1ps / 1ps

package axi_lib;
  parameter int AXI_ID_WIDTH     = 2;                   // Width of ID for for write address, write data, read address and read data
  parameter int AXI_MASK_WIDTH   = 16;
  parameter int AXI_DATA_WIDTH   = 256;                 // Width of S_AXI data bus   
  parameter int AXI_ADDR_WIDTH   = 32;                  // Width of S_AXI address bus
  parameter int AXI_AWUSER_WIDTH = 0;                   // Width of optional user defined signal in write address channel
  parameter int AXI_ARUSER_WIDTH = 0;                   // Width of optional user defined signal in read address channel
  parameter int AXI_WUSER_WIDTH  = 0;                   // Width of optional user defined signal in write data channel
  parameter int AXI_RUSER_WIDTH  = 0;                   // Width of optional user defined signal in read data channel
  parameter int AXI_BUSER_WIDTH  = 0;                   // Width of optional user defined signal in write response channel

  parameter int ADDR_LSB = $clog2(AXI_DATA_WIDTH) - 3;  //

  parameter int RD_DATA_DEPTH = 64;

  // AXI-DMA Bridge type
  typedef struct packed {
    logic is_rd;                                        // Flag indicating that transaction is read transaction; must be 0 for write transactions
    logic [AXI_ADDR_WIDTH-1:0] addr;
    logic [AXI_MASK_WIDTH-1:0] mask;
    logic [AXI_DATA_WIDTH-1:0] data;
  } trx_t;

endpackage
