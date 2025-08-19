-------------------------------------------------------------------------------
-- Title      : Transmitter for a Single Polarization Setup
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : transmitter.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2022-02-28
-- Last update: 2022-03-01
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- Transmitter for a single polarization, including pseudo-random data
-- generation and modulation.
--
-------------------------------------------------------------------------------
-- Copyright (c) 2019 Erik Börjeson
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2022-02-28  1.0      erikbor Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity transmitter is
  generic (PAR      : positive              := 2;
           WIDTH    : positive              := 8;
           MAX_AMP  : real range 0.0 to 1.0 := 0.6;
           MOD_TYPE : string                := "QPSK";
           MOD_BITS : positive              := 2);
  port (clk       : in  std_logic;
        rst       : in  std_logic;
        i_out     : out std_logic_vector(PAR*WIDTH-1 downto 0);
        q_out     : out std_logic_vector(PAR*WIDTH-1 downto 0);
        bits_out  : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
        valid_out : out std_logic);
end entity transmitter;

architecture arch of transmitter is

  constant BITS : positive := PAR*MOD_BITS;

  component rng is
    generic (BITS : positive;
             N    : positive;
             A    : positive;
             B    : positive;
             C    : positive;
             SEED : std_logic_vector);
    port (clk       : in  std_logic;
          rst       : in  std_logic;
          bin       : out std_logic_vector(BITS-1 downto 0);
          valid_out : out std_logic);
  end component rng;

  component modulator is
    generic (PAR      : positive;
             WIDTH    : positive;
             MOD_BITS : positive;
             MOD_TYPE : string;
             MAX_AMP  : real);
    port (clk       : in  std_logic;
          rst       : in  std_logic;
          bits_in   : in  std_logic_vector(PAR*MOD_BITS-1 downto 0);
          valid_in  : in  std_logic;
          i_out     : out std_logic_vector(PAR*WIDTH-1 downto 0);
          q_out     : out std_logic_vector(PAR*WIDTH-1 downto 0);
          bits_out  : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
          valid_out : out std_logic);
  end component modulator;

  signal bin       : std_logic_vector(BITS-1 downto 0);
  signal valid_rng : std_logic;

begin

  rng_inst : component rng
    generic map (BITS => BITS,
                 N    => 64,
                 A    => 13,
                 B    => 7,
                 C    => 17,
                 SEED => "1010010101100010001010010100111001100111001010010110000110001111")
    port map (clk       => clk,
              rst       => rst,
              bin       => bin,
              valid_out => valid_rng);

  modulator_inst : component modulator
    generic map (PAR      => PAR,
                 WIDTH    => WIDTH,
                 MOD_BITS => MOD_BITS,
                 MOD_TYPE => MOD_TYPE,
                 MAX_AMP  => MAX_AMP)
    port map (clk       => clk,
              rst       => rst,
              bits_in   => bin,
              valid_in  => valid_rng,
              i_out     => i_out,
              q_out     => q_out,
              bits_out  => bits_out,
              valid_out => valid_out);


end architecture arch;

