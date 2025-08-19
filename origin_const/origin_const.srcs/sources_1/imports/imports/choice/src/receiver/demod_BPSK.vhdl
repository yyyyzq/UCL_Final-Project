-------------------------------------------------------------------------------
-- Title      : BPSK Demodulator
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : demod_BPSK.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2019-07-03
-- Last update: 2019-07-04
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- BPSK Demodulator
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

entity demod_BPSK is
  generic (WIDTH   : positive               := 8;
           MAX_AMP : real range 0.0 to 1.0 := 1.0);
  port (i      : in  std_logic_vector(WIDTH-1 downto 0);
        q      : in  std_logic_vector(WIDTH-1 downto 0);
        binary : out std_logic);
end entity demod_BPSK;

architecture arch of demod_BPSK is
begin

  binary <= '0' when to_integer(signed(i)) < 0 else
            '1' when to_integer(signed(i)) >= 0 else
            'X';

end architecture arch;


