@echo off
rem program.bat - program Basys3 over JTAG (Windows)
rem Edit VIVADO_DIR below to match your install folder.

set VIVADO_DIR=C:\AMDDesignTools\2025.2\Vivado

cd /d "%~dp0"
if not exist out mkdir out

call "%VIVADO_DIR%\bin\vivado.bat" -mode batch -source program.tcl -nojournal -log out\program.log

echo.
echo Finished. See out\program.log
pause
