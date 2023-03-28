module testbench;
  
reg                              clk;
reg                              rst_x;
reg                              read_en;
reg                              write_en;
reg  [31:0]                      addr_in;
reg                              rd_data_valid;
reg  [255:0]                     data_bus_from_memory;

wire                             is_PIM_result;
wire [255:0]                     PIM_result_to_DRAM;

//------------------------------------------------------------------------------
// Clock
//------------------------------------------------------------------------------

parameter   FREQ   = 100;
parameter   CKP    = 1000.0/FREQ;

initial  forever #(CKP/2)    clk  = ~clk;
  
initial begin 
  clk  = 1'b1;
end

//------------------------------------------------------------------------------
// Reset
//------------------------------------------------------------------------------

initial begin
  rst_x = 1'b0;

  read_en = 1'b0;
  write_en = 1'b0;
  addr_in = 32'b0;
  rd_data_valid = 1'b0;
  data_bus_from_memory = 256'b0;

  repeat (10) @(posedge clk);
  #(CKP) rst_x = 1'b1;
  $display ("Reset disable... Simulation Start !!! ");

  #(CKP*10);
end

task wait_clocks;
    input integer num_clocks;
    integer cnt_clocks;
    for(cnt_clocks = 0; cnt_clocks < num_clocks; cnt_clocks = cnt_clocks + 1) begin
        @ (posedge clk);
    end
endtask : wait_clocks

initial begin 
  integer i=0;
  wait_clocks(100);

  write_en = 1;
  addr_in = 32'h0000_4000;
  wait_clocks(1);  
  write_en = 0;
  addr_in = 32'h0;
  wait_clocks(4);  


  read_en = 1'b1;
  //descriptor A read
  addr_in = 32'h0080_0000;
  wait_clocks(1);  
  //descriptor B read
  addr_in = 32'h0080_0040;
  wait_clocks(1);
  //descriptor C read
  addr_in = 32'h0080_0080;
  wait_clocks(1);
  read_en = 1'b0;
  addr_in = 32'h0;
  wait_clocks(4);

  rd_data_valid = 1'b1;
  data_bus_from_memory = 256'h0008_51F2_0000_0020_0000_0000_d000_0000_0000_0208_0100_0000_0000_0208_0080_0040;
  wait_clocks(1);
  data_bus_from_memory = 256'h0008_51F4_0000_2000_0000_0000_d000_0000_0000_0208_0100_2000_0000_0208_0080_0080;
  wait_clocks(1);
  data_bus_from_memory = 256'h0008_51F9_0000_0020_0000_0208_0100_4000_0000_0000_d000_0000_0000_0208_0080_00C0;
  wait_clocks(1);
  rd_data_valid = 1'b0;
  data_bus_from_memory = 256'h0;

  wait_clocks(40);

  read_en = 1'b1;
  addr_in = 32'h0100_0000;
  wait_clocks(1);
  read_en = 1'b0;
  addr_in = 32'h0;

  wait_clocks(4);

  read_en = 1'b1;
  for(i=0;i<256;i=i+1) begin
    addr_in = 32'h0100_2000 + i*32;
    wait_clocks(1);
  end

  read_en = 1'b0;
  addr_in = 32'h0;

  wait_clocks(4);
  rd_data_valid = 1'b1;
  data_bus_from_memory = 256'h3e4f_3e4e_3e4d_3e4c_3e4b_3e4a_3e49_3e48_3e47_3e46_3e45_3e44_3e43_3e42_3e41_3e40;
  wait_clocks(1);
  rd_data_valid = 1'b0;
  data_bus_from_memory = 256'h0;

  wait_clocks(4);
  rd_data_valid = 1'b1;
  data_bus_from_memory = 256'h3e00_3e00_3e00_3e00_3e00_3e00_3e00_3e00_3e00_3e00_3e00_3e00_3e00_3e00_3e00_3e00;
  wait_clocks(256);
  rd_data_valid = 1'b0;
  data_bus_from_memory = 256'h0;

  wait_clocks(4);

  write_en = 1;
  for(i=0;i<16;i=i+1) begin
    addr_in = 32'h0100_4000 + i*32;
    wait_clocks(1);
  end

  write_en = 0;
  addr_in = 0;

  wait_clocks(4);

  write_en = 1;
  addr_in = 32'h0080_001C;
  wait_clocks(1);
  write_en = 0;
  addr_in = 32'h0;
  wait_clocks(4);

  write_en = 1;
  addr_in = 32'h0080_005C;
  wait_clocks(1);
  write_en = 0;
  addr_in = 32'h0;
  wait_clocks(4);

  write_en = 1;
  addr_in = 32'h0080_009C;
  wait_clocks(1);
  write_en = 0;
  addr_in = 32'h0;
  wait_clocks(4);

  write_en = 1;
  addr_in = 32'h0000_4000;
  wait_clocks(1);  
  write_en = 0;
  addr_in = 32'h0;
  wait_clocks(4);

  wait_clocks(100);

  $finish();

end

//------------------------------------------------------------------------------
// TEST logic
//------------------------------------------------------------------------------
reg                              read_en_SYN;
reg                              write_en_SYN;
reg  [31:0]                      addr_in_SYN;
reg                              rd_data_valid_SYN;
reg  [255:0]                     data_bus_from_memory_SYN;


always @(posedge clk or negedge rst_x) begin
  if (~rst_x) begin
                                                  read_en_SYN <= 'b0;
                                                  write_en_SYN <= 'b0;
                                                  addr_in_SYN <= 'b0;
                                                  rd_data_valid_SYN <= 'b0;
                                                  data_bus_from_memory_SYN <= 'b0;
                                                  
  end
  else begin
                                                  read_en_SYN <= read_en;
                                                  write_en_SYN <= write_en;
                                                  addr_in_SYN <= addr_in;
                                                  rd_data_valid_SYN <= rd_data_valid;
                                                  data_bus_from_memory_SYN <= data_bus_from_memory;

  end
end  

    Device_top U0_DEVICE 
    (
        .clk                                  (clk                      ),
        .rst_x                                (rst_x                      ),
    
        //input
        .read_en                              (read_en_SYN                  ),
        .write_en                             (write_en_SYN                 ),
        .addr_in                              (addr_in_SYN                  ),
    
        .rd_data_valid                        (rd_data_valid_SYN),
        .data_bus_from_memory                 (data_bus_from_memory_SYN     ),
        
        //PIM result for DRAM write (output)
        .is_PIM_result                        (is_PIM_result            ),
        .PIM_result_to_DRAM                   (PIM_result_to_DRAM       )
    );

endmodule
