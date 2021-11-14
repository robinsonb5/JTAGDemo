// JTAG Demo

module jtagdemo #(parameter sysclk_frequency=1000) (
	input  wire       clk,
	input  wire       reset_in,
	output hs,
	output vs,
	output [7:0] r,
	output [7:0] g,
	output [7:0] b,
	output vena,
	output pixel,
	input [31:0] status
);

reg jtag_reset=1'b1;
wire reset_n;
assign reset_n = jtag_reset & reset_in;


localparam JTAG_START=0;
localparam JTAG_WAIT=1;
localparam JTAG_ACT=2;
localparam JTAG_STATUS=3;
localparam JTAG_DORESET=4;
reg [2:0] jtag_nextstate;
reg [2:0] jtag_state;
wire jtag_req;
wire jtag_ack;
wire jtag_wr;
wire [31:0] jtag_d;
wire [31:0] jtag_q;

reg [7:0] red;
reg [7:0] green;
reg [7:0] blue;
reg [31:0] framecount;

always @(posedge clk or negedge reset_in) begin
	if(!reset_in) begin
		jtag_state<=JTAG_START;
		jtag_nextstate<=JTAG_START;
		jtag_req<=1'b0;
		jtag_wr<=1'b0;
		jtag_reset<=1'b1;
	end else begin

		case(jtag_state)
			JTAG_START: begin
					jtag_reset<=1'b1;
					jtag_wr<=1'b0;
					jtag_req<=1'b1;
					jtag_state<=JTAG_WAIT;
					jtag_nextstate<=JTAG_ACT;
				end
			JTAG_ACT: begin
					if(jtag_q[31:24]==8'hff) begin
						jtag_reset<=1'b0;
						jtag_state<=JTAG_DORESET;
					end else begin
						red <= jtag_q[23:16];
						green <= jtag_q[15:8];
						blue <= jtag_q[7:0];
						jtag_d <= framecount;
						jtag_wr<=1'b1;
						jtag_req<=1'b1;
						jtag_state<=JTAG_WAIT;
						jtag_nextstate<=JTAG_STATUS;
					end
				end
			JTAG_STATUS: begin
					jtag_d <= status;
					jtag_wr<=1'b1;
					jtag_req<=1'b1;
					jtag_state<=JTAG_WAIT;
					jtag_nextstate<=JTAG_START;
				end
			JTAG_DORESET: begin
					jtag_state<=JTAG_START;
				end
			JTAG_WAIT: begin
					if(jtag_ack) begin
						jtag_state<=jtag_nextstate;
						jtag_req<=1'b0;
						jtag_wr<=1'b1;
					end
				end
		endcase
	
	end
end

// This bridge is borrowed from the EightThirtyTwo debug interface

debug_bridge_jtag #(.id('h55aa)) bridge (
	.clk(clk),
	.reset_n(reset_n),
	.d(jtag_d),
	.q(jtag_q),
	.req(jtag_req),
	.wr(jtag_wr),
	.ack(jtag_ack)
);



// Video timings / frame generation

wire [10:0] xpos;
wire hb;
wire vb;
wire vb_stb;

video_timings vt
(
	.clk(clk),
	.reset_n(reset_n),
	.hsync_n(hs),
	.vsync_n(vs),
	.hblank_n(hb),
	.vblank_n(vb),
	.vblank_stb(vb_stb),
	.xpos(xpos),
	.pixel_stb(pixel)
);

assign vena=hb&vb;
reg vb_d;

always @(posedge clk) begin
	vb_d<=vb;
	if(vb & !vb_d)
		framecount<=framecount+1;
	if(hb&vb) begin
		r<=red;
		g<=green;
		b<=blue;
	end else begin
		r<=8'b0;
		g<=8'b0;
		b<=8'b0;
	end
	if(!reset_n)
		framecount<=32'd0;
end


endmodule

