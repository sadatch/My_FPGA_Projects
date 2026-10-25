@echo off
rem program.bat - program Basys3 from out\top_basys3.bit (Windows)
rem Connect the board (power ON, micro-USB) before running.
rem Edit VIVADO_DIR if your install folder is different.

set VIVADO_DIR=C:\AMDDesignTools\2025.2\Vivado

cd /d "%~dp0"
if not exist out mkdir out

call "%VIVADO_DIR%\bin\vivado.bat" -mode batch -source program.tcl -nojournal -log out\program.log

echo.
echo Finished. See out\program.log
