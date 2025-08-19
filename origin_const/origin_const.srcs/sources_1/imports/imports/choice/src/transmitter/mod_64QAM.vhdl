-------------------------------------------------------------------------------
-- Title      : 64QAM Modulator
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : mod_65QAM.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2019-07-03
-- Last update: 2021-01-25
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- 64QAM modulator
--
-------------------------------------------------------------------------------
-- Copyright (c) 2019 Erik Börjeson
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-07-03  1.0      erikbor Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity mod_64QAM is
  generic (WIDTH   : positive              := 8;
           MAX_AMP : real range 0.0 to 1.0 := 1.0);
  port (binary : in  std_logic_vector(5 downto 0);
        i      : out std_logic_vector(WIDTH-1 downto 0);
        q      : out std_logic_vector(WIDTH-1 downto 0));
end entity mod_64QAM;

architecture arch of mod_64QAM is

  constant IQ_MAX : real                     := MAX_AMP / sqrt(2.0);
  constant AMP3   : signed(WIDTH-1 downto 0) := to_signed(integer(round(real(2**(WIDTH-1)-1)*IQ_MAX)), WIDTH);
  constant AMP2   : signed(WIDTH-1 downto 0) := to_signed(integer(round(real(2**(WIDTH-1)-1)*IQ_MAX*5.0/7.0)), WIDTH);
  constant AMP1   : signed(WIDTH-1 downto 0) := to_signed(integer(round(real(2**(WIDTH-1)-1)*IQ_MAX*3.0/7.0)), WIDTH);
  constant AMP0   : signed(WIDTH-1 downto 0) := to_signed(integer(round(real(2**(WIDTH-1)-1)*IQ_MAX/7.0)), WIDTH);

begin

  with binary(5 downto 3) select i <=
    std_logic_vector(-AMP3) when "000",
    std_logic_vector(-AMP2) when "001",
    std_logic_vector(-AMP1) when "011",
    std_logic_vector(-AMP0) when "010",
    std_logic_vector(AMP0)  when "110",
    std_logic_vector(AMP1)  when "111",
    std_logic_vector(AMP2)  when "101",
    std_logic_vector(AMP3)  when "100",
    (others => 'X')         when others;

  with binary(2 downto 0) select q <=
    std_logic_vector(-AMP3) when "000",
    std_logic_vector(-AMP2) when "001",
    std_logic_vector(-AMP1) when "011",
    std_logic_vector(-AMP0) when "010",
    std_logic_vector(AMP0)  when "110",
    std_logic_vector(AMP1)  when "111",
    std_logic_vector(AMP2)  when "101",
    std_logic_vector(AMP3)  when "100",
    (others => 'X')         when others;

end architecture arch;
