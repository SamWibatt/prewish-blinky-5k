/*
	prewish5k controller

    a "main" for the hardware

*/
`default_nettype	none



// MAIN ********************************************************************************************************************************************
module prewish5k_controller(
    input i_clk,
    input the_button,       //pin 44 active LOW button? Pulled up and inverted in here. Pin 119
    input i_bit7,           // 119 dip swicth swicths, active low. Will pull up but not debounce.
    input i_bit6,           // 118
    input i_bit5,           // 117
    input i_bit4,           // 116
    input i_bit3,           // 115
    input i_bit2,           // 114
    input i_bit1,           // 113
    input i_bit0,           // 112

	output the_led,			//this is THE LED, the green one that follows the pattern
	output o_led0,			//these others are just the other LEDs on the board and they
	output o_led1,          // act as "alive" indicators for the sub-modules.
	output o_led2,
	output o_led3
);

    // INPUT BUTTON - after https://discourse.tinyfpga.com/t/internal-pullup-in-bx/800
    wire button_internal;
    SB_IO #(
        .PIN_TYPE(6'b 0000_01),     // PIN_NO_OUTPUT | PIN_INPUT (not latched or registered)
        .PULLUP(1'b 1)              // enable pullup and there's our active low
    ) button_input(
        .PACKAGE_PIN(the_button),   //has to be a pin in bank 0,1,2
        .D_IN_0(button_internal)
    );

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


	// Super simple "I'm Alive" blinky on one of the iceStick's red LEDs.
	parameter REDBLINKBITS = 23;			// at 12 MHz this is ok
	reg[REDBLINKBITS-1:0] redblinkct = 0;
	always @(posedge i_clk) begin
		redblinkct <= redblinkct + 1;
	end

	//now let's try alive leds for the modules
	wire blinky_alive;
	wire mentor_alive;
    wire debounce_alive;

	assign o_led3 = debounce_alive;                //otherLEDs[3];
	assign o_led2 = mentor_alive;	               //otherLEDs[2];
	assign o_led1 = blinky_alive;                  //otherLEDs[1];
	assign o_led0 = redblinkct[REDBLINKBITS-1];	   //controller_alive, always block just above this

    // SYSCON ============================================================================================================================
    // Wishbone-like syscon responsible for clock and reset.

    //after https://electronics.stackexchange.com/questions/405363/is-it-possible-to-generate-internal-RST_O-pulse-in-verilog-with-machxo3lf-fpga
    //tis worky, drops RST_O to 0 at 15 clocks. ADJUST THIS IF IT'S INSUFFICIENT
    reg [3:0] rst_cnt = 0;
    wire RST_O = ~rst_cnt[3];       // My RST_O is active high, original was active low; I think that's why it was called rst_n
    wire CLK_O;                     // avoid default_nettype error
	always @(posedge CLK_O)         // see if I can use the output that way
		if( RST_O )                 // active high RST_O
            rst_cnt <= rst_cnt + 1;

	// should this be here?
	//thing that makes this really use a clock routing thing
	/* let's put in test bench...?
    SB_GB clk_gb (
		.USER_SIGNAL_TO_GLOBAL_BUFFER(i_clk),
		.GLOBAL_BUFFER_OUTPUT(CLK_O)             //can I use the output like this?
    );
	*/
	//instead do this until we have to put that back
	assign CLK_O = i_clk;
	// END SYSCON ========================================================================================================================

    wire strobe;
    wire[7:0] data;
    reg mnt_stb=0;
	reg[7:0] mask=0;
	wire[7:0] maskwires = mask;

    //mentor
    prewish5k_mentor mentor(
        .CLK_I(CLK_O),
        .RST_I(RST_O),
        .STB_O(strobe),
        .DAT_O(data),
        .STB_I(mnt_stb),
		.DAT_I(mask),
		.o_alive(mentor_alive)
    );

    // actual blinky module
    // NEWMASK_CLK_BITS is a throwback to when masks were just chosen by a timer instead of USER INPUT!!!!
    // so need to get rid of it
    parameter NEWMASK_CLK_BITS=28;		//default for "build"
	parameter BLINKY_MASK_CLK_BITS = NEWMASK_CLK_BITS - 7;	//default for build, swh //3;			//default for short sim
	prewish5k_blinky #(.SYSCLK_DIV_BITS(BLINKY_MASK_CLK_BITS)) blinky (		//can I do this to cascade parameterization from controller decl in prewish5k_tb? looks like!
        .CLK_I(CLK_O),
        .RST_I(RST_O),
        .STB_I(strobe),
		.DAT_I(data),			//should be data - making this mask didn't fix the trouble
		.o_alive(blinky_alive),
		.o_led(the_led)
    );


  //debouncer
  reg debounce_in_strobe = 0;
  reg[7:0] debounce_mask = 0;           // atm debounce doesn't do anything with the input data, may later be a mask
  wire debounce_out_strobe;
  wire[7:0] button_state;               //... this is kind of confused. we read 8 bits of button state but only have 1 bit input
  reg[7:0] button_streg = 0;            //for remembering button_state
  prewish5k_debounce pre_deb(
      .CLK_I(CLK_O),
      .RST_I(RST_O),
      .STB_O(debounce_out_strobe),      //ack-like
      .DAT_O(button_state),
      .STB_I(debounce_in_strobe),
      .DAT_I(debounce_mask),
      .i_button(~button_internal),      //launder active-low button to active-high signal like this
      .o_alive(debounce_alive)
    );

    // NEW DIP & BUTTON DRIVEN THING ==========================================================================
    // third version: just like the broken no-fetch, but another state machine keeps button state fresh.
    reg [1:0] fetchbuttons_state = 2'b00;

    //This block repeatedly fetches the state of the input(s).
    //might be able to clock this slower, like milliseconds. LOOK INTO. needs to be a global clock.
    always @(posedge CLK_O) begin
        if (RST_O) begin
            fetchbuttons_state <= 2'b00;
            button_streg <= 8'b00000000;          //I think it's safe to assign here
            debounce_in_strobe <= 0;
        end else begin
            case(fetchbuttons_state)
                2'b00: begin
                    //this does nothing but segue out of reset.
                    fetchbuttons_state <= 2'b01;
                end

                2'b01: begin
                    debounce_mask <= 8'b00000001;           //not used atm; this would say only send back lsb
                    debounce_in_strobe <= 1;                //raise debouncer strobe
                    fetchbuttons_state <= 2'b11;
                end

                2'b11: begin
                    debounce_in_strobe <= 0;                //lower strobe, idle here until get ACK (out strobe)
                    if(debounce_out_strobe) begin
                        button_streg <= button_state;       // load button state returned by debouncer
                        fetchbuttons_state <= 2'b10;
                    end
                end

                2'b10: begin
                    //wait state bc why not - future may be clocked on something a bit slower
                    fetchbuttons_state <= 2'b00;
                end

            endcase
        end
    end

    //second state machine for loading the mask on positive button edge.
    reg [1:0] loadmask_state = 2'b00;

    always @(posedge CLK_O) begin
		if (RST_O) begin
			loadmask_state <= 2'b00;
            mask <= 2'b00;
		end else begin
			case(loadmask_state)
				2'b00: begin
                    // this state waits for button release, then 10 waits for press?
                    if (button_state[0] == 0) begin
                        loadmask_state <= 2'b10;
                    end
                end

                2'b10: begin
                    // previous state waited for button release, this one waits for press.
                    if (button_state[0] == 1) begin
                        // invert bc dips active low
                        mask[0] <= ~dip_swicth[0]; mask[1] <= ~dip_swicth[1];
                        mask[2] <= ~dip_swicth[2]; mask[3] <= ~dip_swicth[3];
                        mask[4] <= ~dip_swicth[4]; mask[5] <= ~dip_swicth[5];
                        mask[6] <= ~dip_swicth[6]; mask[7] <= ~dip_swicth[7];
                        loadmask_state <= 2'b11;
					end
				end

				2'b11: begin
					// raise strobe
					mnt_stb <= 1;
					loadmask_state <= 2'b01;
				end

				2'b01: begin
					// lower strobe
					mnt_stb <= 0;
					loadmask_state <= 2'b00;
				end

			endcase
		end
	end

endmodule
