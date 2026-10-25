@echo off
rem build.bat - run Vivado batch build (Windows)
rem Edit VIVADO_DIR below to match your install folder.
rem   e.g. C:\AMDDesignTools\2025.2\Vivado   or   C:\Xilinx\Vivado\2025.2

set VIVADO_DIR=C:\AMDDesignTools\2025.2\Vivado

cd /d "%~dp0"
if not exist out mkdir out

call "%VIVADO_DIR%\bin\vivado.bat" -mode batch -source build.tcl -nojournal -log out\vivado.log

echo.
echo Finished. See out\vivado.log, bitstream: out\top_basys3.bit
