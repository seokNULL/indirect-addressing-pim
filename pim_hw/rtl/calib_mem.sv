`timescale 1ps / 1ps

module calib_mem (
  input  logic clk,
  input  logic page_we,              // Write enable for din_array
  input  logic dword_we,             // Write enable for din_dowrd
  input  logic [3:0]   page_addr,    // Selects an page from the array
  input  logic [3:0]   dword_addr,   // Selects a dword from the page
  input  logic [31:0]  dword_din,    // A single dword input
  output logic [31:0]  dword_dout,
  input  logic [287:0] page_din,     // Parallel input to the entire page
  output logic [287:0] page_dout);

  // ============================== Local Signals ==============================
  logic [8:0][31:0] mem [5:0];       // Main memory: 6 pages, 9 dwords per page
  logic [8:0][31:0] mem_din;
  logic [8:0] mem_we [5:0];

  always_comb
    for (int i=0; i<9; i++) begin
      mem_din[i] = page_we ? page_din[32*i+:32] : dword_din;
    end

  always_comb
    for (int k=0; k<6; k++) begin
      mem_we[k] = 0;
      if (k == page_addr) begin
        for (int i=0; i<9; i++) begin
          mem_we[k][i] = ((i == dword_addr) && dword_we) || page_we;
        end
      end
    end

  always @(posedge clk)
    for (int k=0; k<6; k++) begin
      for (int i=0; i<9; i++) begin
        if (mem_we[k][i]) mem[k][i] <= mem_din[i];
      end
    end

  always @(posedge clk) page_dout  <= mem[page_addr];
  always @(posedge clk) dword_dout <= mem[page_addr][dword_addr];

  initial begin
    mem        = '{6{0}};
    page_dout  = 0;
    dword_dout = 0;
  end

endmodule
