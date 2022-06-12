library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.demistify_config_pkg.all;
use work.mmm_v4r0_pmod_pkg.all;


entity mmm_v4r0_l5sd_top is
port(
--	clk_100mhz_n : in std_logic;
	clk_100mhz_p : in std_logic;

	UART_U1_TXD : out std_logic;
	UART_U1_RXD : in std_logic;
	UART_U2_TXD : out std_logic;
	UART_U2_RXD : in std_logic;
	UART_D1_TXD : out std_logic;
	UART_D1_RXD : in std_logic;
	UART_D2_TXD : out std_logic;
	UART_D2_RXD : in std_logic;

	led1 : out std_logic;
	led2 : out std_logic;

	dr_clk : out std_logic;
	dr_cs_n : out std_logic;
	dr_a : out std_logic_vector(12 downto 0);
	dr_d : inout std_logic_vector(15 downto 0);
	dr_we_n : out std_logic;
	dr_ras_n : out std_logic;
	dr_cas_n : out std_logic;
	dr_cke : out std_logic;
	dr_ba : out std_logic_vector(1 downto 0);
	dr_dqm : out std_logic_vector(1 downto 0);
	
	sd_m_cdet : out std_logic;
	sd_m_clk : out std_logic; -- SPI clk
	sd_m_cmd : out std_logic; -- SPI MOSI
	sd_m_d0 : in std_logic; -- SPI MISO
	sd_m_d1 : out std_logic;
	sd_m_d2 : out std_logic;
	sd_m_d3 : out std_logic; -- SPI CS
	
	AUDIO_L : out std_logic;
	AUDIO_R : out std_logic;
	
	EXPMOD1 : inout std_logic_vector(7 downto 0);
	EXPMOD2 : inout std_logic_vector(7 downto 0);
	EXPMOD3 : inout std_logic_vector(7 downto 0);

	dio_p : out std_logic_vector(3 downto 0)
--	dio_n : out std_logic_vector(3 downto 0) -- Don't declare the _n pins - the _p pins are declared as
	                                         -- LVCMOS33D so their conjugate pairs will be used automatically.
);
end entity;

architecture rtl of mmm_v4r0_l5sd_top is

	-- Assign peripherals to PMODs:

	-- PS/2 keyboard and mouse
	constant ps2_pmod_offset : integer := 0; -- Set this to 1 to use the bottom row of pins, 0 to use the top row.
	alias ps2_pmod is EXPMOD2;


	-- Internal signals

	component TRELLIS_IO
	generic(
		DIR : string := "BIDIR"
	);
	port(
		B : inout std_logic;
		I : in std_logic;
		T : in std_logic;
		O : out std_logic
	);
	end component;

	signal ps2k_dat_in : std_logic;
	signal ps2k_dat_out : std_logic;
	signal ps2k_clk_in : std_logic;
	signal ps2k_clk_out : std_logic;
	signal ps2m_dat_in : std_logic;
	signal ps2m_dat_out : std_logic;
	signal ps2m_clk_in : std_logic;
	signal ps2m_clk_out : std_logic;

	signal sdcard_miso : std_logic;
	signal sdcard_mosi : std_logic;
	signal sdcard_cs : std_logic;
	signal sdcard_clk : std_logic;

	signal pcm_l : signed(15 downto 0);
	signal pcm_r : signed(15 downto 0);

	signal clk_tmds : std_logic;
	signal pll_locked : std_logic;

	signal vga_hs : std_logic;
	signal vga_vs : std_logic;
	signal vga_r_i : unsigned(5 downto 0);
	signal vga_g_i : unsigned(5 downto 0);
	signal vga_b_i : unsigned(5 downto 0);
	signal vga_window : std_logic;
	signal vga_pixel : std_logic;
	signal vga_clock : std_logic;
	signal core_clock : std_logic;

	signal dr_drive_dq : std_logic;
	signal dr_dq_in : std_logic_vector(15 downto 0);
	signal dr_dq_out : std_logic_vector(15 downto 0);

	signal reset_n : std_logic;

	signal rxd : std_logic;
	signal txd : std_logic;

	signal spi_clk_int : std_logic;
	signal spi_fromguest : std_logic;
	signal spi_toguest : std_logic;
	signal spi_ss2 : std_logic;
	signal spi_ss3 : std_logic;
	signal spi_ss4 : std_logic;
	signal conf_data0 : std_logic;

begin

	-- PS/2 tristating

	-- Instantiate IOs explicitly to avoid potential issues with tristate signals.
	ps2kd : component TRELLIS_IO port map ( B => ps2_pmod(PMOD_PS2_KDAT+ps2_pmod_offset), I => '0',	T => ps2k_dat_out, O => ps2k_dat_in );
	ps2kc : component TRELLIS_IO port map ( B => ps2_pmod(PMOD_PS2_KCLK+ps2_pmod_offset), I => '0',	T => ps2k_clk_out, O => ps2k_clk_in );
	ps2md : component TRELLIS_IO port map ( B => ps2_pmod(PMOD_PS2_MDAT+ps2_pmod_offset), I => '0',	T => ps2m_dat_out, O => ps2m_dat_in );
	ps2mc : component TRELLIS_IO port map ( B => ps2_pmod(PMOD_PS2_MCLK+ps2_pmod_offset), I => '0',	T => ps2m_clk_out, O => ps2m_clk_in );


	led1<='0';
	led2<='0';

	UART_U1_TXD <= txd;
	UART_U2_TXD <= txd;
	UART_D1_TXD <= txd;
	UART_D2_TXD <= txd;
	rxd <= UART_U1_RXD;

	dr_d <= (others => 'Z');
--	dr_d <= dr_dq_out when dr_drive_dq='1' else (others => 'Z');
--	dr_dq_in <= dr_d;

	guest: COMPONENT jtagdemo_top
	PORT map
		(
			CLOCK_27 => clk_100mhz_p,
	--		RESET_N => reset_n,
			-- clocks
--			SDRAM_DRIVE_DQ => dr_drive_dq,
--			SDRAM_DQ_IN => dr_dq_in,
--			SDRAM_DQ_OUT => dr_dq_out,
			SDRAM_A => dr_a,
			SDRAM_DQML => dr_dqm(0),
			SDRAM_DQMH => dr_dqm(1),
			SDRAM_nWE => dr_we_n,
			SDRAM_nCAS => dr_cas_n,
			SDRAM_nRAS => dr_ras_n,
			SDRAM_nCS => dr_cs_n,
			SDRAM_BA => dr_ba,
			SDRAM_CLK => dr_clk,
			SDRAM_CKE => dr_cke,
			
	--		SPI_SD_DI => sd_miso,
			SPI_DO => spi_fromguest,
			SPI_DI => spi_toguest,
			SPI_SCK => spi_clk_int,
			SPI_SS2	=> spi_ss2,
			SPI_SS3 => spi_ss3,
			SPI_SS4	=> spi_ss4,
			
			CONF_DATA0 => conf_data0,

			VGA_HS => vga_hs,
			VGA_VS => vga_vs,
			unsigned(VGA_R) => vga_r_i,
			unsigned(VGA_G) => vga_g_i,
			unsigned(VGA_B) => vga_b_i,
			VGA_WINDOW => vga_window,
			VGA_PIXEL => vga_pixel,
			CORE_CLK => core_clock,
			VGA_CLK => clk_tmds,
			AUDIO_L => AUDIO_L,
			AUDIO_R => AUDIO_R
	);

	-- Pass internal signals to external SPI interface
	sdcard_clk <= spi_clk_int;

	controller : entity work.substitute_mcu
		generic map (
			sysclk_frequency => 1000,
			SPI_FASTBIT => 3,
			SPI_INTERNALBIT => 1,
			debug => false
		)
		port map (
			clk => clk_100mhz_p,
			reset_in => '1',
			reset_out => reset_n,

			-- SPI signals
			spi_miso => sdcard_miso,
			spi_mosi	=> sdcard_mosi,
			spi_clk => spi_clk_int,
			spi_cs => sdcard_cs,
			spi_fromguest => spi_fromguest,
			spi_toguest => spi_toguest,
			spi_ss2 => spi_ss2,
			spi_ss3 => spi_ss3,
			spi_ss4 => spi_ss4,
			conf_data0 => conf_data0,
			
			-- PS/2 signals
			ps2k_clk_in => ps2k_clk_in,
			ps2k_dat_in => ps2k_dat_in,
			ps2k_clk_out => ps2k_clk_out,
			ps2k_dat_out => ps2k_dat_out,
			ps2m_clk_in => ps2m_clk_in,
			ps2m_dat_in => ps2m_dat_in,
			ps2m_clk_out => ps2m_clk_out,
			ps2m_dat_out => ps2m_dat_out,

			-- Menu button
			
			buttons => (others=>'1'),
			
			-- UART
			rxd => rxd,
			txd => txd
	);


	-- PS/2 tristating
	-- Leave SP/2 unconnected for now...

	-- Instantiate IOs explicitly to avoid potential issues with tristate signals.
--	ps2kd : component TRELLIS_IO port map ( B => ps2_pmod(PMOD_PS2_KDAT+ps2_pmod_offset), I => '0',	T => ps2k_dat_out, O => ps2k_dat_in );
--	ps2kc : component TRELLIS_IO port map ( B => ps2_pmod(PMOD_PS2_KCLK+ps2_pmod_offset), I => '0',	T => ps2k_clk_out, O => ps2k_clk_in );
--	ps2md : component TRELLIS_IO port map ( B => ps2_pmod(PMOD_PS2_MDAT+ps2_pmod_offset), I => '0',	T => ps2m_dat_out, O => ps2m_dat_in );
--	ps2mc : component TRELLIS_IO port map ( B => ps2_pmod(PMOD_PS2_MCLK+ps2_pmod_offset), I => '0',	T => ps2m_clk_out, O => ps2m_clk_in );


	-- Instantiate DVI out:
	genvideo: block
		constant useddr : integer := 1;

		component dvi
		generic ( DDR_ENABLED : integer := useddr );
		port (
			pclk : in std_logic;
			tmds_clk : in std_logic; -- 10 times faster of pclk

			in_vga_red : in unsigned(7 downto 0);
			in_vga_green : in unsigned(7 downto 0);
			in_vga_blue : in unsigned(7 downto 0);

			in_vga_vsync : in std_logic;
			in_vga_hsync : in std_logic;
			in_vga_pixel : in std_logic;
			in_vga_window : in std_logic;

			out_tmds_red : out std_logic_vector(useddr downto 0);
			out_tmds_green : out std_logic_vector(useddr downto 0);
			out_tmds_blue : out std_logic_vector(useddr downto 0);
			out_tmds_clk : out std_logic_vector(useddr downto 0)
		); end component;
		
		component ODDRX1F
		port (
			D0 : in std_logic;
			D1 : in std_logic;
			Q : out std_logic;
			SCLK : in std_logic;
			RST : in std_logic
		); end component;

		signal dvi_r : std_logic_vector(useddr downto 0);
		signal dvi_g : std_logic_vector(useddr downto 0);
		signal dvi_b : std_logic_vector(useddr downto 0);
		signal dvi_clk : std_logic_vector(useddr downto 0);
		
	begin

		dvi_inst : component dvi
		generic map (
			DDR_ENABLED => useddr
		)
		port map (
			pclk => core_clock,
			tmds_clk => clk_tmds,

			in_vga_red(7 downto 2) => vga_r_i,
			in_vga_red(1 downto 0) => "00",
			in_vga_green(7 downto 2) => vga_g_i,
			in_vga_green(1 downto 0) => "00",
			in_vga_blue(7 downto 2) => vga_b_i,
			in_vga_blue(1 downto 0) => "00",

			in_vga_vsync => vga_vs,
			in_vga_hsync => vga_hs,
			in_vga_pixel => vga_pixel,
			in_vga_window => vga_window,

			out_tmds_red => dvi_r,
			out_tmds_green => dvi_g,
			out_tmds_blue => dvi_b,
			out_tmds_clk => dvi_clk
		);
		
		dviout_c : component ODDRX1F port map (D0 => dvi_clk(0), D1=>dvi_clk(1), Q => dio_p(3), SCLK =>clk_tmds, RST=>'0');
		dviout_r : component ODDRX1F port map (D0 => dvi_r(0), D1=>dvi_r(1), Q => dio_p(2), SCLK =>clk_tmds, RST=>'0');
		dviout_g : component ODDRX1F port map (D0 => dvi_g(0), D1=>dvi_g(1), Q => dio_p(1), SCLK =>clk_tmds, RST=>'0');
		dviout_b : component ODDRX1F port map (D0 => dvi_b(0), D1=>dvi_b(1), Q => dio_p(0), SCLK =>clk_tmds, RST=>'0');
		
	end block;

	sd_m_d3 <= sdcard_cs;
	sd_m_cmd <= sdcard_mosi;
	sd_m_clk <= sdcard_clk;
	sdcard_miso <= sd_m_d0;

end architecture;

