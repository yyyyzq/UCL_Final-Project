-------------------------------------------------------------------------------
-- Title      : 16QAM Modulator
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : mod_16QAM.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2019-07-03
-- Last update: 2019-07-04
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- 16QAM modulator
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

entity mod_16QAM is
  generic (WIDTH   : positive              := 8;
           MAX_AMP : real range 0.0 to 1.0 := 1.0);
  port (binary : in  std_logic_vector(3 downto 0);
        i      : out std_logic_vector(WIDTH-1 downto 0);
        q      : out std_logic_vector(WIDTH-1 downto 0));
end entity mod_16QAM;

architecture arch of mod_16QAM is

  constant IQ_MAX : real                     := MAX_AMP / sqrt(2.0);
  constant AMP1   : signed(WIDTH-1 downto 0) := to_signed(integer(round(real(2**(WIDTH-1)-1)*IQ_MAX)), WIDTH);
  constant AMP0   : signed(WIDTH-1 downto 0) := to_signed(integer(round(real(2**(WIDTH-1)-1)*IQ_MAX/3.0)), WIDTH);

begin

  with binary(3 downto 2) select i <=
    std_logic_vector(-AMP1) when "00",
    std_logic_vector(-AMP0) when "01",
    std_logic_vector(AMP0)  when "11",
    std_logic_vector(AMP1)  when "10",
    (others => 'X')         when others;

  with binary(1 downto 0) select q <=
    std_logic_vector(-AMP1) when "00",
    std_logic_vector(-AMP0) when "01",
    std_logic_vector(AMP0)  when "11",
    std_logic_vector(AMP1)  when "10",
    (others => 'X')         when others;

end architecture arch;
