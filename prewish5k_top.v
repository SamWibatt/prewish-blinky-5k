// all top does is contain / handle platform-dependent stuff.
// it supplies a clock to a controller.
`default_nettype	none

// Main module -----------------------------------------------------------------------------------------

module prewish5k_top(
    input the_button,           //active low button - this module will invert
    input i_bit7,               //active low dip switch, this & the other bits
    input i_bit6,
    input i_bit5,
    input i_bit4,
    input i_bit3,
    input i_bit2,
    input i_bit1,
    input i_bit0,
    output the_led,             //LEDs are also all active low. controller handles that.
    output o_led0,
    output o_led1,
    output o_led2,
    output o_led3
    );



    // INPUT BUTTON - after https://discourse.tinyfpga.com/t/internal-pullup-in-bx/800
    wire button_internal;
    wire button_acthi;
    SB_IO #(
        .PIN_TYPE(6'b 0000_01),     // PIN_NO_OUTPUT | PIN_INPUT (not latched or registered)
        .PULLUP(1'b 1)              // enable pullup and there's our active low
    ) button_input(
        .PACKAGE_PIN(the_button),   //has to be a pin in bank 0,1,2
        .D_IN_0(button_internal)
    );
    assign button_acthi = ~button_internal;

    //input dip switch!
    //dip switch wires and i/o with pullups
    wire[7:0] dip_swicth;
    //can you do this with a for loop?
    SB_IO #(.PIN_TYPE(6'b 0000_01),.PULLUP(1'b 1)) bit7_input(.PACKAGE_PIN(i_bit7),.D_IN_0(dip_swicth[7]));
    SB_IO #(.PIN_TYPE(6'b 0000_01),.PULLUP(1'b 1)) bit6_input(.PACKAGE_PIN(i_bit6),.D_IN_0(dip_swicth[6]));
    SB_IO #(.PIN_TYPE(6'b 0000_01),.PULLUP(1'b 1)) bit5_input(.PACKAGE_PIN(i_bit5),.D_IN_0(dip_swicth[5]));
    SB_IO #(.PIN_TYPE(6'b 0000_01),.PULLUP(1'b 1)) bit4_input(.PACKAGE_PIN(i_bit4),.D_IN_0(dip_swicth[4]));
    SB_IO #(.PIN_TYPE(6'b 0000_01),.PULLUP(1'b 1)) bit3_input(.PACKAGE_PIN(i_bit3),.D_IN_0(dip_swicth[3]));
    SB_IO #(.PIN_TYPE(6'b 0000_01),.PULLUP(1'b 1)) bit2_input(.PACKAGE_PIN(i_bit2),.D_IN_0(dip_swicth[2]));
    SB_IO #(.PIN_TYPE(6'b 0000_01),.PULLUP(1'b 1)) bit1_input(.PACKAGE_PIN(i_bit1),.D_IN_0(dip_swicth[1]));
    SB_IO #(.PIN_TYPE(6'b 0000_01),.PULLUP(1'b 1)) bit0_input(.PACKAGE_PIN(i_bit0),.D_IN_0(dip_swicth[0]));

    //and then the clock, up5k style
    // enable the high frequency oscillator,
	// which generates a 48 MHz clock
	wire clk;
	SB_HFOSC u_hfosc (
		.CLKHFPU(1'b1),
		.CLKHFEN(1'b1),
		.CLKHF(clk)
	);

    //***********************************************************************************************************
    //***********************************************************************************************************
    //***********************************************************************************************************
    //HEY IN HERE PUT A CONTROL ON THE LED BRIGHTNESS BECAUSE THE GREEN IS REALLY REALLY BRIGHT by default
    //on the Upduino
    //SB_LED_DRV_CUR is probably what I need
    //***********************************************************************************************************
    //***********************************************************************************************************
    //***********************************************************************************************************

    // was this for small simulation clocks prewish5k_controller #(.NEWMASK_CLK_BITS(9)) controller(
    // now let's try with real clock values, or as close as I can get - REAL ones take too long, but let's move it out more,
    // like have... 16 bits? default is 26, which is 1000 times longer.
    // one problem with this organization is that I can't get at the blinky's parameter - can I? Can I add a param to controller that
    // passes it along? Let us try. We want a blinky mask clock to be about 3 full cycles of 8... let's say 32x as fast as newmask clk so 5 fewer bits?
    // let's try 6 - ok, that proportion looks not bad!
    // but in practice I did 7 - so let's do that here
    parameter CTRL_MASK_CLK_BITS=30;      //is 28 default in controller, which was for 12MHz - so 30? try it. Good!
    prewish5k_controller
        #(.NEWMASK_CLK_BITS(CTRL_MASK_CLK_BITS),.BLINKY_MASK_CLK_BITS(CTRL_MASK_CLK_BITS-7))
        controller(
        .i_clk(clk),
        .button_internal(button_acthi),          //will this work?
        .dip_switch(dip_swicth),
        .the_led(the_led),
        .o_led0(o_led0),
        .o_led1(o_led1),
        .o_led2(o_led2),
        .o_led3(o_led3)
    );

endmodule
