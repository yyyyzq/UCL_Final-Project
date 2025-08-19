-------------------------------------------------------------------------------
-- Title      : 256QAM Modulator
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : mod_256QAM.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2019-07-03
-- Last update: 2019-07-04
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- 256QAM modulator
--
-------------------------------------------------------------------------------
-- Copyright (c) 2019 Erik Börjeson
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-07-03  1.0      erikbor	Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity mod_256QAM is
  generic (WIDTH   : positive              := 8;
           MAX_AMP : real range 0.0 to 1.0 := 1.0);
  port (binary : in  std_logic_vector(7 downto 0);
        i      : out std_logic_vector(WIDTH-1 downto 0);
        q      : out std_logic_vector(WIDTH-1 downto 0));
end entity mod_256QAM;

architecture arch of mod_256QAM is

  constant IQ_MAX : real                     := MAX_AMP / sqrt(2.0);
  constant AMP7 : signed(WIDTH-1 downto 0) := to_signed(integer(round(real(2**(WIDTH-1)-1)*IQ_MAX*15.0/15.0)), WIDTH);
  constant AMP6 : signed(WIDTH-1 downto 0) := to_signed(integer(round(real(2**(WIDTH-1)-1)*IQ_MAX*13.0/15.0)), WIDTH);
  constant AMP5 : signed(WIDTH-1 downto 0) := to_signed(integer(round(real(2**(WIDTH-1)-1)*IQ_MAX*11.0/15.0)), WIDTH);
  constant AMP4 : signed(WIDTH-1 downto 0) := to_signed(integer(round(real(2**(WIDTH-1)-1)*IQ_MAX*9.0/15.0)), WIDTH);
  constant AMP3 : signed(WIDTH-1 downto 0) := to_signed(integer(round(real(2**(WIDTH-1)-1)*IQ_MAX*7.0/15.0)), WIDTH);
  constant AMP2 : signed(WIDTH-1 downto 0) := to_signed(integer(round(real(2**(WIDTH-1)-1)*IQ_MAX*5.0/15.0)), WIDTH);
  constant AMP1 : signed(WIDTH-1 downto 0) := to_signed(integer(round(real(2**(WIDTH-1)-1)*IQ_MAX*3.0/15.0)), WIDTH);
  constant AMP0 : signed(WIDTH-1 downto 0) := to_signed(integer(round(real(2**(WIDTH-1)-1)*IQ_MAX*1.0/15.0)), WIDTH);

begin

  with binary(7 downto 4) select i <=
    std_logic_vector(-AMP7) when "0000",
    std_logic_vector(-AMP6) when "0001",
    std_logic_vector(-AMP5) when "0011",
    std_logic_vector(-AMP4) when "0010",
    std_logic_vector(-AMP3) when "0110",
    std_logic_vector(-AMP2) when "0111",
    std_logic_vector(-AMP1) when "0101",
    std_logic_vector(-AMP0) when "0100",
    std_logic_vector(AMP0)  when "1100",
    std_logic_vector(AMP1)  when "1101",
    std_logic_vector(AMP2)  when "1111",
    std_logic_vector(AMP3)  when "1110",
    std_logic_vector(AMP4)  when "1010",
    std_logic_vector(AMP5)  when "1011",
    std_logic_vector(AMP6)  when "1001",
    std_logic_vector(AMP7)  when "1000",
    (others => 'X')         when others;

  with binary(3 downto 0) select q <=
    std_logic_vector(-AMP7) when "0000",
    std_logic_vector(-AMP6) when "0001",
    std_logic_vector(-AMP5) when "0011",
    std_logic_vector(-AMP4) when "0010",
    std_logic_vector(-AMP3) when "0110",
    std_logic_vector(-AMP2) when "0111",
    std_logic_vector(-AMP1) when "0101",
    std_logic_vector(-AMP0) when "0100",
    std_logic_vector(AMP0)  when "1100",
    std_logic_vector(AMP1)  when "1101",
    std_logic_vector(AMP2)  when "1111",
    std_logic_vector(AMP3)  when "1110",
    std_logic_vector(AMP4)  when "1010",
    std_logic_vector(AMP5)  when "1011",
    std_logic_vector(AMP6)  when "1001",
    std_logic_vector(AMP7)  when "1000",
    (others => 'X')         when others;

end architecture arch;
