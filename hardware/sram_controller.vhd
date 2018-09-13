-- SRAM Controller Interface
-- ECE 492 - Voice Manipulator
-- Author: Michael Wong, Sean Hunter, Thomas Zylstra
--
-- Glue component to interface to the SRAM chip on the Altera DE2
-- Modified February 2013 from niosII_microc_lab1.vhd by Nancy Minderman

library ieee;
use ieee.std_logic_1164.all;

entity sram_controller is
  port (
    ats_s0_address: in std_logic_vector(18 downto 1);
    ats_s0_data: inout std_logic_vector(15 downto 0);
    ats_s0_write_n: in std_logic;
    ats_s0_byteenable_n: in std_logic_vector(1 downto 0);
    ats_s0_chipselect_n: in std_logic;
    ats_s0_outputenable_n: in std_logic;

    sram_a: out std_logic_vector(17 downto 0);
    sram_we_bar: out std_logic;
    sram_ub_bar: out std_logic;
    sram_lb_bar: out std_logic;
    sram_ce_bar: out std_logic;
    sram_oe_bar: out std_logic
  );
end sram_controller;

architecture behavior of sram_controller is
begin  -- behavior
  sram_a(17 downto 0) <= ats_s0_address(18 downto 1);
  sram_we_bar <= ats_s0_write_n;
  sram_ub_bar <= ats_s0_byteenable_n(1);
  sram_lb_bar <= ats_s0_byteenable_n(0);
  sram_ce_bar <= ats_s0_chipselect_n;
  sram_oe_bar <= ats_s0_outputenable_n;
end behavior;
