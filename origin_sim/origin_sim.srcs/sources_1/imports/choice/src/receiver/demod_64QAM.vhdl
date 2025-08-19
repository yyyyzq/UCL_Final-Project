-------------------------------------------------------------------------------
-- Title      : 64QAM Demodulator
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : demod_64QAM.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2019-07-03
-- Last update: 2019-07-04
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- 64QAM Demodulator
--
-------------------------------------------------------------------------------
-- Copyright (c) 2019 Erik Börjeson
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-07-03  1.0      erikbor	Created
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity demod_64QAM is
  generic (WIDTH   : positive              := 8;
           MAX_AMP : real range 0.0 to 1.0 := 1.0);
  port (i      : in  std_logic_vector(WIDTH-1 downto 0);
        q      : in  std_logic_vector(WIDTH-1 downto 0);
        binary : out std_logic_vector(5 downto 0));
end entity demod_64QAM;

architecture arch of demod_64QAM is

  constant IQ_MAX : real                     := MAX_AMP / sqrt(2.0);
  constant AMP12  : signed(WIDTH-1 downto 0) := to_signed(integer(round(real(2**(WIDTH-1)-1)*IQ_MAX*4.0/7.0)), WIDTH);
  constant AMP01  : signed(WIDTH-1 downto 0) := to_signed(integer(round(real(2**(WIDTH-1)-1)*IQ_MAX*2.0/7.0)), WIDTH);
  
begin

  binary(5) <= '0' when to_integer(signed(i)) < 0                         else '1';
  binary(4) <= '1' when to_integer(abs(signed(i))-AMP12) < 0              else '0';
  binary(3) <= '1' when (abs(to_integer(abs(signed(i))-AMP12))-AMP01) < 0 else '0';

  binary(2) <= '0' when to_integer(signed(q)) < 0                         else '1';
  binary(1) <= '1' when to_integer(abs(signed(q))-AMP12) < 0              else '0';
  binary(0) <= '1' when (abs(to_integer(abs(signed(q))-AMP12))-AMP01) < 0 else '0';

end architecture arch;


