/////////////////////////////////////////////////////////////
// Created by: Synopsys DC Ultra(TM) in wire load mode
// Version   : M-2016.12-SP5-3
// Date      : Fri Jul 10 05:22:32 2020
/////////////////////////////////////////////////////////////


module PIM_LUT_MUX_OVERHEAD_SYN_top ( clk, rst_x, cnt_for_LUT_pos, vACC_0_sign, 
        vACC_1_sign, vACC_2_sign, vACC_3_sign, lut_result_case0_0, 
        lut_result_case0_1, lut_result_case0_2, lut_result_case0_3, 
        lut_result_case0_4, lut_result_case0_5, lut_result_case0_6, 
        lut_result_case0_7, lut_result_case1_0, lut_result_case1_1, 
        lut_result_case1_2, lut_result_case1_3, lut_result_case1_4, 
        lut_result_case1_5, lut_result_case1_6, lut_result_case1_7, 
        lut_result_case2_0, lut_result_case2_1, lut_result_case2_2, 
        lut_result_case2_3, lut_result_case2_4, lut_result_case2_5, 
        lut_result_case2_6, lut_result_case2_7, lut_result_case3_0, 
        lut_result_case3_1, lut_result_case3_2, lut_result_case3_3, 
        lut_result_case3_4, lut_result_case3_5, lut_result_case3_6, 
        lut_result_case3_7, burst_case, lut_result_in_0, lut_result_in_1, 
        lut_result_in_2, lut_result_in_3, lut_result_in_4, lut_result_in_5, 
        lut_result_in_6, lut_result_in_7 );
  input [6:0] cnt_for_LUT_pos;
  input [7:0] vACC_0_sign;
  input [7:0] vACC_1_sign;
  input [7:0] vACC_2_sign;
  input [7:0] vACC_3_sign;
  input [1:0] lut_result_case0_0;
  input [1:0] lut_result_case0_1;
  input [1:0] lut_result_case0_2;
  input [1:0] lut_result_case0_3;
  input [1:0] lut_result_case0_4;
  input [1:0] lut_result_case0_5;
  input [1:0] lut_result_case0_6;
  input [1:0] lut_result_case0_7;
  input [1:0] lut_result_case1_0;
  input [1:0] lut_result_case1_1;
  input [1:0] lut_result_case1_2;
  input [1:0] lut_result_case1_3;
  input [1:0] lut_result_case1_4;
  input [1:0] lut_result_case1_5;
  input [1:0] lut_result_case1_6;
  input [1:0] lut_result_case1_7;
  input [1:0] lut_result_case2_0;
  input [1:0] lut_result_case2_1;
  input [1:0] lut_result_case2_2;
  input [1:0] lut_result_case2_3;
  input [1:0] lut_result_case2_4;
  input [1:0] lut_result_case2_5;
  input [1:0] lut_result_case2_6;
  input [1:0] lut_result_case2_7;
  input [1:0] lut_result_case3_0;
  input [1:0] lut_result_case3_1;
  input [1:0] lut_result_case3_2;
  input [1:0] lut_result_case3_3;
  input [1:0] lut_result_case3_4;
  input [1:0] lut_result_case3_5;
  input [1:0] lut_result_case3_6;
  input [1:0] lut_result_case3_7;
  input [3:0] burst_case;
  output [21:0] lut_result_in_0;
  output [21:0] lut_result_in_1;
  output [21:0] lut_result_in_2;
  output [21:0] lut_result_in_3;
  output [21:0] lut_result_in_4;
  output [21:0] lut_result_in_5;
  output [21:0] lut_result_in_6;
  output [21:0] lut_result_in_7;
  input clk, rst_x;
  wire   lut_result_case0_SYN_0__1_, lut_result_case0_SYN_0__0_,
         lut_result_case0_SYN_1__1_, lut_result_case0_SYN_1__0_,
         lut_result_case0_SYN_2__1_, lut_result_case0_SYN_2__0_,
         lut_result_case0_SYN_3__1_, lut_result_case0_SYN_3__0_,
         lut_result_case0_SYN_4__1_, lut_result_case0_SYN_4__0_,
         lut_result_case0_SYN_5__1_, lut_result_case0_SYN_5__0_,
         lut_result_case0_SYN_6__1_, lut_result_case0_SYN_6__0_,
         lut_result_case0_SYN_7__1_, lut_result_case0_SYN_7__0_,
         lut_result_case1_SYN_0__1_, lut_result_case1_SYN_0__0_,
         lut_result_case1_SYN_1__1_, lut_result_case1_SYN_1__0_,
         lut_result_case1_SYN_2__1_, lut_result_case1_SYN_2__0_,
         lut_result_case1_SYN_3__1_, lut_result_case1_SYN_3__0_,
         lut_result_case1_SYN_4__1_, lut_result_case1_SYN_4__0_,
         lut_result_case1_SYN_5__1_, lut_result_case1_SYN_5__0_,
         lut_result_case1_SYN_6__1_, lut_result_case1_SYN_6__0_,
         lut_result_case1_SYN_7__1_, lut_result_case1_SYN_7__0_,
         lut_result_case2_SYN_0__1_, lut_result_case2_SYN_0__0_,
         lut_result_case2_SYN_1__1_, lut_result_case2_SYN_1__0_,
         lut_result_case2_SYN_2__1_, lut_result_case2_SYN_2__0_,
         lut_result_case2_SYN_3__1_, lut_result_case2_SYN_3__0_,
         lut_result_case2_SYN_4__1_, lut_result_case2_SYN_4__0_,
         lut_result_case2_SYN_5__1_, lut_result_case2_SYN_5__0_,
         lut_result_case2_SYN_6__1_, lut_result_case2_SYN_6__0_,
         lut_result_case2_SYN_7__1_, lut_result_case2_SYN_7__0_,
         lut_result_case3_SYN_0__1_, lut_result_case3_SYN_0__0_,
         lut_result_case3_SYN_1__1_, lut_result_case3_SYN_1__0_,
         lut_result_case3_SYN_2__1_, lut_result_case3_SYN_2__0_,
         lut_result_case3_SYN_3__1_, lut_result_case3_SYN_3__0_,
         lut_result_case3_SYN_4__1_, lut_result_case3_SYN_4__0_,
         lut_result_case3_SYN_5__1_, lut_result_case3_SYN_5__0_,
         lut_result_case3_SYN_6__1_, lut_result_case3_SYN_6__0_,
         lut_result_case3_SYN_7__1_, lut_result_case3_SYN_7__0_,
         burst_case_SYN_3_, burst_case_SYN_2_, burst_case_SYN_1_,
         burst_case_SYN_0_, lut_result_in_SYN_0__21_, lut_result_in_SYN_1__21_,
         lut_result_in_SYN_2__21_, lut_result_in_SYN_3__21_,
         lut_result_in_SYN_4__21_, lut_result_in_SYN_5__21_,
         lut_result_in_SYN_6__21_, lut_result_in_SYN_7__21_,
         sig_pos_result_input_SYN_14_, tanh_result_input0_SYN_0__21_,
         tanh_result_input0_SYN_1__21_, tanh_result_input0_SYN_1__14_,
         tanh_result_input0_SYN_1__13_, tanh_result_input0_SYN_1__12_,
         tanh_result_input0_SYN_1__11_, tanh_result_input0_SYN_1__10_,
         tanh_result_input0_SYN_1__9_, tanh_result_input0_SYN_2__21_,
         tanh_result_input0_SYN_3__21_, tanh_result_input0_SYN_4__21_,
         tanh_result_input0_SYN_5__21_, tanh_result_input0_SYN_6__21_,
         tanh_result_input0_SYN_7__21_, tanh_result_input1_SYN_0__21_,
         tanh_result_input1_SYN_1__21_, tanh_result_input1_SYN_2__21_,
         tanh_result_input1_SYN_3__21_, tanh_result_input1_SYN_4__21_,
         tanh_result_input1_SYN_5__21_, tanh_result_input1_SYN_6__21_,
         tanh_result_input1_SYN_7__21_, tanh_result_input2_SYN_0__21_,
         tanh_result_input2_SYN_1__21_, tanh_result_input2_SYN_2__21_,
         tanh_result_input2_SYN_3__21_, tanh_result_input2_SYN_4__21_,
         tanh_result_input2_SYN_5__21_, tanh_result_input2_SYN_6__21_,
         tanh_result_input2_SYN_7__21_, tanh_result_input3_SYN_0__21_,
         tanh_result_input3_SYN_1__21_, tanh_result_input3_SYN_2__21_,
         tanh_result_input3_SYN_3__21_, tanh_result_input3_SYN_4__21_,
         tanh_result_input3_SYN_5__21_, tanh_result_input3_SYN_6__21_,
         tanh_result_input3_SYN_7__21_, n110, n111, n112, n113, n114, n115,
         n116, n117, n118, n119, n120, n121, n122, n123, n124, n125, n126,
         n127, n128, n129, n130, n131, n132, n133, n134, n135, n136, n137,
         n138, n139, n140, n141, n142, n143, n144, n145, n146, n147, n148,
         n149, n150, n151, n152, n153, n154, n155, n156, n157, n158, n159,
         n160, n161, n162, n163, n164, n165, n334, n335, n336, n337, n338,
         n339, n340, n341, n342, n343, n344, n345, n346, n347, n348, n349,
         n350, n351, n352, n353, n354, n355, n356, n357, n358, n359, n360,
         n361, n362, n363, n364, n365, n366, n367, n368, n369, n370, n371,
         n372, n373, n374, n375, n376, n377, n378, n379, n380, n381, n382,
         n383, n384, n385, n386, n387, n388, n389, n390, n391, n392, n393,
         n394, n395, n396, n397, n398, n399, n400, n401, n402, n403, n404,
         n405, n406, n407, n408, n409, n410, n411, n412, n413, n414, n415,
         n416, n417, n418, n419, n420, n421, n422, n423, n424, n425, n426,
         n427, n428, n429, n430, n431, n432, n433, n434, n435, n436, n437,
         n438, n439, n440, n441, n442, n443, n444, n445, n446, n447, n448,
         n449, n450, n451, n452, n453, n454, n455, n456, n457;

  DFFRQX2MTR cnt_for_LUT_pos_SYN_reg_6_ ( .D(cnt_for_LUT_pos[6]), .CK(clk), 
        .RN(rst_x), .Q(sig_pos_result_input_SYN_14_) );
  DFFRQX2MTR cnt_for_LUT_pos_SYN_reg_5_ ( .D(cnt_for_LUT_pos[5]), .CK(clk), 
        .RN(rst_x), .Q(tanh_result_input0_SYN_1__14_) );
  DFFRQX2MTR cnt_for_LUT_pos_SYN_reg_4_ ( .D(cnt_for_LUT_pos[4]), .CK(clk), 
        .RN(rst_x), .Q(tanh_result_input0_SYN_1__13_) );
  DFFRQX2MTR cnt_for_LUT_pos_SYN_reg_3_ ( .D(cnt_for_LUT_pos[3]), .CK(clk), 
        .RN(rst_x), .Q(tanh_result_input0_SYN_1__12_) );
  DFFRQX2MTR cnt_for_LUT_pos_SYN_reg_2_ ( .D(cnt_for_LUT_pos[2]), .CK(clk), 
        .RN(rst_x), .Q(tanh_result_input0_SYN_1__11_) );
  DFFRQX2MTR cnt_for_LUT_pos_SYN_reg_1_ ( .D(cnt_for_LUT_pos[1]), .CK(clk), 
        .RN(rst_x), .Q(tanh_result_input0_SYN_1__10_) );
  DFFRQX2MTR cnt_for_LUT_pos_SYN_reg_0_ ( .D(cnt_for_LUT_pos[0]), .CK(clk), 
        .RN(rst_x), .Q(tanh_result_input0_SYN_1__9_) );
  DFFRQX2MTR vACC_0_sign_SYN_reg_7_ ( .D(vACC_0_sign[7]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input0_SYN_7__21_) );
  DFFRQX2MTR vACC_0_sign_SYN_reg_6_ ( .D(vACC_0_sign[6]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input0_SYN_6__21_) );
  DFFRQX2MTR vACC_0_sign_SYN_reg_5_ ( .D(vACC_0_sign[5]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input0_SYN_5__21_) );
  DFFRQX2MTR vACC_0_sign_SYN_reg_4_ ( .D(vACC_0_sign[4]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input0_SYN_4__21_) );
  DFFRQX2MTR vACC_0_sign_SYN_reg_3_ ( .D(vACC_0_sign[3]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input0_SYN_3__21_) );
  DFFRQX2MTR vACC_0_sign_SYN_reg_2_ ( .D(vACC_0_sign[2]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input0_SYN_2__21_) );
  DFFRQX2MTR vACC_0_sign_SYN_reg_1_ ( .D(vACC_0_sign[1]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input0_SYN_1__21_) );
  DFFRQX2MTR vACC_0_sign_SYN_reg_0_ ( .D(vACC_0_sign[0]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input0_SYN_0__21_) );
  DFFRQX2MTR vACC_1_sign_SYN_reg_7_ ( .D(vACC_1_sign[7]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input1_SYN_7__21_) );
  DFFRQX2MTR vACC_1_sign_SYN_reg_6_ ( .D(vACC_1_sign[6]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input1_SYN_6__21_) );
  DFFRQX2MTR vACC_1_sign_SYN_reg_5_ ( .D(vACC_1_sign[5]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input1_SYN_5__21_) );
  DFFRQX2MTR vACC_1_sign_SYN_reg_4_ ( .D(vACC_1_sign[4]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input1_SYN_4__21_) );
  DFFRQX2MTR vACC_1_sign_SYN_reg_3_ ( .D(vACC_1_sign[3]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input1_SYN_3__21_) );
  DFFRQX2MTR vACC_1_sign_SYN_reg_2_ ( .D(vACC_1_sign[2]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input1_SYN_2__21_) );
  DFFRQX2MTR vACC_1_sign_SYN_reg_1_ ( .D(vACC_1_sign[1]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input1_SYN_1__21_) );
  DFFRQX2MTR vACC_1_sign_SYN_reg_0_ ( .D(vACC_1_sign[0]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input1_SYN_0__21_) );
  DFFRQX2MTR vACC_2_sign_SYN_reg_7_ ( .D(vACC_2_sign[7]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input2_SYN_7__21_) );
  DFFRQX2MTR vACC_2_sign_SYN_reg_6_ ( .D(vACC_2_sign[6]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input2_SYN_6__21_) );
  DFFRQX2MTR vACC_2_sign_SYN_reg_5_ ( .D(vACC_2_sign[5]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input2_SYN_5__21_) );
  DFFRQX2MTR vACC_2_sign_SYN_reg_4_ ( .D(vACC_2_sign[4]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input2_SYN_4__21_) );
  DFFRQX2MTR vACC_2_sign_SYN_reg_3_ ( .D(vACC_2_sign[3]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input2_SYN_3__21_) );
  DFFRQX2MTR vACC_2_sign_SYN_reg_2_ ( .D(vACC_2_sign[2]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input2_SYN_2__21_) );
  DFFRQX2MTR vACC_2_sign_SYN_reg_1_ ( .D(vACC_2_sign[1]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input2_SYN_1__21_) );
  DFFRQX2MTR vACC_2_sign_SYN_reg_0_ ( .D(vACC_2_sign[0]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input2_SYN_0__21_) );
  DFFRQX2MTR vACC_3_sign_SYN_reg_7_ ( .D(vACC_3_sign[7]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input3_SYN_7__21_) );
  DFFRQX2MTR vACC_3_sign_SYN_reg_6_ ( .D(vACC_3_sign[6]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input3_SYN_6__21_) );
  DFFRQX2MTR vACC_3_sign_SYN_reg_5_ ( .D(vACC_3_sign[5]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input3_SYN_5__21_) );
  DFFRQX2MTR vACC_3_sign_SYN_reg_4_ ( .D(vACC_3_sign[4]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input3_SYN_4__21_) );
  DFFRQX2MTR vACC_3_sign_SYN_reg_3_ ( .D(vACC_3_sign[3]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input3_SYN_3__21_) );
  DFFRQX2MTR vACC_3_sign_SYN_reg_2_ ( .D(vACC_3_sign[2]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input3_SYN_2__21_) );
  DFFRQX2MTR vACC_3_sign_SYN_reg_1_ ( .D(vACC_3_sign[1]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input3_SYN_1__21_) );
  DFFRQX2MTR vACC_3_sign_SYN_reg_0_ ( .D(vACC_3_sign[0]), .CK(clk), .RN(rst_x), 
        .Q(tanh_result_input3_SYN_0__21_) );
  DFFRQX2MTR lut_result_case0_0_SYN_reg_1_ ( .D(lut_result_case0_0[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case0_SYN_0__1_) );
  DFFRQX2MTR lut_result_case0_0_SYN_reg_0_ ( .D(lut_result_case0_0[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case0_SYN_0__0_) );
  DFFRQX2MTR lut_result_case0_1_SYN_reg_1_ ( .D(lut_result_case0_1[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case0_SYN_1__1_) );
  DFFRQX2MTR lut_result_case0_1_SYN_reg_0_ ( .D(lut_result_case0_1[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case0_SYN_1__0_) );
  DFFRQX2MTR lut_result_case0_2_SYN_reg_1_ ( .D(lut_result_case0_2[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case0_SYN_2__1_) );
  DFFRQX2MTR lut_result_case0_2_SYN_reg_0_ ( .D(lut_result_case0_2[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case0_SYN_2__0_) );
  DFFRQX2MTR lut_result_case0_3_SYN_reg_1_ ( .D(lut_result_case0_3[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case0_SYN_3__1_) );
  DFFRQX2MTR lut_result_case0_3_SYN_reg_0_ ( .D(lut_result_case0_3[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case0_SYN_3__0_) );
  DFFRQX2MTR lut_result_case0_4_SYN_reg_1_ ( .D(lut_result_case0_4[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case0_SYN_4__1_) );
  DFFRQX2MTR lut_result_case0_4_SYN_reg_0_ ( .D(lut_result_case0_4[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case0_SYN_4__0_) );
  DFFRQX2MTR lut_result_case0_5_SYN_reg_1_ ( .D(lut_result_case0_5[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case0_SYN_5__1_) );
  DFFRQX2MTR lut_result_case0_5_SYN_reg_0_ ( .D(lut_result_case0_5[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case0_SYN_5__0_) );
  DFFRQX2MTR lut_result_case0_6_SYN_reg_1_ ( .D(lut_result_case0_6[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case0_SYN_6__1_) );
  DFFRQX2MTR lut_result_case0_6_SYN_reg_0_ ( .D(lut_result_case0_6[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case0_SYN_6__0_) );
  DFFRQX2MTR lut_result_case0_7_SYN_reg_1_ ( .D(lut_result_case0_7[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case0_SYN_7__1_) );
  DFFRQX2MTR lut_result_case0_7_SYN_reg_0_ ( .D(lut_result_case0_7[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case0_SYN_7__0_) );
  DFFRQX2MTR lut_result_case1_0_SYN_reg_1_ ( .D(lut_result_case1_0[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case1_SYN_0__1_) );
  DFFRQX2MTR lut_result_case1_0_SYN_reg_0_ ( .D(lut_result_case1_0[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case1_SYN_0__0_) );
  DFFRQX2MTR lut_result_case1_1_SYN_reg_1_ ( .D(lut_result_case1_1[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case1_SYN_1__1_) );
  DFFRQX2MTR lut_result_case1_1_SYN_reg_0_ ( .D(lut_result_case1_1[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case1_SYN_1__0_) );
  DFFRQX2MTR lut_result_case1_2_SYN_reg_1_ ( .D(lut_result_case1_2[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case1_SYN_2__1_) );
  DFFRQX2MTR lut_result_case1_2_SYN_reg_0_ ( .D(lut_result_case1_2[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case1_SYN_2__0_) );
  DFFRQX2MTR lut_result_case1_3_SYN_reg_1_ ( .D(lut_result_case1_3[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case1_SYN_3__1_) );
  DFFRQX2MTR lut_result_case1_3_SYN_reg_0_ ( .D(lut_result_case1_3[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case1_SYN_3__0_) );
  DFFRQX2MTR lut_result_case1_4_SYN_reg_1_ ( .D(lut_result_case1_4[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case1_SYN_4__1_) );
  DFFRQX2MTR lut_result_case1_4_SYN_reg_0_ ( .D(lut_result_case1_4[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case1_SYN_4__0_) );
  DFFRQX2MTR lut_result_case1_5_SYN_reg_1_ ( .D(lut_result_case1_5[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case1_SYN_5__1_) );
  DFFRQX2MTR lut_result_case1_5_SYN_reg_0_ ( .D(lut_result_case1_5[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case1_SYN_5__0_) );
  DFFRQX2MTR lut_result_case1_6_SYN_reg_1_ ( .D(lut_result_case1_6[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case1_SYN_6__1_) );
  DFFRQX2MTR lut_result_case1_6_SYN_reg_0_ ( .D(lut_result_case1_6[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case1_SYN_6__0_) );
  DFFRQX2MTR lut_result_case1_7_SYN_reg_1_ ( .D(lut_result_case1_7[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case1_SYN_7__1_) );
  DFFRQX2MTR lut_result_case1_7_SYN_reg_0_ ( .D(lut_result_case1_7[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case1_SYN_7__0_) );
  DFFRQX2MTR lut_result_case2_0_SYN_reg_1_ ( .D(lut_result_case2_0[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case2_SYN_0__1_) );
  DFFRQX2MTR lut_result_case2_0_SYN_reg_0_ ( .D(lut_result_case2_0[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case2_SYN_0__0_) );
  DFFRQX2MTR lut_result_case2_1_SYN_reg_1_ ( .D(lut_result_case2_1[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case2_SYN_1__1_) );
  DFFRQX2MTR lut_result_case2_1_SYN_reg_0_ ( .D(lut_result_case2_1[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case2_SYN_1__0_) );
  DFFRQX2MTR lut_result_case2_2_SYN_reg_1_ ( .D(lut_result_case2_2[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case2_SYN_2__1_) );
  DFFRQX2MTR lut_result_case2_2_SYN_reg_0_ ( .D(lut_result_case2_2[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case2_SYN_2__0_) );
  DFFRQX2MTR lut_result_case2_3_SYN_reg_1_ ( .D(lut_result_case2_3[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case2_SYN_3__1_) );
  DFFRQX2MTR lut_result_case2_3_SYN_reg_0_ ( .D(lut_result_case2_3[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case2_SYN_3__0_) );
  DFFRQX2MTR lut_result_case2_4_SYN_reg_1_ ( .D(lut_result_case2_4[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case2_SYN_4__1_) );
  DFFRQX2MTR lut_result_case2_4_SYN_reg_0_ ( .D(lut_result_case2_4[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case2_SYN_4__0_) );
  DFFRQX2MTR lut_result_case2_5_SYN_reg_1_ ( .D(lut_result_case2_5[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case2_SYN_5__1_) );
  DFFRQX2MTR lut_result_case2_5_SYN_reg_0_ ( .D(lut_result_case2_5[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case2_SYN_5__0_) );
  DFFRQX2MTR lut_result_case2_6_SYN_reg_1_ ( .D(lut_result_case2_6[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case2_SYN_6__1_) );
  DFFRQX2MTR lut_result_case2_6_SYN_reg_0_ ( .D(lut_result_case2_6[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case2_SYN_6__0_) );
  DFFRQX2MTR lut_result_case2_7_SYN_reg_1_ ( .D(lut_result_case2_7[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case2_SYN_7__1_) );
  DFFRQX2MTR lut_result_case2_7_SYN_reg_0_ ( .D(lut_result_case2_7[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case2_SYN_7__0_) );
  DFFRQX2MTR lut_result_case3_0_SYN_reg_1_ ( .D(lut_result_case3_0[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case3_SYN_0__1_) );
  DFFRQX2MTR lut_result_case3_0_SYN_reg_0_ ( .D(lut_result_case3_0[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case3_SYN_0__0_) );
  DFFRQX2MTR lut_result_case3_1_SYN_reg_1_ ( .D(lut_result_case3_1[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case3_SYN_1__1_) );
  DFFRQX2MTR lut_result_case3_1_SYN_reg_0_ ( .D(lut_result_case3_1[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case3_SYN_1__0_) );
  DFFRQX2MTR lut_result_case3_2_SYN_reg_1_ ( .D(lut_result_case3_2[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case3_SYN_2__1_) );
  DFFRQX2MTR lut_result_case3_2_SYN_reg_0_ ( .D(lut_result_case3_2[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case3_SYN_2__0_) );
  DFFRQX2MTR lut_result_case3_3_SYN_reg_1_ ( .D(lut_result_case3_3[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case3_SYN_3__1_) );
  DFFRQX2MTR lut_result_case3_3_SYN_reg_0_ ( .D(lut_result_case3_3[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case3_SYN_3__0_) );
  DFFRQX2MTR lut_result_case3_4_SYN_reg_1_ ( .D(lut_result_case3_4[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case3_SYN_4__1_) );
  DFFRQX2MTR lut_result_case3_4_SYN_reg_0_ ( .D(lut_result_case3_4[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case3_SYN_4__0_) );
  DFFRQX2MTR lut_result_case3_5_SYN_reg_1_ ( .D(lut_result_case3_5[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case3_SYN_5__1_) );
  DFFRQX2MTR lut_result_case3_5_SYN_reg_0_ ( .D(lut_result_case3_5[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case3_SYN_5__0_) );
  DFFRQX2MTR lut_result_case3_6_SYN_reg_1_ ( .D(lut_result_case3_6[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case3_SYN_6__1_) );
  DFFRQX2MTR lut_result_case3_6_SYN_reg_0_ ( .D(lut_result_case3_6[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case3_SYN_6__0_) );
  DFFRQX2MTR lut_result_case3_7_SYN_reg_1_ ( .D(lut_result_case3_7[1]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case3_SYN_7__1_) );
  DFFRQX2MTR lut_result_case3_7_SYN_reg_0_ ( .D(lut_result_case3_7[0]), .CK(
        clk), .RN(rst_x), .Q(lut_result_case3_SYN_7__0_) );
  DFFRQX2MTR burst_case_SYN_reg_3_ ( .D(burst_case[3]), .CK(clk), .RN(rst_x), 
        .Q(burst_case_SYN_3_) );
  DFFRQX2MTR burst_case_SYN_reg_2_ ( .D(burst_case[2]), .CK(clk), .RN(rst_x), 
        .Q(burst_case_SYN_2_) );
  DFFRQX2MTR burst_case_SYN_reg_1_ ( .D(burst_case[1]), .CK(clk), .RN(rst_x), 
        .Q(burst_case_SYN_1_) );
  DFFRQX2MTR burst_case_SYN_reg_0_ ( .D(burst_case[0]), .CK(clk), .RN(rst_x), 
        .Q(burst_case_SYN_0_) );
  DFFRQX2MTR lut_result_in_7_reg_8_ ( .D(n164), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_7[8]) );
  DFFRQX2MTR lut_result_in_7_reg_21_ ( .D(lut_result_in_SYN_7__21_), .CK(clk), 
        .RN(rst_x), .Q(lut_result_in_7[21]) );
  DFFRQX2MTR lut_result_in_6_reg_8_ ( .D(n163), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_6[8]) );
  DFFRQX2MTR lut_result_in_6_reg_21_ ( .D(lut_result_in_SYN_6__21_), .CK(clk), 
        .RN(rst_x), .Q(lut_result_in_6[21]) );
  DFFRQX2MTR lut_result_in_7_reg_16_ ( .D(n454), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_7[16]) );
  DFFRQX2MTR lut_result_in_7_reg_17_ ( .D(n454), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_7[17]) );
  DFFRQX2MTR lut_result_in_7_reg_18_ ( .D(n454), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_7[18]) );
  DFFRQX2MTR lut_result_in_7_reg_19_ ( .D(n454), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_7[19]) );
  DFFRQX2MTR lut_result_in_6_reg_16_ ( .D(n455), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_6[16]) );
  DFFRQX2MTR lut_result_in_6_reg_17_ ( .D(n455), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_6[17]) );
  DFFRQX2MTR lut_result_in_6_reg_18_ ( .D(n455), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_6[18]) );
  DFFRQX2MTR lut_result_in_6_reg_19_ ( .D(n455), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_6[19]) );
  DFFRQX2MTR lut_result_in_7_reg_9_ ( .D(n156), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_7[9]) );
  DFFRQX2MTR lut_result_in_6_reg_9_ ( .D(n155), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_6[9]) );
  DFFRQX2MTR lut_result_in_7_reg_10_ ( .D(n148), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_7[10]) );
  DFFRQX2MTR lut_result_in_6_reg_10_ ( .D(n147), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_6[10]) );
  DFFRQX2MTR lut_result_in_7_reg_11_ ( .D(n140), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_7[11]) );
  DFFRQX2MTR lut_result_in_6_reg_11_ ( .D(n139), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_6[11]) );
  DFFRQX2MTR lut_result_in_7_reg_12_ ( .D(n132), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_7[12]) );
  DFFRQX2MTR lut_result_in_6_reg_12_ ( .D(n131), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_6[12]) );
  DFFRQX2MTR lut_result_in_7_reg_13_ ( .D(n124), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_7[13]) );
  DFFRQX2MTR lut_result_in_6_reg_13_ ( .D(n123), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_6[13]) );
  DFFRQX2MTR lut_result_in_7_reg_14_ ( .D(n116), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_7[14]) );
  DFFRQX2MTR lut_result_in_6_reg_14_ ( .D(n115), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_6[14]) );
  DFFRQX2MTR lut_result_in_0_reg_21_ ( .D(lut_result_in_SYN_0__21_), .CK(clk), 
        .RN(rst_x), .Q(lut_result_in_0[21]) );
  DFFRQX2MTR lut_result_in_0_reg_19_ ( .D(n454), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_0[19]) );
  DFFRQX2MTR lut_result_in_0_reg_18_ ( .D(n454), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_0[18]) );
  DFFRQX2MTR lut_result_in_0_reg_17_ ( .D(n454), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_0[17]) );
  DFFRQX2MTR lut_result_in_0_reg_16_ ( .D(n454), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_0[16]) );
  DFFRQX2MTR lut_result_in_0_reg_14_ ( .D(n117), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_0[14]) );
  DFFRQX2MTR lut_result_in_0_reg_13_ ( .D(n125), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_0[13]) );
  DFFRQX2MTR lut_result_in_0_reg_12_ ( .D(n133), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_0[12]) );
  DFFRQX2MTR lut_result_in_0_reg_11_ ( .D(n141), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_0[11]) );
  DFFRQX2MTR lut_result_in_0_reg_10_ ( .D(n149), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_0[10]) );
  DFFRQX2MTR lut_result_in_0_reg_9_ ( .D(n157), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_0[9]) );
  DFFRQX2MTR lut_result_in_0_reg_8_ ( .D(n165), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_0[8]) );
  DFFRQX2MTR lut_result_in_1_reg_21_ ( .D(lut_result_in_SYN_1__21_), .CK(clk), 
        .RN(rst_x), .Q(lut_result_in_1[21]) );
  DFFRQX2MTR lut_result_in_1_reg_19_ ( .D(n457), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_1[19]) );
  DFFRQX2MTR lut_result_in_1_reg_18_ ( .D(n457), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_1[18]) );
  DFFRQX2MTR lut_result_in_1_reg_17_ ( .D(n457), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_1[17]) );
  DFFRQX2MTR lut_result_in_1_reg_16_ ( .D(n457), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_1[16]) );
  DFFRQX2MTR lut_result_in_1_reg_14_ ( .D(n110), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_1[14]) );
  DFFRQX2MTR lut_result_in_1_reg_13_ ( .D(n118), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_1[13]) );
  DFFRQX2MTR lut_result_in_1_reg_12_ ( .D(n126), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_1[12]) );
  DFFRQX2MTR lut_result_in_1_reg_11_ ( .D(n134), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_1[11]) );
  DFFRQX2MTR lut_result_in_1_reg_10_ ( .D(n142), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_1[10]) );
  DFFRQX2MTR lut_result_in_1_reg_9_ ( .D(n150), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_1[9]) );
  DFFRQX2MTR lut_result_in_1_reg_8_ ( .D(n158), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_1[8]) );
  DFFRQX2MTR lut_result_in_2_reg_21_ ( .D(lut_result_in_SYN_2__21_), .CK(clk), 
        .RN(rst_x), .Q(lut_result_in_2[21]) );
  DFFRQX2MTR lut_result_in_2_reg_19_ ( .D(n457), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_2[19]) );
  DFFRQX2MTR lut_result_in_2_reg_18_ ( .D(n457), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_2[18]) );
  DFFRQX2MTR lut_result_in_2_reg_17_ ( .D(n457), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_2[17]) );
  DFFRQX2MTR lut_result_in_2_reg_16_ ( .D(n457), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_2[16]) );
  DFFRQX2MTR lut_result_in_2_reg_14_ ( .D(n111), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_2[14]) );
  DFFRQX2MTR lut_result_in_2_reg_13_ ( .D(n119), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_2[13]) );
  DFFRQX2MTR lut_result_in_2_reg_12_ ( .D(n127), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_2[12]) );
  DFFRQX2MTR lut_result_in_2_reg_11_ ( .D(n135), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_2[11]) );
  DFFRQX2MTR lut_result_in_2_reg_10_ ( .D(n143), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_2[10]) );
  DFFRQX2MTR lut_result_in_2_reg_9_ ( .D(n151), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_2[9]) );
  DFFRQX2MTR lut_result_in_2_reg_8_ ( .D(n159), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_2[8]) );
  DFFRQX2MTR lut_result_in_3_reg_21_ ( .D(lut_result_in_SYN_3__21_), .CK(clk), 
        .RN(rst_x), .Q(lut_result_in_3[21]) );
  DFFRQX2MTR lut_result_in_3_reg_19_ ( .D(n456), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_3[19]) );
  DFFRQX2MTR lut_result_in_3_reg_18_ ( .D(n456), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_3[18]) );
  DFFRQX2MTR lut_result_in_3_reg_17_ ( .D(n456), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_3[17]) );
  DFFRQX2MTR lut_result_in_3_reg_16_ ( .D(n456), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_3[16]) );
  DFFRQX2MTR lut_result_in_3_reg_14_ ( .D(n112), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_3[14]) );
  DFFRQX2MTR lut_result_in_3_reg_13_ ( .D(n120), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_3[13]) );
  DFFRQX2MTR lut_result_in_3_reg_12_ ( .D(n128), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_3[12]) );
  DFFRQX2MTR lut_result_in_3_reg_11_ ( .D(n136), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_3[11]) );
  DFFRQX2MTR lut_result_in_3_reg_10_ ( .D(n144), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_3[10]) );
  DFFRQX2MTR lut_result_in_3_reg_9_ ( .D(n152), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_3[9]) );
  DFFRQX2MTR lut_result_in_3_reg_8_ ( .D(n160), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_3[8]) );
  DFFRQX2MTR lut_result_in_4_reg_21_ ( .D(lut_result_in_SYN_4__21_), .CK(clk), 
        .RN(rst_x), .Q(lut_result_in_4[21]) );
  DFFRQX2MTR lut_result_in_4_reg_19_ ( .D(n456), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_4[19]) );
  DFFRQX2MTR lut_result_in_4_reg_18_ ( .D(n456), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_4[18]) );
  DFFRQX2MTR lut_result_in_4_reg_17_ ( .D(n456), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_4[17]) );
  DFFRQX2MTR lut_result_in_4_reg_16_ ( .D(n456), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_4[16]) );
  DFFRQX2MTR lut_result_in_4_reg_14_ ( .D(n113), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_4[14]) );
  DFFRQX2MTR lut_result_in_4_reg_13_ ( .D(n121), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_4[13]) );
  DFFRQX2MTR lut_result_in_4_reg_12_ ( .D(n129), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_4[12]) );
  DFFRQX2MTR lut_result_in_4_reg_11_ ( .D(n137), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_4[11]) );
  DFFRQX2MTR lut_result_in_4_reg_10_ ( .D(n145), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_4[10]) );
  DFFRQX2MTR lut_result_in_4_reg_9_ ( .D(n153), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_4[9]) );
  DFFRQX2MTR lut_result_in_4_reg_8_ ( .D(n161), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_4[8]) );
  DFFRQX2MTR lut_result_in_5_reg_21_ ( .D(lut_result_in_SYN_5__21_), .CK(clk), 
        .RN(rst_x), .Q(lut_result_in_5[21]) );
  DFFRQX2MTR lut_result_in_5_reg_19_ ( .D(n455), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_5[19]) );
  DFFRQX2MTR lut_result_in_5_reg_18_ ( .D(n455), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_5[18]) );
  DFFRQX2MTR lut_result_in_5_reg_17_ ( .D(n455), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_5[17]) );
  DFFRQX2MTR lut_result_in_5_reg_16_ ( .D(n455), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_5[16]) );
  DFFRQX2MTR lut_result_in_5_reg_14_ ( .D(n114), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_5[14]) );
  DFFRQX2MTR lut_result_in_5_reg_13_ ( .D(n122), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_5[13]) );
  DFFRQX2MTR lut_result_in_5_reg_12_ ( .D(n130), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_5[12]) );
  DFFRQX2MTR lut_result_in_5_reg_11_ ( .D(n138), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_5[11]) );
  DFFRQX2MTR lut_result_in_5_reg_10_ ( .D(n146), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_5[10]) );
  DFFRQX2MTR lut_result_in_5_reg_9_ ( .D(n154), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_5[9]) );
  DFFRQX2MTR lut_result_in_5_reg_8_ ( .D(n162), .CK(clk), .RN(rst_x), .Q(
        lut_result_in_5[8]) );
  INVX1MTR U177 ( .A(1'b1), .Y(lut_result_in_7[0]) );
  INVX1MTR U179 ( .A(1'b1), .Y(lut_result_in_7[1]) );
  INVX1MTR U181 ( .A(1'b1), .Y(lut_result_in_7[2]) );
  INVX1MTR U183 ( .A(1'b1), .Y(lut_result_in_7[3]) );
  INVX1MTR U185 ( .A(1'b1), .Y(lut_result_in_7[4]) );
  INVX1MTR U187 ( .A(1'b1), .Y(lut_result_in_7[5]) );
  INVX1MTR U189 ( .A(1'b1), .Y(lut_result_in_7[6]) );
  INVX1MTR U191 ( .A(1'b1), .Y(lut_result_in_7[7]) );
  INVX1MTR U193 ( .A(1'b1), .Y(lut_result_in_7[15]) );
  INVX1MTR U195 ( .A(1'b1), .Y(lut_result_in_7[20]) );
  INVX1MTR U197 ( .A(1'b1), .Y(lut_result_in_6[0]) );
  INVX1MTR U199 ( .A(1'b1), .Y(lut_result_in_6[1]) );
  INVX1MTR U201 ( .A(1'b1), .Y(lut_result_in_6[2]) );
  INVX1MTR U203 ( .A(1'b1), .Y(lut_result_in_6[3]) );
  INVX1MTR U205 ( .A(1'b1), .Y(lut_result_in_6[4]) );
  INVX1MTR U207 ( .A(1'b1), .Y(lut_result_in_6[5]) );
  INVX1MTR U209 ( .A(1'b1), .Y(lut_result_in_6[6]) );
  INVX1MTR U211 ( .A(1'b1), .Y(lut_result_in_6[7]) );
  INVX1MTR U213 ( .A(1'b1), .Y(lut_result_in_6[15]) );
  INVX1MTR U215 ( .A(1'b1), .Y(lut_result_in_6[20]) );
  INVX1MTR U217 ( .A(1'b1), .Y(lut_result_in_5[0]) );
  INVX1MTR U219 ( .A(1'b1), .Y(lut_result_in_5[1]) );
  INVX1MTR U221 ( .A(1'b1), .Y(lut_result_in_5[2]) );
  INVX1MTR U223 ( .A(1'b1), .Y(lut_result_in_5[3]) );
  INVX1MTR U225 ( .A(1'b1), .Y(lut_result_in_5[4]) );
  INVX1MTR U227 ( .A(1'b1), .Y(lut_result_in_5[5]) );
  INVX1MTR U229 ( .A(1'b1), .Y(lut_result_in_5[6]) );
  INVX1MTR U231 ( .A(1'b1), .Y(lut_result_in_5[7]) );
  INVX1MTR U233 ( .A(1'b1), .Y(lut_result_in_5[15]) );
  INVX1MTR U235 ( .A(1'b1), .Y(lut_result_in_5[20]) );
  INVX1MTR U237 ( .A(1'b1), .Y(lut_result_in_4[0]) );
  INVX1MTR U239 ( .A(1'b1), .Y(lut_result_in_4[1]) );
  INVX1MTR U241 ( .A(1'b1), .Y(lut_result_in_4[2]) );
  INVX1MTR U243 ( .A(1'b1), .Y(lut_result_in_4[3]) );
  INVX1MTR U245 ( .A(1'b1), .Y(lut_result_in_4[4]) );
  INVX1MTR U247 ( .A(1'b1), .Y(lut_result_in_4[5]) );
  INVX1MTR U249 ( .A(1'b1), .Y(lut_result_in_4[6]) );
  INVX1MTR U251 ( .A(1'b1), .Y(lut_result_in_4[7]) );
  INVX1MTR U253 ( .A(1'b1), .Y(lut_result_in_4[15]) );
  INVX1MTR U255 ( .A(1'b1), .Y(lut_result_in_4[20]) );
  INVX1MTR U257 ( .A(1'b1), .Y(lut_result_in_3[0]) );
  INVX1MTR U259 ( .A(1'b1), .Y(lut_result_in_3[1]) );
  INVX1MTR U261 ( .A(1'b1), .Y(lut_result_in_3[2]) );
  INVX1MTR U263 ( .A(1'b1), .Y(lut_result_in_3[3]) );
  INVX1MTR U265 ( .A(1'b1), .Y(lut_result_in_3[4]) );
  INVX1MTR U267 ( .A(1'b1), .Y(lut_result_in_3[5]) );
  INVX1MTR U269 ( .A(1'b1), .Y(lut_result_in_3[6]) );
  INVX1MTR U271 ( .A(1'b1), .Y(lut_result_in_3[7]) );
  INVX1MTR U273 ( .A(1'b1), .Y(lut_result_in_3[15]) );
  INVX1MTR U275 ( .A(1'b1), .Y(lut_result_in_3[20]) );
  INVX1MTR U277 ( .A(1'b1), .Y(lut_result_in_2[0]) );
  INVX1MTR U279 ( .A(1'b1), .Y(lut_result_in_2[1]) );
  INVX1MTR U281 ( .A(1'b1), .Y(lut_result_in_2[2]) );
  INVX1MTR U283 ( .A(1'b1), .Y(lut_result_in_2[3]) );
  INVX1MTR U285 ( .A(1'b1), .Y(lut_result_in_2[4]) );
  INVX1MTR U287 ( .A(1'b1), .Y(lut_result_in_2[5]) );
  INVX1MTR U289 ( .A(1'b1), .Y(lut_result_in_2[6]) );
  INVX1MTR U291 ( .A(1'b1), .Y(lut_result_in_2[7]) );
  INVX1MTR U293 ( .A(1'b1), .Y(lut_result_in_2[15]) );
  INVX1MTR U295 ( .A(1'b1), .Y(lut_result_in_2[20]) );
  INVX1MTR U297 ( .A(1'b1), .Y(lut_result_in_1[0]) );
  INVX1MTR U299 ( .A(1'b1), .Y(lut_result_in_1[1]) );
  INVX1MTR U301 ( .A(1'b1), .Y(lut_result_in_1[2]) );
  INVX1MTR U303 ( .A(1'b1), .Y(lut_result_in_1[3]) );
  INVX1MTR U305 ( .A(1'b1), .Y(lut_result_in_1[4]) );
  INVX1MTR U307 ( .A(1'b1), .Y(lut_result_in_1[5]) );
  INVX1MTR U309 ( .A(1'b1), .Y(lut_result_in_1[6]) );
  INVX1MTR U311 ( .A(1'b1), .Y(lut_result_in_1[7]) );
  INVX1MTR U313 ( .A(1'b1), .Y(lut_result_in_1[15]) );
  INVX1MTR U315 ( .A(1'b1), .Y(lut_result_in_1[20]) );
  INVX1MTR U317 ( .A(1'b1), .Y(lut_result_in_0[0]) );
  INVX1MTR U319 ( .A(1'b1), .Y(lut_result_in_0[1]) );
  INVX1MTR U321 ( .A(1'b1), .Y(lut_result_in_0[2]) );
  INVX1MTR U323 ( .A(1'b1), .Y(lut_result_in_0[3]) );
  INVX1MTR U325 ( .A(1'b1), .Y(lut_result_in_0[4]) );
  INVX1MTR U327 ( .A(1'b1), .Y(lut_result_in_0[5]) );
  INVX1MTR U329 ( .A(1'b1), .Y(lut_result_in_0[6]) );
  INVX1MTR U331 ( .A(1'b1), .Y(lut_result_in_0[7]) );
  INVX1MTR U333 ( .A(1'b1), .Y(lut_result_in_0[15]) );
  INVX1MTR U335 ( .A(1'b1), .Y(lut_result_in_0[20]) );
  NAND2X1MTR U337 ( .A(n360), .B(n359), .Y(n407) );
  AOI22X1MTR U338 ( .A0(n392), .A1(lut_result_case2_SYN_5__0_), .B0(n379), 
        .B1(lut_result_case3_SYN_5__0_), .Y(n360) );
  AOI22X1MTR U339 ( .A0(n380), .A1(lut_result_case0_SYN_5__0_), .B0(n393), 
        .B1(lut_result_case1_SYN_5__0_), .Y(n359) );
  NAND2X1MTR U340 ( .A(n372), .B(n371), .Y(n409) );
  AOI22X1MTR U341 ( .A0(burst_case_SYN_2_), .A1(lut_result_case2_SYN_4__0_), 
        .B0(n379), .B1(lut_result_case3_SYN_4__0_), .Y(n372) );
  AOI22X1MTR U342 ( .A0(n380), .A1(lut_result_case0_SYN_4__0_), .B0(n385), 
        .B1(lut_result_case1_SYN_4__0_), .Y(n371) );
  NAND2X1MTR U343 ( .A(n378), .B(n377), .Y(n410) );
  AOI22X1MTR U344 ( .A0(burst_case_SYN_2_), .A1(lut_result_case2_SYN_3__0_), 
        .B0(burst_case_SYN_3_), .B1(lut_result_case3_SYN_3__0_), .Y(n378) );
  AOI22X1MTR U345 ( .A0(burst_case_SYN_0_), .A1(lut_result_case0_SYN_3__0_), 
        .B0(n385), .B1(lut_result_case1_SYN_3__0_), .Y(n377) );
  NAND2X1MTR U346 ( .A(n354), .B(n353), .Y(n403) );
  AOI22X1MTR U347 ( .A0(burst_case_SYN_2_), .A1(lut_result_case2_SYN_2__0_), 
        .B0(burst_case_SYN_3_), .B1(lut_result_case3_SYN_2__0_), .Y(n354) );
  AOI22X1MTR U348 ( .A0(burst_case_SYN_0_), .A1(lut_result_case0_SYN_2__0_), 
        .B0(n385), .B1(lut_result_case1_SYN_2__0_), .Y(n353) );
  NAND2X1MTR U349 ( .A(n348), .B(n347), .Y(n404) );
  AOI22X1MTR U350 ( .A0(n413), .A1(lut_result_case2_SYN_1__0_), .B0(
        burst_case_SYN_3_), .B1(lut_result_case3_SYN_1__0_), .Y(n348) );
  AOI22X1MTR U351 ( .A0(burst_case_SYN_0_), .A1(lut_result_case0_SYN_1__0_), 
        .B0(n385), .B1(lut_result_case1_SYN_1__0_), .Y(n347) );
  NAND2X1MTR U352 ( .A(n395), .B(n394), .Y(n405) );
  AOI22X1MTR U353 ( .A0(n392), .A1(lut_result_case2_SYN_0__0_), .B0(n397), 
        .B1(lut_result_case3_SYN_0__0_), .Y(n395) );
  AOI22X1MTR U354 ( .A0(n398), .A1(lut_result_case0_SYN_0__0_), .B0(n393), 
        .B1(lut_result_case1_SYN_0__0_), .Y(n394) );
  NAND2X1MTR U355 ( .A(n366), .B(n365), .Y(n406) );
  AOI22X1MTR U356 ( .A0(n392), .A1(lut_result_case2_SYN_6__0_), .B0(n397), 
        .B1(lut_result_case3_SYN_6__0_), .Y(n366) );
  AOI22X1MTR U357 ( .A0(n398), .A1(lut_result_case0_SYN_6__0_), .B0(n393), 
        .B1(lut_result_case1_SYN_6__0_), .Y(n365) );
  NAND2X1MTR U358 ( .A(n387), .B(n386), .Y(n408) );
  AOI22X1MTR U359 ( .A0(n392), .A1(lut_result_case2_SYN_7__0_), .B0(n397), 
        .B1(lut_result_case3_SYN_7__0_), .Y(n387) );
  AOI22X1MTR U360 ( .A0(n398), .A1(lut_result_case0_SYN_7__0_), .B0(n393), 
        .B1(lut_result_case1_SYN_7__0_), .Y(n386) );
  AND2X1MTR U361 ( .A(n362), .B(n361), .Y(n449) );
  AOI22X1MTR U362 ( .A0(n414), .A1(lut_result_case1_SYN_5__1_), .B0(n396), 
        .B1(lut_result_case2_SYN_5__1_), .Y(n362) );
  AOI22X1MTR U363 ( .A0(n380), .A1(lut_result_case0_SYN_5__1_), .B0(n379), 
        .B1(lut_result_case3_SYN_5__1_), .Y(n361) );
  NAND2X1MTR U364 ( .A(n449), .B(n407), .Y(n448) );
  NAND2BX1MTR U365 ( .AN(n407), .B(n449), .Y(n452) );
  AND2X1MTR U366 ( .A(n374), .B(n373), .Y(n434) );
  AOI22X1MTR U367 ( .A0(n414), .A1(lut_result_case1_SYN_4__1_), .B0(n396), 
        .B1(lut_result_case2_SYN_4__1_), .Y(n374) );
  AOI22X1MTR U368 ( .A0(n380), .A1(lut_result_case0_SYN_4__1_), .B0(n379), 
        .B1(lut_result_case3_SYN_4__1_), .Y(n373) );
  NAND2X1MTR U369 ( .A(n434), .B(n409), .Y(n433) );
  NAND2BX1MTR U370 ( .AN(n409), .B(n434), .Y(n435) );
  AND2X1MTR U371 ( .A(n382), .B(n381), .Y(n440) );
  AOI22X1MTR U372 ( .A0(burst_case_SYN_1_), .A1(lut_result_case1_SYN_3__1_), 
        .B0(n396), .B1(lut_result_case2_SYN_3__1_), .Y(n382) );
  AOI22X1MTR U373 ( .A0(n380), .A1(lut_result_case0_SYN_3__1_), .B0(n379), 
        .B1(lut_result_case3_SYN_3__1_), .Y(n381) );
  NAND2X1MTR U374 ( .A(n440), .B(n410), .Y(n439) );
  NAND2BX1MTR U375 ( .AN(n410), .B(n440), .Y(n441) );
  AND2X1MTR U376 ( .A(n356), .B(n355), .Y(n437) );
  AOI22X1MTR U377 ( .A0(n415), .A1(lut_result_case0_SYN_2__1_), .B0(n412), 
        .B1(lut_result_case3_SYN_2__1_), .Y(n355) );
  AOI22X1MTR U378 ( .A0(burst_case_SYN_1_), .A1(lut_result_case1_SYN_2__1_), 
        .B0(n396), .B1(lut_result_case2_SYN_2__1_), .Y(n356) );
  NAND2X1MTR U379 ( .A(n437), .B(n403), .Y(n436) );
  NAND2BX1MTR U380 ( .AN(n403), .B(n437), .Y(n438) );
  AND2X1MTR U381 ( .A(n350), .B(n349), .Y(n446) );
  AOI22X1MTR U382 ( .A0(burst_case_SYN_0_), .A1(lut_result_case0_SYN_1__1_), 
        .B0(burst_case_SYN_3_), .B1(lut_result_case3_SYN_1__1_), .Y(n349) );
  AOI22X1MTR U383 ( .A0(burst_case_SYN_1_), .A1(lut_result_case1_SYN_1__1_), 
        .B0(n396), .B1(lut_result_case2_SYN_1__1_), .Y(n350) );
  NAND2X1MTR U384 ( .A(n446), .B(n404), .Y(n445) );
  NAND2BX1MTR U385 ( .AN(n404), .B(n446), .Y(n447) );
  AND2X1MTR U386 ( .A(n400), .B(n399), .Y(n426) );
  AOI22X1MTR U387 ( .A0(n414), .A1(lut_result_case1_SYN_0__1_), .B0(n396), 
        .B1(lut_result_case2_SYN_0__1_), .Y(n400) );
  AOI22X1MTR U388 ( .A0(n398), .A1(lut_result_case0_SYN_0__1_), .B0(n397), 
        .B1(lut_result_case3_SYN_0__1_), .Y(n399) );
  INVX1MTR U389 ( .A(sig_pos_result_input_SYN_14_), .Y(n418) );
  NAND2X1MTR U390 ( .A(n426), .B(n405), .Y(n425) );
  NAND2BX1MTR U391 ( .AN(n405), .B(n426), .Y(n428) );
  NAND2X1MTR U392 ( .A(tanh_result_input0_SYN_1__14_), .B(n417), .Y(n416) );
  NAND2X1MTR U393 ( .A(tanh_result_input0_SYN_1__13_), .B(n417), .Y(n420) );
  NAND2X1MTR U394 ( .A(n418), .B(n340), .Y(n419) );
  NAND2X1MTR U395 ( .A(tanh_result_input0_SYN_1__12_), .B(n417), .Y(n424) );
  NAND2X1MTR U396 ( .A(n418), .B(n342), .Y(n423) );
  NAND2X1MTR U397 ( .A(tanh_result_input0_SYN_1__11_), .B(n417), .Y(n422) );
  NAND2X1MTR U398 ( .A(n418), .B(n338), .Y(n421) );
  NAND2X1MTR U399 ( .A(tanh_result_input0_SYN_1__10_), .B(n417), .Y(n429) );
  NAND2X1MTR U400 ( .A(n418), .B(n344), .Y(n427) );
  NAND2X1MTR U401 ( .A(tanh_result_input0_SYN_1__9_), .B(n417), .Y(n451) );
  NAND2X1MTR U402 ( .A(n336), .B(n418), .Y(n450) );
  OR4X1MTR U403 ( .A(n415), .B(n414), .C(n413), .D(n412), .Y(n453) );
  NAND2BX1MTR U404 ( .AN(n406), .B(n443), .Y(n444) );
  AND2X1MTR U405 ( .A(n368), .B(n367), .Y(n443) );
  AOI22X1MTR U406 ( .A0(burst_case_SYN_1_), .A1(lut_result_case1_SYN_6__1_), 
        .B0(n396), .B1(lut_result_case2_SYN_6__1_), .Y(n368) );
  AOI22X1MTR U407 ( .A0(n398), .A1(lut_result_case0_SYN_6__1_), .B0(n397), 
        .B1(lut_result_case3_SYN_6__1_), .Y(n367) );
  NAND2X1MTR U408 ( .A(n443), .B(n406), .Y(n442) );
  NAND2BX1MTR U409 ( .AN(n408), .B(n431), .Y(n432) );
  AND2X1MTR U410 ( .A(n389), .B(n388), .Y(n431) );
  AOI22X1MTR U411 ( .A0(burst_case_SYN_1_), .A1(lut_result_case1_SYN_7__1_), 
        .B0(n396), .B1(lut_result_case2_SYN_7__1_), .Y(n389) );
  AOI22X1MTR U412 ( .A0(n398), .A1(lut_result_case0_SYN_7__1_), .B0(n397), 
        .B1(lut_result_case3_SYN_7__1_), .Y(n388) );
  NAND2X1MTR U413 ( .A(n431), .B(n408), .Y(n430) );
  NAND2X1MTR U414 ( .A(n418), .B(n334), .Y(n411) );
  OAI22X1MTR U415 ( .A0(n449), .A1(n411), .B0(n334), .B1(n448), .Y(n162) );
  OAI222X1MTR U416 ( .A0(n452), .A1(n451), .B0(n450), .B1(n449), .C0(n336), 
        .C1(n448), .Y(n154) );
  OAI222X1MTR U417 ( .A0(n429), .A1(n452), .B0(n427), .B1(n449), .C0(n344), 
        .C1(n448), .Y(n146) );
  OAI222X1MTR U418 ( .A0(n422), .A1(n452), .B0(n421), .B1(n449), .C0(n338), 
        .C1(n448), .Y(n138) );
  OAI222X1MTR U419 ( .A0(n424), .A1(n452), .B0(n423), .B1(n449), .C0(n343), 
        .C1(n448), .Y(n130) );
  OAI222X1MTR U420 ( .A0(n420), .A1(n452), .B0(n419), .B1(n449), .C0(n341), 
        .C1(n448), .Y(n122) );
  OAI22X1MTR U421 ( .A0(n346), .A1(n448), .B0(n452), .B1(n416), .Y(n114) );
  AOI21X1MTR U422 ( .A0(n364), .A1(n363), .B0(n452), .Y(
        lut_result_in_SYN_5__21_) );
  AOI22X1MTR U423 ( .A0(n413), .A1(tanh_result_input2_SYN_5__21_), .B0(n379), 
        .B1(tanh_result_input3_SYN_5__21_), .Y(n364) );
  AOI22X1MTR U424 ( .A0(n380), .A1(tanh_result_input0_SYN_5__21_), .B0(n393), 
        .B1(tanh_result_input1_SYN_5__21_), .Y(n363) );
  OAI22X1MTR U425 ( .A0(n434), .A1(n411), .B0(n334), .B1(n433), .Y(n161) );
  OAI222X1MTR U426 ( .A0(n435), .A1(n451), .B0(n450), .B1(n434), .C0(n337), 
        .C1(n433), .Y(n153) );
  OAI222X1MTR U427 ( .A0(n429), .A1(n435), .B0(n427), .B1(n434), .C0(n345), 
        .C1(n433), .Y(n145) );
  OAI222X1MTR U428 ( .A0(n422), .A1(n435), .B0(n421), .B1(n434), .C0(n339), 
        .C1(n433), .Y(n137) );
  OAI222X1MTR U429 ( .A0(n424), .A1(n435), .B0(n423), .B1(n434), .C0(n342), 
        .C1(n433), .Y(n129) );
  OAI222X1MTR U430 ( .A0(n420), .A1(n435), .B0(n419), .B1(n434), .C0(n340), 
        .C1(n433), .Y(n121) );
  OAI22X1MTR U431 ( .A0(n346), .A1(n433), .B0(n435), .B1(n416), .Y(n113) );
  AOI21X1MTR U432 ( .A0(n376), .A1(n375), .B0(n435), .Y(
        lut_result_in_SYN_4__21_) );
  AOI22X1MTR U433 ( .A0(n413), .A1(tanh_result_input2_SYN_4__21_), .B0(n379), 
        .B1(tanh_result_input3_SYN_4__21_), .Y(n376) );
  AOI22X1MTR U434 ( .A0(n380), .A1(tanh_result_input0_SYN_4__21_), .B0(n385), 
        .B1(tanh_result_input1_SYN_4__21_), .Y(n375) );
  OAI22X1MTR U435 ( .A0(n440), .A1(n411), .B0(n335), .B1(n439), .Y(n160) );
  OAI222X1MTR U436 ( .A0(n441), .A1(n451), .B0(n450), .B1(n440), .C0(n337), 
        .C1(n439), .Y(n152) );
  OAI222X1MTR U437 ( .A0(n429), .A1(n441), .B0(n427), .B1(n440), .C0(n345), 
        .C1(n439), .Y(n144) );
  OAI222X1MTR U438 ( .A0(n422), .A1(n441), .B0(n421), .B1(n440), .C0(n339), 
        .C1(n439), .Y(n136) );
  OAI222X1MTR U439 ( .A0(n424), .A1(n441), .B0(n423), .B1(n440), .C0(n343), 
        .C1(n439), .Y(n128) );
  OAI222X1MTR U440 ( .A0(n420), .A1(n441), .B0(n419), .B1(n440), .C0(n340), 
        .C1(n439), .Y(n120) );
  OAI22X1MTR U441 ( .A0(n346), .A1(n439), .B0(n441), .B1(n416), .Y(n112) );
  AOI21X1MTR U442 ( .A0(n384), .A1(n383), .B0(n441), .Y(
        lut_result_in_SYN_3__21_) );
  AOI22X1MTR U443 ( .A0(burst_case_SYN_2_), .A1(tanh_result_input2_SYN_3__21_), 
        .B0(burst_case_SYN_3_), .B1(tanh_result_input3_SYN_3__21_), .Y(n384)
         );
  AOI22X1MTR U444 ( .A0(burst_case_SYN_0_), .A1(tanh_result_input0_SYN_3__21_), 
        .B0(n385), .B1(tanh_result_input1_SYN_3__21_), .Y(n383) );
  OAI22X1MTR U445 ( .A0(n437), .A1(n411), .B0(n335), .B1(n436), .Y(n159) );
  OAI222X1MTR U446 ( .A0(n438), .A1(n451), .B0(n450), .B1(n437), .C0(n336), 
        .C1(n436), .Y(n151) );
  OAI222X1MTR U447 ( .A0(n429), .A1(n438), .B0(n427), .B1(n437), .C0(n344), 
        .C1(n436), .Y(n143) );
  OAI222X1MTR U448 ( .A0(n422), .A1(n438), .B0(n421), .B1(n437), .C0(n339), 
        .C1(n436), .Y(n135) );
  OAI222X1MTR U449 ( .A0(n424), .A1(n438), .B0(n423), .B1(n437), .C0(n342), 
        .C1(n436), .Y(n127) );
  OAI222X1MTR U450 ( .A0(n420), .A1(n438), .B0(n419), .B1(n437), .C0(n341), 
        .C1(n436), .Y(n119) );
  OAI22X1MTR U451 ( .A0(n418), .A1(n436), .B0(n438), .B1(n416), .Y(n111) );
  AOI21X1MTR U452 ( .A0(n358), .A1(n357), .B0(n438), .Y(
        lut_result_in_SYN_2__21_) );
  AOI22X1MTR U453 ( .A0(burst_case_SYN_2_), .A1(tanh_result_input2_SYN_2__21_), 
        .B0(n412), .B1(tanh_result_input3_SYN_2__21_), .Y(n358) );
  AOI22X1MTR U454 ( .A0(n415), .A1(tanh_result_input0_SYN_2__21_), .B0(n385), 
        .B1(tanh_result_input1_SYN_2__21_), .Y(n357) );
  OAI22X1MTR U455 ( .A0(n446), .A1(n411), .B0(n334), .B1(n445), .Y(n158) );
  OAI222X1MTR U456 ( .A0(n447), .A1(n451), .B0(n450), .B1(n446), .C0(n337), 
        .C1(n445), .Y(n150) );
  OAI222X1MTR U457 ( .A0(n429), .A1(n447), .B0(n427), .B1(n446), .C0(n345), 
        .C1(n445), .Y(n142) );
  OAI222X1MTR U458 ( .A0(n422), .A1(n447), .B0(n421), .B1(n446), .C0(n339), 
        .C1(n445), .Y(n134) );
  OAI222X1MTR U459 ( .A0(n424), .A1(n447), .B0(n423), .B1(n446), .C0(n343), 
        .C1(n445), .Y(n126) );
  OAI222X1MTR U460 ( .A0(n420), .A1(n447), .B0(n419), .B1(n446), .C0(n341), 
        .C1(n445), .Y(n118) );
  OAI22X1MTR U461 ( .A0(n346), .A1(n445), .B0(n447), .B1(n416), .Y(n110) );
  AOI21X1MTR U462 ( .A0(n352), .A1(n351), .B0(n447), .Y(
        lut_result_in_SYN_1__21_) );
  AOI22X1MTR U463 ( .A0(n392), .A1(tanh_result_input2_SYN_1__21_), .B0(n412), 
        .B1(tanh_result_input3_SYN_1__21_), .Y(n352) );
  AOI22X1MTR U464 ( .A0(n415), .A1(tanh_result_input0_SYN_1__21_), .B0(n393), 
        .B1(tanh_result_input1_SYN_1__21_), .Y(n351) );
  OAI22X1MTR U465 ( .A0(n426), .A1(n411), .B0(n334), .B1(n425), .Y(n165) );
  OAI222X1MTR U466 ( .A0(n337), .A1(n425), .B0(n450), .B1(n426), .C0(n428), 
        .C1(n451), .Y(n157) );
  OAI222X1MTR U467 ( .A0(n429), .A1(n428), .B0(n427), .B1(n426), .C0(n344), 
        .C1(n425), .Y(n149) );
  OAI222X1MTR U468 ( .A0(n422), .A1(n428), .B0(n421), .B1(n426), .C0(n338), 
        .C1(n425), .Y(n141) );
  OAI222X1MTR U469 ( .A0(n424), .A1(n428), .B0(n423), .B1(n426), .C0(n342), 
        .C1(n425), .Y(n133) );
  OAI222X1MTR U470 ( .A0(n420), .A1(n428), .B0(n419), .B1(n426), .C0(n340), 
        .C1(n425), .Y(n125) );
  OAI22X1MTR U471 ( .A0(n425), .A1(n418), .B0(n428), .B1(n416), .Y(n117) );
  AOI21X1MTR U472 ( .A0(n402), .A1(n401), .B0(n428), .Y(
        lut_result_in_SYN_0__21_) );
  AOI22X1MTR U473 ( .A0(n392), .A1(tanh_result_input2_SYN_0__21_), .B0(n397), 
        .B1(tanh_result_input3_SYN_0__21_), .Y(n402) );
  AOI22X1MTR U474 ( .A0(n398), .A1(tanh_result_input0_SYN_0__21_), .B0(n393), 
        .B1(tanh_result_input1_SYN_0__21_), .Y(n401) );
  OAI22X1MTR U475 ( .A0(n346), .A1(n442), .B0(n444), .B1(n416), .Y(n115) );
  OAI22X1MTR U476 ( .A0(n346), .A1(n430), .B0(n432), .B1(n416), .Y(n116) );
  OAI222X1MTR U477 ( .A0(n420), .A1(n444), .B0(n419), .B1(n443), .C0(n340), 
        .C1(n442), .Y(n123) );
  OAI222X1MTR U478 ( .A0(n420), .A1(n432), .B0(n419), .B1(n431), .C0(n341), 
        .C1(n430), .Y(n124) );
  OAI222X1MTR U479 ( .A0(n424), .A1(n444), .B0(n423), .B1(n443), .C0(n343), 
        .C1(n442), .Y(n131) );
  OAI222X1MTR U480 ( .A0(n424), .A1(n432), .B0(n423), .B1(n431), .C0(n342), 
        .C1(n430), .Y(n132) );
  OAI222X1MTR U481 ( .A0(n422), .A1(n444), .B0(n421), .B1(n443), .C0(n338), 
        .C1(n442), .Y(n139) );
  OAI222X1MTR U482 ( .A0(n422), .A1(n432), .B0(n421), .B1(n431), .C0(n338), 
        .C1(n430), .Y(n140) );
  OAI222X1MTR U483 ( .A0(n429), .A1(n444), .B0(n427), .B1(n443), .C0(n344), 
        .C1(n442), .Y(n147) );
  OAI222X1MTR U484 ( .A0(n429), .A1(n432), .B0(n427), .B1(n431), .C0(n345), 
        .C1(n430), .Y(n148) );
  OAI222X1MTR U485 ( .A0(n444), .A1(n451), .B0(n450), .B1(n443), .C0(n336), 
        .C1(n442), .Y(n155) );
  OAI222X1MTR U486 ( .A0(n432), .A1(n451), .B0(n450), .B1(n431), .C0(n336), 
        .C1(n430), .Y(n156) );
  AOI21X1MTR U487 ( .A0(n370), .A1(n369), .B0(n444), .Y(
        lut_result_in_SYN_6__21_) );
  AOI22X1MTR U488 ( .A0(n392), .A1(tanh_result_input2_SYN_6__21_), .B0(n379), 
        .B1(tanh_result_input3_SYN_6__21_), .Y(n370) );
  AOI22X1MTR U489 ( .A0(n380), .A1(tanh_result_input0_SYN_6__21_), .B0(n393), 
        .B1(tanh_result_input1_SYN_6__21_), .Y(n369) );
  OAI22X1MTR U490 ( .A0(n443), .A1(n411), .B0(n335), .B1(n442), .Y(n163) );
  AOI21X1MTR U491 ( .A0(n391), .A1(n390), .B0(n432), .Y(
        lut_result_in_SYN_7__21_) );
  AOI22X1MTR U492 ( .A0(n392), .A1(tanh_result_input2_SYN_7__21_), .B0(n397), 
        .B1(tanh_result_input3_SYN_7__21_), .Y(n391) );
  AOI22X1MTR U493 ( .A0(n398), .A1(tanh_result_input0_SYN_7__21_), .B0(n385), 
        .B1(tanh_result_input1_SYN_7__21_), .Y(n390) );
  OAI22X1MTR U494 ( .A0(n431), .A1(n411), .B0(n335), .B1(n430), .Y(n164) );
  INVX1MTR U495 ( .A(tanh_result_input0_SYN_1__9_), .Y(n334) );
  INVX1MTR U496 ( .A(tanh_result_input0_SYN_1__9_), .Y(n335) );
  INVX1MTR U497 ( .A(tanh_result_input0_SYN_1__10_), .Y(n336) );
  INVX1MTR U498 ( .A(tanh_result_input0_SYN_1__10_), .Y(n337) );
  INVX1MTR U499 ( .A(tanh_result_input0_SYN_1__12_), .Y(n338) );
  INVX1MTR U500 ( .A(tanh_result_input0_SYN_1__12_), .Y(n339) );
  INVX1MTR U501 ( .A(tanh_result_input0_SYN_1__14_), .Y(n340) );
  INVX1MTR U502 ( .A(tanh_result_input0_SYN_1__14_), .Y(n341) );
  INVX1MTR U503 ( .A(tanh_result_input0_SYN_1__13_), .Y(n342) );
  INVX1MTR U504 ( .A(tanh_result_input0_SYN_1__13_), .Y(n343) );
  INVX1MTR U505 ( .A(tanh_result_input0_SYN_1__11_), .Y(n344) );
  INVX1MTR U506 ( .A(tanh_result_input0_SYN_1__11_), .Y(n345) );
  INVX1MTR U507 ( .A(sig_pos_result_input_SYN_14_), .Y(n346) );
  BUFX2MTR U508 ( .A(burst_case_SYN_2_), .Y(n392) );
  BUFX2MTR U509 ( .A(burst_case_SYN_3_), .Y(n412) );
  BUFX2MTR U510 ( .A(burst_case_SYN_0_), .Y(n415) );
  BUFX2MTR U511 ( .A(burst_case_SYN_1_), .Y(n393) );
  BUFX2MTR U512 ( .A(burst_case_SYN_2_), .Y(n413) );
  BUFX2MTR U513 ( .A(burst_case_SYN_1_), .Y(n385) );
  BUFX2MTR U514 ( .A(burst_case_SYN_2_), .Y(n396) );
  BUFX2MTR U515 ( .A(burst_case_SYN_3_), .Y(n379) );
  BUFX2MTR U516 ( .A(burst_case_SYN_0_), .Y(n380) );
  BUFX2MTR U517 ( .A(burst_case_SYN_1_), .Y(n414) );
  BUFX2MTR U518 ( .A(burst_case_SYN_3_), .Y(n397) );
  BUFX2MTR U519 ( .A(burst_case_SYN_0_), .Y(n398) );
  BUFX2MTR U520 ( .A(n453), .Y(n417) );
  BUFX2MTR U521 ( .A(n453), .Y(n454) );
  BUFX2MTR U522 ( .A(n453), .Y(n455) );
  BUFX2MTR U523 ( .A(n453), .Y(n456) );
  BUFX2MTR U524 ( .A(n453), .Y(n457) );
endmodule

