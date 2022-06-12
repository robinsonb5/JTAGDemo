module pll (
	input inclk0,
	output c0,
	output c1,
	output c2,
	output c3,
	output locked
);

wire [3:0] clk_o;

assign c0=clk_o[0];
assign c1=clk_o[1];
assign c2=clk_o[2];
assign c3=clk_o[3];

pllwrap pll (
	.clk_i(inclk0),
	.clk_o(clk_o),
	.reset(1'b0),
	.locked(locked)
);

endmodule

