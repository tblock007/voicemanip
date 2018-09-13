-- Top level VHDL file for ECE 492 - Voice Manipulator
-- Author: Michael Wong, Sean Hunter, Thomas Zylstra
-- Modified February 2013 from niosII_microc_lab1.vhd by Nancy Minderman
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity VoiceManipulator is
	port
	(
		-- GPIO
		GPIO_1		: inout	std_logic_vector (9 downto 0);
	
		-- LCD ports
		LCD_ON  	:  out std_logic;
		LCD_BLON 	:  out std_logic;
		LCD_EN  	:  out std_logic;
		LCD_RS  	:  out std_logic;
		LCD_RW  	:  out std_logic;
		LCD_DATA 	:  inout std_logic_vector (7 downto 0);
					 
		-- LEDS
		LEDG  		:  out std_logic_vector(7 downto 0);              

		-- SRAM ports
		SRAM_ADDR 	: out std_logic_vector (17 DOWNTO 0);
		SRAM_DQ 	: inout std_logic_vector (15 DOWNTO 0);
		SRAM_CE_N 	: out std_logic;
		SRAM_UB_N 	: out std_logic;
		SRAM_LB_N 	: out std_logic;
		SRAM_OE_N 	: out std_logic;            
		SRAM_WE_N 	: out std_logic;

		-- CLOCK port
		CLOCK_50 	: in std_logic;
		CLOCK_27 	: in std_logic;
      
		--I2C interface
		I2C_SCLK	:  out std_logic;
		I2C_SDAT	:  inout std_logic;
					 
		-- Switch			
		SW		:  in std_logic_vector(4 downto 0);
		
		--AUDIO 
		AUD_ADCLRCK 	:  inout std_logic; 
		AUD_ADCDAT 	:  in std_logic; 
		AUD_DACLRCK 	:  inout std_logic; 
		AUD_DACDAT 	:  out std_logic; 
		AUD_XCK 	:  out std_logic; 
		AUD_BCLK 	:  inout std_logic; 
	
		--buttons
		KEY		: in std_logic_vector(3 downto 0);
	
		-- RESET key
      	RST		:  in std_logic;
				
					-- CFI Flash ports
		FL_ADDR : out std_logic_vector(21 downto 0);
		FL_DQ : inout std_logic_vector(7 downto 0);
		FL_OE_N : out std_logic ;
		FL_CE_N : out std_logic ;
		FL_WE_N : out std_logic ;
		FL_RST_N : out std_logic
	);
end VoiceManipulator;


architecture structure of VoiceManipulator is

component niosII_system
	port
	(
                 -- 1) global signals:
                    signal clk_0 : IN STD_LOGIC;
                    signal clk_1 : IN STD_LOGIC;
                    signal clocks_0_AUD_CLK_out : OUT STD_LOGIC;
                    signal clocks_0_sys_clk_out : OUT STD_LOGIC;
                    signal reset_n : IN STD_LOGIC;
                    signal sram_controller_0_s0_data : INOUT STD_LOGIC_VECTOR (15 DOWNTO 0);

                 -- the_audio_0
                    signal AUD_ADCDAT_to_the_audio_0 : IN STD_LOGIC;
                    signal AUD_ADCLRCK_to_and_from_the_audio_0 : INOUT STD_LOGIC;
                    signal AUD_BCLK_to_and_from_the_audio_0 : INOUT STD_LOGIC;
                    signal AUD_DACDAT_from_the_audio_0 : OUT STD_LOGIC;
                    signal AUD_DACLRCK_to_and_from_the_audio_0 : INOUT STD_LOGIC;

                 -- the_audio_and_video_config_0
                    signal I2C_SCLK_from_the_audio_and_video_config_0 : OUT STD_LOGIC;
                    signal I2C_SDAT_to_and_from_the_audio_and_video_config_0 : INOUT STD_LOGIC;

                 -- the_button0
                    signal in_port_to_the_button0 : IN STD_LOGIC;

                 -- the_button1
                    signal in_port_to_the_button1 : IN STD_LOGIC;

                 -- the_button2
                    signal in_port_to_the_button2 : IN STD_LOGIC;

                 -- the_button3
                    signal in_port_to_the_button3 : IN STD_LOGIC;

                 -- the_green_leds
                    signal out_port_from_the_green_leds : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);

                 -- the_lcd_0
                    signal LCD_E_from_the_lcd_0 : OUT STD_LOGIC;
                    signal LCD_RS_from_the_lcd_0 : OUT STD_LOGIC;
                    signal LCD_RW_from_the_lcd_0 : OUT STD_LOGIC;
                    signal LCD_data_to_and_from_the_lcd_0 : INOUT STD_LOGIC_VECTOR (7 DOWNTO 0);
						  
				 -- the_lm20_uart
					signal cts_n_to_the_lm20_uart : IN STD_LOGIC;
					signal rts_n_from_the_lm20_uart : OUT STD_LOGIC;
					signal rxd_to_the_lm20_uart : IN STD_LOGIC;
					signal txd_from_the_lm20_uart : OUT STD_LOGIC;	
						  
				 -- the_pcm_interface_0
                    signal coe_pcmc_export_to_the_pcm_interface_0 : IN STD_LOGIC;
                    signal coe_pcmi_export_from_the_pcm_interface_0 : OUT STD_LOGIC;
                    signal coe_pcmo_export_to_the_pcm_interface_0 : IN STD_LOGIC;
                    signal coe_pcms_export_to_the_pcm_interface_0 : IN STD_LOGIC;
                    signal coe_reset_export_to_the_pcm_interface_0 : IN STD_LOGIC;

                 -- the_sram_controller_0
                    signal sram_a_from_the_sram_controller_0 : OUT STD_LOGIC_VECTOR (17 DOWNTO 0);
                    signal sram_ce_bar_from_the_sram_controller_0 : OUT STD_LOGIC;
                    signal sram_lb_bar_from_the_sram_controller_0 : OUT STD_LOGIC;
                    signal sram_oe_bar_from_the_sram_controller_0 : OUT STD_LOGIC;
                    signal sram_ub_bar_from_the_sram_controller_0 : OUT STD_LOGIC;
                    signal sram_we_bar_from_the_sram_controller_0 : OUT STD_LOGIC;

                 -- the_switch
                    signal in_port_to_the_switch : IN STD_LOGIC_VECTOR (3 DOWNTO 0);
						  
				 -- the_tri_state_bridge_0_avalon_slave
                    signal address_to_the_cfi_flash_0 : OUT STD_LOGIC_VECTOR (21 DOWNTO 0);
                    signal read_n_to_the_cfi_flash_0 : OUT STD_LOGIC;
                    signal select_n_to_the_cfi_flash_0 : OUT STD_LOGIC;
                    signal tri_state_bridge_0_data : INOUT STD_LOGIC_VECTOR (7 DOWNTO 0);
                    signal write_n_to_the_cfi_flash_0 : OUT STD_LOGIC

	);
end component;

begin
    LCD_ON <= '1';
	FL_RST_N <= '1';

	-- Component Instantiation Statement (optional)
	NIOSII : niosII_system port map ( 
                    clk_0 => CLOCK_50,
					clk_1 => CLOCK_27,
                    clocks_0_AUD_CLK_out => AUD_XCK,
                    reset_n => RST,
                    sram_controller_0_s0_data => SRAM_DQ,

                    AUD_ADCDAT_to_the_audio_0 => AUD_ADCDAT,
                    AUD_ADCLRCK_to_and_from_the_audio_0 => AUD_ADCLRCK,
                    AUD_BCLK_to_and_from_the_audio_0 => AUD_BCLK,
                    AUD_DACDAT_from_the_audio_0 => AUD_DACDAT,
                    AUD_DACLRCK_to_and_from_the_audio_0 => AUD_DACLRCK,

                    I2C_SCLK_from_the_audio_and_video_config_0 => I2C_SCLK,
                    I2C_SDAT_to_and_from_the_audio_and_video_config_0 => I2C_SDAT,

                    in_port_to_the_button0 => KEY(0),
                    in_port_to_the_button1 => KEY(1),
                    in_port_to_the_button2 => KEY(2),
                    in_port_to_the_button3 => KEY(3),

                    out_port_from_the_green_leds => LEDG,

                    LCD_E_from_the_lcd_0 => LCD_EN,
                    LCD_RS_from_the_lcd_0 => LCD_RS,
                    LCD_RW_from_the_lcd_0 => LCD_RW,
                    LCD_data_to_and_from_the_lcd_0 => LCD_DATA,
						  
					cts_n_to_the_lm20_uart => GPIO_1(9),
					rts_n_from_the_lm20_uart => GPIO_1(7),
					rxd_to_the_lm20_uart => GPIO_1(5),
					txd_from_the_lm20_uart => GPIO_1(3),	
		
					coe_pcmc_export_to_the_pcm_interface_0 => GPIO_1(4),
					coe_pcmo_export_to_the_pcm_interface_0 => GPIO_1(6),
					coe_pcmi_export_from_the_pcm_interface_0 => GPIO_1(8),
					coe_pcms_export_to_the_pcm_interface_0 => GPIO_1(2),
					coe_reset_export_to_the_pcm_interface_0 => SW(4),

                    sram_a_from_the_sram_controller_0 => SRAM_ADDR,
                    sram_ce_bar_from_the_sram_controller_0 => SRAM_CE_N,
                    sram_lb_bar_from_the_sram_controller_0 => SRAM_LB_N,
                    sram_oe_bar_from_the_sram_controller_0 => SRAM_OE_N,
                    sram_ub_bar_from_the_sram_controller_0 => SRAM_UB_N,
                    sram_we_bar_from_the_sram_controller_0 => SRAM_WE_N,

                    in_port_to_the_switch => SW(3 downto 0),
						  
					address_to_the_cfi_flash_0 => FL_ADDR,
					tri_state_bridge_0_data => FL_DQ,
					read_n_to_the_cfi_flash_0 => FL_OE_N,
					select_n_to_the_cfi_flash_0 => FL_CE_N,
					write_n_to_the_cfi_flash_0 => FL_WE_N
				
	);	  
end structure;
		  

