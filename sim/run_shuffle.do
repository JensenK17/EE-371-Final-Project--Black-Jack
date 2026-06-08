#==========================================================================
# run_shuffle.do  -  Compile and run tb_shuffle_fifo in batch mode.
# Run from the PROJECT ROOT:
#   vsim -c -do sim/run_shuffle.do
#==========================================================================
if {[file exists work]} { vdel -all }
vlib work

vlog -sv +acc \
    src/lfsr.sv \
    src/deck_memory.sv \
    src/shuffle_fifo.sv \
    tb/tb_shuffle_fifo.sv

vsim work.tb_shuffle_fifo
run -all
