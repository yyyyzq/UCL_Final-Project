-------------------------------------------------------------------------------
-- Title      : Channel for a Dual Polarization Setup
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : channel.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2022-02-28
-- Last update: 2022-03-03
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- Channel a dual polarization setup, including AWGN, phase noise and PMD
-- emulation. 
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
use ieee.numeric_std.all;

entity channel is
  generic (WIDTH             : positive := 8;
           BITS              : positive := 2;
           PN_PHASE_WIDTH    : positive := 16;
           PN_LUT_WIDTH      : positive := 16;
           PMD_SECTIONS_N    : positive := 10;
           PMD_THETA_WIDTH   : positive := 10;
           PMD_COUNTER_WIDTH : positive := 32;
           PMD_TAP_WIDTH     : positive := 10;
           PMD_TAPS_N        : positive := 5;
           PMD_PHI_WIDTH     : positive := 10);
  port (clk             : in  std_logic;
        rst             : in  std_logic;
        x_i_in          : in  std_logic_vector(2*WIDTH-1 downto 0);
        x_q_in          : in  std_logic_vector(2*WIDTH-1 downto 0);
        y_i_in          : in  std_logic_vector(2*WIDTH-1 downto 0);
        y_q_in          : in  std_logic_vector(2*WIDTH-1 downto 0);
        bits_x_in       : in  std_logic_vector(BITS-1 downto 0);
        bits_y_in       : in  std_logic_vector(BITS-1 downto 0);
        valid_in        : in  std_logic;
        awgn_scaling    : in  std_logic_vector(15 downto 0);
        pn_scaling      : in  std_logic_vector(15 downto 0);
        pmd_theta_start : in  std_logic_vector((PMD_SECTIONS_N+1)*PMD_THETA_WIDTH-1 downto 0);
        pmd_count_max   : in  std_logic_vector((PMD_SECTIONS_N+1)*PMD_COUNTER_WIDTH-1 downto 0);
        pmd_direction   : in  std_logic_vector(PMD_SECTIONS_N downto 0);
        pmd_taps        : in  std_logic_vector(PMD_TAPS_N*PMD_TAP_WIDTH-1 downto 0);
        pmd_phi         : in  std_logic_vector(PMD_SECTIONS_N*PMD_PHI_WIDTH-1 downto 0);
        x_i_out         : out std_logic_vector(2*WIDTH-1 downto 0);
        x_q_out         : out std_logic_vector(2*WIDTH-1 downto 0);
        y_i_out         : out std_logic_vector(2*WIDTH-1 downto 0);
        y_q_out         : out std_logic_vector(2*WIDTH-1 downto 0);
        bits_x_out      : out std_logic_vector(BITS-1 downto 0);
        bits_y_out      : out std_logic_vector(BITS-1 downto 0);
        valid_out       : out std_logic);
end entity channel;

architecture arch of channel is

  component awgn is
    generic (PAR   : positive;
             WIDTH : positive;
             BITS  : positive);
    port (clk       : in  std_logic;
          rst       : in  std_logic;
          i_in      : in  std_logic_vector(PAR*WIDTH-1 downto 0);
          q_in      : in  std_logic_vector(PAR*WIDTH-1 downto 0);
          bits_in   : in  std_logic_vector(BITS-1 downto 0);
          valid_in  : in  std_logic;
          scaling   : in  std_logic_vector(15 downto 0);
          i_out     : out std_logic_vector(PAR*WIDTH-1 downto 0);
          q_out     : out std_logic_vector(PAR*WIDTH-1 downto 0);
          bits_out  : out std_logic_vector(BITS-1 downto 0);
          valid_out : out std_logic);
  end component awgn;

  component phase_noise is
    generic (PAR         : positive;
             WIDTH       : positive;
             BITS        : positive;
             PHASE_WIDTH : positive;
             LUT_WIDTH   : positive);
    port (clk        : in  std_logic;
          rst        : in  std_logic;
          x_i_in     : in  std_logic_vector(PAR*WIDTH-1 downto 0);
          x_q_in     : in  std_logic_vector(PAR*WIDTH-1 downto 0);
          y_i_in     : in  std_logic_vector(PAR*WIDTH-1 downto 0);
          y_q_in     : in  std_logic_vector(PAR*WIDTH-1 downto 0);
          bits_x_in  : in  std_logic_vector(BITS-1 downto 0);
          bits_y_in  : in  std_logic_vector(BITS-1 downto 0);
          valid_in   : in  std_logic;
          scaling    : in  std_logic_vector(15 downto 0);
          x_i_out    : out std_logic_vector(PAR*WIDTH-1 downto 0);
          x_q_out    : out std_logic_vector(PAR*WIDTH-1 downto 0);
          y_i_out    : out std_logic_vector(PAR*WIDTH-1 downto 0);
          y_q_out    : out std_logic_vector(PAR*WIDTH-1 downto 0);
          bits_x_out : out std_logic_vector(BITS-1 downto 0);
          bits_y_out : out std_logic_vector(BITS-1 downto 0);
          valid_out  : out std_logic);
  end component phase_noise;


  component pmd is
    generic (WIDTH         : positive;
             BITS          : positive;
             SECTIONS_N    : positive;
             THETA_WIDTH   : positive;
             COUNTER_WIDTH : positive;
             TAP_WIDTH     : positive;
             TAPS_N        : positive;
             PHI_WIDTH     : positive);
    port (clk         : in  std_logic;
          rst         : in  std_logic;
          x_i_in      : in  std_logic_vector(2*WIDTH-1 downto 0);
          x_q_in      : in  std_logic_vector(2*WIDTH-1 downto 0);
          y_i_in      : in  std_logic_vector(2*WIDTH-1 downto 0);
          y_q_in      : in  std_logic_vector(2*WIDTH-1 downto 0);
          bits_x_in   : in  std_logic_vector(BITS-1 downto 0);
          bits_y_in   : in  std_logic_vector(BITS-1 downto 0);
          valid_in    : in  std_logic;
          theta_start : in  std_logic_vector((SECTIONS_N+1)*THETA_WIDTH-1 downto 0);
          count_max   : in  std_logic_vector((SECTIONS_N+1)*COUNTER_WIDTH-1 downto 0);
          direction   : in  std_logic_vector(SECTIONS_N downto 0);
          taps        : in  std_logic_vector(TAPS_N*TAP_WIDTH-1 downto 0);
          phi         : in  std_logic_vector(SECTIONS_N*PHI_WIDTH-1 downto 0);
          x_i_out     : out std_logic_vector(2*WIDTH-1 downto 0);
          x_q_out     : out std_logic_vector(2*WIDTH-1 downto 0);
          y_i_out     : out std_logic_vector(2*WIDTH-1 downto 0);
          y_q_out     : out std_logic_vector(2*WIDTH-1 downto 0);
          bits_x_out  : out std_logic_vector(BITS-1 downto 0);
          bits_y_out  : out std_logic_vector(BITS-1 downto 0);
          valid_out   : out std_logic);
  end component pmd;


  signal i_awgn_in     : std_logic_vector(4*WIDTH-1 downto 0);
  signal q_awgn_in     : std_logic_vector(4*WIDTH-1 downto 0);
  signal bits_awgn_in  : std_logic_vector(2*BITS-1 downto 0);
  signal i_awgn_out    : std_logic_vector(4*WIDTH-1 downto 0);
  signal q_awgn_out    : std_logic_vector(4*WIDTH-1 downto 0);
  signal bits_awgn_out : std_logic_vector(2*BITS-1 downto 0);
  signal x_i_awgn      : std_logic_vector(2*WIDTH-1 downto 0);
  signal x_q_awgn      : std_logic_vector(2*WIDTH-1 downto 0);
  signal y_i_awgn      : std_logic_vector(2*WIDTH-1 downto 0);
  signal y_q_awgn      : std_logic_vector(2*WIDTH-1 downto 0);
  signal bits_x_awgn   : std_logic_vector(BITS-1 downto 0);
  signal bits_y_awgn   : std_logic_vector(BITS-1 downto 0);
  signal valid_awgn    : std_logic;

  signal x_i_pn    : std_logic_vector(2*WIDTH-1 downto 0);
  signal x_q_pn    : std_logic_vector(2*WIDTH-1 downto 0);
  signal y_i_pn    : std_logic_vector(2*WIDTH-1 downto 0);
  signal y_q_pn    : std_logic_vector(2*WIDTH-1 downto 0);
  signal bits_x_pn : std_logic_vector(BITS-1 downto 0);
  signal bits_y_pn : std_logic_vector(BITS-1 downto 0);
  signal valid_pn  : std_logic;

  signal x_i_pmd    : std_logic_vector(2*WIDTH-1 downto 0);
  signal x_q_pmd    : std_logic_vector(2*WIDTH-1 downto 0);
  signal y_i_pmd    : std_logic_vector(2*WIDTH-1 downto 0);
  signal y_q_pmd    : std_logic_vector(2*WIDTH-1 downto 0);
  signal bits_x_pmd : std_logic_vector(BITS-1 downto 0);
  signal bits_y_pmd : std_logic_vector(BITS-1 downto 0);
  signal valid_pmd  : std_logic;

begin

  i_awgn_in    <= y_i_in & x_i_in;
  q_awgn_in    <= y_q_in & x_q_in;
  bits_awgn_in <= bits_y_in & bits_x_in;

  awgn_inst : component awgn
    generic map (PAR   => 4,
                 WIDTH => WIDTH,
                 BITS  => 2*BITS)
    port map(clk       => clk,
             rst       => rst,
             i_in      => i_awgn_in,
             q_in      => q_awgn_in,
             bits_in   => bits_awgn_in,
             valid_in  => valid_in,
             scaling   => awgn_scaling,
             i_out     => i_awgn_out,
             q_out     => q_awgn_out,
             bits_out  => bits_awgn_out,
             valid_out => valid_awgn);

  x_i_awgn    <= i_awgn_out(2*WIDTH-1 downto 0);
  y_i_awgn    <= i_awgn_out(4*WIDTH-1 downto 2*WIDTH);
  x_q_awgn    <= q_awgn_out(2*WIDTH-1 downto 0);
  y_q_awgn    <= q_awgn_out(4*WIDTH-1 downto 2*WIDTH);
  bits_x_awgn <= bits_awgn_out(BITS-1 downto 0);
  bits_y_awgn <= bits_awgn_out(2*BITS-1 downto BITS);

  phase_noise_inst : component phase_noise
    generic map (PAR         => 2,
                 WIDTH       => WIDTH,
                 BITS        => BITS,
                 PHASE_WIDTH => PN_PHASE_WIDTH,
                 LUT_WIDTH   => PN_LUT_WIDTH)
    port map(clk        => clk,
             rst        => rst,
             x_i_in     => x_i_awgn,
             x_q_in     => x_q_awgn,
             y_i_in     => y_i_awgn,
             y_q_in     => y_q_awgn,
             bits_x_in  => bits_x_awgn,
             bits_y_in  => bits_y_awgn,
             valid_in   => valid_awgn,
             scaling    => pn_scaling,
             x_i_out    => x_i_pn,
             x_q_out    => x_q_pn,
             y_i_out    => y_i_pn,
             y_q_out    => y_q_pn,
             bits_x_out => bits_x_pn,
             bits_y_out => bits_y_pn,
             valid_out  => valid_pn);

  pmd_inst : component pmd
    generic map (WIDTH         => WIDTH,
                 BITS          => BITS,
                 SECTIONS_N    => PMD_SECTIONS_N,
                 THETA_WIDTH   => PMD_THETA_WIDTH,
                 COUNTER_WIDTH => PMD_COUNTER_WIDTH,
                 TAP_WIDTH     => PMD_TAP_WIDTH,
                 TAPS_N        => PMD_TAPS_N,
                 PHI_WIDTH     => PMD_PHI_WIDTH)
    port map (clk         => clk,
              rst         => rst,
              x_i_in      => x_i_pn,
              x_q_in      => x_q_pn,
              y_i_in      => y_i_pn,
              y_q_in      => y_q_pn,
              bits_x_in   => bits_x_pn,
              bits_y_in   => bits_y_pn,
              valid_in    => valid_pn,
              theta_start => pmd_theta_start,
              count_max   => pmd_count_max,
              direction   => pmd_direction,
              taps        => pmd_taps,
              phi         => pmd_phi,
              x_i_out     => x_i_pmd,
              x_q_out     => x_q_pmd,
              y_i_out     => y_i_pmd,
              y_q_out     => y_q_pmd,
              bits_x_out  => bits_x_pmd,
              bits_y_out  => bits_y_pmd,
              valid_out   => valid_pmd);

  x_i_out    <= x_i_pmd;
  x_q_out    <= x_q_pmd;
  y_i_out    <= y_i_pmd;
  y_q_out    <= y_q_pmd;
  bits_x_out <= bits_x_pmd;
  bits_y_out <= bits_y_pmd;
  valid_out  <= valid_pmd;

end architecture arch;
