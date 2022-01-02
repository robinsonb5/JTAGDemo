// Simple IIR Bandpass filter
// Copyright 2022 by Alastair M. Robinson

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that they will
// be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
// of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>
//

module iirbandpass #(parameter inputwidth=16, parameter outputwidth=16)
(
	input clk,
	input reset_n,
	input ena,
	input [inputwidth-1:0] d,
	output reg [outputwidth-1:0] q
);

// 13, 11, 12 -> 109Hz
// 13, 10, 12 -> 190Hz
// 13, 9, 12 -> 290Hz
// 13, 8, 12 -> 424Hz
// 13, 7, 12 -> 611Hz
// 13, 6, 12 -> 871Hz
// 13, 5, 12 -> 1237Hz
// 13, 4, 12 -> 1756Hz
// 13, 3, 12 -> 2492Hz

//bpdata_r[23:8]
// 12, 9, 11 -> 269Hz - wider bandpass, breathier sound
// 12, 9, 12 -> 290Hz - Louder
localparam widthdif = outputwidth-inputwidth;
localparam bshift = 10-widthdif;	// Amplitude
localparam a1shift = 10;		// Pitch
localparam a2shift = 14;		// Resonance - but affects the pitch

localparam footroom=bshift;
localparam headroom=1+footroom;

reg [outputwidth-1:0] x_0;
reg [outputwidth-1:0] x_1;
reg [outputwidth-1:0] x_2;
reg [outputwidth+headroom-1:0] y_1;
reg [outputwidth+headroom-1:0] y_2;

wire [outputwidth+headroom-1:0] x_0_shifted = {{widthdif+bshift+headroom-footroom{1'b0}},x_0[outputwidth-1:bshift-footroom]};
wire [outputwidth+headroom-1:0] x_2_shifted = {{widthdif+bshift+headroom-footroom{1'b0}},x_2[outputwidth-1:bshift-footroom]};
wire [outputwidth+headroom-1:0] y_1_shifted = {{a1shift{y_1[outputwidth+headroom-1]}},y_1[outputwidth+headroom-1:a1shift]};
wire [outputwidth+headroom-1:0] y_2_shifted = {{a2shift{y_2[outputwidth+headroom-1]}},y_2[outputwidth+headroom-1:a2shift]};

wire [outputwidth+headroom-1:0] x_sum = x_0_shifted - x_2_shifted;
wire [outputwidth+headroom-1:0] y2_sum = y_2_shifted - y_2;
wire [outputwidth+headroom-1:0] y1_sum = y_1 + y_1 - y_1_shifted;


always @(*) begin
	case(y_1[outputwidth+footroom:outputwidth+footroom-1])
		2'b00 : q <= y_1[outputwidth+footroom-1:footroom];
		2'b11 : q <= y_1[outputwidth+footroom-1:footroom];
		2'b01 : q <= {1'b0,{outputwidth-1{1'b1}}};
		2'b10 : q <= {1'b1,{outputwidth-1{1'b0}}};
	endcase
end

always @(posedge clk) begin

	if(ena) begin
		x_2<=x_1;
		x_1<=x_0;
		x_0<=d;
		y_2<=y_1;
		y_1 <= x_sum + y1_sum + y2_sum;
	end
end

endmodule
