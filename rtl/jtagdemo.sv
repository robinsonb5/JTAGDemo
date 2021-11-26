// JTAG Demo

module jtagdemo #(parameter sysclk_frequency=1000) (
	input  wire       clk,
	input  wire       reset_in,
	output hs,
	output vs,
	output [7:0] r,
	output [7:0] g,
	output [7:0] b,
	output [15:0] audio_l,
	output [15:0] audio_r,
	output vena,
	output pixel,
	input [31:0] status
);


reg [11:0] filterval;
reg [7:0] red;
reg [7:0] green;
reg [7:0] blue;
reg [31:0] framecount;

reg jtag_reset=1'b1;
reg jtag_report=1'b0;

wire reset_n;
assign reset_n = jtag_reset & reset_in;


localparam JTAG_IDX_MAX=2;


wire jtag_req;
wire jtag_ack;
wire jtag_wr;
reg [3:0] jtag_idx=JTAG_IDX_MAX;
reg [31:0] jtag_d;
wire [31:0] jtag_q;


// Data sent to the host computer 

always @(posedge clk) begin
		case(jtag_idx)
			4'h0: jtag_d<=framecount;
			4'b1: jtag_d<=status;
		endcase
end


// Data received from the host computer

always @(posedge clk) begin
	jtag_reset<=1'b1;
	jtag_report<=1'b0;
	if(jtag_ack && !jtag_wr) begin
		case(jtag_q[31:24]) // Interpret the highest 8 bits as a command byte

			8'h00: begin	// Command 0: interpret the rest of the word as an RGB colour value
					red <= jtag_q[23:16];
					green <= jtag_q[15:8];
					blue <= jtag_q[7:0];
			end

			8'h01: filterval <= jtag_q[11:0];	// Command 1: Filter delay

			8'hfe: jtag_report<=1'b1;

			8'hff: jtag_reset<=1'b0; // Command 0xff: reset

		endcase
	end
end


// Plumbing

always @(posedge clk or negedge reset_in) begin
	if(!reset_in) begin
		jtag_wr<=1'b0;
		jtag_req<=1'b0;
		jtag_idx<=JTAG_IDX_MAX;
	end else begin
		jtag_req<=!jtag_ack;
		jtag_wr<=(jtag_idx!=JTAG_IDX_MAX);

		if(jtag_report) begin
			jtag_idx<=1'b0;
			jtag_wr<=1'b1;
		end

		if(jtag_ack && jtag_wr)
			jtag_idx<=jtag_idx+1'b1;
		
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


// Sound:
// Create a 32-bit LFSR

wire [31:0] lfsrdata;
reg lfsr_ena;

lfsr #(.width(32)) lfsr
(
	.clk(clk),
	.reset_n(reset_n),
	.e(lfsr_ena),
	.save(1'b0),
	.restore(1'b0),
	.q(lfsrdata)
);

reg [11:0] lfsrtick;
always @(posedge clk) begin
	lfsrtick<=lfsrtick-1'b1;
	lfsr_ena<=1'b0;
	if(!lfsrtick) begin
		lfsrtick<=12'd2267;
		lfsr_ena<=1'b1;
	end
end


// Filter

reg filter_ena;
reg [11:0] filtertick;
always @(posedge clk) begin
	filtertick<=filtertick-1'b1;
	filter_ena<=1'b0;
	if(!filtertick) begin
		filtertick<=filterval;
		filter_ena<=1'b1;
	end
end

wire [15:0] filterdata_l;
wire [15:0] filterdata_r;
wire [15:0] filterdata2_l;
wire [15:0] filterdata2_r;

iirfilter_stereo #(.signalwidth(15),.cbits(4),.immediate(0), .highpass(0))
(
	.clk(clk),
	.reset_n(reset_n),
	.ena(filter_ena),
	.d_l(lfsrdata[31:16]),
	.d_r(lfsrdata[15:0]),
	.q_l(filterdata_l),
	.q_r(filterdata_r)
);

iirfilter_stereo #(.signalwidth(15),.cbits(4),.immediate(0), .highpass(1))
(
	.clk(clk),
	.reset_n(reset_n),
	.ena(filter_ena),
	.d_l(filterdata_l),
	.d_r(filterdata_r),
	.q_l(filterdata2_l),
	.q_r(filterdata2_r)
);

assign audio_l=filterdata2_l;
assign audio_r=filterdata2_r;

endmodule

