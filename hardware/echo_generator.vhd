-- Echo Generator for the Voice Manipulator
-- Author: Sean Hunter, Michael Wong

-- turn off superfluous VHDL processor warnings 
-- altera message_level Level1 
-- altera message_off 10034 10035 10036 10037 10230 10240 10030 

library altera;
use altera.altera_europa_support_lib.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity echo_core is 
        port (
              -- inputs:
		  asi_incoming_0_data : IN STD_LOGIC_VECTOR (31 DOWNTO 0);
		  asi_incoming_0_valid : IN STD_LOGIC;
		  asi_incoming_1_data : IN STD_LOGIC_VECTOR (31 DOWNTO 0);
		  asi_incoming_1_valid : IN STD_LOGIC;
		  csi_clock_clk : IN STD_LOGIC; 
		  

              -- outputs:
		  aso_outgoing_data : OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
		  aso_outgoing_valid : OUT STD_LOGIC

              );
end entity echo_core;


architecture europa of echo_core is
		signal accepted_data_0 : std_logic_vector(31 downto 0);
		signal accepted_data_1 : std_logic_vector(31 downto 0);
		signal sum : std_logic_vector(31 downto 0);
		signal sum_latched : std_logic_vector(31 downto 0);
		signal output : std_logic_vector(31 downto 0);

begin

	sum <= std_logic_vector(accepted_data_0 + accepted_data_1);
	output <= std_logic_vector(sum_latched + "0111111111111111");
	
 	accept_data: process (csi_clock_clk)	
	begin
		if (csi_clock_clk='1' and csi_clock_clk'event) then
			if (asi_incoming_0_valid = '1') then
				accepted_data_0 <= asi_incoming_0_data;
			end if;
			if (asi_incoming_1_valid = '1') then
				accepted_data_1 <= asi_incoming_1_data;
				sum_latched <= sum;
				aso_outgoing_data <= output;
				aso_outgoing_valid <= '1';
			else			
				aso_outgoing_valid <= '0';
			end if;
		end if;
	end process;


end europa;
