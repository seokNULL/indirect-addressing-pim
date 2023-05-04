`timescale 1ps / 1ps 
 
module fp32_bf16 #(parameter SIZE=8) ( 
  input  logic clk, 
  input  logic store, 
  input  logic [SIZE-1:0][31:0] fp32_i, 
  output logic [2*SIZE-1:0][15:0] bf16_o); 
   
  logic [SIZE-1:0][15:0] bf16_mem; 
  logic [SIZE-1:0][15:0] bf16_new; 
 
  genvar i; 
  generate 
    for (i=0; i<SIZE; i++) begin : typeCast 
      // Type casting 
      logic s;                              //s : stikcy bit 
      logic rnd;  
 
      assign s   = |fp32_i[i][14:0];  
      assign rnd = fp32_i[i][15] && (s | (~s&&fp32_i[i][16])); 
 
      assign bf16_new[i] = fp32_i[i][31:16] + rnd; 
 
      // Temporary storage for half of the burst 
      always @(posedge clk) 
        if (store) bf16_mem[i] <= bf16_new[i]; 
 
      // Output contructor 
      assign bf16_o[i+SIZE]       = bf16_new[i];  // MSB part is taken directly from the input (filled second)
      assign bf16_o[i]            = bf16_mem[i];  // LSB part is taken from the memory (filled first) 
    end 
  endgenerate 
 
  initial bf16_mem = 0; 
 
endmodule
