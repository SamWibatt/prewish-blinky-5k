#!/bin/bash
set -ex
# and so this is easy to copy to other projects and rename stuff
proj="prewish5k"

# device targeted, use one of the architecture flags from nextpnr-ice40's help:
#Architecture specific options:
#  --lp384                     set device type to iCE40LP384
#  --lp1k                      set device type to iCE40LP1K
#  --lp8k                      set device type to iCE40LP8K
#  --hx1k                      set device type to iCE40HX1K
#  --hx8k                      set device type to iCE40HX8K
#  --up5k                      set device type to iCE40UP5K
#  --u4k                       set device type to iCE5LP4K
# only without the --
device="up5k"

# AND FIGURE OUT HOW TO USE THIS!
#  --package arg               set device package

# yosys produces the .json file from all the verilog sources. See the .ys file for details.
yosys "$proj".ys

# nextpnr does place-and-route, associating the design with the particular hardware layout
# given in the .pcf.
nextpnr-ice40 --"$device" --json "$proj".json --pcf "$proj".pcf --asc "$proj".asc

# icepack converts nextpnr's output to a bitstream usable by the target hardware.
icepack "$proj".asc "$proj".bin

# use
# iceprog (proj).bin
# to send the binary to the chip.
# iceprog -v shows LOTS of info
# you may have to sudo.
