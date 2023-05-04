`timescale 1ps / 1ps

// Hardened logic for collecting responses using 8-element collector pipe.
// The module is designed to avoid "fake" asserted bits in the response queue, which are preset with the mask.
// Recall that multicasting is implemented by asserting "fake" response bits in the channels not used in the 
// request,so we need to make sure that actual responses don't accidentally write to the same position where
// "fake" bits are set.

module rptr_shift8 (
  input  logic signed [7:0] resp_array,  // Signed type required for the carry_out sign extension to work
  input  logic [2:0] resp_push_cnt,
  output logic [2:0] resp_push_ptr,
  output logic       carry_out);
  
  // Consider array full, if all positions up from the requested one (push_cnt) are full
  assign carry_out = &(resp_array >>> resp_push_cnt);

  always_comb begin
    casex({resp_push_cnt, resp_array})
      11'b000_???????0 : resp_push_ptr = 0;  // Example: expected response ptr is "0" and its position is empty - writing response to "0"
      11'b000_??????01 : resp_push_ptr = 1;  // Example: expected response ptr is "0", but its position is taken by a fake response - writing response to "1"
      11'b000_?????011 : resp_push_ptr = 2;
      11'b000_????0111 : resp_push_ptr = 3;
      11'b000_???01111 : resp_push_ptr = 4;
      11'b000_??011111 : resp_push_ptr = 5;
      11'b000_?0111111 : resp_push_ptr = 6;
      11'b000_01111111 : resp_push_ptr = 7;
      11'b000_11111111 : resp_push_ptr = 0;  // Example: expected response ptr is "0", but all positions are taken by fake responses (resp que full) - keeping ptr at "0"

      11'b001_??????0? : resp_push_ptr = 1;
      11'b001_?????01? : resp_push_ptr = 2;
      11'b001_????011? : resp_push_ptr = 3;
      11'b001_???0111? : resp_push_ptr = 4;
      11'b001_??01111? : resp_push_ptr = 5;
      11'b001_?011111? : resp_push_ptr = 6;
      11'b001_0111111? : resp_push_ptr = 7;
      11'b001_11111110 : resp_push_ptr = 0;
      11'b001_11111111 : resp_push_ptr = 1;

      11'b010_?????0?? : resp_push_ptr = 2;
      11'b010_????01?? : resp_push_ptr = 3;
      11'b010_???011?? : resp_push_ptr = 4;
      11'b010_??0111?? : resp_push_ptr = 5;
      11'b010_?01111?? : resp_push_ptr = 6;
      11'b010_011111?? : resp_push_ptr = 7;
      11'b010_111111?0 : resp_push_ptr = 0;
      11'b010_11111101 : resp_push_ptr = 1;
      11'b010_11111111 : resp_push_ptr = 2;

      11'b011_????0??? : resp_push_ptr = 3;
      11'b011_???01??? : resp_push_ptr = 4;
      11'b011_??011??? : resp_push_ptr = 5;
      11'b011_?0111??? : resp_push_ptr = 6;
      11'b011_01111??? : resp_push_ptr = 7;
      11'b011_11111??0 : resp_push_ptr = 0;
      11'b011_11111?01 : resp_push_ptr = 1;
      11'b011_11111011 : resp_push_ptr = 2;
      11'b011_11111111 : resp_push_ptr = 3;

      11'b100_???0???? : resp_push_ptr = 4;
      11'b100_??01???? : resp_push_ptr = 5;
      11'b100_?011???? : resp_push_ptr = 6;
      11'b100_0111???? : resp_push_ptr = 7;
      11'b100_1111???0 : resp_push_ptr = 0;
      11'b100_1111??01 : resp_push_ptr = 1;
      11'b100_1111?011 : resp_push_ptr = 2;
      11'b100_11110111 : resp_push_ptr = 3;
      11'b100_11111111 : resp_push_ptr = 4;

      11'b101_??0????? : resp_push_ptr = 5;
      11'b101_?01????? : resp_push_ptr = 6;
      11'b101_011????? : resp_push_ptr = 7;
      11'b101_111????0 : resp_push_ptr = 0;
      11'b101_111???01 : resp_push_ptr = 1;
      11'b101_111??011 : resp_push_ptr = 2;
      11'b101_111?0111 : resp_push_ptr = 3;
      11'b101_11101111 : resp_push_ptr = 4;
      11'b101_11111111 : resp_push_ptr = 5;

      11'b110_?0?????? : resp_push_ptr = 6;
      11'b110_01?????? : resp_push_ptr = 7;
      11'b110_11?????0 : resp_push_ptr = 0;
      11'b110_11????01 : resp_push_ptr = 1;
      11'b110_11???011 : resp_push_ptr = 2;
      11'b110_11??0111 : resp_push_ptr = 3;
      11'b110_11?01111 : resp_push_ptr = 4;
      11'b110_11011111 : resp_push_ptr = 5;
      11'b110_11111111 : resp_push_ptr = 6;

      11'b111_0??????? : resp_push_ptr = 7;
      11'b111_1??????0 : resp_push_ptr = 0;
      11'b111_1?????01 : resp_push_ptr = 1;
      11'b111_1????011 : resp_push_ptr = 2;
      11'b111_1???0111 : resp_push_ptr = 3;
      11'b111_1??01111 : resp_push_ptr = 4;
      11'b111_1?011111 : resp_push_ptr = 5;
      11'b111_10111111 : resp_push_ptr = 6;
      11'b111_11111111 : resp_push_ptr = 7;

      default : resp_push_ptr = 0;
    endcase
  end

endmodule
