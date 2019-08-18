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
    output the_led,             //green LED, as I have this wired for Upduino. active high bc SB_RGBA_DRV is driving it
    output led_b,               //blue LED (in this version the_led is the RGB's green led)
    output led_r,               //red LED, similar
    output o_led0,              //alive-LEDs are all active low, controller does negation
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
    //or maybe not
    // See Private/elec/FPGA/SBTICETechnologyLibrary201504.pdf, the SiliconBlue ICE Technology doc,
    // re: https://github.com/gtjennings1/UPDuino_v2_0/blob/master/RGB_LED_BLINK_20170606/RGB_LED_BLINK.v primitive
    // SB_RGBA_DRV
    // GGrey's use is in a blinker, so the PWM varies based on system clock, thus
    // module RGB_LED_BLINK
    // (
    //     // outputs
    //     output  wire        REDn,       // Red
    //     output  wire        BLUn,       // Blue
    //     output  wire        GRNn        // Green
    // );
    // [...]
    // SB_RGBA_DRV RGB_DRIVER (
    //   .RGBLEDEN (1'b1),
    //   .RGB0PWM  (frequency_counter_i[25]&frequency_counter_i[24]),
    //   .RGB1PWM  (frequency_counter_i[25]&~frequency_counter_i[24]),
    //   .RGB2PWM  (~frequency_counter_i[25]&frequency_counter_i[24]),
    //   .CURREN   (1'b1),
    //   .RGB0     (REDn),		//Actual Hardware connection
    //   .RGB1     (GRNn),
    //   .RGB2     (BLUn)
    // );
    // defparam RGB_DRIVER.RGB0_CURRENT = "0b000001";
    // defparam RGB_DRIVER.RGB1_CURRENT = "0b000001";
    // defparam RGB_DRIVER.RGB2_CURRENT = "0b000001";
    //***********************************************************************************************************
    //***********************************************************************************************************
    //***********************************************************************************************************
    // see also https://blog.idorobots.org/entries/upduino-fpga-tutorial.html for how they did it
    /*

       SB_RGBA_DRV rgb (
         .RGBLEDEN (1'b1),
         .RGB0PWM  (counter[N]),
         .RGB1PWM  (counter[N-1]),
         .RGB2PWM  (counter[N-2]),
         .CURREN   (1'b1),
         .RGB0     (led_blue),
         .RGB1     (led_green),
         .RGB2     (led_red)
       );
       defparam rgb.CURRENT_MODE = "0b1";
       defparam rgb.RGB0_CURRENT = "0b000001";
       defparam rgb.RGB1_CURRENT = "0b000001";
       defparam rgb.RGB2_CURRENT = "0b000001";
    */
    wire led_b, led_r;
    //looks like the pwm parameters like registers - not quite sure how they work, but let's
    //just create some registers and treat them as active-high ... Well, we'll see what we get.
    reg led_r_reg = 0;
    reg led_g_reg = 0;
    reg led_b_reg = 0;
    SB_RGBA_DRV rgb (
      .RGBLEDEN (1'b1),         // enable LED
      .RGB0PWM  (led_g_reg),    //these appear to be single-bit parameters. ordering determined by experimentation and may be wrong
      .RGB1PWM  (led_b_reg),    //driven from registers within counter arrays in every example I've seen
      .RGB2PWM  (led_r_reg),    //so I will do similar
      .CURREN   (1'b1),         // supply current; 0 shuts off the driver (verify)
      .RGB0     (the_led),		//Actual Hardware connection - output wires. looks like it goes 0=green
      .RGB1     (led_b),        //1 = blue 
      .RGB2     (led_r)         //2 = red - but verify
    );
    defparam rgb.CURRENT_MODE = "0b1";          //half current mode
    defparam rgb.RGB0_CURRENT = "0b000001";     //4mA for Full Mode; 2mA for Half Mode
    defparam rgb.RGB1_CURRENT = "0b000001";     //see SiliconBlue ICE Technology doc
    defparam rgb.RGB2_CURRENT = "0b000001";


    // was this for small simulation clocks prewish5k_controller #(.NEWMASK_CLK_BITS(9)) controller(
    // now let's try with real clock values, or as close as I can get - REAL ones take too long, but let's move it out more,
    // like have... 16 bits? default is 26, which is 1000 times longer.
    // one problem with this organization is that I can't get at the blinky's parameter - can I? Can I add a param to controller that
    // passes it along? Let us try. We want a blinky mask clock to be about 3 full cycles of 8... let's say 32x as fast as newmask clk so 5 fewer bits?
    // let's try 6 - ok, that proportion looks not bad!
    // but in practice I did 7 - so let's do that here
    parameter CTRL_MASK_CLK_BITS=30;      //is 28 default in controller, which was for 12MHz - so 30? try it. Good!
    wire led_outwire;
    prewish5k_controller
        #(.NEWMASK_CLK_BITS(CTRL_MASK_CLK_BITS),.BLINKY_MASK_CLK_BITS(CTRL_MASK_CLK_BITS-7))
        controller(
        .i_clk(clk),
        .button_internal(button_acthi),          //will this work?
        .dip_switch(dip_swicth),
        .the_led(led_outwire),                   //was the_led), now the driver above is doing that
        .o_led0(o_led0),
        .o_led1(o_led1),
        .o_led2(o_led2),
        .o_led3(o_led3)
    );
    parameter PWMbits = 3;              // for dimming test, try having LED on only 1/2^PWMbits of the time
    reg[PWMbits-1:0] pwmctr = 0;
    always @(posedge clk) begin
        //assign output of main blinky to the driver module
        //ok, even this is a little too bright.
        //led_g_reg <= led_outwire;              //output from blinky is active high now , used to have ~led_outwire
        led_g_reg <= (&pwmctr) & led_outwire;    //when counter is all ones, turn on (if we're in a blink)
        pwmctr <= pwmctr + 1;
    end

endmodule
