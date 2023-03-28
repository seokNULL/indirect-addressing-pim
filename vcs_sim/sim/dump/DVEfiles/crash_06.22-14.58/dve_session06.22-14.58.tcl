# Begin_DVE_Session_Save_Info
# DVE full session
# Saved on Mon Jun 22 14:58:30 2020
# Designs open: 1
#   V1: /home/kch/work/TDRAM/run_app_platform/Device_top_sim_MAC/sim/dump/Dev_top_test.vpd
# Toplevel windows open: 2
# 	TopLevel.1
# 	TopLevel.2
#   Source.1: testbench
#   Wave.1: 28 signals
#   Group count = 1
#   Group Group1 signal count = 28
# End_DVE_Session_Save_Info

# DVE version: K-2015.09-SP1_Full64
# DVE build date: Nov 24 2015 21:15:24


#<Session mode="Full" path="/home/kch/work/TDRAM/run_app_platform/Device_top_sim_MAC/sim/dump/DVEfiles//crash_06.22-14.58/dve_session06.22-14.58.tcl" type="Debug">

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


# Create and position top-level window: TopLevel.1

if {![gui_exist_window -window TopLevel.1]} {
    set TopLevel.1 [ gui_create_window -type TopLevel \
       -icon $::env(DVE)/auxx/gui/images/toolbars/dvewin.xpm] 
} else { 
    set TopLevel.1 TopLevel.1
}
gui_show_window -window ${TopLevel.1} -show_state normal -rect {{758 224} {2612 1277}}

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
gui_hide_toolbar -toolbar {Testbench}

# End ToolBar settings

# Docked window settings
set DLPane.1 [gui_create_window -type DLPane -parent ${TopLevel.1} -dock_state right -dock_on_new_line true -dock_extent 1332]
catch { set Data.1 [gui_share_window -id ${DLPane.1} -type Data] }
gui_set_window_pref_key -window ${DLPane.1} -key dock_width -value_type integer -value 1332
gui_set_window_pref_key -window ${DLPane.1} -key dock_height -value_type integer -value -1
gui_set_window_pref_key -window ${DLPane.1} -key dock_offset -value_type integer -value 9
gui_update_layout -id ${DLPane.1} {{left 0} {top 0} {width 1331} {height 820} {dock_state right} {dock_on_new_line true} {child_data_colvariable 565} {child_data_colvalue 412} {child_data_coltype 390} {child_data_col1 0} {child_data_col2 1} {child_data_col3 2}}
set Console.1 [gui_create_window -type Console -parent ${TopLevel.1} -dock_state bottom -dock_on_new_line true -dock_extent 153]
gui_set_window_pref_key -window ${Console.1} -key dock_width -value_type integer -value 1855
gui_set_window_pref_key -window ${Console.1} -key dock_height -value_type integer -value 153
gui_set_window_pref_key -window ${Console.1} -key dock_offset -value_type integer -value 0
gui_update_layout -id ${Console.1} {{left 0} {top 0} {width 1854} {height 152} {dock_state bottom} {dock_on_new_line true}}
#### Start - Readjusting docked view's offset / size
set dockAreaList { top left right bottom }
foreach dockArea $dockAreaList {
  set viewList [gui_ekki_get_window_ids -active_parent -dock_area $dockArea]
  foreach view $viewList {
      if {[lsearch -exact [gui_get_window_pref_keys -window $view] dock_width] != -1} {
        set dockWidth [gui_get_window_pref_value -window $view -key dock_width]
        set dockHeight [gui_get_window_pref_value -window $view -key dock_height]
        set offset [gui_get_window_pref_value -window $view -key dock_offset]
        if { [string equal "top" $dockArea] || [string equal "bottom" $dockArea]} {
          gui_set_window_attributes -window $view -dock_offset $offset -width $dockWidth
        } else {
          gui_set_window_attributes -window $view -dock_offset $offset -height $dockHeight
        }
      }
  }
}
#### End - Readjusting docked view's offset / size
gui_sync_global -id ${TopLevel.1} -option true

# MDI window settings
set HSPane.1 [gui_create_window -type {HSPane}  -parent ${TopLevel.1}]
if {[gui_get_shared_view -id ${HSPane.1} -type Hier] == {}} {
        set Hier.1 [gui_share_window -id ${HSPane.1} -type Hier]
} else {
        set Hier.1  [gui_get_shared_view -id ${HSPane.1} -type Hier]
}

gui_show_window -window ${HSPane.1} -show_state maximized
gui_update_layout -id ${HSPane.1} {{show_state maximized} {dock_state undocked} {dock_on_new_line false} {child_hier_colhier 452} {child_hier_coltype 67} {child_hier_colpd 0} {child_hier_col1 0} {child_hier_col2 1} {child_hier_col3 -1}}
set Source.1 [gui_create_window -type {Source}  -parent ${TopLevel.1}]
gui_show_window -window ${Source.1} -show_state maximized
gui_update_layout -id ${Source.1} {{show_state maximized} {dock_state undocked} {dock_on_new_line false}}

# End MDI window settings


# Create and position top-level window: TopLevel.2

if {![gui_exist_window -window TopLevel.2]} {
    set TopLevel.2 [ gui_create_window -type TopLevel \
       -icon $::env(DVE)/auxx/gui/images/toolbars/dvewin.xpm] 
} else { 
    set TopLevel.2 TopLevel.2
}
gui_show_window -window ${TopLevel.2} -show_state normal -rect {{1928 54} {3846 1053}}

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
gui_hide_toolbar -toolbar {Testbench}

# End ToolBar settings

# Docked window settings
gui_sync_global -id ${TopLevel.2} -option true

# MDI window settings
set Wave.1 [gui_create_window -type {Wave}  -parent ${TopLevel.2}]
gui_show_window -window ${Wave.1} -show_state maximized
gui_update_layout -id ${Wave.1} {{show_state maximized} {dock_state undocked} {dock_on_new_line false} {child_wave_left 556} {child_wave_right 1357} {child_wave_colname 408} {child_wave_colvalue 144} {child_wave_col1 0} {child_wave_col2 1}}

# End MDI window settings

gui_set_env TOPLEVELS::TARGET_FRAME(Source) ${TopLevel.1}
gui_set_env TOPLEVELS::TARGET_FRAME(Schematic) ${TopLevel.1}
gui_set_env TOPLEVELS::TARGET_FRAME(PathSchematic) ${TopLevel.1}
gui_set_env TOPLEVELS::TARGET_FRAME(Wave) none
gui_set_env TOPLEVELS::TARGET_FRAME(List) none
gui_set_env TOPLEVELS::TARGET_FRAME(Memory) ${TopLevel.1}
gui_set_env TOPLEVELS::TARGET_FRAME(DriverLoad) none
gui_update_statusbar_target_frame ${TopLevel.1}
gui_update_statusbar_target_frame ${TopLevel.2}

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
gui_load_child_values {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.BFLOAT16_ALU[0].BFLOAT_ALU}
gui_load_child_values {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP}


set _session_group_4 Group1
gui_sg_create "$_session_group_4"
set Group1 "$_session_group_4"

gui_sg_addsignal -group "$_session_group_4" { {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.vector_mask0} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.ALU_MASK[0].vec0_scalar_case} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.mask_neg_detect0} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.vecB_3} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.vecB_2} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.vecB_1} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.vecB_0} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.vecB0_load_case} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.vecA_3} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.vecA_2} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.vecA_1} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.vecA_0} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.debug_accO_norm} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.debug_ADD0_in_result_norm} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.debug_accO_r_norm} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.BFLOAT16_ALU[0].BFLOAT_ALU.debug_result_norm} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.alu_result_sign} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.burst_rd_cnt_rrr} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.data_burst3} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.data_burst2} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.data_burst1} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.data_burst0} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.burst_rd_cnt_r} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.acc_move_temp_array_r} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.LUT_start_load3} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.LUT_start_load2} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.LUT_start_load1} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.LUT_start_load0} }

# Global: Highlighting

# Global: Stack
gui_change_stack_mode -mode list

# Post database loading setting...

# Restore C1 time
gui_set_time -C1_only 443490



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
gui_list_set_filter -id ${Hier.1} -text {*}
gui_hier_list_init -id ${Hier.1}
gui_change_design -id ${Hier.1} -design V1
catch {gui_list_expand -id ${Hier.1} testbench}
catch {gui_list_expand -id ${Hier.1} testbench.U0_DEVICE}
catch {gui_list_expand -id ${Hier.1} testbench.U0_DEVICE.U0_CHIP_TOP}
catch {gui_list_select -id ${Hier.1} {{testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP}}}
gui_view_scroll -id ${Hier.1} -vertical -set 0
gui_view_scroll -id ${Hier.1} -horizontal -set 0

# Data 'Data.1'
gui_list_set_filter -id ${Data.1} -list { {Buffer 1} {Input 1} {Others 1} {Linkage 1} {Output 1} {LowPower 1} {Parameter 1} {All 1} {Aggregate 1} {LibBaseMember 1} {Event 1} {Assertion 1} {Constant 1} {Interface 1} {BaseMembers 1} {Signal 1} {$unit 1} {Inout 1} {Variable 1} }
gui_list_set_filter -id ${Data.1} -text {*result*}
gui_list_show_data -id ${Data.1} {testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP}
gui_show_window -window ${Data.1}
catch { gui_list_select -id ${Data.1} {{testbench.U0_DEVICE.U0_CHIP_TOP.BANK[0].U0_BANK_TOP.alu_result_sign} }}
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
gui_marker_create -id ${Wave.1} M1 442000
gui_marker_create -id ${Wave.1} M2 445000
gui_marker_create -id ${Wave.1} M3 449000
gui_marker_set_ref -id ${Wave.1}  C1
gui_wv_zoom_timerange -id ${Wave.1} 431190 458783
gui_list_add_group -id ${Wave.1} -after {New Group} {Group1}
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
gui_list_set_insertion_bar  -id ${Wave.1} -group {New Group} -position in

gui_marker_move -id ${Wave.1} {C1} 443490
gui_view_scroll -id ${Wave.1} -vertical -set 0
gui_show_grid -id ${Wave.1} -enable false
# Restore toplevel window zorder
# The toplevel window could be closed if it has no view/pane
if {[gui_exist_window -window ${TopLevel.2}]} {
	gui_set_active_window -window ${TopLevel.2}
	gui_set_active_window -window ${Wave.1}
}
if {[gui_exist_window -window ${TopLevel.1}]} {
	gui_set_active_window -window ${TopLevel.1}
	gui_set_active_window -window ${HSPane.1}
	gui_set_active_window -window ${DLPane.1}
}
#</Session>

