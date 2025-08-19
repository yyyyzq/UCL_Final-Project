-------------------------------------------------------------------------------
-- Title      : Xorshift RNG
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : xorshift.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2019-07-03
-- Last update: 2019-07-05
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- Xorshift RNG, used as a subcomponent to then rng. Based in the work done
-- in [1].
--
-- [1] G. Marsaglia, "Xorshift RNGs," Journal of Statistical Software,
--     vol. 8, no. 14, pp. 1-6, 2003.
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

entity xorshift is
  generic (N    : positive         := 64;
           A    : positive         := 13;
           B    : positive         := 7;
           C    : positive         := 17;
           SEED : std_logic_vector := "0101010101010101010101010101010101010101010101010101010101010101");
  port (clk    : in  std_logic;
        en     : in  std_logic;
        rst    : in  std_logic;
        output : out std_logic_vector(N-1 downto 0));
end entity xorshift;

architecture arch of xorshift is
  signal state : std_logic_vector(N-1 downto 0);
begin

  process (rst, clk)
    variable temp_state : unsigned(N-1 downto 0);
  begin
    if rst = '1' then
      state <= SEED;
    elsif rising_edge(clk) then
      if en = '1' then
        temp_state := unsigned(state);
        temp_state := temp_state xor shift_left(temp_state, A);
        temp_state := temp_state xor shift_right(temp_state, B);
        temp_state := temp_state xor shift_left(temp_state, C);
        state      <= std_logic_vector(temp_state);
      end if;
    end if;
  end process;

  output <= state;

end architecture arch;

