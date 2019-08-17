// debouncer for the button.
`default_nettype	none

// Gisselquist's version from his tutorial's lesson 7 "bouncing"
// with slight modifications
module	debouncer(i_clk, i_btn, o_debounced);
    //icestick values, 12MHz clock
    //parameter TIME_PERIOD = 100000;
    //parameter TIME_BITS = 17;
    //upduino v2 values, 48 MHz
    parameter TIME_PERIOD = 400000;
    parameter TIME_BITS = 19;
	input	wire	i_clk, i_btn;
	output	reg	o_debounced;

	reg	r_btn, r_aux;
	reg	[TIME_BITS-1:0]	timer;

	// Our 2FF synchronizer
	initial	{ r_btn, r_aux } = 2'b00;
	always @(posedge i_clk)
		{ r_btn, r_aux } <= { r_aux, i_btn };

	// The count-down timer
	initial	timer = 0;
	always @(posedge i_clk)
	if (timer != 0)
		timer <= timer - 1;
	else if (r_btn != o_debounced)
		timer <= TIME_PERIOD[TIME_BITS-1:0] - 1;

	// Finally, set our output value
	initial	o_debounced = 0;
	always @(posedge i_clk)
	if (timer == 0)
		o_debounced <= r_btn;
endmodule

// MY OWN MODULE ============================================================================================----
module prewish5k_debounce(
    input CLK_I,
    input RST_I,
    output STB_O,                   //mentor/outgoing interface, writes to caller with current status byte
    output[7:0] DAT_O,
    input STB_I,                    //incoming / student
    input[7:0] DAT_I,               // currently unused - later may be a mask to screen multiple inputs
    //HEY THE NEXT WILL BE MULTIPLE BITS WIDE TOO AND HANDLED AS SUCH LATER?
    input i_button,	                // active HIGH input from button, caller presumably just passes this straight along from a pad WILL BE REFACTORED INTO AN ARRAY
    output o_alive                  // debug outblinky
);

    reg[1:0] state = 2'b00;		    //state machine state
    reg strobe_o_reg = 0;		    //for letting state machine send STB_O
    reg alivereg = 0;               //debug thing to toggle alive-LED when strobes happen? Toggle on debounced pos edge
    reg [7:0] dat_reg = 8'b0;       //for saving the switch state for return to caller
    reg[7:0] button_state = 8'b0;	// button state (not state machine state) - ACTIVE HIGH even if inputs are active low, caller must adjust

    //here are the little mechanisms that make a single input work, WILL BE REFACTORED INTO AN ARRAY OR FOR LOOP OR SOMETHING
    wire button_debounced;
    //here's the Gisselquist way, and is this a good place to switch on the sim_step def?
    //this works. use iverilog -D SIM_STEP in build
    `ifdef SIM_STEP
        debouncer #(.TIME_PERIOD(37),.TIME_BITS(6)) deb(.i_clk(CLK_I), .i_btn(i_button), .o_debounced(button_debounced));
    `else
        debouncer deb(CLK_I, i_button, button_debounced);
    `endif

    //so here shift button wire into the status register!
    always @(posedge CLK_I) begin
        if(RST_I == 1) begin
            strobe_o_reg <= 0;
            state <= 2'b00;
		          button_state <= 0;
        end else begin
      		//HARDCODE STATE 0 IS BUTTON. LATER THIS CAN BE MULTIPLE BITS.
            button_state[0] <= button_debounced;

            //ALIVE-BLINKY: look for a positive edge in button_debounced.
            if(~button_state[0] && button_debounced) begin
                alivereg <= ~alivereg;  //toggle alive-reg for debug.
            end

            //state machine stuff
            case (state)
                2'b00 : begin
                    //00 - reset/initial, send all the outgoing signals low, load data advance to 01 if STB_I goes high
                    //otherwise just stay here
                    //I think the nice thing about separate state is waiting for STB_I to be let off, so let's stay with it for now.
                    strobe_o_reg <= 0;
                    if(STB_I == 1) begin
                        //this is unrolled because I used to negate here and couldn't figure out how to do
                        //it all at once - maybe some xor with 8'b11111111
                        dat_reg[0] <= button_state[0];
                        dat_reg[1] <= button_state[1];
                        dat_reg[2] <= button_state[2];
                        dat_reg[3] <= button_state[3];
                        dat_reg[4] <= button_state[4];
                        dat_reg[5] <= button_state[5];
                        dat_reg[6] <= button_state[6];
                        dat_reg[7] <= button_state[7];

                        state <= 2'b01;                     //forgot this wrinkle
                    end
                end

                2'b01 : begin
                    //01 - if STB_I is low, advance to 11 and raise STB_O
                    //so we'll idle here as long as STB_I stays high
                    if(~STB_I) begin
                        strobe_o_reg <= 1;
                        state <= 2'b11;
                    end
                end

                2'b11 : begin
                    //11 - lower STB_O, go to 00
                    strobe_o_reg <= 0;
                    state <= 2'b00;
                end

                2'b10 : begin
                    //10 - currently meaningless, zero out stb_o and go to 00
                    strobe_o_reg <= 0;
                    state <= 2'b00;
                end
            endcase
        end
    end

    assign STB_O = strobe_o_reg;      //is this how I should do this?
    assign DAT_O = dat_reg;           //and is this how you send data? seems to have an extra assign (state -> dat_reg), but who knows when state might have changed...

    assign o_alive = ~alivereg;       // debug LED should toggle when strobe happens - the ~ should make it start out on 1, yes?
endmodule
