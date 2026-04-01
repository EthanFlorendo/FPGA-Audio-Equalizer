#==============================================================================
# create_project.tcl
#
# Creates the Vivado project for the FPGA Audio Equalizer on PYNQ-Z2.
# Run from the repo root:
#   vivado -mode batch -source vivado/scripts/create_project.tcl
#==============================================================================

set project_name  "audio_equalizer"
set project_dir   "[file normalize [file dirname [info script]]]/../../vivado/project"]"
set board_part    "tul.com.tw:pynq-z2:part0:1.0"
set fpga_part     "xc7z020clg400-1"

# ── Create project ────────────────────────────────────────────────────────────
create_project $project_name $project_dir -part $fpga_part -force

set_property BOARD_PART $board_part [current_project]

# ── Add HLS IP repository ─────────────────────────────────────────────────────
# Point to the exported IP from Vitis HLS
# (export path set in Vitis HLS solution settings as hls/solution/impl/ip)
set hls_ip_repo "[file normalize [file dirname [info script]]]/../../hls/solution/impl/ip"
set_property ip_repo_paths $hls_ip_repo [current_project]
update_ip_catalog -rebuild

# ── Add constraint files ──────────────────────────────────────────────────────
add_files -fileset constrs_1 \
    "[file normalize [file dirname [info script]]]/../constraints/pynq_z2.xdc"

# ── Create and populate block design ─────────────────────────────────────────
source "[file normalize [file dirname [info script]]]/block_design.tcl"

# ── Generate wrapper ──────────────────────────────────────────────────────────
set bd_file [get_files *.bd]
make_wrapper -files [get_files $bd_file] -top
add_files -norecurse \
    [file join $project_dir "${project_name}.srcs/sources_1/bd/audio_eq_bd/hdl/audio_eq_bd_wrapper.v"]
set_property top audio_eq_bd_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts "Project created. Run 'launch_runs impl_1 -to_step write_bitstream' to build."
