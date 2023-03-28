#----------------------------------------------------------------------
# environment
#----------------------------------------------------------------------
sh date '+DATE: 20%y/%m/%d, TIME:%H:%M'

#set LIB_TYPE                "sec130"
set LIB_TYPE                "sec065"

set TOP_NAME                PIM_ALU_SYN_top

set SYN_ROOT_DIR            [pwd]

#cd ../Posit-HDL-Arithmetic
#set RTL_ROOT_DIR            [pwd]
#cd $SYN_ROOT_DIR

set INCLUDE_DIR		[concat "../rtl/" \
		/usr/synopsys/syn_vM-2016.12-SP5-3/dw/syn_ver \
		/usr/synopsys/syn_vM-2016.12-SP5-3/dw/sim_ver \
		/usr/synopsys/syn_vM-2016.12-SP5-3/libraries/syn \
		/usr/synopsys/syn_vM-2016.12-SP5-3/minpower/syn \
		]
cd ../rtl/
set RTL_ROOT_DIR            [pwd]

cd $SYN_ROOT_DIR
set RTL_LIST                ./scripts/v_list
set FILE_LIST               [list]


set REPORT_DIR              ./reports
set NETLIST_DIR             ./results
set NETLIST_NAME_BASE       [format "%s%s%s%s%s" $NETLIST_DIR / $TOP_NAME . $LIB_TYPE]
set REPORT_NAME_BASE        [format "%s%s%s%s%s" $REPORT_DIR  / $TOP_NAME . $LIB_TYPE]

#----------------------------------------------------------------------
# library
#----------------------------------------------------------------------
set std_lib_path 		/usr/syn_lib/samsung/CB_121st_tt/PRIMITIVE/sec100226_0042_SS65LP_Normal_RVT_Normal_FE_Common_N/synopsys

#----------------------------------------------------------------------
# set search_path
#----------------------------------------------------------------------
set search_path             [concat . \
                             ./WORK \
                             ${std_lib_path} \
                             ${INCLUDE_DIR} \
                             ${search_path} \
                            ]

#----------------------------------------------------------------------
# setup
#----------------------------------------------------------------------

set_host_options -max_cores 8

set std_lib_max             scmetro_cmos10lp_rvt_ss_1p08v_125c_sadhm
set std_lib_min             scmetro_cmos10lp_rvt_ff_1p32v_m40c_sadhm

set target_library          [list $std_lib_max.db]

set synthetic_library       {dw_foundation.sldb dw_minpower.sldb standard.sldb}
set link_library            [concat * $target_library \
                              $synthetic_library
                            ]
set alib_library_analysis_path      .
define_design_lib           "MY_LIB" -path ./WORK

#----------------------------------------------------------------------
# synthesis variables
#----------------------------------------------------------------------
set verilogout_single_bit                       false
set verilogout_show_unconnected_pins            true
set verilogout_higher_designs_first             true
set auto_link_options                           -all
set auto_link_disable                           false
set power_cg_ext_feedback_loop                  false 
set change_names_use_alternative                true
set compile_seqmap_no_scan_cell                 true
set compile_seqmap_propagate_constants          true
set compile_seqmap_synchronous_extraction       true
set compile_delete_unloaded_sequential_cells    true
set compile_seqmap_propagate_high_effort        false
set power_keep_license_after_power_commands     true
set hdlin_enable_rtldrc_info                    true
set hdlin_check_user_full_case                  true
set hdlin_check_user_parallel_case              true

set set_default_scan_style                      multiplexed_flip_flop
set SNPSLMD_QUEUE                               true
set compile_disable_hierarchical_inverter_opt   true
set compile_register_replication                false
set compile_enable_register_merging             true
set report_default_significant_digits           3

define_name_rules raon_verilog -type port \
                               -equal_ports_nets  \
                               -allowed {A-Z a-z 0-9 _ [] !} \
                               -first_restricted {0-9 _ !}   

define_name_rules raon_verilog -type cell \
                               -allowed {A-Z a-z 0-9 _ !} \
                               -first_restricted {0-9 _ !} \
                               -map {{{"\\*cell\\*", "U"}, {"*-return", "RET"}}}    

define_name_rules raon_verilog -type net \
                               -equal_ports_nets \
                               -allowed {A-Z a-z 0-9 _ !} \
                               -first_restricted {0-9 _ !} \
                               -map {{{"\\*cell\\*", "n"}, {"*-return", "RET"}}}    

define_name_rules raon_verilog -remove_internal_net_bus -equal_ports_nets

set bus_naming_style {%s[%d]}

#----------------------------------------------------------------------
# RTL read
#----------------------------------------------------------------------
 set fid [open ${RTL_LIST}]
 set file_list [read $fid]
 set def_list ""
 close $fid

 foreach file_name $file_list {
   set abs_file_name ${file_name}
   analyze \
    -format verilog $abs_file_name \
    -work MY_LIB \
    -define ${def_list} 
 }

 elaborate ${TOP_NAME} -work MY_LIB
 current_design ${TOP_NAME}
 change_names -rules raon_verilog -hierarchy -verbose
 link
 uniquify


#----------------------------------------------------------------------
# check design 
#----------------------------------------------------------------------
redirect $REPORT_NAME_BASE.check_design_link.rpt \
{ check_design -multiple_designs }

#----------------------------------------------------------------------
# clocks, inputs, outputs
#----------------------------------------------------------------------
set_fix_multiple_port_nets -all -buffer_constants [current_design]
#set_max_fanout 8.0 [current_design]
#set_max_transition 2.0 [current_design]

source -echo -verbose ./scripts/constraints.tcl

#set_fix_hold [all_clocks]

current_design ${TOP_NAME}
set_fix_multiple_port_nets -all -buffer_constants

#----------------------------------------------------------------------
# wire load model
#----------------------------------------------------------------------
#set auto_wire_load_selection "true"
#set auto_wire_load_selection false

#set_wire_load_mode segmented
#set_wire_load_model -name "cmos10lp_wl10"
#set_wire_load_model -name "cmos10lp_wl30" [get_designs buf_wrap*]
#set_wire_load_model -name "cmos10lp_wl10" [get_designs pe_buf_wrap*]

#----------------------------------------------------------------------
# operating condition
#----------------------------------------------------------------------
#set_operating_conditions -max op_cond -max_lib ${std_lib_max} \
                         -min op_cond -min_lib ${std_lib_min}
#set_operating_conditions -max tt_1p2v_25c -max_lib ${std_lib_typ} \
                         -min tt_1p2v_25c -min_lib ${std_lib_typ}

set_max_leakage_power 1000000
#set_max_area 10000000
set_max_area 0
#set_max_area 0.0 -ignore_tns
#set_max_dynamic_power 0
#--- cost priority
#set_cost_priority -delay                ;# for post
#set_cost_priority -default

#set_cost_priority {min_delay max_delay} ;# for pre

#set_switching_activity -toggle_rate 0.1


### check design
redirect $REPORT_NAME_BASE.check_design_constraints.rpt \
{ check_design }

#----------------------------------------------------------------------
# first compile
#----------------------------------------------------------------------

current_design ${TOP_NAME}

#set OPT_RETIME -retime
#set OPT_RETIME -timing_high_effort_script
set OPT_RETIME -area_high_effort_script
#optimize_netlist -area
#set_dont_retime [get_cells *] true
#set_app_var compile_timing_high_effort true

#set compile_timing_high_effort true
#ungroup -all -flatten

#ungroup U0_BANK_TOP -prefix "BANK_TOP:"

compile_ultra -no_autoungroup -no_seq_output_inversion ${OPT_RETIME}
#compile_ultra

write -format verilog -output "${NETLIST_NAME_BASE}.compile.v"  -hierarchy

redirect $REPORT_NAME_BASE.report_timing_setup_inc0.rpt \
{ report_timing -max_paths 1000 }

#----------------------------------------------------------------------
# second compile
#----------------------------------------------------------------------
current_design ${TOP_NAME}
foreach_in_collection design_list [find -h design *] {
    current_design $design_list
    set_fix_multiple_port_nets -all -buffer_constants
    report_compile_options
}

current_design ${TOP_NAME}
set_fix_multiple_port_nets -all -buffer_constants

current_design ${TOP_NAME}
compile_ultra -incremental -only_design_rule

compile_ultra -incremental
redirect $REPORT_NAME_BASE.report_timing_setup_inc1.rpt \
{ report_timing -max_paths 1000 }

#optimize_registers
compile_ultra -incremental
redirect $REPORT_NAME_BASE.report_timing_setup_inc2.rpt \
 { report_timing -max_paths 1000 }
compile_ultra -incremental
redirect $REPORT_NAME_BASE.report_timing_setup_inc3.rpt \
 { report_timing -max_paths 1000 }
compile_ultra -incremental 
# redirect $REPORT_NAME_BASE.report_timing_setup_inc4.rpt \
#  { report_timing -max_paths 1000 }
# compile_ultra -retime -incremental
# redirect $REPORT_NAME_BASE.report_timing_setup_inc5.rpt \
#  { report_timing -max_paths 1000 }
# compile_ultra -retime -incremental
# redirect $REPORT_NAME_BASE.report_timing_setup_inc6.rpt \
#  { report_timing -max_paths 1000 }
# compile_ultra -retime -incremental
# redirect $REPORT_NAME_BASE.report_timing_setup_inc7.rpt \
#  { report_timing -max_paths 1000 }
# compile_ultra -retime -incremental
# redirect $REPORT_NAME_BASE.report_timing_setup_inc8.rpt \
#  { report_timing -max_paths 1000 }

change_names -rules raon_verilog -hierarchy -verbose
write_sdc -version 1.7 "$NETLIST_NAME_BASE.sdc"
write_sdf -context verilog -version 1.7 "$NETLIST_NAME_BASE.sdf"
write -format verilog -output "$NETLIST_NAME_BASE.v"  -hierarchy
write -format ddc     -output "$NETLIST_NAME_BASE.ddc" -hierarchy

#----------------------------------------------------------------------
# check & report
#----------------------------------------------------------------------
redirect $REPORT_NAME_BASE.report_resources.rpt \
  { report_resources -hierarchy}

#-- Setup
redirect $REPORT_NAME_BASE.report_lib.rpt \
  { report_lib ${std_lib_max} }

#-- Read verilog
redirect $REPORT_NAME_BASE.report_hierarchy.rpt \
  { report_hierarchy }

#-- Wire Load Model(WLM)
redirect $REPORT_NAME_BASE.report_wire_load.rpt \
  { report_wire_load }

#-- Operating Conditions
redirect $REPORT_NAME_BASE.report_operating_conditions.rpt \
  { report_operating_conditions -library ${std_lib_max} }
redirect -append $REPORT_NAME_BASE.report_operating_conditions.rpt \
  { report_operating_conditions -library ${std_lib_min} }

#-- Clocks
redirect $REPORT_NAME_BASE.report_clock_skew.rpt \
  { report_clock -skew }

#-- Reset / Scan Ports
redirect $REPORT_NAME_BASE.report_ideal_network.rpt \
  { report_ideal_network }

#-- Delay and Drive Strength on Input Ports
redirect $REPORT_NAME_BASE.report_port_inputs.rpt \
  { report_port -v [all_inputs] }

#-- Delay and Load on Output Ports
redirect $REPORT_NAME_BASE.report_port_outputs.rpt \
  { report_port -v [all_outputs] }

#-- Check Design
redirect $REPORT_NAME_BASE.check_design.rpt \
  { check_design -multiple_designs }

#-- Check Timing
redirect $REPORT_NAME_BASE.check_timing.rpt \
  { check_timing }

#-- Miscs
redirect $REPORT_NAME_BASE.report_area.rpt { report_area -hier }
redirect $REPORT_NAME_BASE.report_qor.rpt { report_qor }
redirect $REPORT_NAME_BASE.report_reference.rpt { report_reference }

#-- Report Timing
redirect $REPORT_NAME_BASE.report_timing_setup.rpt \
  { report_timing -delay max -nosplit -sig 3 }
  
redirect $REPORT_NAME_BASE.report_timing_hold.rpt \
  { report_timing -delay min -nosplit -sig 3 }

redirect $REPORT_NAME_BASE.report_timing_setup_1000.rpt \
  { report_timing -max_paths 1000 }

redirect $REPORT_NAME_BASE.report_timing_setup_input.rpt \
  { report_timing -max_paths 1000 -from $all_inputs_no_clocks }

redirect $REPORT_NAME_BASE.report_timing_setup_output.rpt \
  { report_timing -max_paths 1000 -from [all_outputs] }

#-- Report All Violations
redirect $REPORT_NAME_BASE.report_constraint_allvio.sum \
  { report_constraint  -all_violators -nosplit -sig 3 }

redirect $REPORT_NAME_BASE.report_constraint_allvio.rpt \
  { report_constraint -verbose -all_violators -nosplit }

redirect $REPORT_NAME_BASE.report_constraint_max_trans.rpt \
  { report_constraint -all_violators -max_transition -nosplit }

#--
redirect $REPORT_NAME_BASE.report_clock.rpt \
  { report_clock -attributes }

#--
redirect $REPORT_NAME_BASE.report_clock_timing_skew.rpt \
  { report_clock_timing -type skew -include_uncertainty_in_skew -significant_digits 3 \
                        -nworst 1000 -to [all_registers -clock_pins] }      

#--
redirect $REPORT_NAME_BASE.report_clock_gating.rpt \
  { report_clock_gating -gating_elements -gated -ungated -hier }

#-- Report Power
redirect $REPORT_NAME_BASE.report_power.rpt \
  { report_power }

redirect $REPORT_NAME_BASE.report_timing_derate.rpt \
  { report_timing_derate }

#svf
set_svf -off

exit
