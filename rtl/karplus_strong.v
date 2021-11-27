module karplus_strong #(parameter datawidth=16, depthbits=12)
(
	input clk,
	input reset_n,
	input ena,
	input filter_ena,
	input [datawidth-1:0] d,
	output reg [datawidth-1:0] q
);

reg [datawidth-1:0] buffer [2**depthbits-1:0];
reg [depthbits-1:0] ptr;

reg [datawidth:0] sum;
wire [datawidth-1:0] filter_q;

iirfilter_mono #(.signalwidth(datawidth), .cbits(5),.immediate(0)) filter
(
	.clk(clk),
	.reset_n(reset_n),
	.ena(filter_ena),
	.d(buffer[ptr]),
	.q(filter_q)
);


always @(posedge clk) begin

	sum <= d + filter_q;
	if(ena) begin
		buffer[ptr]<=sum[datawidth-1:0];
		ptr<=ptr+1'b1;
	end
	q <= sum[datawidth-1:0];
end

endmodule
