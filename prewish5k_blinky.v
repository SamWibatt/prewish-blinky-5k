/*
All right! So here's the blinky part.

The idea is that we have an 8-bit value, "mask," describing a pattern of blinks. Each bit takes ~1/10 second,
a 1 bit means "on" and 0 is "off." The pattern repeats until another mask is set or the module is reset.

For instance,
10100000
would mean two closely-spaced, short blinks roughly once a second.
11110000
would be a symmetrical flash about 1/2 second on, 1/2 off.

---

Do the subset of the wishbone port. Per docs, about STUDENTs,

CLK_I
The clock input [CLK_I] coordinates all activities for the internal logic within the WISHBONE interconnect. All WISHBONE
output signals are registered at the rising edge of [CLK_I]. All WISHBONE input signals are stable before the rising edge of [CLK_I].

DAT_I()
The data input array [DAT_I()] is used to pass binary data. The array boundaries are determined by the port size, with a
maximum port size of 64-bits (e.g. [DAT_I(63..0)]). Also see the [DAT_O()] and [SEL_O()] signal descriptions.

RST_I
The reset input [RST_I] forces the WISHBONE interface to restart. Furthermore, all internal self-starting state machines
will be forced into an initial state. This signal only resets the WISHBONE interface. It is not required to reset other
parts of an IP core (although it may be used that way).

STB_I
The strobe input [STB_I], when asserted, indicates that the STUDENT is selected. A STUDENT shall respond to other WISHBONE
signals only when this [STB_I] is asserted (except for the [RST_I] signal which should always be responded to). The
STUDENT asserts either the [ACK_O], [ERR_O] or [RTY_O] signals in response to every assertion of the [STB_I] signal.
*/
`default_nettype	none

module prewish5k_blinky (
    input CLK_I,
    input RST_I,
    input STB_I,
    input[7:0] DAT_I,
    output o_alive,         // "I'm-alive" signal out
    output o_led
);
    reg[7:0] mask = 0;              //high bits mean LED on for the corresponding segment of blink

    //Counter to divide system clock CLK_I down to blinky clock.
    parameter SYSCLK_DIV_BITS = 22;
    reg [SYSCLK_DIV_BITS-1:0] ckdiv = 0;
    reg ledreg = 0;                 //register for synching LED output

    always @(posedge CLK_I) begin
        if(RST_I == 1) begin        // reset case - zero out
            ckdiv <= 0;             // reset clock divider
            mask <= 0;              // clear blink pattern so LED would be off anyway
            ledreg <= 0;            // clear register that syncs LED
        end else begin
            if(STB_I == 1) begin    // strobe case, load mask with DAT
                ckdiv <= 0;         // reset divider
                ledreg <= 0;        // shut off active high LED during load
                mask <= DAT_I;      // load input data to the mask
            end else begin
                ckdiv <= ckdiv + 1;

                // when the blink-interval has passed, "roll" the mask so the next bit will drive the LED.
                if(ckdiv == 1) begin
                    mask <= mask <<< 1;
                    mask[0] <= mask[7];
                    ledreg <= mask[7];
                end
            end
        end
    end

    //see if I need a wire to drive parent's LED - doesn't seem to have been necessary, but maybe keep
    assign o_led = ledreg;

    //debug thing, send out an "I'm alive" signal to caller. Here let's try at the mask roll rate
    assign o_alive = ckdiv[SYSCLK_DIV_BITS-1];

endmodule
