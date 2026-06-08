@echo off
cd /d "%~dp0"
"C:\intelFPGA_lite\17.0\modelsim_ase\win32aloem\modelsim.exe" -do "vlib work; vmap work work"
