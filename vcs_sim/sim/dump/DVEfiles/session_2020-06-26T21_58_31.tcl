# Begin_DVE_Session_Save_Info
# DVE reload session
# Saved on Fri Jun 26 21:58:31 2020
# Designs open: 1
#   V1: /home/kch/work/TDRAM/run_app_platform/Device_top_sim_MAC/sim/dump/Dev_top_test.vpd
# Toplevel windows open: 2
# 	TopLevel.1
# 	TopLevel.2
#   Source.1: testbench
#   Wave.1: 13 signals
#   Group count = 1
#   Group Group1 signal count = 13
# End_DVE_Session_Save_Info

# DVE version: K-2015.09-SP1_Full64
# DVE build date: Nov 24 2015 21:15:24


#<Session mode="Reload" path="/home/kch/work/TDRAM/run_app_platform/Device_top_sim_MAC/sim/dump/DVEfiles/session.tcl" type="Debug">

gui_set_loading_session_type Reload
gui_continuetime_set

# Close design
if { [gui_sim_state -check active] } {
    gui_sim_terminate
}
gui_close_db -all
gui_expr_clear_all
gui_clear_window -type Wave
gui_clear_window -type List

# Application preferences
gui_set_pref_value -key app_default_font -value {Helvetica,10,-1,5,50,0,0,0,0,0}
gui_src_preferences -tabstop 8 -maxbits 24 -windownumber 1
#<WindowLayout>

# DVE top-level session


# Create and position top-level window: TopLevel.1

set TopLevel.1 TopLevel.1

# Docked window settings
set DLPane.1 DLPane.1
set Data.1 Data.1
set Console.1 Console.1
gui_sync_global -id ${TopLevel.1} -option true

# MDI window settings
set HSPane.1 HSPane.1
set Hier.1 Hier.1
gui_update_layout -id ${HSPane.1} {{show_state maximized} {dock_state undocked} {dock_on_new_line false} {child_hier_colhier 461} {child_hier_coltype 60} {child_hier_colpd 0} {child_hier_col1 0} {child_hier_col2 1} {child_hier_col3 -1}}
set Source.1 Source.1
gui_update_layout -id ${Source.1} {{show_state maximized} {dock_state undocked} {dock_on_new_line false}}

# End MDI window settings


# Create and position top-level window: TopLevel.2

set TopLevel.2 TopLevel.2

# Docked window settings
gui_sync_global -id ${TopLevel.2} -option true

# MDI window settings
set Wave.1 Wave.1
gui_update_layout -id ${Wave.1} {{show_state maximized} {dock_state undocked} {dock_on_new_line false} {child_wave_left 557} {child_wave_right 1357} {child_wave_colname 276} {child_wave_colvalue 277} {child_wave_col1 0} {child_wave_col2 1}}

# End MDI window settings


#</WindowLayout>

#<Database>

# DVE Open design session: 

if { ![gui_is_db_opened -db {/home/kch/work/TDRAM/run_app_platform/Device_top_sim_MAC/sim/dump/Dev_top_test.vpd}] } {
	gui_open_db -design V1 -file /home/kch/work/TDRAM/run_app_platform/Device_top_sim_MAC/sim/dump/Dev_top_test.vpd -nosource
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
gui_load_child_values {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP}


set _session_group_7 Group1
gui_sg_create "$_session_group_7"
set Group1 "$_session_group_7"

gui_sg_addsignal -group "$_session_group_7" { {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.vecA_0} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.vecA_1} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.vecA_2} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.vecA_3} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.vecB_0} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.vecB_1} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.vecB_2} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.vecB_3} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.is_sigmoid} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.cnt_for_LUT_neg} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.PIM_vecB_read_burst_rrr} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.cnt_for_LUT_neg_inc} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.cnt_for_LUT_neg_case} }
gui_set_radix -radix {decimal} -signals {{V1:testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.cnt_for_LUT_neg}}
gui_set_radix -radix {unsigned} -signals {{V1:testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.cnt_for_LUT_neg}}

# Global: Highlighting

# Global: Stack
gui_change_stack_mode -mode list

# Post database loading setting...

# Restore C1 time
gui_set_time -C1_only 456356



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


# Hier 'Hier.1'
gui_show_window -window ${Hier.1}
gui_list_set_filter -id ${Hier.1} -list { {Package 1} {All 0} {Process 1} {VirtPowSwitch 0} {UnnamedProcess 1} {UDP 0} {Function 1} {Block 1} {SrsnAndSpaCell 0} {OVA Unit 1} {LeafScCell 1} {LeafVlgCell 1} {Interface 1} {LeafVhdCell 1} {$unit 1} {NamedBlock 1} {Task 1} {VlgPackage 1} {ClassDef 1} {VirtIsoCell 0} }
gui_list_set_filter -id ${Hier.1} -text {*} -force
gui_change_design -id ${Hier.1} -design V1
catch {gui_list_expand -id ${Hier.1} testbench}
catch {gui_list_expand -id ${Hier.1} testbench.U0_DEVICE}
catch {gui_list_expand -id ${Hier.1} testbench.U0_DEVICE.U0_CHIP_TOP}
catch {gui_list_select -id ${Hier.1} {{testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP}}}
gui_view_scroll -id ${Hier.1} -vertical -set 0
gui_view_scroll -id ${Hier.1} -horizontal -set 0

# Data 'Data.1'
gui_list_set_filter -id ${Data.1} -list { {Buffer 1} {Input 1} {Others 1} {Linkage 1} {Output 1} {LowPower 1} {Parameter 1} {All 1} {Aggregate 1} {LibBaseMember 1} {Event 1} {Assertion 1} {Constant 1} {Interface 1} {BaseMembers 1} {Signal 1} {$unit 1} {Inout 1} {Variable 1} }
gui_list_set_filter -id ${Data.1} -text {*neg*}
gui_list_show_data -id ${Data.1} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP}
gui_show_window -window ${Data.1}
catch { gui_list_select -id ${Data.1} {{testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.cnt_for_LUT_neg_case} }}
gui_view_scroll -id ${Data.1} -vertical -set 0
gui_view_scroll -id ${Data.1} -horizontal -set 0
gui_view_scroll -id ${Hier.1} -vertical -set 0
gui_view_scroll -id ${Hier.1} -horizontal -set 0

# Source 'Source.1'
gui_src_value_annotate -id ${Source.1} -switch false
gui_set_env TOGGLE::VALUEANNOTATE 0
gui_open_source -id ${Source.1}  -replace -active testbench /home/kch/work/TDRAM/run_app_platform/Device_top_sim_MAC/sim/./testbench.v
gui_view_scroll -id ${Source.1} -vertical -set 34
gui_src_set_reusable -id ${Source.1}

# View 'Wave.1'
gui_wv_sync -id ${Wave.1} -switch false
set groupExD [gui_get_pref_value -category Wave -key exclusiveSG]
gui_set_pref_value -category Wave -key exclusiveSG -value {false}
set origWaveHeight [gui_get_pref_value -category Wave -key waveRowHeight]
gui_list_set_height -id Wave -height 25
set origGroupCreationState [gui_list_create_group_when_add -wave]
gui_list_create_group_when_add -wave -disable
gui_wv_zoom_timerange -id ${Wave.1} 421531 531995
gui_list_add_group -id ${Wave.1} -after {New Group} {Group1}
gui_list_expand -id ${Wave.1} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.cnt_for_LUT_neg_case}
gui_list_select -id ${Wave.1} {{testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.cnt_for_LUT_neg_case[0]} }
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
gui_list_set_insertion_bar  -id ${Wave.1} -group Group1  -position in

gui_marker_move -id ${Wave.1} {C1} 456356
gui_view_scroll -id ${Wave.1} -vertical -set 0
gui_show_grid -id ${Wave.1} -enable false
# Restore toplevel window zorder
# The toplevel window could be closed if it has no view/pane
if {[gui_exist_window -window ${TopLevel.1}]} {
	gui_set_active_window -window ${TopLevel.1}
	gui_set_active_window -window ${HSPane.1}
	gui_set_active_window -window ${DLPane.1}
}
if {[gui_exist_window -window ${TopLevel.2}]} {
	gui_set_active_window -window ${TopLevel.2}
	gui_set_active_window -window ${Wave.1}
}
#</Session>

