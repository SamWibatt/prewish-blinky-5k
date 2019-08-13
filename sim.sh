#!/bin/bash
# this one simulates with prewish5k_tb instead of prewish5k_sim_tb
echo "SIMULATION =============================================================================================== " > sim_tb_out.txt
echo "SIMULATION =============================================================================================== " > sim_tb_err.txt

# simulation, old: DO IT THIS WAY TO SEE THE SENSIBLE SIMULATION TRACE
iverilog -D SIM_STEP -o prewish5k_tb.vvp prewish5k_controller.v prewish5k_mentor.v prewish5k_blinky.v prewish5k_debounce.v prewish5k_tb.v 1>> sim_tb_out.txt 2>> sim_tb_err.txt
vvp prewish5k_tb.vvp  1>> sim_tb_out.txt 2>> sim_tb_err.txt
#gtkwave -o does optimization of vcd to FST format, good for the big sims
# or just do it here
vcd2fst prewish5k_tb.vcd prewish5k_tb.fst
rm -f prewish5k_tb.vcd
#gtkwave -o prewish5k_tb.vcd &
