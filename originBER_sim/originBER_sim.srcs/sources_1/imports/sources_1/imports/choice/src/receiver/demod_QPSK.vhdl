-------------------------------------------------------------------------------
-- Title      : QPSK Demodulator
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : demod_QPSK.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2019-07-03
-- Last update: 2019-07-04
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- QPSK demodulator
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

entity demod_QPSK is
  generic (WIDTH   : positive              := 8;
           MAX_AMP : real range 0.0 to 1.0 := 1.0);
  port (i      : in  std_logic_vector(WIDTH-1 downto 0);
        q      : in  std_logic_vector(WIDTH-1 downto 0);
        binary : out std_logic_vector(1 downto 0));
end entity demod_QPSK;

architecture arch of demod_QPSK is
begin

  binary(1) <= '0' when to_integer(signed(i)) < 0 else
               '1' when to_integer(signed(i)) >= 0 else
               'X';

  binary(0) <= '0' when to_integer(signed(q)) < 0 else
               '1' when to_integer(signed(q)) >= 0 else
               'X';

end architecture arch;
