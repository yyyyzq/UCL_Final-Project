-------------------------------------------------------------------------------
-- Title      : Receiver for a Dual Polarization Setup
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : receiver.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2022-02-28
-- Last update: 2022-03-01
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- Demonstration of a receiver for a dual polarization setup
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
use ieee.math_real.all;

entity receiver is
  generic (WIDTH    : positive              := 8;
           MOD_BITS : positive              := 2;
           MOD_TYPE : string                := "QPSK";
           MAX_AMP  : real range 0.0 to 1.0 := 1.0);
  port (clk         : in  std_logic;
        rst         : in  std_logic;
        x_i_in      : in  std_logic_vector(2*WIDTH-1 downto 0);
        x_q_in      : in  std_logic_vector(2*WIDTH-1 downto 0);
        y_i_in      : in  std_logic_vector(2*WIDTH-1 downto 0);
        y_q_in      : in  std_logic_vector(2*WIDTH-1 downto 0);
        bits_x_in   : in  std_logic_vector(MOD_BITS-1 downto 0);
        bits_y_in   : in  std_logic_vector(MOD_BITS-1 downto 0);
        valid_in    : in  std_logic;
        demod_x_out : out std_logic_vector(MOD_BITS-1 downto 0);
        demod_y_out : out std_logic_vector(MOD_BITS-1 downto 0);
        bits_x_out  : out std_logic_vector(MOD_BITS-1 downto 0);
        bits_y_out  : out std_logic_vector(MOD_BITS-1 downto 0);
        valid_out   : out std_logic);
end entity receiver;

architecture arch of receiver is

  constant BITS : positive := MOD_BITS;

  component dsp is
    generic(WIDTH : positive;
            BITS  : positive);
    port (clk        : in  std_logic;
          rst        : in  std_logic;
          x_i_in     : in  std_logic_vector(2*WIDTH-1 downto 0);
          x_q_in     : in  std_logic_vector(2*WIDTH-1 downto 0);
          y_i_in     : in  std_logic_vector(2*WIDTH-1 downto 0);
          y_q_in     : in  std_logic_vector(2*WIDTH-1 downto 0);
          bits_x_in  : in  std_logic_vector(BITS-1 downto 0);
          bits_y_in  : in  std_logic_vector(BITS-1 downto 0);
          valid_in   : in  std_logic;
          x_i_out    : out std_logic_vector(WIDTH-1 downto 0);
          x_q_out    : out std_logic_vector(WIDTH-1 downto 0);
          y_i_out    : out std_logic_vector(WIDTH-1 downto 0);
          y_q_out    : out std_logic_vector(WIDTH-1 downto 0);
          bits_x_out : out std_logic_vector(BITS-1 downto 0);
          bits_y_out : out std_logic_vector(BITS-1 downto 0);
          valid_out  : out std_logic);
  end component dsp;

  component demodulator is
    generic (PAR      : positive;
             MOD_BITS : positive;
             MOD_TYPE : string;
             WIDTH    : positive;
             MAX_AMP  : real range 0.0 to 1.0);
    port (clk       : in  std_logic;
          rst       : in  std_logic;
          i_in      : in  std_logic_vector(PAR*WIDTH-1 downto 0);
          q_in      : in  std_logic_vector(PAR*WIDTH-1 downto 0);
          bits_in   : in  std_logic_vector(PAR*MOD_BITS-1 downto 0);
          valid_in  : in  std_logic;
          demod_out : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
          bits_out  : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
          valid_out : out std_logic);
  end component demodulator;

  signal x_i_dsp    : std_logic_vector(WIDTH-1 downto 0);
  signal x_q_dsp    : std_logic_vector(WIDTH-1 downto 0);
  signal y_i_dsp    : std_logic_vector(WIDTH-1 downto 0);
  signal y_q_dsp    : std_logic_vector(WIDTH-1 downto 0);
  signal bits_x_dsp : std_logic_vector(BITS-1 downto 0);
  signal bits_y_dsp : std_logic_vector(BITS-1 downto 0);
  signal valid_dsp  : std_logic;

  signal valid_x_out : std_logic;
  signal valid_y_out : std_logic;

begin

  dsp_inst : component dsp
    generic map(WIDTH => WIDTH,
                BITS  => BITS)
    port map (clk        => clk,
              rst        => rst,
              x_i_in     => x_i_in,
              x_q_in     => x_q_in,
              y_i_in     => y_i_in,
              y_q_in     => y_q_in,
              bits_x_in  => bits_x_in,
              bits_y_in  => bits_y_in,
              valid_in   => valid_in,
              x_i_out    => x_i_dsp,
              x_q_out    => x_q_dsp,
              y_i_out    => y_i_dsp,
              y_q_out    => y_q_dsp,
              bits_x_out => bits_x_dsp,
              bits_y_out => bits_y_dsp,
              valid_out  => valid_dsp);


  demodulator_x_inst : component demodulator
    generic map (PAR      => 1,
                 WIDTH    => WIDTH,
                 MOD_BITS => MOD_BITS,
                 MOD_TYPE => MOD_TYPE,
                 MAX_AMP  => MAX_AMP)
    port map (clk       => clk,
              rst       => rst,
              i_in      => x_i_dsp,
              q_in      => x_q_dsp,
              bits_in   => bits_x_dsp,
              valid_in  => valid_dsp,
              demod_out => demod_x_out,
              bits_out  => bits_x_out,
              valid_out => valid_x_out);

  demodulator_y_inst : component demodulator
    generic map (PAR      => 1,
                 WIDTH    => WIDTH,
                 MOD_BITS => MOD_BITS,
                 MOD_TYPE => MOD_TYPE,
                 MAX_AMP  => MAX_AMP)
    port map (clk       => clk,
              rst       => rst,
              i_in      => y_i_dsp,
              q_in      => y_q_dsp,
              bits_in   => bits_y_dsp,
              valid_in  => valid_dsp,
              demod_out => demod_y_out,
              bits_out  => bits_y_out,
              valid_out => valid_y_out);

  valid_out <= valid_x_out and valid_y_out;

end architecture arch;
