#==========================================================================
# run_game.do  -  Compile and run tb_game (integration test).
# Run from the PROJECT ROOT:  do sim/run_game.do
#==========================================================================
if {[file exists work]} { vdel -all }
vlib work

vlog -sv +acc \
    src/hex_decoder.sv \
    src/hand_total.sv \
    src/hand_registers.sv \
    src/game_controller.sv \
    src/balance_tracker.sv \
    tb/tb_game.sv

vsim work.tb_game
run -all
