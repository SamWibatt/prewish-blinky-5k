// making a little tb for just the debounce, bc I should do that.
// and make a gneralized sim.sh.
// kind of ok `timescale 100ns/10ns
`timescale 100ns/100ns

//let's see if this can work to tell the tool chain we're simulating
`define SIM_STEP


// APP SPECIFIC THINGS ===========================================================================================================================================
// like here I will make up a modulito that just emits "noisy," i.e. 1-bit random, signal at the frequency of clk.
// simulates button bounce.
// per https://www.quora.com/What-would-be-the-verilog-code-for-8-bit-linear-feedback-shift-register here is an 8 bit lfsr
// slight mods like changing reset signal name to "reset" from "rst"
// feh, these look very repeaty, maybe the thing isn't to assign to one bit - well, sampling out[0] gives us the feedback bit, which is pretty wiggly
// if the clock is enough faster than slowclk this looks pretty noisy
module lfsr8 (out, clk, reset);
	output reg [7:0] out = 0;				//doesn't work with 0, which is why reset block below does the 8'hff, but for that first clock tick we need something here to avoid X
	input clk, reset;
	wire feedback;
	//assign feedback = ~(out[7] ^ out[6]);		//one below uses different taps, if wanna try - yeah, let's try them
	assign feedback = out[4] ^ out[2];  // these are taps (depends on polynomial used)
	always @(posedge clk)		//original had, negedge reset) and used blocking (? the bare = kind) assigns. Also that means reset is active low, which mine isn't.
	begin
		if (reset) begin				//sean made reset active high
			out <= 8'h7F;				//orig 7'hFF;		//sean adds <; he had 7'h not sure why, throws a warning re truncation. Might have been going for 7F? FF seems to get glued in place forever. 7F appears to work
		end	else begin
			out <= {out[6:0],feedback};		//sean adds <
		end
	end
endmodule
/* another one that looks quite similar
reg [7:0] lfsr;  // lfsr register
wire bit;			//original had reset declared here too, but I generate my own
assign bit = lfsr[4] ^ lfsr[2];  // these are taps (depends on polynomial used)
always@(posedge clk) begin
	if (reset)
		 lfsr <= 8'hFF;   // lfsr must be non-zero to work. Sean notes might want to populate with a different seed, but this should be ok for the task at hand and several others!
	else
		 lfsr <= {lfsr[6:0], bit};
end
*/


// Main module -----------------------------------------------------------------------------------------

module prewish5k_debounce_tb;


	// TESTBENCH BOILERPLATE =========================================================================================================================================

	//here is the core of the prewish5k interconnect
	//here is generic clock. use for CLK_I in modules
    reg clk = 0;
    always #1 clk = (clk === 1'b0);

	//and a little lump to act as the tiniest syscon ever: -----------------------------------------------
	//from https://electronics.stackexchange.com/questions/405363/is-it-possible-to-generate-internal-reset-pulse-in-verilog-with-machxo3lf-fpga
    //tis worky, drops reset to 0 at 15 clocks
  reg [3:0] rst_cnt = 0;
	wire reset = ~rst_cnt[3];     // My reset is active high, original was active low; I think that's why it was called rst_n
	always @(posedge clk)      // see if I can use the output that way
		if( reset )               // active high reset
            rst_cnt <= rst_cnt + 1;
	//end tiny syscon ------------------------------------------------------------------------------------
	/* turns out debounce can't use this - but something like it might help a little bit,
	the somewhat divided sysclk like down to a millisecond, so this prescale can save us FFs for each
	thing what needs debounced, curently they need 17 bits for a 120Hz-ish rate.

	//and a clock divider, bc I think I'm going to design my modules to use buffered clocks & therefore clock param
	//which lets me consolidate the clock dividing and save ffs if I want to potato-stamp copies of modules all over
	//by default, assuming iceStick 12 MHz clock, can fancy up the math and do pll stuff later.
	//so, 20 bits would be a divide-by-million so 12Hz, ish. fiddle around from there.
	//for simulation, let's make this small, like say 7, we do want to be able to have a pseudo-noisy input whose frequency is a lot higher than the
	//debounce interval. 128 should make us not need too much simulation time, but give us good resolution
	//delete or duplicate or decorate as needed. Maybe modularize.
	parameter SLOW_CLK_BITS=7;
	reg [SLOW_CLK_BITS-1:0] slow_clk_ct = 0;

	always @(posedge clk) begin
		if (~reset) begin
			slow_clk_ct <= slow_clk_ct + 1;
		end else begin
			slow_clk_ct <= 0;
		end
	end

	wire slow_clk = slow_clk_ct[SLOW_CLK_BITS-1];			//hopework - does! but much too predictable,
	*/
	//more interconnect stuff
	wire strobe;
  wire[7:0] data;

	// END TESTBENCH BOILERPLATE =====================================================================================================================================

	wire[7:0] randwire;			//not sure if I can use regs declared here or if that makes them get multiply driven or what - figure out. So I will try reg and swh
	//nope, not regs
	/*
		prewish5k_debounce_tb.v:87: error: reg rando; cannot be driven by primitives or continuous assignment.
		prewish5k_debounce_tb.v:87: error: Output port expression must support continuous assignment.
		prewish5k_debounce_tb.v:87:      : Port 1 (out) of lfsr8 is connected to rando
	*/
	lfsr8 rng(randwire,clk,reset);

	//then the always that makes our random signal
	reg noisybit = 0;
	always @(posedge clk) begin
		noisybit <= randwire[0];		//try uppermost bit - looked ok, try one in the middle, pretty repeaty. bit 0 is "feedback" which looks pretty random, let's try it
	end

	// THING WE'RE TESTING ===========================================================================================================================================
	//here's what we're testing
	// module prewish5k_debounce(
	// 	input CLK_I,
	// 	input RST_I,
	// 	output STB_O,        //mentor/outgoing interface, writes to caller with current status byte
	// 	output[7:0] DAT_O,
	// 	input STB_I,        //then here is the student that takes direction from testbench
	// 	input[7:0] DAT_I,
	// 	input i_button,	// active HIGH input from button, caller presumably just passes this straight along from a pad WILL BE REFACTORED INTO AN ARRAY
	//NOT ANYMORE input i_dbclock,	// debounce (slow) clock
	// 	//output ACK_O,		// do I need this? let's say not, for the moment; I think it's for stuff that might not work right away and will ping back later with results?
	// 	output o_alive      // debug outblinky
	// );

	wire db_alive;		//would tie to an LED if we were really running this

	wire[7:0] data_from_db;
	wire strobe_from_db;

	reg[7:0] data_to_db = 0;
	reg strobe_to_db = 0;

	reg button_raw = 0;		//active low pin value for button

	prewish5k_debounce db(
		.CLK_I(clk),
		.RST_I(reset),
		.STB_O(strobe_from_db),        //mentor/outgoing interface, writes to caller with current status byte
		.DAT_O(data_from_db),
		.STB_I(strobe_to_db),        //then here is the student that takes direction from testbench
		.DAT_I(data_to_db),
		.i_button(button_raw),		 // first test just used noisybit here. active HIGH input from button, caller presumably just passes this straight along from a pad WILL BE REFACTORED INTO AN ARRAY
		//.i_dbclock(slow_clk),		// debounce (slow) clock
		//output ACK_O,		// do I need this? let's say not, for the moment; I think it's for stuff that might not work right away and will ping back later with results?
		.o_alive(db_alive)      // debug outblinky
	);

	// end THING WE'RE TESTING =======================================================================================================================================

	// SIMULATION PROPER =============================================================================================================================================
    //bit for creating gtkwave output
    initial begin
        //uncomment the next two for gtkwave?
		$dumpfile("prewish5k_debounce_tb.vcd");
		$dumpvars(0, prewish5k_debounce_tb);
    end

    initial begin
		#1 button_raw = 0;		//start off with button "off" (active high)
		#50 button_raw = 1;
		#7 button_raw = 0;
		#100 button_raw = 1;
		#123 button_raw = 0;
    #12000 $finish;
    end

endmodule
