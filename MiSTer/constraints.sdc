set topmodule emu|

set RAM_CLK SDRAM_CLK
set RAM_IN SDRAM_DQ[*]
set RAM_OUT {SDRAM_A[*] SDRAM_DQ[*] SDRAM_DQMH SDRAM_DQML SDRAM_nRAS SDRAM_nCAS SDRAM_nWE SDRAM_nCS}

set sysclk ${topmodule}pll|pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk

create_generated_clock -name sdramclk -source [get_pins ${topmodule}pll|pll_inst|altera_pll_i|outclk_wire[0]~CLKENA0|outclk] [get_ports $RAM_CLK]

set_input_delay -clock sdramclk -max 6.5 $RAM_IN
set_input_delay -clock sdramclk -min 1.5 $RAM_IN

set_output_delay -clock sdramclk -max 1.5 $RAM_OUT
set_output_delay -clock sdramclk -min -0.8 $RAM_OUT

set_multicycle_path -from sdramclk -to [get_clocks $sysclk] -setup -end 2
