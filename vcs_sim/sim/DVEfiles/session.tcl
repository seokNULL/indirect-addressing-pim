# Begin_DVE_Session_Save_Info
# DVE full session
# Saved on Fri Jan 27 19:01:31 2023
# Designs open: 1
#   V1: /home/kch/work/TDRAM/run_app_platform/Device_top_sim_GDDR6_TASK/sim/dump/Dev_top_test.vpd
# Toplevel windows open: 1
# 	TopLevel.1
#   Source.1: testbench
#   Group count = 1
#   Group Group1 signal count = 121
# End_DVE_Session_Save_Info

# DVE version: K-2015.09-SP1_Full64
# DVE build date: Nov 24 2015 21:15:24


#<Session mode="Full" path="/home/kch/work/TDRAM/run_app_platform/Device_top_sim_GDDR6_TASK/sim/DVEfiles/session.tcl" type="Debug">

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
gui_show_window -window ${TopLevel.1} -show_state maximized -rect {{1080 23} {3277 1439}}

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
set DLPane.1 [gui_create_window -type DLPane -parent ${TopLevel.1} -dock_state right -dock_on_new_line true -dock_extent 1684]
catch { set Data.1 [gui_share_window -id ${DLPane.1} -type Data] }
gui_set_window_pref_key -window ${DLPane.1} -key dock_width -value_type integer -value 1684
gui_set_window_pref_key -window ${DLPane.1} -key dock_height -value_type integer -value 797
gui_set_window_pref_key -window ${DLPane.1} -key dock_offset -value_type integer -value 0
gui_update_layout -id ${DLPane.1} {{left 0} {top 0} {width 1683} {height 1109} {dock_state right} {dock_on_new_line true} {child_data_colvariable 667} {child_data_colvalue 514} {child_data_coltype 491} {child_data_col1 0} {child_data_col2 1} {child_data_col3 2}}
set Console.1 [gui_create_window -type Console -parent ${TopLevel.1} -dock_state bottom -dock_on_new_line true -dock_extent 233]
gui_set_window_pref_key -window ${Console.1} -key dock_width -value_type integer -value 1919
gui_set_window_pref_key -window ${Console.1} -key dock_height -value_type integer -value 233
gui_set_window_pref_key -window ${Console.1} -key dock_offset -value_type integer -value 0
gui_update_layout -id ${Console.1} {{left 0} {top 0} {width 2197} {height 232} {dock_state bottom} {dock_on_new_line true}}
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
gui_update_layout -id ${HSPane.1} {{show_state maximized} {dock_state undocked} {dock_on_new_line false} {child_hier_colhier 456} {child_hier_coltype 54} {child_hier_colpd 0} {child_hier_col1 0} {child_hier_col2 1} {child_hier_col3 -1}}
set Source.1 [gui_create_window -type {Source}  -parent ${TopLevel.1}]
gui_show_window -window ${Source.1} -show_state maximized
gui_update_layout -id ${Source.1} {{show_state maximized} {dock_state undocked} {dock_on_new_line false}}

# End MDI window settings

gui_set_env TOPLEVELS::TARGET_FRAME(Source) ${TopLevel.1}
gui_set_env TOPLEVELS::TARGET_FRAME(Schematic) ${TopLevel.1}
gui_set_env TOPLEVELS::TARGET_FRAME(PathSchematic) ${TopLevel.1}
gui_set_env TOPLEVELS::TARGET_FRAME(Wave) none
gui_set_env TOPLEVELS::TARGET_FRAME(List) none
gui_set_env TOPLEVELS::TARGET_FRAME(Memory) ${TopLevel.1}
gui_set_env TOPLEVELS::TARGET_FRAME(DriverLoad) none
gui_update_statusbar_target_frame ${TopLevel.1}

#</WindowLayout>

#<Database>

# DVE Open design session: 

if { ![gui_is_db_opened -db {/home/kch/work/TDRAM/run_app_platform/Device_top_sim_GDDR6_TASK/sim/dump/Dev_top_test.vpd}] } {
	gui_open_db -design V1 -file /home/kch/work/TDRAM/run_app_platform/Device_top_sim_GDDR6_TASK/sim/dump/Dev_top_test.vpd -nosource
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
gui_load_child_values {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP}


set _session_group_1 Group1
gui_sg_create "$_session_group_1"
set Group1 "$_session_group_1"

gui_sg_addsignal -group "$_session_group_1" { {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.clk} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.rst_x} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.HPC_clear_sig} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.DRAM_data} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.src_A_RD_pass} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.src_B_RD_pass} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.dst_C_WR_pass} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.bank_config_reg} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_result} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_CLR_vecA_config} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_CLR_vecB_config} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_CLR_ACC_config} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_CLR_CTRL_reg_config} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_DUP_config} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_DUP_config_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_ADD_config} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_SUB_config} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_MUL_config} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_MAC_config} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_vecA_start_config} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_vecB_start_config} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_ADD_config_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_SUB_config_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_MUL_config_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_MAC_config_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_vecA_start_config_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_vecB_start_config_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_ADD_config_rr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_SUB_config_rr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_MUL_config_rr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_MAC_config_rr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_vecA_start_config_rr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_vecB_start_config_rr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_CLR_vecA} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_CLR_vecB} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_CLR_ACC} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_CLR_CTRL_reg} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_DUP} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_ADD} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_SUB} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_MUL} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_MAC} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_vecA_start} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_vecB_start} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.req_AIM_RD} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.req_AIM_WR} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.req_AIM_RD_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.req_AIM_WR_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.src_A_RD_pass_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.src_B_RD_pass_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_RD_A_sig} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_RD_B_sig} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_WR_C_sig} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.global_burst_cnt_SCAL_gran} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_vecA_read_burst} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_vecB_read_burst} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_write_burst} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_result_WB_done} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_proc} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_ALU_proc} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.case_vecA} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.case_vecB} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.case_both} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_ALU_proc_case} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.global_burst_cnt_SCAL_gran_rst} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_vecA_read_burst_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_vecA_read_burst_rr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_vecB_read_burst_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_vecB_read_burst_rr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_vecB_read_burst_rrr} }
gui_sg_addsignal -group "$_session_group_1" { {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_ALU_proc_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_ALU_proc_rr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_ALU_proc_rrr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_ALU_proc_rrrr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_ALU_proc_rrrrr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.global_burst_cnt_SCAL_gran_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.global_burst_cnt_SCAL_gran_rr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.global_burst_cnt_SCAL_gran_rrr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.global_burst_cnt_SCAL_gran_rrrr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.global_burst_cnt_SCAL_gran_rst_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.EX1_burst} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.WB_burst} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.FE_vecB_burst_delay} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.data_burst} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.data_burst_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.data_burst_rr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecA} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecB} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.alu_result_sign} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.alu_result_exp} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.alu_result_mant} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.norm_result} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.norm_result_vec} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecA_in} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecA_clr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecA_load} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecA_keep} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecA_load_case} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecB_in} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecB_clr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecB_keep} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecB_load_case} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vA_s} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecA_dup_cnt} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecA_temp} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.srcA_temp} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.srcA_input} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecA_burst} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecB_temp} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vACC_burst} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.acc_case} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.acc_rst} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.acc_result_en} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.acc_keep} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.alu_src0} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.alu_src1} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vACC} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vACC_in} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.norm_in} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.alu_src0_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.alu_src1_r} }

# Global: Highlighting

# Global: Stack
gui_change_stack_mode -mode list

# Post database loading setting...

# Restore C1 time
gui_set_time -C1_only 133827



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
catch {gui_list_select -id ${Hier.1} {{testbench.U0_DEVICE.BANK[0].U0_BANK_TOP}}}
gui_view_scroll -id ${Hier.1} -vertical -set 87
gui_view_scroll -id ${Hier.1} -horizontal -set 0

# Data 'Data.1'
gui_list_set_filter -id ${Data.1} -list { {Buffer 1} {Input 1} {Others 1} {Linkage 1} {Output 1} {LowPower 1} {Parameter 1} {All 1} {Aggregate 1} {LibBaseMember 1} {Event 1} {Assertion 1} {Constant 1} {Interface 1} {BaseMembers 1} {Signal 1} {$unit 1} {Inout 1} {Variable 1} }
gui_list_set_filter -id ${Data.1} -text {*}
gui_list_show_data -id ${Data.1} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP}
gui_show_window -window ${Data.1}
catch { gui_list_select -id ${Data.1} {{testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.clk} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.rst_x} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.HPC_clear_sig} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.DRAM_data} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.src_A_RD_pass} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.src_B_RD_pass} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.dst_C_WR_pass} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.bank_config_reg} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_result} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_CLR_vecA_config} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_CLR_vecB_config} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_CLR_ACC_config} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_CLR_CTRL_reg_config} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_DUP_config} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_DUP_config_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_ADD_config} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_SUB_config} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_MUL_config} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_MAC_config} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_vecA_start_config} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_vecB_start_config} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_ADD_config_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_SUB_config_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_MUL_config_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_MAC_config_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_vecA_start_config_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_vecB_start_config_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_ADD_config_rr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_SUB_config_rr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_MUL_config_rr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_MAC_config_rr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_vecA_start_config_rr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_vecB_start_config_rr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_CLR_vecA} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_CLR_vecB} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_CLR_ACC} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_CLR_CTRL_reg} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_DUP} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_ADD} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_SUB} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_MUL} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_MAC} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_vecA_start} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.is_vecB_start} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.req_AIM_RD} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.req_AIM_WR} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.req_AIM_RD_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.req_AIM_WR_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.src_A_RD_pass_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.src_B_RD_pass_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_RD_A_sig} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_RD_B_sig} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_WR_C_sig} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.global_burst_cnt_SCAL_gran} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_vecA_read_burst} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_vecB_read_burst} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_write_burst} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_result_WB_done} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_proc} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_ALU_proc} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.case_vecA} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.case_vecB} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.case_both} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_ALU_proc_case} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.global_burst_cnt_SCAL_gran_rst} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_vecA_read_burst_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_vecA_read_burst_rr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_vecB_read_burst_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_vecB_read_burst_rr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_vecB_read_burst_rrr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_ALU_proc_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_ALU_proc_rr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_ALU_proc_rrr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_ALU_proc_rrrr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.PIM_ALU_proc_rrrrr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.global_burst_cnt_SCAL_gran_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.global_burst_cnt_SCAL_gran_rr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.global_burst_cnt_SCAL_gran_rrr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.global_burst_cnt_SCAL_gran_rrrr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.global_burst_cnt_SCAL_gran_rst_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.EX1_burst} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.WB_burst} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.FE_vecB_burst_delay} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.data_burst} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.data_burst_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.data_burst_rr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecA} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecB} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.alu_result_sign} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.alu_result_exp} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.alu_result_mant} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.norm_result} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.norm_result_vec} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecA_in} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecA_clr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecA_load} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecA_keep} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecA_load_case} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecB_in} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecB_clr} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecB_keep} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecB_load_case} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vA_s} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecA_dup_cnt} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecA_temp} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.srcA_temp} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.srcA_input} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecA_burst} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vecB_temp} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vACC_burst} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.acc_case} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.acc_rst} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.acc_result_en} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.acc_keep} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.alu_src0} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.alu_src1} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vACC} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.vACC_in} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.norm_in} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.alu_src0_r} {testbench.U0_DEVICE.BANK[0].U0_BANK_TOP.alu_src1_r} }}
gui_view_scroll -id ${Data.1} -vertical -set 0
gui_view_scroll -id ${Data.1} -horizontal -set 0
gui_view_scroll -id ${Hier.1} -vertical -set 87
gui_view_scroll -id ${Hier.1} -horizontal -set 0

# Source 'Source.1'
gui_src_value_annotate -id ${Source.1} -switch false
gui_set_env TOGGLE::VALUEANNOTATE 0
gui_open_source -id ${Source.1}  -replace -active testbench /home/kch/work/TDRAM/run_app_platform/Device_top_sim_GDDR6_TASK/sim/./testbench.v
gui_view_scroll -id ${Source.1} -vertical -set 0
gui_src_set_reusable -id ${Source.1}
# Restore toplevel window zorder
# The toplevel window could be closed if it has no view/pane
if {[gui_exist_window -window ${TopLevel.1}]} {
	gui_set_active_window -window ${TopLevel.1}
	gui_set_active_window -window ${HSPane.1}
	gui_set_active_window -window ${DLPane.1}
}
#</Session>

