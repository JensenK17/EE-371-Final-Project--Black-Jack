#==========================================================================
# run_hand_total.do  -  Compile and run tb_hand_total.
# Run from the PROJECT ROOT:  do sim/run_hand_total.do
#==========================================================================
if {[file exists work]} { vdel -all }
vlib work

vlog -sv +acc \
    src/hand_total.sv \
    tb/tb_hand_total.sv

vsim work.tb_hand_total
run -all
