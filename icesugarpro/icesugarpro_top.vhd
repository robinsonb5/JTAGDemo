library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.icesugarpro_pmod_pkg.all;
use work.demistify_config_pkg.all;

entity icesugarpro_top is
port(
	clk_i : in std_logic; -- 25MHz

	txd : out std_logic;
	rxd : in std_logic;

	led_red : out std_logic;
	led_green : out std_logic;
	led_blue : out std_logic;

	sdram_clk : out std_logic;
	sdram_cs_n : out std_logic;
	sdram_a : out std_logic_vector(12 downto 0);
	sdram_dq : inout std_logic_vector(15 downto 0);
	sdram_we_n : out std_logic;
	sdram_ras_n : out std_logic;
	sdram_cas_n : out std_logic;
	sdram_cke : out std_logic;
	sdram_ba : out std_logic_vector(1 downto 0);
	sdram_dm : out std_logic_vector(1 downto 0);
	
	spisdcard_clk : out std_logic;
	spisdcard_mosi : out std_logic;
	spisdcard_cs_n : out std_logic;
	spisdcard_miso : in std_logic;

	gpdi_dp : out std_logic_vector(3 downto 0);	-- Quasi-differential output for digital video.
	gpdi_dn : out std_logic_vector(3 downto 0);

	P2_pmod_high : inout std_logic_vector(7 downto 0);
	P2_gpio : inout std_logic_vector(3 downto 0);
	P2_pmod_low : inout std_logic_vector(7 downto 0);
	P3_pmod_high : inout std_logic_vector(7 downto 0);
	P3_gpio : inout std_logic_vector(3 downto 0);
	P3_pmod_low : inout std_logic_vector(7 downto 0);
	P4_pmod_low : inout std_logic_vector(7 downto 0);
	P4_gpio : inout std_logic_vector(3 downto 0);
	P4_gpio2 : inout std_logic_vector(5 downto 0); -- Two pins not connected, so called GPIO instead of PMOD.
	P5_pmod_high : inout std_logic_vector(7 downto 0); -- Pins shared with breakout board's DAPLink.
	P5_gpio : inout std_logic_vector(3 downto 0);
	P5_pmod_low : inout std_logic_vector(7 downto 0);
	P6_pmod_high : inout std_logic_vector(7 downto 0);
	P6_gpio : inout std_logic_vector(3 downto 0);
	P6_pmod_low : inout std_logic_vector(7 downto 0)
);
end entity;

architecture rtl of icesugarpro_top is

	-- Assign peripherals to PMODs:

	-- PS/2 keyboard and mouse
	constant ps2_pmod_offset : integer := 4; -- Set this to 4 to use the bottom row of pins, 0 to use the top row.
	alias ps2_pmod is P6_pmod_high;

	-- Audio
	alias sigmadelta_pmod is P2_pmod_low;
	alias i2s_pmod is P2_pmod_high;

	-- SD Card
	constant use_pmod_sdcard : boolean := true; -- Set to false to use the built-in (but awkwardly-placed) micro-SD slot
	alias sdcard_pmod is P5_pmod_low;

	-- VGA
	alias vga_pmod_high is P3_pmod_high;
	alias vga_pmod_low is P3_pmod_low;

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


-- Sigma Delta audio
	COMPONENT hybrid_pwm_sd_2ndorder
	PORT
	(
		clk	:	IN STD_LOGIC;
		reset_n : in std_logic;
--		terminate : in std_logic;
		d_l	:	IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		q_l	:	OUT STD_LOGIC;
		d_r	:	IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		q_r	:	OUT STD_LOGIC
	);
	END COMPONENT;


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

	signal audio_l_msb : std_logic;
	signal audio_l : signed(15 downto 0);
	signal audio_r_msb : std_logic;
	signal audio_r : signed(15 downto 0);

	signal vga_r : unsigned(5 downto 0);
	signal vga_g : unsigned(5 downto 0);
	signal vga_b : unsigned(5 downto 0);
	signal vga_hs : std_logic;
	signal vga_vs : std_logic;

	signal vga_r_i : unsigned(7 downto 0);
	signal vga_g_i : unsigned(7 downto 0);
	signal vga_b_i : unsigned(7 downto 0);
	signal vga_window : std_logic;

	signal sdram_drive_dq : std_logic;
	signal sdram_dq_in : std_logic_vector(15 downto 0);
	signal sdram_dq_out : std_logic_vector(15 downto 0);

	signal trace : std_logic_vector(63 downto 0);
	signal capreset : std_logic;
	signal reset_n : std_logic;

	signal spi_clk_int : std_logic;
	signal spi_fromguest : std_logic;
	signal spi_toguest : std_logic;
	signal spi_ss2 : std_logic;
	signal spi_ss3 : std_logic;
	signal spi_ss4 : std_logic;
	signal conf_data0 : std_logic;

begin

	sdram_dq <= (others => 'Z');

	-- PS/2 tristating

	-- Instantiate IOs explicitly to avoid potential issues with tristate signals.
	ps2kd : component TRELLIS_IO port map ( B => ps2_pmod(PMOD_PS2_KDAT+ps2_pmod_offset), I => '0',	T => ps2k_dat_out, O => ps2k_dat_in );
	ps2kc : component TRELLIS_IO port map ( B => ps2_pmod(PMOD_PS2_KCLK+ps2_pmod_offset), I => '0',	T => ps2k_clk_out, O => ps2k_clk_in );
	ps2md : component TRELLIS_IO port map ( B => ps2_pmod(PMOD_PS2_MDAT+ps2_pmod_offset), I => '0',	T => ps2m_dat_out, O => ps2m_dat_in );
	ps2mc : component TRELLIS_IO port map ( B => ps2_pmod(PMOD_PS2_MCLK+ps2_pmod_offset), I => '0',	T => ps2m_clk_out, O => ps2m_clk_in );


	guest: COMPONENT jtagdemo_top
	PORT map
		(
			CLOCK_27 => clk_i,
	--		RESET_N => reset_n,
			-- clocks
--			SDRAM_DRIVE_DQ => sdram_drive_dq,
--			SDRAM_DQ_IN => sdram_dq_in,
--			SDRAM_DQ_OUT => sdram_dq_out,
			SDRAM_A => sdram_a,
			SDRAM_DQML => sdram_dm(0),
			SDRAM_DQMH => sdram_dm(1),
			SDRAM_nWE => sdram_we_n,
			SDRAM_nCAS => sdram_cas_n,
			SDRAM_nRAS => sdram_ras_n,
			SDRAM_nCS => sdram_cs_n,
			SDRAM_BA => sdram_ba,
			SDRAM_CLK => sdram_clk,
			SDRAM_CKE => sdram_cke,
			
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
			unsigned(VGA_R) => vga_r,
			unsigned(VGA_G) => vga_g,
			unsigned(VGA_B) => vga_b,
			DAC_L => audio_l,
			DAC_R => audio_r
--			AUDIO_L => sigma_l,
--			AUDIO_R => sigma_r
	);

	-- Pass internal signals to external SPI interface
	sdcard_clk <= spi_clk_int;

	controller : entity work.substitute_mcu
		generic map (
			sysclk_frequency => 250,
			SPI_FASTBIT => 1,
			SPI_INTERNALBIT => 0,
			debug => false
		)
		port map (
			clk => clk_i,
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

	vga_pmod_high(7 downto 4)<=std_logic_vector(vga_r(5 downto 2));
	vga_pmod_high(3 downto 0)<=std_logic_vector(vga_b(5 downto 2));
	vga_pmod_low(7 downto 4)<=std_logic_vector(vga_g(5 downto 2));
	vga_pmod_low(3 downto 0)<="00"&vga_vs&vga_hs;

	dac : entity work.i2s_dac
	generic map (
		sysclk_frequency => 100,
		mclk_to_lrclk => 256,
		samplerate => 44100,
		width => 16
	)
	port map (
		sysclk => clk_i,
		reset_n => reset_n,
		left_in => std_logic_vector(audio_l),
		right_in => std_logic_vector(audio_r),
		--
		mclk => i2s_pmod(PMOD_I2S_DA_MCLK),
		sclk => i2s_pmod(PMOD_I2S_DA_SCLK),
		lrclk => i2s_pmod(PMOD_I2S_DA_LRCK),
		sdata => i2s_pmod(PMOD_I2S_DA_SDIN)
	);


	-- PMOD-based SD card socket
	genpmodsd : if use_pmod_sdcard=true generate
		-- Instantiate a TRELLIS_IO manually to create an input from the "inout" PMOD ports.
		sdcardmiso : component TRELLIS_IO port map ( B => sdcard_pmod(PMOD_SD_MISO), I => '0',	T => '1', O => sdcard_miso );
		sdcard_pmod(PMOD_SD_CS) <= sdcard_cs;
		sdcard_pmod(PMOD_SD_MOSI) <= sdcard_mosi;
		sdcard_pmod(PMOD_SD_CLK) <= sdcard_clk;
		spisdcard_cs_n <= '1';
		spisdcard_mosi <= '1';
		spisdcard_clk <= '1';
	end generate;
	
	-- Internal SD card socket
	geninternalsd : if use_pmod_sdcard=false generate
		spisdcard_cs_n <= sdcard_cs;
		spisdcard_mosi <= sdcard_mosi;
		spisdcard_clk <= sdcard_clk;
		sdcard_miso <= spisdcard_miso;
	end generate;

end architecture;

