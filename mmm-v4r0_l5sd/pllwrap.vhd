library ieee;
use ieee.std_logic_1164.all;

entity pllwrap is
port(
	clk_i : in std_logic;
	clk_o : out std_logic_vector(3 downto 0);
	reset : in std_logic;
	locked : out std_logic
);
end entity;

architecture rtl of pllwrap is

begin
	
ecp5pll : entity work.ecp5pll
generic map (
	in_hz => 100000,
	out0_hz => 100000,
	out0_tol_hz => 3000,
	out0_deg => 270,
	out1_hz => 100000,
	out1_tol_hz => 3000,
	out2_hz => 50000,
	out2_tol_hz => 3000,
	out3_hz => 125000,
	out3_tol_hz => 3000	
)
port map (
	clk_i => clk_i,
	clk_o => clk_o,
	reset => reset,
	locked => locked
);

end architecture;

