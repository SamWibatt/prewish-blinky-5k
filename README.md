# prewish-blinky-5k
Same as prewish-blinky, but for the Upduino v2.0 instead of the iceStick.

I expect this to be largely identical to prewish-blinky. It should be the same except for pcf pin assignments, bits for clock dividers, global buffer and oscillator settings, etc. Platform-dependent stuff.

It ended up needing a little bit of a refactor into the "top," which supplies the system clock. The testbench takes the place of "top" and just creates a clock with always #1 thing.

As of 8/17/19, wired up and working!

----
### From [osresearch's up5k repository](https://github.com/osresearch/up5k):

Schematics for the upduino: https://github.com/gtjennings1/UPDuino_v2_0

![Upduino v2 pinout by Matt Mets](images/pinout.jpg)

Note that the [`upduino_v2.pcf`](images/upduino_v2.pcf) file (copied from osresearch's repo) disagrees with the serial port in the pinout and schematic.  The pins were determined through experimentation and seem to work (and the ones in the pinout do not).

### end from osresearch's up5k repo
----
