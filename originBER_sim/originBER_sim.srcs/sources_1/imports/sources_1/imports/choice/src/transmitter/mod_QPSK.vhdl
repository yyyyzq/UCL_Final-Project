-------------------------------------------------------------------------------
-- Title      : QPSK Modulator
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : mod_QPSK.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2019-07-03
-- Last update: 2019-07-04
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- QPSK modulator
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


entity mod_QPSK is
  generic (WIDTH   : positive              := 8;
           MAX_AMP : real range 0.0 to 1.0 := 0.5);
  port (binary : in  std_logic_vector(1 downto 0);
        i      : out std_logic_vector(WIDTH-1 downto 0);
        q      : out std_logic_vector(WIDTH-1 downto 0));
end entity mod_QPSK;

architecture arch of mod_QPSK is

  constant IQ_MAX : real                     := MAX_AMP / sqrt(2.0);
  constant AMP : signed(WIDTH-1 downto 0) := to_signed(integer(round(real(2**(WIDTH-1)-1)*IQ_MAX)), WIDTH);

begin

  with binary(1) select i <=
    std_logic_vector(-AMP) when '0',
    std_logic_vector(AMP)  when '1',
    (others => 'X')        when others;

  with binary(0) select q <=
    std_logic_vector(-AMP) when '0',
    std_logic_vector(AMP)  when '1',
    (others => 'X')        when others;

end architecture arch;
