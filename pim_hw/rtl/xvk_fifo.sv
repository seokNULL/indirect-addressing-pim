`timescale 1ps / 1ps

module xvk_fifo #(parameter 
  WIDTH     = 16,       // Data width of the FIFO
  DEPTH     = 32,       // Number of entries in the FIFO
  PROG_FULL = 30,       // Programmable full threshold value
  RAM_TYPE  = "BLOCK")  // Type of Xilinx memory used for the FIFO: DISTRIBUTED, BLOCK, ULTRA, MIXED
(
  input  logic clk, rst,
  input  logic wr_en, 
  input  logic rd_en,
  input  logic [WIDTH-1:0] din,
  output logic full,
  output logic empty,
  output logic last,
  output logic prog_full,
  output logic [WIDTH-1:0] dout);

  // ================================ Local Declarations ================================
  logic [WIDTH-1:0] dout_ram;                // Output from the main FIFO's RAM
  logic [WIDTH-1:0] dout_early;              // Temporary buffer that provides first-word-fall-through functionality
  logic auto_rd_en;                          // Used for implementing first-word-fall-through functionality
  logic [$clog2(DEPTH)-1:0] wr_ptr, rd_ptr;  // Read and Write addresses for RAM
  logic [$clog2(DEPTH):0] taken_slot_cnt;    // Counter for occupied memory slots
  logic pass_early, pass_early_nxt;          // Flag for selecting dout_early as the FIFO dout
  logic wr;                                  // Memory array write enable
  logic rd;                                  // Memory array read enable

  // ==================================== FIFO Memory ===================================
  generate
    if (RAM_TYPE == "DISTRIBUTED") begin
      (* RAM_STYLE = "DISTRIBUTED" *) logic [WIDTH-1:0] ram_distr [DEPTH-1:0];
      always @(posedge clk)
        if (wr) ram_distr[wr_ptr] <= din;

      always @(posedge clk)
        if      (rst) dout_ram <= 0;
        else if (rd)  dout_ram <= ram_distr[rd_ptr];

      initial ram_distr = '{DEPTH{0}};
    end

    else if (RAM_TYPE == "BLOCK") begin
      (* RAM_STYLE = "BLOCK" *)       logic [WIDTH-1:0] ram_block [DEPTH-1:0];
      always @(posedge clk)
        if (wr) ram_block[wr_ptr] <= din;

      always @(posedge clk)
        if      (rst) dout_ram <= 0;
        else if (rd)  dout_ram <= ram_block[rd_ptr];

      initial ram_block = '{DEPTH{0}};
    end

    else if (RAM_TYPE == "ULTRA") begin
      (* RAM_STYLE = "ULTRA" *)       logic [WIDTH-1:0] ram_ultra [DEPTH-1:0];
      always @(posedge clk)
        if (wr) ram_ultra[wr_ptr] <= din;

      always @(posedge clk)
        if      (rst) dout_ram <= 0;
        else if (rd)  dout_ram <= ram_ultra[rd_ptr];

      initial ram_ultra = '{DEPTH{0}};
    end

    // !! NOTE !! In MIXED type, 36 bits of data are stored in 512x36 BRAM primitives, the rest is stored in LUTRAM.
    // This type is recommended for shallow FIFOs (DEPTH < 100) with the WIDTH parameter in the range 37-54 bits.
    else if (RAM_TYPE == "MIXED") begin
      (* RAM_STYLE = "DISTRIBUTED" *) logic [WIDTH-36-1:0] ram_distr [DEPTH-1:0];
      (* RAM_STYLE = "BLOCK" *)       logic [35:0]         ram_block [DEPTH-1:0];
      always @(posedge clk)
        if (wr) begin
          ram_block[wr_ptr] <= din[35:0];
          ram_distr[wr_ptr] <= din[WIDTH-1:36];
        end

      always @(posedge clk)
        if      (rst) dout_ram <= 0;
        else if (rd)  dout_ram <= {ram_distr[rd_ptr], ram_block[rd_ptr]};

      initial begin
        ram_block = '{DEPTH{0}};
        ram_distr = '{DEPTH{0}};
      end
    end
  endgenerate

  assign dout = pass_early ? dout_early : dout_ram;

  assign wr = !full && wr_en;
  assign rd = (!(wr_ptr==rd_ptr)||full) && (rd_en||auto_rd_en);  // Don't read if pointers are equal unless write pointer made a full circle (FIFO is full)
  
  always @(posedge clk, posedge rst)
    if (rst) auto_rd_en <= 0;
    else     auto_rd_en <= (pass_early_nxt && wr_en);            // Read once with the first wr_en

  // ======================================= Flags ======================================
  always @(posedge clk, posedge rst)
    if      (rst)          taken_slot_cnt <= 0;
    else if (wr_en||rd_en) taken_slot_cnt <= taken_slot_cnt + (~full & wr_en) - (~empty & rd_en);

  assign empty     = taken_slot_cnt == 0;
  assign last      = taken_slot_cnt == 1;
  assign full      = taken_slot_cnt[$clog2(DEPTH)];              // Use "taken_slot_cnt == DEPTH" if DEPTH is not expressed as a power of 2
  assign prog_full = taken_slot_cnt >= PROG_FULL;

  // ===================================== Pointers =====================================
  always @(posedge clk, posedge rst)
    if (rst) begin
      wr_ptr <= 0;
      rd_ptr <= 0;
    end
    else begin
      wr_ptr <= wr_ptr + wr;
      rd_ptr <= rd_ptr + rd;
    end

  always @(posedge clk, posedge rst)
    if      (rst)   dout_early <= 0;
    else if (wr_en) dout_early <= din;

  assign pass_early_nxt = empty || (last && wr_en && rd_en);     // Last entry will always be prestored in the out reg, so nothing left in the mem when slot_cnt is 1, need to pass dout_early

  always @(posedge clk, posedge rst)
    if (rst) pass_early <= 1;
    else     pass_early <= pass_early_nxt;

  // ================================== Initialization ==================================
  initial begin
    dout_ram       = 0;
    dout_early     = 0;
    auto_rd_en     = 0;
    taken_slot_cnt = 0;
    pass_early     = 0;
    wr_ptr         = 0;
    rd_ptr         = 0;
  end

endmodule

