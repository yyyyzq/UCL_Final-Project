-------------------------------------------------------------------------------
-- Title      : Analysis Tools for a Single Polarization System 
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : analysis.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2022-03-02
-- Last update: 2022-03-03
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-------------------------------------------------------------------------------
-- Copyright (c) 2022 Erik Börjeson
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2022-03-02  1.0      erikbor Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity analysis is
  generic (BITS             : positive := 4;
           BITS_CNT_WIDTH   : positive := 16;
           ERRORS_CNT_WIDTH : positive := 16);
  port (clk        : in  std_logic;
        rst        : in  std_logic;
        bits_demod : in  std_logic_vector(BITS-1 downto 0);
        bits_ref   : in  std_logic_vector(BITS-1 downto 0);
        valid_in   : in  std_logic;
        bits_cnt   : out std_logic_vector(BITS_CNT_WIDTH-1 downto 0);
        errors_cnt : out std_logic_vector(ERRORS_CNT_WIDTH-1 downto 0));
end entity analysis;

architecture arch of analysis is

  component error_counter is
    generic (BITS             : positive;
             BITS_CNT_WIDTH   : positive;
             ERRORS_CNT_WIDTH : positive);
    port (clk        : in  std_logic;
          rst        : in  std_logic;
          input0     : in  std_logic_vector(BITS-1 downto 0);
          input1     : in  std_logic_vector(BITS-1 downto 0);
          valid_in0  : in  std_logic;
          valid_in1  : in  std_logic;
          bits_cnt   : out std_logic_vector(BITS_CNT_WIDTH-1 downto 0);
          errors_cnt : out std_logic_vector(ERRORS_CNT_WIDTH-1 downto 0));
  end component error_counter;

begin

  error_counter_inst : component error_counter
    generic map (BITS             => BITS,
                 BITS_CNT_WIDTH   => BITS_CNT_WIDTH,
                 ERRORS_CNT_WIDTH => ERRORS_CNT_WIDTH)
    port map (clk        => clk,
              rst        => rst,
              input0     => bits_demod,
              input1     => bits_ref,
              valid_in0  => valid_in,
              valid_in1  => valid_in,
              bits_cnt   => bits_cnt,
              errors_cnt => errors_cnt);

end architecture arch;
