#==========================================================================
# ModelSim / Questa run script.  Run from the PROJECT ROOT:
#
#   Batch (default = tb_game):   vsim -c -do sim/run.do
#   Pick a testbench:            vsim -c -do "set TB tb_shuffle_fifo; do sim/run.do"
#   GUI with waves:              vsim -do "set GUI 1; do sim/run.do"
#
# Available testbenches: tb_hand_total  tb_shuffle_fifo  tb_game
#==========================================================================
if {![info exists TB]}  { set TB  tb_game }
if {![info exists GUI]} { set GUI 0 }

if {[file exists work]} { vdel -all }
vlib work

vlog -sv +acc \
    src/synchronizer.sv \
    src/debouncer.sv \
    src/hex_decoder.sv \
    src/input_conditioning.sv \
    src/lfsr.sv \
    src/deck_memory.sv \
    src/shuffle_fifo.sv \
    src/hand_total.sv \
    src/hand_registers.sv \
    src/game_controller.sv \
    src/vga_timing.sv \
    src/char_rom.sv \
    src/vga_renderer.sv \
    src/balance_tracker.sv \
    blackjack_top.sv \
    tb/tb_hand_total.sv \
    tb/tb_shuffle_fifo.sv \
    tb/tb_game.sv

if {$GUI} {
    vsim work.$TB
    catch {add wave -r /*}
    run -all
} else {
    vsim -c work.$TB
    run -all
    quit -f
}
