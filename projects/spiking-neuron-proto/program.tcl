# program.tcl - program Basys3 over JTAG (Vivado Hardware Manager, batch)
# Usage: vivado -mode batch -source program.tcl -nojournal -log out/program.log

cd [file dirname [file normalize [info script]]]

set bit out/top_basys3.bit
if {![file exists $bit]} {
    puts "ERROR: $bit not found. Run build.bat first."
    exit 1
}

open_hw_manager
connect_hw_server
open_hw_target

set dev [lindex [get_hw_devices xc7a35t_0] 0]
current_hw_device $dev
set_property PROGRAM.FILE $bit $dev
program_hw_devices $dev

puts "PROGRAMMED: $bit"
close_hw_manager
