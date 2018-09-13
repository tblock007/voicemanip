-- PCM Interface
-- ECE 492 - Voice Manipulator
-- Author: Michael Wong
--
-- Takes incoming PCM Interface data (assumed to be 256kHz from the LM20) and converts 
-- it to Avalon Streaming format (assumed to be using 50MHz system clock)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcm_interface is
  port( 

    csi_clock_clk		: in  std_logic;
    coe_reset_export		: in  std_logic; 
    coe_pcms_export		: in  std_logic;
    coe_pcmc_export		: in  std_logic;
    coe_pcmo_export		: in  std_logic;
    coe_pcmi_export		: out std_logic;

    asi_audioin_data		: in  std_logic_vector(31 downto 0);
    asi_audioin_valid		: in  std_logic;    
    aso_audio_data		: out std_logic_vector(31 downto 0);
    aso_audio_valid		: out std_logic
  );

end pcm_interface;


architecture pcm of pcm_interface is

	--this counter signal is used to provide the frame timing for this interface;
	--counter will take the value 0 on the first falling edge after sync is asserted, 
	--and will have the value 31 on the falling edge just before the next sync is asserted;
	--incoming serial data can therefore be read on falling edges 0-15, and outgoing serial
	--data can be asserted on falling edges 0-15
	signal counter : integer range 0 to 31;
	signal latched_sync : std_logic; --used to determine when counter should be set to 0

	--signals to store data being read and data being written
	signal read_data : std_logic_vector(15 downto 0);
	signal write_data : std_logic_vector(15 downto 0);

	--a FIFO of 128 samples that will hold samples as they come in from the streaming interface;
	--makes the assumption that no more than 128 samples will arrive before 128 frames pass;
	--this is a valid assumption in the Voice Manipulator, as we are reading audio at 32kHz and
	--downsampling to 8kHz
	type delay_fifo is array(0 to 127) of std_logic_vector(15 downto 0);
	signal delay : delay_fifo;
	signal delay_fifo_fill : integer range 0 to 128; --fill level signal indicating the next sample to be sent
	
	--signals to aid FIFO fill level communication between the processes
	signal decrement_flag : std_logic;
	signal latched_decrement_flag: std_logic;

begin
	--bit clock process:
	--based on value of counter, output serial data or latch samples from FIFO on rising edges, 
	--update counter and read incoming serial data on falling edges
  	process (coe_pcmc_export, coe_reset_export)
  	begin
		if (coe_reset_export = '1') then
			latched_sync <= '0';
			counter <= 0;
			decrement_flag <= '0';
			read_data <= "0000000000000000";
			write_data <= "0000000000000000";
		elsif (coe_pcmc_export='1' and coe_pcmc_export'event) then
			if (counter >= 0 and counter <= 14) then
				--output bits
				coe_pcmi_export <= write_data(14-counter);
			elsif (counter = 30) then
				--get next sample from FIFO
				if (delay_fifo_fill > 0) then
					write_data <= delay(delay_fifo_fill-1);
					decrement_flag <= not decrement_flag;
				end if;
			elsif (counter = 31) then
				--output MSB
				coe_pcmi_export <= write_data(15);
			end if;
		elsif (coe_pcmc_export='0' and coe_pcmc_export'event) then
			if (latched_sync /= coe_pcms_export and coe_pcms_export = '1') then
				counter <= 0;
				read_data(15) <= coe_pcmo_export;
			else
				counter <= counter + 1;
				if (counter >= 0 and counter <= 14) then
					read_data(14-counter) <= coe_pcmo_export;
				end if;
			end if;
			latched_sync <= coe_pcms_export;
		end if;
	end process; 

	--system clock process:
	--latches incoming parallel data and places it in the FIFO
	--manages fifo fill level indicator
	--outputs to outgoing parallel data once read is complete
	process (csi_clock_clk, coe_reset_export)	
  	begin
		if (coe_reset_export = '1') then
			latched_decrement_flag <= '0';
			delay_fifo_fill <= 0;
			for i in 0 to 127 loop
        			delay(i) <= "0000000000000000";
      			end loop;
		elsif (csi_clock_clk='1' and csi_clock_clk'event) then
			--latch data from NIOS
			if (asi_audioin_valid = '1') then
				for i in 0 to 126 loop
        				delay(127-i) <= delay(126-i);
      				end loop;
				delay(0) <= asi_audioin_data(15 downto 0);
				if (delay_fifo_fill < 128) then
					delay_fifo_fill <= delay_fifo_fill + 1;
				end if;
			end if;

			--if sample was read, decrement fill level
			if (latched_decrement_flag /= decrement_flag) then
				if (delay_fifo_fill > 0) then
						delay_fifo_fill <= delay_fifo_fill - 1;
				end if;
			end if;
			--output data to NIOS once read is complete
			if (counter >= 15 and counter <= 29) then
				if (read_data(15) = '1') then
					aso_audio_data(31 downto 16) <= (others => '1');
				else
					aso_audio_data(31 downto 16) <= (others => '0');
				end if;
				aso_audio_data(15 downto 0) <= read_data;
				aso_audio_valid <= '1';
			else
				aso_audio_valid <= '0';
			end if;
			latched_decrement_flag <= decrement_flag;
		end if;
	end process;  
end pcm;

