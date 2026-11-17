# build.tcl - Vivado batch build for Basys3 (spiking-neuron-proto)
# Usage: vivado -mode batch -source build.tcl -nojournal -log out/vivado.log
#   (Windows: build.bat をダブルクリック。VIVADO_DIR は build.bat 内で自分の環境に合わせる)

# run from this script's folder
cd [file dirname [file normalize [info script]]]
file mkdir out

set top  top_basys3
set part xc7a35tcpg236-1

# --- sources (SystemVerilog) ---
read_verilog -sv rtl/serial_mul.sv
read_verilog -sv rtl/preset_rom.sv
read_verilog -sv rtl/neuron_core.sv
read_verilog -sv rtl/tick_gen.sv
read_verilog -sv rtl/uart_tx.sv
read_verilog -sv rtl/uart_frame_tx.sv
read_verilog -sv rtl/vga_timing.sv
read_verilog -sv rtl/wave_display.sv
read_verilog -sv rtl/bin2bcd.sv
read_verilog -sv rtl/seg7_4digit.sv
read_verilog -sv rtl/top_basys3.sv

read_xdc constraints/basys3.xdc

synth_design -top $top -part $part

# Basys3 config voltage (avoids the CFGBVS DRC message)
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

opt_design
place_design
route_design

report_timing_summary -file out/timing.rpt
report_utilization    -file out/util.rpt
report_drc            -file out/drc.rpt
write_bitstream -force out/$top.bit

# 目視しやすいように、タイミングの要点をログにも出す
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "WNS (setup slack) = $wns ns   <-- 0 未満ならタイミング違反。out/timing.rpt を確認"
puts "DONE: out/$top.bit"
