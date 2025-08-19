-------------------------------------------------------------------------------
-- Title      : 256QAM Demodulator
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : demod_256QAM.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2019-07-03
-- Last update: 2019-07-04
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- 256QAM Demodulator
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

entity demod_256QAM is
  generic (WIDTH   : positive              := 8;
           MAX_AMP : real range 0.0 to 1.0 := 1.0);
  port (i      : in  std_logic_vector(WIDTH-1 downto 0);
        q      : in  std_logic_vector(WIDTH-1 downto 0);
        binary : out std_logic_vector(7 downto 0));
end entity demod_256QAM;

architecture arch of demod_256QAM is

  constant IQ_MAX : real                     := MAX_AMP / sqrt(2.0);
  constant AMP34 : signed(WIDTH-1 downto 0) := to_signed(integer(round(real(2**(WIDTH-1)-1)*IQ_MAX*8.0/15.0)), WIDTH);
  constant AMP12 : signed(WIDTH-1 downto 0) := to_signed(integer(round(real(2**(WIDTH-1)-1)*IQ_MAX*4.0/15.0)), WIDTH);
  constant AMP01 : signed(WIDTH-1 downto 0) := to_signed(integer(round(real(2**(WIDTH-1)-1)*IQ_MAX*2.0/15.0)), WIDTH);

begin

  binary(7) <= '0' when signed(i) < 0                                  else '1';
  binary(6) <= '1' when abs(signed(i))-AMP34 < 0                       else '0';
  binary(5) <= '1' when abs(abs(signed(i))-AMP34)-AMP12 < 0            else '0';
  binary(4) <= '1' when abs(abs(abs(signed(i))-AMP34)-AMP12)-AMP01 < 0 else '0';

  binary(3) <= '0' when to_integer(signed(q)) < 0                                    else '1';
  binary(2) <= '1' when to_integer(abs(signed(q))-AMP34) < 0                         else '0';
  binary(1) <= '1' when (abs(to_integer(abs(signed(q))-AMP34))-AMP12) < 0            else '0';
  binary(0) <= '1' when (abs(abs(to_integer(abs(signed(q))-AMP34))-AMP12)-AMP01) < 0 else '0';

end architecture arch;


