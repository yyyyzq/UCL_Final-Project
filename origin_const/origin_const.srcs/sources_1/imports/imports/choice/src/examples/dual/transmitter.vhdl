-------------------------------------------------------------------------------
-- Title      : Transmitter for a Dual Polarization Setup
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
-- Transmitter for a dual polarization setup, including pseudo-random data
-- generation, modulation and RRC filter.
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
  generic (WIDTH         : positive              := 8;
           MAX_AMP       : real range 0.0 to 1.0 := 0.6;
           MOD_TYPE      : string                := "QPSK";
           MOD_BITS      : positive              := 2;
           RRC_TAP_WIDTH : positive              := 12);
  port (clk        : in  std_logic;
        rst        : in  std_logic;
        x_i_out    : out std_logic_vector(2*WIDTH-1 downto 0);
        x_q_out    : out std_logic_vector(2*WIDTH-1 downto 0);
        y_i_out    : out std_logic_vector(2*WIDTH-1 downto 0);
        y_q_out    : out std_logic_vector(2*WIDTH-1 downto 0);
        bits_x_out : out std_logic_vector(MOD_BITS-1 downto 0);
        bits_y_out : out std_logic_vector(MOD_BITS-1 downto 0);
        valid_out  : out std_logic);
end entity transmitter;

architecture arch of transmitter is

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

  component rrc is
    generic (WIDTH     : positive;
             TAP_WIDTH : positive;
             BITS      : positive);
    port (clk       : in  std_logic;
          rst       : in  std_logic;
          i_in      : in  std_logic_vector(WIDTH-1 downto 0);
          q_in      : in  std_logic_vector(WIDTH-1 downto 0);
          bits_in   : in  std_logic_vector(BITS-1 downto 0);
          valid_in  : in  std_logic;
          i_out     : out std_logic_vector(2*WIDTH-1 downto 0);
          q_out     : out std_logic_vector(2*WIDTH-1 downto 0);
          bits_out  : out std_logic_vector(BITS-1 downto 0);
          valid_out : out std_logic);
  end component rrc;


  signal bin       : std_logic_vector(3 downto 0);
  signal valid_rng : std_logic;

  signal x_i_mod     : std_logic_vector(WIDTH-1 downto 0);
  signal x_q_mod     : std_logic_vector(WIDTH-1 downto 0);
  signal y_i_mod     : std_logic_vector(WIDTH-1 downto 0);
  signal y_q_mod     : std_logic_vector(WIDTH-1 downto 0);
  signal bits_x_mod  : std_logic_vector(MOD_BITS-1 downto 0);
  signal bits_y_mod  : std_logic_vector(MOD_BITS-1 downto 0);
  signal valid_x_mod : std_logic;
  signal valid_y_mod : std_logic;

  signal valid_x_out : std_logic;
  signal valid_y_out : std_logic;

begin

  rng_inst : component rng
    generic map (BITS => MOD_BITS*2,
                 N    => 64,
                 A    => 13,
                 B    => 7,
                 C    => 17,
                 SEED => "1010010101100010001010010100111001100111001010010110000110001111")
    port map (clk       => clk,
              rst       => rst,
              bin       => bin,
              valid_out => valid_rng);

  modulator_x_inst : component modulator
    generic map (PAR      => 1,
                 WIDTH    => WIDTH,
                 MOD_BITS => MOD_BITS,
                 MOD_TYPE => MOD_TYPE,
                 MAX_AMP  => MAX_AMP)
    port map (clk       => clk,
              rst       => rst,
              bits_in   => bin(1 downto 0),
              valid_in  => valid_rng,
              i_out     => x_i_mod,
              q_out     => x_q_mod,
              bits_out  => bits_x_mod,
              valid_out => valid_x_mod);

  modulator_y_inst : component modulator
    generic map (PAR      => 1,
                 WIDTH    => WIDTH,
                 MOD_BITS => MOD_BITS,
                 MOD_TYPE => MOD_TYPE,
                 MAX_AMP  => MAX_AMP)
    port map (clk       => clk,
              rst       => rst,
              bits_in   => bin(3 downto 2),
              valid_in  => valid_rng,
              i_out     => y_i_mod,
              q_out     => y_q_mod,
              bits_out  => bits_y_mod,
              valid_out => valid_y_mod);

  rrc_x_inst : component rrc
    generic map (WIDTH     => WIDTH,
                 TAP_WIDTH => RRC_TAP_WIDTH,
                 BITS      => MOD_BITS)
    port map (clk       => clk,
              rst       => rst,
              i_in      => x_i_mod,
              q_in      => x_q_mod,
              bits_in   => bits_x_mod,
              valid_in  => valid_x_mod,
              i_out     => x_i_out,
              q_out     => x_q_out,
              bits_out  => bits_x_out,
              valid_out => valid_x_out);

  rrc_y_inst : component rrc
    generic map (WIDTH     => WIDTH,
                 TAP_WIDTH => RRC_TAP_WIDTH,
                 BITS      => MOD_BITS)
    port map (clk       => clk,
              rst       => rst,
              i_in      => y_i_mod,
              q_in      => y_q_mod,
              bits_in   => bits_y_mod,
              valid_in  => valid_y_mod,
              i_out     => y_i_out,
              q_out     => y_q_out,
              bits_out  => bits_y_out,
              valid_out => valid_y_out);

  valid_out <= valid_x_out and valid_y_out;
  
end architecture arch;

