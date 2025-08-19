-------------------------------------------------------------------------------
-- Title      : Dual Polarization System 
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : system.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2022-03-21
-- Last update: 2022-03-03
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- Description of the complete fiber-optic system including transmitter,
-- channel and receiver.
--
-------------------------------------------------------------------------------
-- Copyright (c) 2022 Erik Börjeson
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2022-03-01  1.0      erikbor Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity system is
  generic (WIDTH             : positive              := 8;
           MAX_AMP           : real range 0.0 to 1.0 := 0.5;
           MOD_TYPE          : string                := "QPSK";
           MOD_BITS          : positive              := 2;
           RRC_TAP_WIDTH     : positive              := 12;
           PN_PHASE_WIDTH    : positive              := 16;
           PN_LUT_WIDTH      : positive              := 16;
           PMD_SECTIONS_N    : positive              := 10;
           PMD_THETA_WIDTH   : positive              := 10;
           PMD_COUNTER_WIDTH : positive              := 32;
           PMD_TAP_WIDTH     : positive              := 10;
           PMD_TAPS_N        : positive              := 5;
           PMD_PHI_WIDTH     : positive              := 10);
  port (clk             : in  std_logic;
        rst             : in  std_logic;
        awgn_scaling    : in  std_logic_vector(15 downto 0);
        pn_scaling      : in  std_logic_vector(15 downto 0);
        pmd_theta_start : in  std_logic_vector((PMD_SECTIONS_N+1)*PMD_THETA_WIDTH-1 downto 0);
        pmd_count_max   : in  std_logic_vector((PMD_SECTIONS_N+1)*PMD_COUNTER_WIDTH-1 downto 0);
        pmd_direction   : in  std_logic_vector(PMD_SECTIONS_N downto 0);
        pmd_taps        : in  std_logic_vector(PMD_TAPS_N*PMD_TAP_WIDTH-1 downto 0);
        pmd_phi         : in  std_logic_vector(PMD_SECTIONS_N*PMD_PHI_WIDTH-1 downto 0);
        bits_x_demod    : out std_logic_vector(MOD_BITS-1 downto 0);
        bits_y_demod    : out std_logic_vector(MOD_BITS-1 downto 0);
        bits_x_ref      : out std_logic_vector(MOD_BITS-1 downto 0);
        bits_y_ref      : out std_logic_vector(MOD_BITS-1 downto 0);
        valid_out       : out std_logic);
end entity system;

architecture arch of system is

  constant BITS : positive := MOD_BITS;

  component transmitter is
    generic (WIDTH         : positive;
             MAX_AMP       : real range 0.0 to 1.0;
             MOD_TYPE      : string;
             MOD_BITS      : positive;
             RRC_TAP_WIDTH : positive);
    port (clk        : in  std_logic;
          rst        : in  std_logic;
          x_i_out    : out std_logic_vector(2*WIDTH-1 downto 0);
          x_q_out    : out std_logic_vector(2*WIDTH-1 downto 0);
          y_i_out    : out std_logic_vector(2*WIDTH-1 downto 0);
          y_q_out    : out std_logic_vector(2*WIDTH-1 downto 0);
          bits_x_out : out std_logic_vector(MOD_BITS-1 downto 0);
          bits_y_out : out std_logic_vector(MOD_BITS-1 downto 0);
          valid_out  : out std_logic);
  end component transmitter;

  component channel is
    generic (WIDTH             : positive;
             BITS              : positive;
             PN_PHASE_WIDTH    : positive;
             PN_LUT_WIDTH      : positive;
             PMD_SECTIONS_N    : positive;
             PMD_THETA_WIDTH   : positive;
             PMD_COUNTER_WIDTH : positive;
             PMD_TAP_WIDTH     : positive;
             PMD_TAPS_N        : positive;
             PMD_PHI_WIDTH     : positive);
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
  end component channel;

  component receiver is
    generic (WIDTH    : positive;
             MOD_BITS : positive;
             MOD_TYPE : string;
             MAX_AMP  : real range 0.0 to 1.0);
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
  end component receiver;

  signal x_i_tx    : std_logic_vector(2*WIDTH-1 downto 0);
  signal x_q_tx    : std_logic_vector(2*WIDTH-1 downto 0);
  signal y_i_tx    : std_logic_vector(2*WIDTH-1 downto 0);
  signal y_q_tx    : std_logic_vector(2*WIDTH-1 downto 0);
  signal bits_x_tx : std_logic_vector(MOD_BITS-1 downto 0);
  signal bits_y_tx : std_logic_vector(MOD_BITS-1 downto 0);
  signal valid_tx  : std_logic;

  signal x_i_ch    : std_logic_vector(2*WIDTH-1 downto 0);
  signal x_q_ch    : std_logic_vector(2*WIDTH-1 downto 0);
  signal y_i_ch    : std_logic_vector(2*WIDTH-1 downto 0);
  signal y_q_ch    : std_logic_vector(2*WIDTH-1 downto 0);
  signal bits_x_ch : std_logic_vector(MOD_BITS-1 downto 0);
  signal bits_y_ch : std_logic_vector(MOD_BITS-1 downto 0);
  signal valid_ch  : std_logic;

begin

  transmitter_inst : component transmitter
    generic map (WIDTH         => WIDTH,
                 MAX_AMP       => MAX_AMP,
                 MOD_TYPE      => MOD_TYPE,
                 MOD_BITS      => MOD_BITS,
                 RRC_TAP_WIDTH => RRC_TAP_WIDTH)
    port map (clk        => clk,
              rst        => rst,
              x_i_out    => x_i_tx,
              x_q_out    => x_q_tx,
              y_i_out    => y_i_tx,
              y_q_out    => y_q_tx,
              bits_x_out => bits_x_tx,
              bits_y_out => bits_y_tx,
              valid_out  => valid_tx);

  channel_inst : component channel
    generic map (WIDTH             => WIDTH,
                 BITS              => BITS,
                 PN_PHASE_WIDTH    => PN_PHASE_WIDTH,
                 PN_LUT_WIDTH      => PN_LUT_WIDTH,
                 PMD_SECTIONS_N    => PMD_SECTIONS_N,
                 PMD_THETA_WIDTH   => PMD_THETA_WIDTH,
                 PMD_COUNTER_WIDTH => PMD_COUNTER_WIDTH,
                 PMD_TAP_WIDTH     => PMD_TAP_WIDTH,
                 PMD_TAPS_N        => PMD_TAPS_N,
                 PMD_PHI_WIDTH     => PMD_PHI_WIDTH)
    port map (clk             => clk,
              rst             => rst,
              x_i_in          => x_i_tx,
              x_q_in          => x_q_tx,
              y_i_in          => y_i_tx,
              y_q_in          => y_q_tx,
              bits_x_in       => bits_x_tx,
              bits_y_in       => bits_y_tx,
              valid_in        => valid_tx,
              awgn_scaling    => awgn_scaling,
              pn_scaling      => pn_scaling,
              pmd_theta_start => pmd_theta_start,
              pmd_count_max   => pmd_count_max,
              pmd_direction   => pmd_direction,
              pmd_taps        => pmd_taps,
              pmd_phi         => pmd_phi,
              x_i_out         => x_i_ch,
              x_q_out         => x_q_ch,
              y_i_out         => y_i_ch,
              y_q_out         => y_q_ch,
              bits_x_out      => bits_x_ch,
              bits_y_out      => bits_y_ch,
              valid_out       => valid_ch);

  receiver_inst : component receiver
    generic map (WIDTH    => WIDTH,
                 MOD_BITS => MOD_BITS,
                 MOD_TYPE => MOD_TYPE,
                 MAX_AMP  => MAX_AMP)
    port map (clk         => clk,
              rst         => rst,
              x_i_in      => x_i_ch,
              x_q_in      => x_q_ch,
              y_i_in      => y_i_ch,
              y_q_in      => y_q_ch,
              bits_x_in   => bits_x_ch,
              bits_y_in   => bits_y_ch,
              valid_in    => valid_ch,
              demod_x_out => bits_x_demod,
              demod_y_out => bits_y_demod,
              bits_x_out  => bits_x_ref,
              bits_y_out  => bits_y_ref,
              valid_out   => valid_out);

end architecture arch;
