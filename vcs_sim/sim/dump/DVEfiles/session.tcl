# Begin_DVE_Session_Save_Info
# DVE full session
# Saved on Thu Dec 22 11:55:16 2022
# Designs open: 1
#   V1: /home/kch/work/TDRAM/run_app_platform/Device_top_sim_GDDR6/sim/dump/Dev_top_test.vpd
# Toplevel windows open: 1
# 	TopLevel.2
#   Wave.1: 19 signals
#   Group count = 7
#   Group Group1 signal count = 4
#   Group Group2 signal count = 0
#   Group Group3 signal count = 7
#   Group Group4 signal count = 4
#   Group Group5 signal count = 4
#   Group Group6 signal count = 36
#   Group Group7 signal count = 25
# End_DVE_Session_Save_Info

# DVE version: K-2015.09-SP1_Full64
# DVE build date: Nov 24 2015 21:15:24


#<Session mode="Full" path="/home/kch/work/TDRAM/run_app_platform/Device_top_sim_GDDR6/sim/dump/DVEfiles/session.tcl" type="Debug">

gui_set_loading_session_type Post
gui_continuetime_set

# Close design
if { [gui_sim_state -check active] } {
    gui_sim_terminate
}
gui_close_db -all
gui_expr_clear_all

# Close all windows
gui_close_window -type Console
gui_close_window -type Wave
gui_close_window -type Source
gui_close_window -type Schematic
gui_close_window -type Data
gui_close_window -type DriverLoad
gui_close_window -type List
gui_close_window -type Memory
gui_close_window -type HSPane
gui_close_window -type DLPane
gui_close_window -type Assertion
gui_close_window -type CovHier
gui_close_window -type CoverageTable
gui_close_window -type CoverageMap
gui_close_window -type CovDetail
gui_close_window -type Local
gui_close_window -type Stack
gui_close_window -type Watch
gui_close_window -type Group
gui_close_window -type Transaction



# Application preferences
gui_set_pref_value -key app_default_font -value {Helvetica,10,-1,5,50,0,0,0,0,0}
gui_src_preferences -tabstop 8 -maxbits 24 -windownumber 1
#<WindowLayout>

# DVE top-level session


# Create and position top-level window: TopLevel.2

if {![gui_exist_window -window TopLevel.2]} {
    set TopLevel.2 [ gui_create_window -type TopLevel \
       -icon $::env(DVE)/auxx/gui/images/toolbars/dvewin.xpm] 
} else { 
    set TopLevel.2 TopLevel.2
}
gui_show_window -window ${TopLevel.2} -show_state normal -rect {{678 369} {3235 1371}}

# ToolBar settings
gui_set_toolbar_attributes -toolbar {TimeOperations} -dock_state top
gui_set_toolbar_attributes -toolbar {TimeOperations} -offset 0
gui_show_toolbar -toolbar {TimeOperations}
gui_hide_toolbar -toolbar {&File}
gui_set_toolbar_attributes -toolbar {&Edit} -dock_state top
gui_set_toolbar_attributes -toolbar {&Edit} -offset 0
gui_show_toolbar -toolbar {&Edit}
gui_hide_toolbar -toolbar {CopyPaste}
gui_set_toolbar_attributes -toolbar {&Trace} -dock_state top
gui_set_toolbar_attributes -toolbar {&Trace} -offset 0
gui_show_toolbar -toolbar {&Trace}
gui_hide_toolbar -toolbar {TraceInstance}
gui_hide_toolbar -toolbar {BackTrace}
gui_set_toolbar_attributes -toolbar {&Scope} -dock_state top
gui_set_toolbar_attributes -toolbar {&Scope} -offset 0
gui_show_toolbar -toolbar {&Scope}
gui_set_toolbar_attributes -toolbar {&Window} -dock_state top
gui_set_toolbar_attributes -toolbar {&Window} -offset 0
gui_show_toolbar -toolbar {&Window}
gui_set_toolbar_attributes -toolbar {Signal} -dock_state top
gui_set_toolbar_attributes -toolbar {Signal} -offset 0
gui_show_toolbar -toolbar {Signal}
gui_set_toolbar_attributes -toolbar {Zoom} -dock_state top
gui_set_toolbar_attributes -toolbar {Zoom} -offset 0
gui_show_toolbar -toolbar {Zoom}
gui_set_toolbar_attributes -toolbar {Zoom And Pan History} -dock_state top
gui_set_toolbar_attributes -toolbar {Zoom And Pan History} -offset 0
gui_show_toolbar -toolbar {Zoom And Pan History}
gui_set_toolbar_attributes -toolbar {Grid} -dock_state top
gui_set_toolbar_attributes -toolbar {Grid} -offset 0
gui_show_toolbar -toolbar {Grid}
gui_hide_toolbar -toolbar {Simulator}
gui_hide_toolbar -toolbar {Interactive Rewind}
gui_set_toolbar_attributes -toolbar {Testbench} -dock_state top
gui_set_toolbar_attributes -toolbar {Testbench} -offset 0
gui_show_toolbar -toolbar {Testbench}

# End ToolBar settings

# Docked window settings
gui_sync_global -id ${TopLevel.2} -option true

# MDI window settings
set Wave.1 [gui_create_window -type {Wave}  -parent ${TopLevel.2}]
gui_show_window -window ${Wave.1} -show_state maximized
gui_update_layout -id ${Wave.1} {{show_state maximized} {dock_state undocked} {dock_on_new_line false} {child_wave_left 742} {child_wave_right 1810} {child_wave_colname 296} {child_wave_colvalue 442} {child_wave_col1 0} {child_wave_col2 1}}

# End MDI window settings

gui_set_env TOPLEVELS::TARGET_FRAME(Source) none
gui_set_env TOPLEVELS::TARGET_FRAME(Schematic) none
gui_set_env TOPLEVELS::TARGET_FRAME(PathSchematic) none
gui_set_env TOPLEVELS::TARGET_FRAME(Wave) none
gui_set_env TOPLEVELS::TARGET_FRAME(List) none
gui_set_env TOPLEVELS::TARGET_FRAME(Memory) none
gui_set_env TOPLEVELS::TARGET_FRAME(DriverLoad) none
gui_update_statusbar_target_frame ${TopLevel.2}

#</WindowLayout>

#<Database>

# DVE Open design session: 

if { ![gui_is_db_opened -db {/home/kch/work/TDRAM/run_app_platform/Device_top_sim_GDDR6/sim/dump/Dev_top_test.vpd}] } {
	gui_open_db -design V1 -file /home/kch/work/TDRAM/run_app_platform/Device_top_sim_GDDR6/sim/dump/Dev_top_test.vpd -nosource
}
gui_set_precision 10ps
gui_set_time_units 10ps
#</Database>

# DVE Global setting session: 


# Global: Bus

# Global: Expressions

# Global: Signal Time Shift

# Global: Signal Compare

# Global: Signal Groups
gui_load_child_values {testbench.U0_BANK_GDDR6_TOP.ACC_GEN[0].NORM_LOGIC}
gui_load_child_values {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU}
gui_load_child_values {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0}


set _session_group_1 Group1
gui_sg_create "$_session_group_1"
set Group1 "$_session_group_1"

gui_sg_addsignal -group "$_session_group_1" { testbench.U0_BANK_GDDR6_TOP.clk testbench.U0_BANK_GDDR6_TOP.src_A_RD_pass testbench.U0_BANK_GDDR6_TOP.src_B_RD_pass testbench.U0_BANK_GDDR6_TOP.dst_C_WR_pass }

set _session_group_2 Group2
gui_sg_create "$_session_group_2"
set Group2 "$_session_group_2"


set _session_group_3 Group3
gui_sg_create "$_session_group_3"
set Group3 "$_session_group_3"

gui_sg_addsignal -group "$_session_group_3" { testbench.U0_BANK_GDDR6_TOP.DRAM_data testbench.U0_BANK_GDDR6_TOP.PIM_RD_A_sig testbench.U0_BANK_GDDR6_TOP.PIM_RD_B_sig testbench.U0_BANK_GDDR6_TOP.PIM_WR_C_sig testbench.U0_BANK_GDDR6_TOP.PIM_vecA_read_burst testbench.U0_BANK_GDDR6_TOP.PIM_vecB_read_burst testbench.U0_BANK_GDDR6_TOP.global_burst_cnt_SCAL_gran }

set _session_group_4 Group4
gui_sg_create "$_session_group_4"
set Group4 "$_session_group_4"

gui_sg_addsignal -group "$_session_group_4" { testbench.U0_BANK_GDDR6_TOP.alu_src0 testbench.U0_BANK_GDDR6_TOP.alu_src1 testbench.U0_BANK_GDDR6_TOP.vecA testbench.U0_BANK_GDDR6_TOP.vecB }

set _session_group_5 Group5
gui_sg_create "$_session_group_5"
set Group5 "$_session_group_5"

gui_sg_addsignal -group "$_session_group_5" { testbench.U0_BANK_GDDR6_TOP.vACC testbench.U0_BANK_GDDR6_TOP.norm_result testbench.U0_BANK_GDDR6_TOP.PIM_result testbench.U0_BANK_GDDR6_TOP.PIM_result_WB_done }

set _session_group_6 Group6
gui_sg_create "$_session_group_6"
set Group6 "$_session_group_6"

gui_sg_addsignal -group "$_session_group_6" { {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.vACC_sign} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.vACC_mant} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.vACC_in} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.vACC_exp} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.rst_x} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.result_sign} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.result_mant} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.result_exp} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.mul_result_zero} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.is_vecB_start} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.is_vecA_start} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.is_SUB} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.is_MUL} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.is_MAC} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.is_ADD} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.exp_control_r} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.exp_control} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.clk} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.alu_src0} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.alu_src1} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.PIM_vecB_read_burst_r} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.PIM_vecA_read_burst_r} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.MUL0_out_sign_temp} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.MUL0_out_sign} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.MUL0_out_mant} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.MUL0_out_exp} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.ADD0_in_sign} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.ADD0_in_mant} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.ADD0_in_exp} {testbench.U0_BANK_GDDR6_TOP.ACC_GEN[0].NORM_LOGIC.in_exp} {testbench.U0_BANK_GDDR6_TOP.ACC_GEN[0].NORM_LOGIC.in_mant} {testbench.U0_BANK_GDDR6_TOP.ACC_GEN[0].NORM_LOGIC.in_sign} {testbench.U0_BANK_GDDR6_TOP.ACC_GEN[0].NORM_LOGIC.out} {testbench.U0_BANK_GDDR6_TOP.ACC_GEN[0].NORM_LOGIC.out_exp_reg} {testbench.U0_BANK_GDDR6_TOP.ACC_GEN[0].NORM_LOGIC.out_exp_upper} {testbench.U0_BANK_GDDR6_TOP.ACC_GEN[0].NORM_LOGIC.out_mant_reg} }

set _session_group_7 Group7
gui_sg_create "$_session_group_7"
set Group7 "$_session_group_7"

gui_sg_addsignal -group "$_session_group_7" { {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.in_A} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.in_B} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.is_ADD} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.is_SUB} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.PIM_vecA_read_burst_r} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.PIM_vecB_read_burst_r} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.out_mul_sign} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.out_mul_exp} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.out_mul_mant} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.exp_control} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.in_A_sign} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.in_A_exp} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.in_A_mant} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.in_B_sign} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.in_B_exp} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.in_B_mant} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.check_zero} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.exp_add_temp} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.exp_bias_sub} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.mul_sign} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.mul_exp} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.mul_HH} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.mul_HL} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.mul_mant} {testbench.U0_BANK_GDDR6_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.U_MUL0.exp_compare} }

# Global: Highlighting

# Global: Stack
gui_change_stack_mode -mode list

# Post database loading setting...

# Restore C1 time
gui_set_time -C1_only 116000



# Save global setting...

# Wave/List view global setting
gui_cov_show_value -switch false

# Close all empty TopLevel windows
foreach __top [gui_ekki_get_window_ids -type TopLevel] {
    if { [llength [gui_ekki_get_window_ids -parent $__top]] == 0} {
        gui_close_window -window $__top
    }
}
gui_set_loading_session_type noSession
# DVE View/pane content session: 


# View 'Wave.1'
gui_wv_sync -id ${Wave.1} -switch false
set groupExD [gui_get_pref_value -category Wave -key exclusiveSG]
gui_set_pref_value -category Wave -key exclusiveSG -value {false}
set origWaveHeight [gui_get_pref_value -category Wave -key waveRowHeight]
gui_list_set_height -id Wave -height 25
set origGroupCreationState [gui_list_create_group_when_add -wave]
gui_list_create_group_when_add -wave -disable
gui_marker_set_ref -id ${Wave.1}  C1
gui_wv_zoom_timerange -id ${Wave.1} 107333 135712
gui_list_add_group -id ${Wave.1} -after {New Group} {Group1}
gui_list_add_group -id ${Wave.1} -after {New Group} {Group2}
gui_list_add_group -id ${Wave.1} -after {New Group} {Group3}
gui_list_add_group -id ${Wave.1} -after {New Group} {Group4}
gui_list_add_group -id ${Wave.1} -after {New Group} {Group5}
gui_list_expand -id ${Wave.1} testbench.U0_BANK_GDDR6_TOP.alu_src0
gui_list_expand -id ${Wave.1} testbench.U0_BANK_GDDR6_TOP.alu_src1
gui_list_expand -id ${Wave.1} testbench.U0_BANK_GDDR6_TOP.vACC
gui_list_expand -id ${Wave.1} testbench.U0_BANK_GDDR6_TOP.norm_result
gui_list_select -id ${Wave.1} {{testbench.U0_BANK_GDDR6_TOP.alu_src1[0]} }
gui_seek_criteria -id ${Wave.1} {Any Edge}



gui_set_env TOGGLE::DEFAULT_WAVE_WINDOW ${Wave.1}
gui_set_pref_value -category Wave -key exclusiveSG -value $groupExD
gui_list_set_height -id Wave -height $origWaveHeight
if {$origGroupCreationState} {
	gui_list_create_group_when_add -wave -enable
}
if { $groupExD } {
 gui_msg_report -code DVWW028
}
gui_list_set_filter -id ${Wave.1} -list { {Buffer 1} {Input 1} {Others 1} {Linkage 1} {Output 1} {Parameter 1} {All 1} {Aggregate 1} {LibBaseMember 1} {Event 1} {Assertion 1} {Constant 1} {Interface 1} {BaseMembers 1} {Signal 1} {$unit 1} {Inout 1} {Variable 1} }
gui_list_set_filter -id ${Wave.1} -text {*}
gui_list_set_insertion_bar  -id ${Wave.1} -group Group5  -item testbench.U0_BANK_GDDR6_TOP.PIM_result_WB_done -position below

gui_marker_move -id ${Wave.1} {C1} 116000
gui_view_scroll -id ${Wave.1} -vertical -set 1365
gui_show_grid -id ${Wave.1} -enable false
# Restore toplevel window zorder
# The toplevel window could be closed if it has no view/pane
if {[gui_exist_window -window ${TopLevel.2}]} {
	gui_set_active_window -window ${TopLevel.2}
	gui_set_active_window -window ${Wave.1}
}
#</Session>

