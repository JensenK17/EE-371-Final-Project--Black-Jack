#==========================================================================
# Blackjack timing constraints
#==========================================================================

# 50 MHz board clock. The whole design (including the VGA pixel counters via a
# clock-enable) runs on this single clock; VGA_CLK is just a registered /2
# output, not an internal clock, so no generated clock is needed.
create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]

derive_clock_uncertainty

# Asynchronous board I/O - not timing critical, cut from analysis.
set_false_path -from [get_ports {KEY[*] SW[*]}]
set_false_path -to   [get_ports {HEX0[*] HEX1[*] HEX2[*] HEX3[*] HEX4[*] HEX5[*]}]
set_false_path -to   [get_ports {LEDR[*]}]

# VGA outputs are latched externally by the ADV7123 on VGA_CLK; the exact
# pad delays are not critical for a 25 MHz pixel clock.
set_false_path -to   [get_ports {VGA_R[*] VGA_G[*] VGA_B[*]}]
set_false_path -to   [get_ports {VGA_HS VGA_VS VGA_BLANK_N VGA_SYNC_N VGA_CLK}]
