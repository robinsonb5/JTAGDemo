library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dacwrap is
port (
	clk : in std_logic;
	reset_n : in std_logic;
	d_l : in std_logic_vector(15 downto 0);
	d_r : in std_logic_vector(15 downto 0);
	q_l : out std_logic;
	q_r : out std_logic
);
end entity;

architecture rtl of dacwrap is

begin

ldac : entity work.dac
generic map(C_bits => 16)
port map (
	clk_i => clk,
	res_n_i => reset_n,
	dac_i => d_l,
	dac_o => q_l
);

rdac : entity work.dac
generic map(C_bits => 16)
port map (
	clk_i => clk,
	res_n_i => reset_n,
	dac_i => d_r,
	dac_o => q_r
);

end architecture;

