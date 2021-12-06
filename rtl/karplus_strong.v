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
reg [datawidth-1:0] filter_d;

iirfilter_mono #(.signalwidth(datawidth), .cbits(5),.immediate(0)) filter
(
	.clk(clk),
	.reset_n(reset_n),
	.ena(filter_ena),
	.d(filter_d),
	.q(filter_q)
);

always @(posedge clk or negedge reset_n) begin
	if(!reset_n) begin
		filter_d<={1'b1,{datawidth-1{1'b0}}};
		ptr<={depthbits{1'b0}};
	end else begin
		if(ena)
			ptr<=ptr+1'b1;
		filter_d<=buffer[ptr];
	end
end

always @(posedge clk) begin
	sum <= d + filter_q;
	if(ena)
		buffer[ptr]<=sum[datawidth-1:0];
	q <= sum[datawidth-1:0];
end

endmodule
