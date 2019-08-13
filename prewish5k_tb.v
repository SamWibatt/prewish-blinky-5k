//this version is meant to use the prewish5k_controller instead of prewish5k_syscon
//for doing sim of thing that will be put on the actual chip
//the controller creates all the other modules

`default_nettype	none

//let's see if I can do 12 MHz
//8.3333333333333333333333333333333e-8 seconds per tick
// = 83.3 nanos, not real accurate
// = 83,333 picos, close enough.
//`timescale 83333ps/1ns
// weird, seems you can only do 1 or 2 as the first digit.
// can I do 100 nanos? That'd be in the ballpark but slow.
// FIGURE OUT HOW TO DO THAT PLL THING OR WHATEVER so I can do this - if it ends up mattering.
// kind of ok `timescale 100ns/10ns
`timescale 100ns/100ns

// THESE ARE MOCKUPS OF ICE40 BUILT IN MODULES THAT MAKE MY SIM.SH BUILD FAIL. GROSS BUT I WILL
// FIGURE OUT HOW TO DO THIS RIGHT LATER (probably putting the device-specific stuff ... somewhere else.)
//here's a cheap fake of the SB_GB module that the other tool chain uses
//this lets it compile!
module SB_GB(input USER_SIGNAL_TO_GLOBAL_BUFFER, output GLOBAL_BUFFER_OUTPUT);
    assign GLOBAL_BUFFER_OUTPUT = USER_SIGNAL_TO_GLOBAL_BUFFER;
endmodule

//similar for pullup input pin
/*
SB_IO #(
  .PIN_TYPE(6'b 0000_01),     //IS THIS RIGHT? looks like it's PIN_NO_OUTPUT | PIN_INPUT (not latched or registered)
  .PULLUP(1'b 1)
) button_input(
  .PACKAGE_PIN(the_button),   //has to be a pin in bank 0,1,2
  .D_IN_0(button_internal)
);
*/
module SB_IO(input wire PACKAGE_PIN, output wire D_IN_0);
  parameter PIN_TYPE = 0;
  parameter PULLUP = 0;
  assign D_IN_0 = PACKAGE_PIN;
endmodule


// Main module -----------------------------------------------------------------------------------------

module prewish5k_tb;
    reg clk = 0;
    always #1 clk = (clk === 1'b0);

    wire reset;
    wire sysclk;
    wire strobe;
    wire[7:0] data;
    wire led;                       //active high LED
    reg buttonreg = 0;              // simulated button input
    reg[7:0] dipswicth_reg = 0;     //simulated dip swicth input
    wire led0, led1, led2, led3;    //other lights on the icestick
    reg mnt_stb=0;       //STB_I,   //then here is the student that takes direction from testbench
    reg[7:0] mnt_data=8'b00000000;  //DAT_I

	//primitive for routing iceStick's onboard clock to a global buffer, which is good for clocks
  //because GBs can drive a lot more little modules
    wire CLK_O;
    SB_GB clk_gb (
		.USER_SIGNAL_TO_GLOBAL_BUFFER(clk),
		.GLOBAL_BUFFER_OUTPUT(CLK_O)             //can I use the output like this?
    );



    //module prewish5k_controller(
    //    input i_clk,
    //    output RST_O
    //    output CLK_O
    //           );

    // was this for small simulation clocks prewish5k_controller #(.NEWMASK_CLK_BITS(9)) controller(
    // now let's try with real clock values, or as close as I can get - REAL ones take too long, but let's move it out more,
    // like have... 16 bits? default is 26, which is 1000 times longer.
    // one problem with this organization is that I can't get at the blinky's parameter - can I? Can I add a param to controller that
    // passes it along? Let us try. We want a blinky mask clock to be about 3 full cycles of 8... let's say 32x as fast as newmask clk so 5 fewer bits?
    // let's try 6 - ok, that proportion looks not bad!
    // but in practice I did 7 - so let's do that here
    parameter CTRL_MASK_CLK_BITS=16; //20;    //26 is "real?";  FROM CALCS IN THE LOOP BELOW I THINK 25 WILL BE IT     //works at 16 and 20
    prewish5k_controller
        #(.NEWMASK_CLK_BITS(CTRL_MASK_CLK_BITS),.BLINKY_MASK_CLK_BITS(CTRL_MASK_CLK_BITS-7)) controller(
        .i_clk(clk),
        .the_button(buttonreg),
        .i_bit7(dipswicth_reg[7]),
        .i_bit6(dipswicth_reg[6]),
        .i_bit5(dipswicth_reg[5]),
        .i_bit4(dipswicth_reg[4]),
        .i_bit3(dipswicth_reg[3]),
        .i_bit2(dipswicth_reg[2]),
        .i_bit1(dipswicth_reg[1]),
        .i_bit0(dipswicth_reg[0]),
        .the_led(led),
        .o_led0(led0),
        .o_led1(led1),
        .o_led2(led2),
        .o_led3(led3)
    );

    //bit for creating gtkwave output
    initial begin
        //uncomment the next two for gtkwave?
        $dumpfile("prewish5k_tb.vcd");
        $dumpvars(0, prewish5k_tb);
    end

    initial begin
        #0 buttonreg = 1;           //active low
        #1 dipswicth_reg = 8'b01011111;         //user-swicthed mask. ACTIVE LOW. classic blink-blink
        //drive button! Now we can do that
        #7 buttonreg = 0;
        #100 buttonreg = 1;

        //try one before release interval done?
        #30023 buttonreg = 0;
        #19 buttonreg = 1;

        //then set up some new data
        #1 dipswicth_reg = 8'b00110011;         //user-swicthed mask ACTIVE LOW. slower steady flash

        // then one that does take, in order to toggle the LED
        #137 buttonreg = 0;
        #75 buttonreg = 1;

        #100000 $finish;           //longer sim, mask clock is now 16 bits. 5 sec run on vm, 30M vcd.
    end

endmodule
