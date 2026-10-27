# build.tcl - Vivado batch build for Basys3 (pingpong-2D)
# Usage: vivado -mode batch -source build.tcl -nojournal -log out/vivado.log

# run from this script's folder
cd [file dirname [file normalize [info script]]]
file mkdir out

set top  top_basys3
set part xc7a35tcpg236-1

# --- sources (listed explicitly so a broken file does not break the build) ---
read_verilog main/clk_div25.v
read_verilog main/debounce.v
read_verilog main/game_logic.v
read_verilog main/renderer.v
read_verilog main/vga_640x480.v
read_verilog main/top_basys3.v
# add this line after seg7_display.v is fixed and used by top_basys3:
read_verilog main/seg7_display.v

read_xdc constraints/pingpong.xdc

synth_design -top $top -part $part

# Basys3 config voltage (avoids the CFGBVS DRC message)
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

opt_design
place_design
route_design

report_timing_summary -file out/timing.rpt
report_utilization    -file out/util.rpt
write_bitstream -force out/$top.bit

puts "DONE: out/$top.bit"
