//testbench is very much like top but we drive all the signals with assignments instead of THE REAL WORLD.
`default_nettype	none

// not very realistic for 48MHz ... see if it works. Nope, 20 isn't a good one
`timescale 10ns/10ns


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
    wire buttonhi = ~buttonreg;     //assign! need active high for controller
    wire led0, led1, led2, led3;    //other lights on the icestick
    reg mnt_stb=0;       //STB_I,   //then here is the student that takes direction from testbench
    reg[7:0] mnt_data=8'b00000000;  //DAT_I
    reg[7:0] dipswitch_reg;
    wire[7:0] dipswitch_wires = dipswitch_reg;



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
        .button_internal(buttonhi),
        .dip_switch(dipswitch_wires),
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
        #1 dipswitch_reg = 8'b01011111;         //user-swicthed mask. ACTIVE LOW. classic blink-blink
        //drive button! Now we can do that
        #7 buttonreg = 0;
        #100 buttonreg = 1;

        //try one before release interval done?
        #30023 buttonreg = 0;
        #19 buttonreg = 1;

        //then set up some new data
        #1 dipswitch_reg = 8'b00110011;         //user-swicthed mask ACTIVE LOW. slower steady flash

        // then one that does take, in order to toggle the LED
        #137 buttonreg = 0;
        #75 buttonreg = 1;

        #100000 $finish;           //longer sim, mask clock is now 16 bits. 5 sec run on vm, 30M vcd.
    end

endmodule
