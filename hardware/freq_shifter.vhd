-- Frequency Shifter for the Voice Manipulator
-- Author: Michael Wong
-- Hilbert Transform component modified from Hilbert Transformer OpenCores 
-- [http://opencores.org/project,hilbert_transformer]
-- Hilbert Filter is of order 102.
--
-- This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation; either version 3 of the License, or (at your option) any later version.
-- 
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
-- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License along with this program; 
-- if not, see <http://www.gnu.org/licenses/>.

-- Package Definition

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.resize_tools_pkg.all;

entity freq_shifter is
  generic(
    input_data_width : integer := 32;
    output_data_width : integer := 32;
    internal_data_width : integer := 32
  );
  port( 
    --clock and reset signals
    csi_clock_clk		: in  std_logic;
    csi_reset_rst		: in  std_logic;

    --incoming data streams: audio data, sine values, cosine values 
    asi_incoming_valid         	: in  std_logic;
    asi_incoming_data   	: in  std_logic_vector(31 downto 0);
    asi_sine_valid		: in  std_logic;
    asi_sine_data		: in  std_logic_vector(31 downto 0);
    asi_cosine_valid		: in  std_logic;
    asi_cosine_data		: in  std_logic_vector(31 downto 0);

    --outgoing data stream: transformed audio data
    aso_outgoing_valid		: out std_logic;
    aso_outgoing_data  		: out std_logic_vector(31 downto 0)	
  );

end freq_shifter;


architecture freq_shifter_arch of freq_shifter is

--26 values are needed for order 102. For an even order Hilbert filter, 
--odd coefficients will be zero, and coefficients on the other side of the 26th 
--coefficient will be mirrored negatives.
constant no_of_coefficients : integer := 26;

--Two sets of coefficients are presented here. The latter was found to perform better.

--obtained from firls(102, [0 1], [1 1], 'Hilbert')
--constant h0_real : real := -409.0/32768.0;
--constant h2_real : real := -425.0/32768.0;
--constant h4_real : real := -444.0/32768.0;
--constant h6_real : real := -464.0/32768.0;
--constant h8_real : real := -485.0/32768.0;
--constant h10_real : real := -509.0/32768.0;
--constant h12_real : real := -535.0/32768.0;
--constant h14_real : real := -564.0/32768.0;
--constant h16_real : real := -596.0/32768.0;
--constant h18_real : real := -632.0/32768.0;
--constant h20_real : real := -673.0/32768.0;
--constant h22_real : real := -719.0/32768.0;
--constant h24_real : real := -773.0/32768.0;
--constant h26_real : real := -834.0/32768.0;
--constant h28_real : real := -907.0/32768.0;
--constant h30_real : real := -993.0/32768.0;
--constant h32_real : real := -1098.0/32768.0;
--constant h34_real : real := -1227.0/32768.0;
--constant h36_real : real := -1391.0/32768.0;
--constant h38_real : real := -1605.0/32768.0;
--constant h40_real : real := -1896.0/32768.0;
--constant h42_real : real := -2318.0/32768.0;
--constant h44_real : real := -2980.0/32768.0;
--constant h46_real : real := -4172.0/32768.0;
--constant h48_real : real := -6954.0/32768.0;
--constant h50_real : real := -20861.0/32768.0;

--obtained from firls(102, [0.05 0.95], [1 1], 'Hilbert')
constant h0_real : real := -1.0/32768.0;
constant h2_real : real := -3.0/32768.0;
constant h4_real : real := -6.0/32768.0;
constant h6_real : real := -10.0/32768.0;
constant h8_real : real := -17.0/32768.0;
constant h10_real : real := -26.0/32768.0;
constant h12_real : real := -39.0/32768.0;
constant h14_real : real := -56.0/32768.0;
constant h16_real : real := -78.0/32768.0;
constant h18_real : real := -107.0/32768.0;
constant h20_real : real := -144.0/32768.0;
constant h22_real : real := -190.0/32768.0;
constant h24_real : real := -247.0/32768.0;
constant h26_real : real := -318.0/32768.0;
constant h28_real : real := -404.0/32768.0;
constant h30_real : real := -509.0/32768.0;
constant h32_real : real := -638.0/32768.0;
constant h34_real : real := -797.0/32768.0;
constant h36_real : real := -996.0/32768.0;
constant h38_real : real := -1250.0/32768.0;
constant h40_real : real := -1587.0/32768.0;
constant h42_real : real := -2058.0/32768.0;
constant h44_real : real := -2774.0/32768.0;
constant h46_real : real := -4023.0/32768.0;
constant h48_real : real := -6863.0/32768.0;
constant h50_real : real := -20830.0/32768.0;

constant h0_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h0_real * 2.0**(internal_data_width/2-1)),internal_data_width/2));  
constant h2_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h2_real * 2.0**(internal_data_width/2-1)),internal_data_width/2));  
constant h4_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h4_real * 2.0**(internal_data_width/2-1)),internal_data_width/2)); 
constant h6_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h6_real * 2.0**(internal_data_width/2-1)),internal_data_width/2));  
constant h8_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h8_real * 2.0**(internal_data_width/2-1)),internal_data_width/2));  
constant h10_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h10_real * 2.0**(internal_data_width/2-1)),internal_data_width/2)); 
constant h12_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h12_real * 2.0**(internal_data_width/2-1)),internal_data_width/2));
constant h14_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h14_real * 2.0**(internal_data_width/2-1)),internal_data_width/2)); 
constant h16_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h16_real * 2.0**(internal_data_width/2-1)),internal_data_width/2));
constant h18_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h18_real * 2.0**(internal_data_width/2-1)),internal_data_width/2)); 
constant h20_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h20_real * 2.0**(internal_data_width/2-1)),internal_data_width/2)); 
constant h22_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h22_real * 2.0**(internal_data_width/2-1)),internal_data_width/2));
constant h24_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h24_real * 2.0**(internal_data_width/2-1)),internal_data_width/2)); 
constant h26_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h26_real * 2.0**(internal_data_width/2-1)),internal_data_width/2));
constant h28_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h28_real * 2.0**(internal_data_width/2-1)),internal_data_width/2)); 
constant h30_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h30_real * 2.0**(internal_data_width/2-1)),internal_data_width/2)); 
constant h32_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h32_real * 2.0**(internal_data_width/2-1)),internal_data_width/2));
constant h34_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h34_real * 2.0**(internal_data_width/2-1)),internal_data_width/2)); 
constant h36_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h36_real * 2.0**(internal_data_width/2-1)),internal_data_width/2));
constant h38_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h38_real * 2.0**(internal_data_width/2-1)),internal_data_width/2)); 
constant h40_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h40_real * 2.0**(internal_data_width/2-1)),internal_data_width/2)); 
constant h42_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h42_real * 2.0**(internal_data_width/2-1)),internal_data_width/2));
constant h44_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h44_real * 2.0**(internal_data_width/2-1)),internal_data_width/2)); 
constant h46_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h46_real * 2.0**(internal_data_width/2-1)),internal_data_width/2));
constant h48_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h48_real * 2.0**(internal_data_width/2-1)),internal_data_width/2)); 
constant h50_int : std_logic_vector(internal_data_width/2-1 downto 0) := std_logic_vector(to_signed(integer(h50_real * 2.0**(internal_data_width/2-1)),internal_data_width/2)); 

--delay line; delay of a 102-tap filter is 51 samples, so we must also delay the original audio 
--stream in order to add in phase
signal delay0 : std_logic_vector(input_data_width-1 downto 0);
signal delay1 : std_logic_vector(input_data_width-1 downto 0);
signal delay2 : std_logic_vector(input_data_width-1 downto 0);
signal delay3 : std_logic_vector(input_data_width-1 downto 0);
signal delay4 : std_logic_vector(input_data_width-1 downto 0);
signal delay5 : std_logic_vector(input_data_width-1 downto 0);
signal delay6 : std_logic_vector(input_data_width-1 downto 0);
signal delay7 : std_logic_vector(input_data_width-1 downto 0);
signal delay8 : std_logic_vector(input_data_width-1 downto 0);
signal delay9 : std_logic_vector(input_data_width-1 downto 0);
signal delay10 : std_logic_vector(input_data_width-1 downto 0);
signal delay11 : std_logic_vector(input_data_width-1 downto 0);
signal delay12 : std_logic_vector(input_data_width-1 downto 0);
signal delay13 : std_logic_vector(input_data_width-1 downto 0);
signal delay14 : std_logic_vector(input_data_width-1 downto 0);
signal delay15 : std_logic_vector(input_data_width-1 downto 0);
signal delay16 : std_logic_vector(input_data_width-1 downto 0);
signal delay17 : std_logic_vector(input_data_width-1 downto 0);
signal delay18 : std_logic_vector(input_data_width-1 downto 0);
signal delay19 : std_logic_vector(input_data_width-1 downto 0);
signal delay20 : std_logic_vector(input_data_width-1 downto 0);
signal delay21 : std_logic_vector(input_data_width-1 downto 0);
signal delay22 : std_logic_vector(input_data_width-1 downto 0);
signal delay23 : std_logic_vector(input_data_width-1 downto 0);
signal delay24 : std_logic_vector(input_data_width-1 downto 0);
signal delay25 : std_logic_vector(input_data_width-1 downto 0);
signal delay26 : std_logic_vector(input_data_width-1 downto 0);
signal delay27 : std_logic_vector(input_data_width-1 downto 0);
signal delay28 : std_logic_vector(input_data_width-1 downto 0);
signal delay29 : std_logic_vector(input_data_width-1 downto 0);
signal delay30 : std_logic_vector(input_data_width-1 downto 0);
signal delay31 : std_logic_vector(input_data_width-1 downto 0);
signal delay32 : std_logic_vector(input_data_width-1 downto 0);
signal delay33 : std_logic_vector(input_data_width-1 downto 0);
signal delay34 : std_logic_vector(input_data_width-1 downto 0);
signal delay35 : std_logic_vector(input_data_width-1 downto 0);
signal delay36 : std_logic_vector(input_data_width-1 downto 0);
signal delay37 : std_logic_vector(input_data_width-1 downto 0);
signal delay38 : std_logic_vector(input_data_width-1 downto 0);
signal delay39 : std_logic_vector(input_data_width-1 downto 0);
signal delay40 : std_logic_vector(input_data_width-1 downto 0);
signal delay41 : std_logic_vector(input_data_width-1 downto 0);
signal delay42 : std_logic_vector(input_data_width-1 downto 0);
signal delay43 : std_logic_vector(input_data_width-1 downto 0);
signal delay44 : std_logic_vector(input_data_width-1 downto 0);
signal delay45 : std_logic_vector(input_data_width-1 downto 0);
signal delay46 : std_logic_vector(input_data_width-1 downto 0);
signal delay47 : std_logic_vector(input_data_width-1 downto 0);
signal delay48 : std_logic_vector(input_data_width-1 downto 0);
signal delay49 : std_logic_vector(input_data_width-1 downto 0);
signal delay50 : std_logic_vector(input_data_width-1 downto 0);
signal delay51 : std_logic_vector(input_data_width-1 downto 0);

type xmh_type is array(0 to no_of_coefficients-1) of std_logic_vector(internal_data_width-1 downto 0);
signal xmh : xmh_type;  --x mult with coeff. h
signal xmhd : xmh_type; --xmh delayed one clock

signal xmhd0inv : std_logic_vector(internal_data_width-1 downto 0);
signal xmhd0invd : std_logic_vector(internal_data_width-1 downto 0);
signal xmhd0invdd : std_logic_vector(internal_data_width-1 downto 0);

type tmp_type is array(0 to 2*(no_of_coefficients-1)-1) of std_logic_vector(internal_data_width-1 downto 0);
signal t : tmp_type;    --temporary signal after each addition
signal td : tmp_type;   --t delayed one clock
signal tdd : tmp_type;  --t delayed two clocks

signal latched_sine : std_logic_vector(internal_data_width-1 downto 0);
signal latched_cosine : std_logic_vector(internal_data_width-1 downto 0);
signal hilbert_output : std_logic_vector(internal_data_width-1 downto 0);
signal hilbert_output_latched : std_logic_vector(internal_data_width-1 downto 0);
signal m1 : std_logic_vector(internal_data_width-1 downto 0);
signal m1_latched : std_logic_vector(internal_data_width-1 downto 0);
signal m2 : std_logic_vector(internal_data_width-1 downto 0);
signal m2_latched : std_logic_vector(internal_data_width-1 downto 0);
signal z : std_logic_vector(internal_data_width-1 downto 0);

begin

  delay0 <= asi_incoming_data;

  xmh(0) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h0_int));
  xmh(1) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h2_int));
  xmh(2) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h4_int));
  xmh(3) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h6_int));
  xmh(4) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h8_int));
  xmh(5) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h10_int));
  xmh(6) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h12_int));
  xmh(7) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h14_int));
  xmh(8) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h16_int));
  xmh(9) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h18_int));
  xmh(10) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h20_int));
  xmh(11) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h22_int));
  xmh(12) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h24_int));
  xmh(13) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h26_int));
  xmh(14) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h28_int));
  xmh(15) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h30_int));
  xmh(16) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h32_int));
  xmh(17) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h34_int));
  xmh(18) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h36_int));
  xmh(19) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h38_int));
  xmh(20) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h40_int));
  xmh(21) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h42_int));
  xmh(22) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h44_int));
  xmh(23) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h46_int));
  xmh(24) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h48_int));
  xmh(25) <= std_logic_vector(signed(resize_to_lsb_trunc(asi_incoming_data,internal_data_width/2)) * signed(h50_int));

  xmhd0inv <= std_logic_vector(to_signed(-1 * to_integer(signed(xmhd(0))),internal_data_width));

  t(0) <= std_logic_vector(signed(xmhd0invdd) - signed(xmhd(1)));
  t(1) <= std_logic_vector(signed(tdd(0)) - signed(xmhd(2)));
  t(2) <= std_logic_vector(signed(tdd(1)) - signed(xmhd(3)));
  t(3) <= std_logic_vector(signed(tdd(2)) - signed(xmhd(4)));
  t(4) <= std_logic_vector(signed(tdd(3)) - signed(xmhd(5)));
  t(5) <= std_logic_vector(signed(tdd(4)) - signed(xmhd(6)));
  t(6) <= std_logic_vector(signed(tdd(5)) - signed(xmhd(7)));
  t(7) <= std_logic_vector(signed(tdd(6)) - signed(xmhd(8)));
  t(8) <= std_logic_vector(signed(tdd(7)) - signed(xmhd(9)));
  t(9) <= std_logic_vector(signed(tdd(8)) - signed(xmhd(10)));
  t(10) <= std_logic_vector(signed(tdd(9)) - signed(xmhd(11)));
  t(11) <= std_logic_vector(signed(tdd(10)) - signed(xmhd(12)));
  t(12) <= std_logic_vector(signed(tdd(11)) - signed(xmhd(13)));
  t(13) <= std_logic_vector(signed(tdd(12)) - signed(xmhd(14)));
  t(14) <= std_logic_vector(signed(tdd(13)) - signed(xmhd(15)));
  t(15) <= std_logic_vector(signed(tdd(14)) - signed(xmhd(16)));
  t(16) <= std_logic_vector(signed(tdd(15)) - signed(xmhd(17)));
  t(17) <= std_logic_vector(signed(tdd(16)) - signed(xmhd(18)));
  t(18) <= std_logic_vector(signed(tdd(17)) - signed(xmhd(19)));
  t(19) <= std_logic_vector(signed(tdd(18)) - signed(xmhd(20)));
  t(20) <= std_logic_vector(signed(tdd(19)) - signed(xmhd(21)));
  t(21) <= std_logic_vector(signed(tdd(20)) - signed(xmhd(22)));
  t(22) <= std_logic_vector(signed(tdd(21)) - signed(xmhd(23)));
  t(23) <= std_logic_vector(signed(tdd(22)) - signed(xmhd(24)));
  t(24) <= std_logic_vector(signed(tdd(23)) - signed(xmhd(25)));

  t(25) <= std_logic_vector(signed(tdd(24)) + signed(xmhd(25)));
  t(26) <= std_logic_vector(signed(tdd(25)) + signed(xmhd(24)));
  t(27) <= std_logic_vector(signed(tdd(26)) + signed(xmhd(23)));
  t(28) <= std_logic_vector(signed(tdd(27)) + signed(xmhd(22)));
  t(29) <= std_logic_vector(signed(tdd(28)) + signed(xmhd(21)));
  t(30) <= std_logic_vector(signed(tdd(29)) + signed(xmhd(20)));
  t(31) <= std_logic_vector(signed(tdd(30)) + signed(xmhd(19)));
  t(32) <= std_logic_vector(signed(tdd(31)) + signed(xmhd(18)));
  t(33) <= std_logic_vector(signed(tdd(32)) + signed(xmhd(17)));
  t(34) <= std_logic_vector(signed(tdd(33)) + signed(xmhd(16)));
  t(35) <= std_logic_vector(signed(tdd(34)) + signed(xmhd(15)));
  t(36) <= std_logic_vector(signed(tdd(35)) + signed(xmhd(14)));
  t(37) <= std_logic_vector(signed(tdd(36)) + signed(xmhd(13)));
  t(38) <= std_logic_vector(signed(tdd(37)) + signed(xmhd(12)));
  t(39) <= std_logic_vector(signed(tdd(38)) + signed(xmhd(11)));
  t(40) <= std_logic_vector(signed(tdd(39)) + signed(xmhd(10)));
  t(41) <= std_logic_vector(signed(tdd(40)) + signed(xmhd(9)));
  t(42) <= std_logic_vector(signed(tdd(41)) + signed(xmhd(8)));
  t(43) <= std_logic_vector(signed(tdd(42)) + signed(xmhd(7)));
  t(44) <= std_logic_vector(signed(tdd(43)) + signed(xmhd(6)));
  t(45) <= std_logic_vector(signed(tdd(44)) + signed(xmhd(5)));
  t(46) <= std_logic_vector(signed(tdd(45)) + signed(xmhd(4)));
  t(47) <= std_logic_vector(signed(tdd(46)) + signed(xmhd(3)));
  t(48) <= std_logic_vector(signed(tdd(47)) + signed(xmhd(2)));
  t(49) <= std_logic_vector(signed(tdd(48)) + signed(xmhd(1)));
 
  hilbert_output <= std_logic_vector(signed(tdd(49)) + signed(xmhd(0)));
  m1 <= std_logic_vector(signed(resize_to_lsb_trunc(hilbert_output_latched,internal_data_width/2)) * signed(resize_to_lsb_trunc(latched_sine,internal_data_width/2)));
  m2 <= std_logic_vector(signed(resize_to_lsb_trunc(delay51,internal_data_width/2)) * signed(resize_to_lsb_trunc(latched_cosine,internal_data_width/2)));
  z <= std_logic_vector(signed(m1_latched) + signed(m2_latched) + to_signed(integer(1073741823),32));

  process (csi_clock_clk, csi_reset_rst)	
  begin
	if csi_reset_rst = '1' then
      		for i in 0 to no_of_coefficients-1 loop
        		xmhd(i) <= (others => '0');
      		end loop;
      		for i in 0 to 2*(no_of_coefficients-1)-1 loop
        		td(i) <= (others => '0');
        		tdd(i) <= (others => '0');
      		end loop;
      		xmhd0invd <= (others => '0');
      		xmhd0invdd <= (others => '0');
      		aso_outgoing_data <= (others => '0');
	elsif csi_clock_clk'event and csi_clock_clk = '1' then
			if (asi_sine_valid = '1') then
				latched_sine <= asi_sine_data;
			end if;
			if (asi_cosine_valid = '1') then
				latched_cosine <= asi_cosine_data;
			end if;
			if (asi_incoming_valid = '1') then
				for i in 0 to no_of_coefficients-1 loop
						xmhd(i) <= xmh(i);
				end loop;
				for i in 0 to 2*(no_of_coefficients-1)-1 loop
						td(i) <= t(i);
						tdd(i) <= td(i);
				end loop;
				
				delay1 <= delay0;
				delay2 <= delay1;
				delay3 <= delay2;
				delay4 <= delay3;
				delay5 <= delay4;
				delay6 <= delay5;
				delay7 <= delay6;
				delay8 <= delay7;
				delay9 <= delay8;
				delay10 <= delay9;
				delay11 <= delay10;
				delay12 <= delay11;
				delay13 <= delay12;
				delay14 <= delay13;
				delay15 <= delay14;
				delay16 <= delay15;
				delay17 <= delay16;
				delay18 <= delay17;
				delay19 <= delay18;
				delay20 <= delay19;
				delay21 <= delay20;
				delay22 <= delay21;
				delay23 <= delay22;
				delay24 <= delay23;
				delay25 <= delay24;
				delay26 <= delay25;
				delay27 <= delay26;
				delay28 <= delay27;
				delay29 <= delay28;
				delay30 <= delay29;
				delay31 <= delay30;
				delay32 <= delay31;
				delay33 <= delay32;
				delay34 <= delay33;
				delay35 <= delay34;
				delay36 <= delay35;
				delay37 <= delay36;
				delay38 <= delay37;
				delay39 <= delay38;
				delay40 <= delay39;
				delay41 <= delay40;
				delay42 <= delay41;
				delay43 <= delay42;
				delay44 <= delay43;
				delay45 <= delay44;
				delay46 <= delay45;
				delay47 <= delay46;
				delay48 <= delay47;
				delay49 <= delay48;
				delay50 <= delay49;
				delay51 <= delay50;
				
				xmhd0invd <= xmhd0inv;
				xmhd0invdd <= xmhd0invd;

				hilbert_output_latched(output_data_width/2-1 downto 0) <= hilbert_output(output_data_width-2 downto output_data_width/2-1);
				if (hilbert_output(output_data_width-1) = '1') then
					hilbert_output_latched(output_data_width-1 downto output_data_width/2) <= (others => '1');
				else
					hilbert_output_latched(output_data_width-1 downto output_data_width/2) <= (others => '0');
				end if;

				m1_latched <= m1;
				m2_latched <= m2;

				aso_outgoing_data(output_data_width/2-1 downto 0) <= z(output_data_width-2 downto output_data_width/2-1);
				if (z(output_data_width-1) = '1') then
					aso_outgoing_data(output_data_width-1 downto output_data_width/2) <= (others => '1');
				else
					aso_outgoing_data(output_data_width-1 downto output_data_width/2) <= (others => '0');
				end if;

				aso_outgoing_valid <= '1';
			else
				aso_outgoing_valid <= '0';
			end if;				
   end if;
  end process;

  
  
end freq_shifter_arch;
