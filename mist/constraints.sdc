set sysclk ${topmodule}pll|altpll_component|auto_generated|pll1|clk[1]
set vidclk ${topmodule}pll|altpll_component|auto_generated|pll1|clk[2]

set_clock_groups -asynchronous -group spiclk [get_clocks $vidclk]

create_generated_clock -name sdramclk -source [get_pins ${topmodule}pll|altpll_component|auto_generated|pll1|clk[0]] [get_ports $RAM_CLK]

set_input_delay -clock sdramclk -max 6.5 $RAM_IN
set_input_delay -clock sdramclk -min 1.5 $RAM_IN

set_output_delay -clock sdramclk -max 1.5 $RAM_OUT
set_output_delay -clock sdramclk -min -0.8 $RAM_OUT

set_multicycle_path -from sdramclk -to [get_clocks $sysclk] -setup -end 2

set_false_path -to $FALSE_OUT
set_false_path -from $FALSE_IN

set_false_path -to $VGA_OUT

set_false_path -to $RAM_CLK
