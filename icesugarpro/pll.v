module pll (
	input inclk0,
	output c0,
	output c1,
	output c2,
	output locked
);

wire [3:0] clk_o;

assign c0=clk_o[0];
assign c1=clk_o[1];
assign c2=clk_o[2];

ecp5pll
#(
	.in_hz(25000000),
	.out0_hz(100000000),
	.out0_tol_hz(1000000),
	.out0_deg(270),
	.out1_hz(100000000),
	.out1_tol_hz(1000000),
	.out1_deg(0),
	.out2_hz(50000000),
	.out2_tol_hz(1000000)
) pll (
	.clk_i(inclk0),
	.clk_o(clk_o),
	.reset(1'b0),
	.locked(locked)
);

endmodule

