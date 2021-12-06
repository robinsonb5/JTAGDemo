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

// Aliases for controls within the status word

wire st_trigger = status[1]; // Trigger sound

// Parameters which are remotely controlled from the host computer:

reg [11:0] filterval = 12'h20;
reg chirp;
reg [11:0] chirpctr;
reg [11:0] ksperiod = 12'h20;
reg [11:0] ksfilterperiod = 12'h20;
reg [7:0] red;
reg [7:0] green;
reg [7:0] blue;

reg jtag_reset=1'b0;
reg jtag_report=1'b0;


// Data sent to the host computer 

localparam JTAG_IDX_MAX=2;

reg [31:0] framecount;

reg [3:0] jtag_idx=JTAG_IDX_MAX;
reg [31:0] jtag_d;

always @(posedge clk) begin
		case(jtag_idx)
			4'h0: jtag_d<=framecount;
			4'b1: jtag_d<=status;
		endcase
end


// Data received from the host computer

wire jtag_req;
wire jtag_ack;
wire jtag_wr;
wire [31:0] jtag_q;

always @(posedge clk) begin
	jtag_reset<=1'b0;
	jtag_report<=1'b0;
	chirp<=1'b0;
	if(jtag_ack && !jtag_wr) begin
		case(jtag_q[31:24]) // Interpret the highest 8 bits as a command byte

			8'h00: begin	// Command 0: interpret the rest of the word as an RGB colour value
					red <= jtag_q[23:16];
					green <= jtag_q[15:8];
					blue <= jtag_q[7:0];
			end

			8'h01: filterval <= jtag_q[11:0];	// Command 1: Filter delay

			8'h02: ksperiod <= jtag_q[11:0];	// Command 2: Karplus Strong delay

			8'h03: ksfilterperiod <= jtag_q[11:0];	// Command 2: Karplus Strong delay

			8'hfd: chirp<=1'b1;
			
			8'hfe: jtag_report<=1'b1;

			8'hff: jtag_reset<=1'b1; // Command 0xff: reset

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


wire reset_n;
assign reset_n = ~jtag_reset & reset_in;


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


// Lowpass filter following LFSR

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

iirfilter_stereo #(.signalwidth(16),.cbits(4),.highpass(0)) lpfilter
(
	.clk(clk),
	.reset_n(reset_n),
	.ena(filter_ena),
	.d_l(lfsrdata[31:16]),
	.d_r(lfsrdata[15:0]),
	.q_l(filterdata_l),
	.q_r(filterdata_r)
);


// Highpass filter following previous lowpass filter

wire [15:0] filterdata2_l;
wire [15:0] filterdata2_r;

iirfilter_stereo #(.signalwidth(16),.cbits(4),.highpass(1)) hpfilter
(
	.clk(clk),
	.reset_n(reset_n),
	.ena(filter_ena),
	.d_l(filterdata_l),
	.d_r(filterdata_r),
	.q_l(filterdata2_l),
	.q_r(filterdata2_r)
);


// Karplus-Strong waveguide

// period tick, and initial excitement burst

reg ks_ena;
reg [11:0] kstick;
always @(posedge clk) begin
	kstick<=kstick-1'b1;
	ks_ena<=1'b0;

	if(chirp || st_trigger)
		chirpctr<=chirpctr-1'b1;

	if(!kstick) begin
		kstick<=ksperiod;
		ks_ena<=1'b1;
		if(chirpctr)
			chirpctr<=chirpctr-1'b1;
	end
end


// Filter tick

reg ksfilter_ena;
reg [11:0] ksfiltertick;
always @(posedge clk) begin
	ksfiltertick<=ksfiltertick-1'b1;
	ksfilter_ena<=1'b0;
	if(!ksfiltertick) begin
		ksfiltertick<=ksfilterperiod;
		ksfilter_ena<=1'b1;
	end
end


wire [15:0] ksdata_l;
wire [15:0] ksdata_r;

karplus_strong ks1 
(
	.clk(clk),
	.reset_n(reset_n),
	.ena(ks_ena),
	.filter_ena(ksfilter_ena),
	.d(chirpctr ? filterdata2_l : 16'h0000),
	.q(ksdata_l)
);

karplus_strong ks2
(
	.clk(clk),
	.reset_n(reset_n),
	.ena(ks_ena),
	.filter_ena(ksfilter_ena),
	.d(chirpctr ? filterdata2_r : 16'h0000),
	.q(ksdata_r)
);

assign audio_l=ksdata_l;
assign audio_r=ksdata_r;

endmodule

