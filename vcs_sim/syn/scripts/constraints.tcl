#/*--========================================================================--*/
#set period_margin_f		0.80
#set period_margin_f		0.65
#set period_margin_f		0.85	; # pre-layout constraints
#set period_margin_f		0.50
set period_margin_f		1.00


#----------------------------------------------------------

 #set src_period			    [expr 1.515]
 set src_period         [expr 20.0]

 set prd_clk_core			[expr ${src_period} * ${period_margin_f}]

 set CLOCK_SLEW 			[expr 0.1]

#ext clk
 set pin_ext_clk     [get_port clk] 
#reset 
 set pin_ext_rst     [get_port rst_x]


#--- ext_clk
 create_clock           -name clk_ext -period ${prd_clk_core} -waveform [list 0 [expr ${prd_clk_core} / 2]]  $pin_ext_clk

#--- ideal network
  set_ideal_network -no_propagate $pin_ext_clk
  set_ideal_network -no_propagate $pin_ext_rst

  set_false_path   -through $pin_ext_rst
#/*--========================================================================--*/
#/*    Define a clock transition time variable.                                */
#/*    Fujitsu recommends mandatorily that a clock transition time be set      */
#/*    to 399ps.                                                               */
#/*--========================================================================--*/

#/*--========================================================================--*/
#/*    Set clock transition time of FF's CK pin. (MTTV) for ideal clock        */
#/*--========================================================================--*/
#set all_clocks_no_vclk [remove_from_collection [all_clocks] [get_clocks  [list vclk]]]
#set_clock_transition $CLOCK_SLEW $all_clocks_no_vclk

#/*--========================================================================--*/
#/*    Set dont_touch attribute of clock network.                              */
#/*--========================================================================--*/
#set_dont_touch_network [all_clocks]
#set_fix_hold           [all_clocks]

#/******************************************************************************/
#/*    Boundary conditions                                                     */
#/******************************************************************************/
#/*--========================================================================--*/
#/*    Set input delay time of primary inputs except clock inputs.             */
#/*    Edit clkportname, delay value and  systemclk*.                          */
#/*--========================================================================--*/
set all_inputs_no_clocks [remove_from_collection [all_inputs] \
                                                 [get_ports  [list \
                                                    clk\
                                                 ]]]
set_input_delay  0 -clock [get_clocks clk_ext] $all_inputs_no_clocks
set_output_delay 0 -clock [get_clocks clk_ext] [all_outputs]
#0.5
#/*--========================================================================--*/
#/*    Set transition time of all primary inputs.                              */
#/*--========================================================================--*/
set_input_transition 0.5   $all_inputs_no_clocks
#set_driving_cell -lib_cell DFFRHQX1MTR -pin Q -library scmetro_cmos10lp_rvt_ss_1p08v_125c_sadhm $all_inputs_no_clocks
#set_driving_cell    -lib_cell DFFR_X1    -pin Q  -library cmos10lplvt_ntv_ss $all_inputs_no_clocks

#--- false path
#--- load budget
#set MAX_INPUT_LOAD  [expr [load_of [format "%s%s"   $std_lib_max "/INVX1MTR/A"]] * 100]
#set_max_capacitance ${MAX_INPUT_LOAD}               $all_inputs_no_clocks
#set_load            [expr $MAX_INPUT_LOAD * 3]      [all_outputs]
#set_wire_load_model -name zero-wire-load-model

#--- max fanout
set_max_fanout 8.0 [current_design]

#--- timing_drate for SRAM cell (Only for pre)
#set mem_cell_list           [list cmos10lpsvrv_ra1w_hd_32768x32m32 \
                                  cmos10lphvrv_ra2w_met_256x32m4   \
                                  cmos10lphvrv_ra2_met_256x20m4    \
                                  cmos10lphvrv_ra2w_met_256x128m4  \
                                  cmos10lpsvrv_ra1w_hd_256x128m8   \
                                  cmos10lpsvrv_ra1_hd_256x20m8]

#foreach mem_cell $mem_cell_list {
#set_timing_derate -cell_check -late 0.70 [get_lib_cells [format "%s%s" */ $mem_cell]]
#set_timing_derate -cell_delay -late 0.70 [get_lib_cells [format "%s%s" */ $mem_cell]]
#}

#set mem_cell_list           [list U_PAD/U0_TOP/U2_SRAM/CHIP_* \
                                  U_PAD/U0_TOP/U_PLATFORM_WRAPPER/U1_PLATFORM/U0_LUCIDA_TOP/LUCIDA_SCP_TOP/ICACHE/ICACHE_4WAY_SRAM/L_WAY_*DATA*     \
                                  U_PAD/U0_TOP/U_PLATFORM_WRAPPER/U1_PLATFORM/U0_LUCIDA_TOP/LUCIDA_SCP_TOP/ICACHE/ICACHE_4WAY_SRAM/L_WAY_*TAG*      \
                                  U_PAD/U0_TOP/U_PLATFORM_WRAPPER/U1_PLATFORM/U0_LUCIDA_TOP/LUCIDA_SCP_TOP/DCACHE_4WAY/L_DATA_SRAM_WAY_*            \
                                  U_PAD/U0_TOP/U_PLATFORM_WRAPPER/U1_PLATFORM/U0_LUCIDA_TOP/LUCIDA_SCP_TOP/DCACHE_4WAY/L_TAG_SRAM_WAY_*TAG*         ]

#foreach mem_cell $mem_cell_list {
#set_timing_derate -cell_check -late 0.70 [get_cells $mem_cell]
#set_timing_derate -cell_delay -late 0.70 [get_cells $mem_cell]
#set_clock_uncertainty  -hold 0.135 [get_pins -of_object [get_cells $mem_cell]]
#}
