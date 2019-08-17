/*
Here's the dummy mentor which also has a student interface. It's just a link in a dataflow chain
Student interface can receive data from testbench, which touches off the state machine.
state
any - if RST_I is 1, zero everything out incl state
00 - reset/initial, send all the outgoing signals low, load data advance to 01 if STB_I goes high
01 - if STB_I is low, advance to 11 and raise STB_O
11 - lower STB_O, go to 00
10 - currently meaningless, zero out STB_O and go to 00
*/
`default_nettype	none

module prewish5k_mentor(
    input CLK_I,        //mentor/outgoing interface, writes to blinky
    input RST_I,
    output STB_O,
    output[7:0] DAT_O,
    input STB_I,        //then here is the student that takes direction from testbench
    input[7:0] DAT_I,
    output o_alive      // debug outblinky
);
    reg[1:0] state = 2'b00;
    reg strobe_reg = 0;
    reg[7:0] dat_reg = 8'b00000000;

    reg alivereg = 0;           //debug thing to toggle alive-LED when strobes happen?

    //state machine
    always @(posedge CLK_I) begin
        if(RST_I == 1) begin
            strobe_reg <= 0;    //resset! glue state and output to 0
            state <= 2'b00;
        end else begin
            //state machine stuff
            case (state)
                2'b00 : begin
                    //00 - reset/initial, send all the outgoing signals low, load data advance to 01 if STB_I goes high
                    //otherwise just stay here
                    strobe_reg <= 0;
                    if(STB_I == 1) begin
                        alivereg <= ~alivereg;  //toggle alive-reg for debug
                        dat_reg <= DAT_I;       //load data from input pins to output register
                        state <= 2'b01;         //advance to 01
                    end
                end

                2'b01 : begin
                    //01 - if STB_I is low, advance to 11 and raise STB_O (wait for strobe to drop)
                    if(~STB_I) begin
                        strobe_reg <= 1;
                        state <= 2'b11;
                    end
                end

                2'b11 : begin
                    //11 - lower STB_O, go to 00
                    strobe_reg <= 0;
                    state <= 2'b00;         //had a thing where it went to 10
                end

                2'b10 : begin
                    //10 - currently meaningless, zero out stb_o and go to 00
                    strobe_reg <= 0;
                    state <= 2'b00;
                end
            endcase

        end
    end

    assign STB_O = strobe_reg;      //is this how I should do this? Similar seems to work with reset. Necessary?
    assign DAT_O = dat_reg;         //and is this how you send data?

    assign o_alive = ~alivereg;      // debug LED should toggle when strobe happens - the ~ should make it start out on
endmodule
