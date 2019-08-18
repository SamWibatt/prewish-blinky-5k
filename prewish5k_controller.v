/*
	prewish5k controller

    a "main" for the hardware

*/
`default_nettype	none



// MAIN ********************************************************************************************************************************************
module prewish5k_controller(
    input i_clk,
    input button_internal,       //active high button. Pulled up and inverted in top module.
    input wire[7:0] dip_switch,     // dip swicth swicths, active low, not inverted by top mod.
	output the_led,			//this is THE LED, the green one that follows the pattern.
	output o_led0,			//these others are just external and they
	output o_led1,          // act as "alive" indicators for the sub-modules.
	output o_led2,          // All LED logic is active high and inverted; alive-LEDs are all active low IRL
	output o_led3
);

	// Super simple "I'm Alive" blinky on one of the external LEDs.
	parameter REDBLINKBITS = 23;			// at 12 MHz this is ok
	reg[REDBLINKBITS-1:0] redblinkct = 0;
	always @(posedge i_clk) begin
		redblinkct <= redblinkct + 1;
	end

	//now let's try alive leds for the modules
	wire blinky_alive;
	wire mentor_alive;
    wire debounce_alive;

	// sean changes: Upduino LEDs active low unlike icestick. Invert here to allow LED logic in the modules to remain
    // active high.
	assign o_led3 = ~debounce_alive;                //otherLEDs[3];
	assign o_led2 = ~mentor_alive;	               //otherLEDs[2];
	assign o_led1 = ~blinky_alive;                  //otherLEDs[1];
	assign o_led0 = ~redblinkct[REDBLINKBITS-1];	   //controller_alive, always block just above this

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
    parameter NEWMASK_CLK_BITS=30;		//was 28 for 12MHz clock - now 48MHz - default for "build"
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
	  .i_button(button_internal),      //active-low button laundered to active-high signal in top module
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
                        mask[0] <= ~dip_switch[0]; mask[1] <= ~dip_switch[1];
                        mask[2] <= ~dip_switch[2]; mask[3] <= ~dip_switch[3];
                        mask[4] <= ~dip_switch[4]; mask[5] <= ~dip_switch[5];
                        mask[6] <= ~dip_switch[6]; mask[7] <= ~dip_switch[7];
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
