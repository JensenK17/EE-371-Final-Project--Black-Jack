@echo off
:: =========================================================================
:: run_shuffle_sim.bat  -  Launch ModelSim and run the shuffle_fifo testbench
:: Double-click this file from Windows Explorer, or run it from any terminal.
:: =========================================================================

:: Change to the project root (folder that contains this .bat file)
cd /d "%~dp0"

:: -------------------------------------------------------------------------
:: Locate vsim.exe - checks PATH first, then common Quartus/ModelSim installs
:: -------------------------------------------------------------------------
where vsim >nul 2>&1
if %ERRORLEVEL% == 0 (
    set VSIM=vsim
    goto :run
)

set SEARCH_DIRS=^
    "C:\intelFPGA_lite\23.1std\questa_fse\win64\vsim.exe" ^
    "C:\intelFPGA_lite\22.1std\questa_fse\win64\vsim.exe" ^
    "C:\intelFPGA_lite\21.1\modelsim_ase\win32aloem\vsim.exe" ^
    "C:\intelFPGA_lite\20.1\modelsim_ase\win32aloem\vsim.exe" ^
    "C:\intelFPGA\23.1\questa_fse\win64\vsim.exe" ^
    "C:\intelFPGA\22.1\questa_fse\win64\vsim.exe" ^
    "C:\intelFPGA\20.1\modelsim_ase\win32aloem\vsim.exe" ^
    "C:\questasim64_10.7c\win64\vsim.exe" ^
    "C:\modeltech64_2020.4\win64\vsim.exe"

for %%P in (%SEARCH_DIRS%) do (
    if exist %%P (
        set VSIM=%%P
        goto :run
    )
)

echo ERROR: vsim.exe not found. Add ModelSim/Questa bin folder to your PATH
echo        or edit SEARCH_DIRS in this script.
pause
exit /b 1

:run
echo =========================================================
echo  Running shuffle_fifo testbench ...
echo =========================================================
"%VSIM%" -c -do sim/run_shuffle.do

echo.
echo =========================================================
echo  Simulation complete.
echo =========================================================
pause
