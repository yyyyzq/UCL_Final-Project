-------------------------------------------------------------------------------
-- Title      : Pseudo Random Number Generator
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : rng.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2019-07-03
-- Last update: 2019-07-04
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- Generates a pseudora random bitsequence by instantiating the number of
-- xorshift modules needed to supply the number of bits specified in the
-- BITS generic.
--
-- The generator is based on the architecture suggested in [1], and this
-- paper can be reference for values to use when setting up the A, B, C
-- generics.
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
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity rng is
  generic (BITS : positive         := 64;
           N    : positive         := 64;
           A    : positive         := 21;
           B    : positive         := 35;
           C    : positive         := 4;
           SEED : std_logic_vector := "1010010101100010001010010100111001100111001010010110000110001111");
  port (clk       : in  std_logic;
        rst       : in  std_logic;
        bin       : out std_logic_vector(BITS-1 downto 0);
        valid_out : out std_logic);
end entity rng;

architecture arch of rng is

  -- Constant declarations
  constant RNG_N : integer := integer(ceil(real(BITS)/real(N)));
  constant CNT_N : integer := integer(floor(real(N)/real(BITS)));

  -- Component declarations 
  component xorshift is
    generic (N    : positive;
             A    : positive;
             B    : positive;
             C    : positive;
             SEED : std_logic_vector);
    port (clk    : in  std_logic;
          en     : in  std_logic;
          rst    : in  std_logic;
          output : out std_logic_vector);
  end component xorshift;

  -- Signal declarations
  signal xorshifts_out : std_logic_vector(RNG_N*N-1 downto 0);
  signal rst_flag      : std_logic;
  signal cnt           : integer range 0 to abs(CNT_N-1);
  signal en            : std_logic;

begin

  one_gen : if BITS < N generate
    process (rst, clk)
    begin
      if rst = '1' then
        cnt       <= 0;
        en        <= '1';
        bin       <= (others => '0');
        valid_out <= '0';
        rst_flag  <= '1';
      elsif rising_edge(clk) then
        if cnt = CNT_N-1 then
          cnt      <= 0;
          en       <= '1';
          rst_flag <= '0';
        else
          cnt <= cnt + 1;
          en  <= '0';
        end if;
        if rst_flag <= '0' then
          bin       <= xorshifts_out((cnt+1)*BITS-1 downto cnt*BITS);
          valid_out <= '1';
        end if;
      end if;
    end process;
  end generate one_gen;

  multiple_gen : if BITS >= N generate
    en <= '1';
    process (rst, clk)
    begin
      if rst = '1' then
        bin       <= (others => '0');
        valid_out <= '0';
      elsif rising_edge(clk) then
        bin       <= xorshifts_out(BITS-1 downto 0);
        valid_out <= '1';
      end if;
    end process;
  end generate;

  xorshifts_gen : for i in 0 to RNG_N-1 generate
    xorshift_gen : xorshift
      generic map (N    => N,
                   A    => A,
                   B    => B,
                   C    => C,
                   SEED => SEED(i*N to (i+1)*N-1))
      port map (clk    => clk,
                en     => en,
                rst    => rst,
                output => xorshifts_out((i+1)*N-1 downto i*N));
  end generate;

end architecture arch;

