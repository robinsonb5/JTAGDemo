//
// jtagdemo_top.sv
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or 
// (at your option) any later version. 
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 
//

module jtagdemo_top (
   input  	 CLOCK_27,

	// LED outputs
   output 	 LED, // LED Yellow
	
   // SDRAM interface
   inout [15:0]  SDRAM_DQ, // SDRAM Data bus 16 Bits
   output [12:0] SDRAM_A, // SDRAM Address bus 13 Bits
   output 	 SDRAM_DQML, // SDRAM Low-byte Data Mask
   output 	 SDRAM_DQMH, // SDRAM High-byte Data Mask
   output 	 SDRAM_nWE, // SDRAM Write Enable
   output 	 SDRAM_nCAS, // SDRAM Column Address Strobe
   output 	 SDRAM_nRAS, // SDRAM Row Address Strobe
   output 	 SDRAM_nCS, // SDRAM Chip Select
   output [1:0]  SDRAM_BA, // SDRAM Bank Address
   output 	 SDRAM_CLK, // SDRAM Clock
   output 	 SDRAM_CKE, // SDRAM Clock Enable
  
   // SPI interface to arm io controller
   output 	 SPI_DO,
   input 	 SPI_DI,
   input 	 SPI_SCK,
   input 	 SPI_SS2,
   input 	 SPI_SS3,
   input 	 SPI_SS4,
   input 	 CONF_DATA0, 

   output 	 AUDIO_L, // sigma-delta DAC output left
   output 	 AUDIO_R, // sigma-delta DAC output right

   output 	 VGA_HS,
   output 	 VGA_VS,
   output [5:0]  VGA_R,
   output [5:0]  VGA_G,
   output [5:0]  VGA_B,

   input     UART_RX,
   output    UART_TX
);

// -------------------------------------------------------------------------
// ------------------------------ user_io ----------------------------------
// -------------------------------------------------------------------------

`include "build_id.v"
parameter CONF_STR = {
        "JTAGDemo;;",
        "O1,Option 1,On,Off;",
        "O23,Option 2,A,B,C,D;",
        "T0,Reset;",
        "V",`BUILD_DATE
};

// the status register is controlled by the on screen display (OSD)
wire [31:0] status;

// SDRAM control signals - safe defaults
assign SDRAM_CKE = 1'b1;
assign SDRAM_nCS = 1'b1;
assign SDRAM_nRAS = 1'b1;
assign SDRAM_nCAS = 1'b1;
assign SDRAM_nWE = 1'b1;
assign SDRAM_DQ={16{1'bz}};

wire vidclk;
wire sysclk;

// include user_io module for arm controller communication
user_io #(.STRLEN($size(CONF_STR)>>3)) user_io (
	.conf_str       ( CONF_STR       ),

	.clk_sys        ( vidclk         ),
	.clk_sd         ( vidclk         ),

	.SPI_CLK        ( SPI_SCK        ),
	.SPI_SS_IO      ( CONF_DATA0     ),
	.SPI_MISO       ( SPI_DO         ),
	.SPI_MOSI       ( SPI_DI         ),

	.status         ( status         )
);

wire hs,vs;
wire [7:0] r,g,b;

mist_video #(.COLOR_DEPTH(6), .OSD_COLOR(3'd5), .SD_HCNT_WIDTH(10), .OSD_AUTO_CE(0)) mist_video (
	.clk_sys     ( vidclk     ),

	// OSD SPI interface
	.SPI_SCK     ( SPI_SCK    ),
	.SPI_SS3     ( SPI_SS3    ),
	.SPI_DI      ( SPI_DI     ),

	.scanlines   ( 2'b00  ),
	.ce_divider  ( 1'b0       ),
	.scandoubler_disable ( 1'b1 ),
	.no_csync    ( 1'b1   ),
	.ypbpr       ( 1'b0      ),
	.rotate      ( 2'b00      ),
	.blend       ( 1'b0       ),

	// video in
	.R           ( r[7:2]    ),
	.G           ( g[7:2]    ),
	.B           ( b[7:2]    ),

	.HSync       ( hs    ),
	.VSync       ( vs    ),

	// MiST video output signals
	.VGA_R       ( VGA_R      ),
	.VGA_G       ( VGA_G      ),
	.VGA_B       ( VGA_B      ),
	.VGA_VS      ( VGA_VS     ),
	.VGA_HS      ( VGA_HS     )
);

assign AUDIO_L=1'b1;
assign AUDIO_R=1'b1;

// A PLL to derive the system clock from the MiSTs 27MHz

wire pll_locked;

pll pll (
	.inclk0  ( CLOCK_27  ),
	.c0      ( SDRAM_CLK ),
	.c1      ( sysclk    ),
	.c2      ( vidclk    ),
	.locked  ( pll_locked )
);


jtagdemo #(.sysclk_frequency(1000)) test (
	.clk(sysclk),
	.reset_in(pll_locked & !status[0]),
	.hs(hs),
	.vs(vs),
	.r(r),
	.g(g),
	.b(b),
	.status(status)
);

endmodule

