-------------------------------------------------------------------------------
-- Title      : Receiver for a Single Polarization Setup
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
-- Receiver for single polarization setup, basically a wrapper for the
-- demodulator. 
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
  generic (PAR      : positive              := 2;
           WIDTH    : positive              := 8;
           MOD_BITS : positive              := 2;
           MOD_TYPE : string                := "QPSK";
           MAX_AMP  : real range 0.0 to 1.0 := 1.0);
  port (clk       : in  std_logic;
        rst       : in  std_logic;
        i_in      : in  std_logic_vector(PAR*WIDTH-1 downto 0);
        q_in      : in  std_logic_vector(PAR*WIDTH-1 downto 0);
        bits_in   : in  std_logic_vector(PAR*MOD_BITS-1 downto 0);
        valid_in  : in  std_logic;
        demod_out : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
        bits_out  : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
        valid_out : out std_logic);
end entity receiver;

architecture arch of receiver is

  constant BITS : positive := PAR*MOD_BITS;

  component dsp is
    generic(PAR   : positive;
            WIDTH : positive;
            BITS  : positive);
    port (clk       : in  std_logic;
          rst       : in  std_logic;
          i_in      : in  std_logic_vector(PAR*WIDTH-1 downto 0);
          q_in      : in  std_logic_vector(PAR*WIDTH-1 downto 0);
          bits_in   : in  std_logic_vector(BITS-1 downto 0);
          valid_in  : in  std_logic;
          i_out     : out std_logic_vector(PAR*WIDTH-1 downto 0);
          q_out     : out std_logic_vector(PAR*WIDTH-1 downto 0);
          bits_out  : out std_logic_vector(BITS-1 downto 0);
          valid_out : out std_logic);
  end component dsp;
  
  component bps is
    generic(
      PAR     : positive;
      WIDTH   : positive;
      WINLEN  : positive;
      PHASES  : positive
    );
    port(
      clk        : in  std_logic;
      rst        : in  std_logic;
      i_in       : in  std_logic_vector(PAR*WIDTH-1 downto 0);
      q_in       : in  std_logic_vector(PAR*WIDTH-1 downto 0);
      valid_in   : in  std_logic;
      i_out      : out std_logic_vector(PAR*WIDTH-1 downto 0);
      q_out      : out std_logic_vector(PAR*WIDTH-1 downto 0);
      valid_out  : out std_logic
    );
  end component;

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

  signal i_dsp     : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal q_dsp     : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal bits_dsp  : std_logic_vector(BITS-1 downto 0);
  signal valid_dsp : std_logic;
  
  signal i_bps     : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal q_bps     : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal valid_bps : std_logic;

begin

  dsp_inst : component dsp
    generic map(PAR   => PAR,
                WIDTH => WIDTH,
                BITS  => BITS)
    port map (clk       => clk,
              rst       => rst,
              i_in      => i_in,
              q_in      => q_in,
              bits_in   => bits_in,
              valid_in  => valid_in,
              i_out     => i_dsp,
              q_out     => q_dsp,
              bits_out  => bits_dsp,
              valid_out => valid_dsp);

  bps_inst : component bps
    generic map(
      PAR     => PAR,
      WIDTH   => WIDTH,
      WINLEN  => 32,    -- 或其它你想测试的窗口长度
      PHASES  => 16      -- 或16，按你的需求
    )
    port map(
      clk        => clk,
      rst        => rst,
      i_in       => i_dsp,
      q_in       => q_dsp,
      valid_in   => valid_dsp,
      i_out      => i_bps,
      q_out      => q_bps,
      valid_out  => valid_bps
    );

  
  demodulator_inst : component demodulator
    generic map (PAR      => PAR,
                 WIDTH    => WIDTH,
                 MOD_BITS => MOD_BITS,
                 MOD_TYPE => MOD_TYPE,
                 MAX_AMP  => MAX_AMP)
    port map (clk       => clk,
              rst       => rst,
              i_in      => i_bps,
              q_in      => q_bps,
              bits_in   => bits_dsp,     
              valid_in  => valid_bps,
              demod_out => demod_out,
              bits_out  => bits_out,
              valid_out => valid_out);

end architecture arch;
