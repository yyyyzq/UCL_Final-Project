-------------------------------------------------------------------------------
-- Title      : Top-Level Component for a Single Polarization System 
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : top.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2022-03-02
-- Last update: 2022-03-03
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-------------------------------------------------------------------------------
-- Copyright (c) 2022 Erik Börjeson
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2022-03-02  1.0      erikbor Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity top is
  port (clk  : in  std_logic;
        arst : in  std_logic;
        rx   : in  std_logic;
        tx   : out std_logic);
end entity top;

architecture arch of top is

  -- Settings
  constant CLK_FREQ          : positive              := 100e6;
  constant BAUDRATE          : positive              := 115200;
  constant REC_WIDTH         : positive              := 8;
  constant REC_DEPTH         : positive              := 32;
  constant WIDTH             : positive              := 8;
  constant MAX_AMP           : real range 0.0 to 1.0 := 0.5;
  constant MOD_TYPE          : string                := "QPSK";
  constant MOD_BITS          : positive              := 2;
  constant RRC_TAP_WIDTH     : positive              := 12;
  constant PN_PHASE_WIDTH    : positive              := 16;
  constant PN_LUT_WIDTH      : positive              := 16;
  constant PMD_SECTIONS_N    : positive              := 10;
  constant PMD_THETA_WIDTH   : positive              := 10;
  constant PMD_COUNTER_WIDTH : positive              := 32;
  constant PMD_TAP_WIDTH     : positive              := 10;
  constant PMD_TAPS_N        : positive              := 5;
  constant PMD_PHI_WIDTH     : positive              := 10;

  component reset_sync is
    port (clk  : in  std_logic;
          arst : in  std_logic;
          rst  : out std_logic);
  end component reset_sync;

  component control is
    generic (CLK_FREQ          : positive := 100e6;
             BAUDRATE          : positive := 115200;
             PMD_SECTIONS_N    : positive := 10;
             PMD_THETA_WIDTH   : positive := 10;
             PMD_COUNTER_WIDTH : positive := 32;
             PMD_TAP_WIDTH     : positive := 10;
             PMD_TAPS_N        : positive := 5;
             PMD_PHI_WIDTH     : positive := 10;
             REC_WIDTH         : positive := 8;
             REC_DEPTH         : positive := 32);
    port (clk             : in  std_logic;
          rst             : in  std_logic;
          rx              : in  std_logic;
          tx              : out std_logic;
          rst_emu         : out std_logic;
          bits_cnt        : in  std_logic_vector(63 downto 0);
          errors_cnt      : in  std_logic_vector(63 downto 0);
          pn_scaling      : out std_logic_vector(15 downto 0);
          awgn_scaling    : out std_logic_vector(15 downto 0);
          pmd_theta_start : out std_logic_vector((PMD_SECTIONS_N+1)*PMD_THETA_WIDTH-1 downto 0);
          pmd_count_max   : out std_logic_vector((PMD_SECTIONS_N+1)*PMD_COUNTER_WIDTH-1 downto 0);
          pmd_direction   : out std_logic_vector(PMD_SECTIONS_N downto 0);
          pmd_taps        : out std_logic_vector(PMD_TAPS_N*PMD_TAP_WIDTH-1 downto 0);
          pmd_phi         : out std_logic_vector(PMD_SECTIONS_N*PMD_PHI_WIDTH-1 downto 0);
          rec_addr        : out std_logic_vector(integer(ceil(log2(real(REC_DEPTH))))-1 downto 0);
          rec_data        : in  std_logic_vector(REC_WIDTH-1 downto 0);
          rec_done        : in  std_logic);
  end component control;

  component system is
    generic (WIDTH             : positive;
             MAX_AMP           : real range 0.0 to 1.0;
             MOD_TYPE          : string;
             MOD_BITS          : positive;
             RRC_TAP_WIDTH     : positive;
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
  end component system;

  component analysis is
    generic (BITS             : positive;
             BITS_CNT_WIDTH   : positive;
             ERRORS_CNT_WIDTH : positive);
    port (clk          : in  std_logic;
          rst          : in  std_logic;
          bits_x_demod : in  std_logic_vector(BITS-1 downto 0);
          bits_y_demod : in  std_logic_vector(BITS-1 downto 0);
          bits_x_ref   : in  std_logic_vector(BITS-1 downto 0);
          bits_y_ref   : in  std_logic_vector(BITS-1 downto 0);
          valid_in     : in  std_logic;
          bits_cnt     : out std_logic_vector(BITS_CNT_WIDTH-1 downto 0);
          errors_cnt   : out std_logic_vector(ERRORS_CNT_WIDTH-1 downto 0));
  end component analysis;

  signal rst             : std_logic;
  signal rst_emu         : std_logic;
  signal bits_cnt        : std_logic_vector(63 downto 0);
  signal errors_cnt      : std_logic_vector(63 downto 0);
  signal pn_scaling      : std_logic_vector(15 downto 0);
  signal awgn_scaling    : std_logic_vector(15 downto 0);
  signal pmd_theta_start : std_logic_vector((PMD_SECTIONS_N+1)*PMD_THETA_WIDTH-1 downto 0);
  signal pmd_count_max   : std_logic_vector((PMD_SECTIONS_N+1)*PMD_COUNTER_WIDTH-1 downto 0);
  signal pmd_direction   : std_logic_vector(PMD_SECTIONS_N downto 0);
  signal pmd_taps        : std_logic_vector(PMD_TAPS_N*PMD_TAP_WIDTH-1 downto 0);
  signal pmd_phi         : std_logic_vector(PMD_SECTIONS_N*PMD_PHI_WIDTH-1 downto 0);
  signal bits_x_demod    : std_logic_vector(MOD_BITS-1 downto 0);
  signal bits_y_demod    : std_logic_vector(MOD_BITS-1 downto 0);
  signal bits_x_ref      : std_logic_vector(MOD_BITS-1 downto 0);
  signal bits_y_ref      : std_logic_vector(MOD_BITS-1 downto 0);
  signal valid_bits      : std_logic;

begin

  reset_sync_inst : component reset_sync
    port map (clk  => clk,
              arst => arst,
              rst  => rst);

  control_inst : component control
    generic map (CLK_FREQ          => CLK_FREQ,
                 BAUDRATE          => BAUDRATE,
                 PMD_SECTIONS_N    => PMD_SECTIONS_N,
                 PMD_THETA_WIDTH   => PMD_THETA_WIDTH,
                 PMD_COUNTER_WIDTH => PMD_COUNTER_WIDTH,
                 PMD_TAP_WIDTH     => PMD_TAP_WIDTH,
                 PMD_TAPS_N        => PMD_TAPS_N,
                 PMD_PHI_WIDTH     => PMD_PHI_WIDTH,
                 REC_WIDTH         => REC_WIDTH,
                 REC_DEPTH         => REC_DEPTH)
    port map (clk             => clk,
              rst             => rst,
              rx              => rx,
              tx              => tx,
              rst_emu         => rst_emu,
              bits_cnt        => bits_cnt,
              errors_cnt      => errors_cnt,
              pn_scaling      => pn_scaling,
              awgn_scaling    => awgn_scaling,
              pmd_theta_start => pmd_theta_start,
              pmd_count_max   => pmd_count_max,
              pmd_direction   => pmd_direction,
              pmd_taps        => pmd_taps,
              pmd_phi         => pmd_phi,
              rec_addr        => open,
              rec_data        => (others => '0'),
              rec_done        => '0');

  system_inst : component system
    generic map (WIDTH             => WIDTH,
                 MAX_AMP           => MAX_AMP,
                 MOD_TYPE          => MOD_TYPE,
                 MOD_BITS          => MOD_BITS,
                 RRC_TAP_WIDTH     => RRC_TAP_WIDTH,
                 PN_PHASE_WIDTH    => PN_PHASE_WIDTH,
                 PN_LUT_WIDTH      => PN_LUT_WIDTH,
                 PMD_SECTIONS_N    => PMD_SECTIONS_N,
                 PMD_THETA_WIDTH   => PMD_THETA_WIDTH,
                 PMD_COUNTER_WIDTH => PMD_COUNTER_WIDTH,
                 PMD_TAP_WIDTH     => PMD_TAP_WIDTH,
                 PMD_TAPS_N        => PMD_TAPS_N,
                 PMD_PHI_WIDTH     => PMD_PHI_WIDTH)
    port map (clk             => clk,
              rst             => rst_emu,
              awgn_scaling    => awgn_scaling,
              pn_scaling      => pn_scaling,
              pmd_theta_start => pmd_theta_start,
              pmd_count_max   => pmd_count_max,
              pmd_direction   => pmd_direction,
              pmd_taps        => pmd_taps,
              pmd_phi         => pmd_phi,
              bits_x_demod    => bits_x_demod,
              bits_y_demod    => bits_y_demod,
              bits_x_ref      => bits_x_ref,
              bits_y_ref      => bits_y_ref,
              valid_out       => valid_bits);

  analysis_int : component analysis
    generic map (BITS             => MOD_BITS,
                 BITS_CNT_WIDTH   => 64,
                 ERRORS_CNT_WIDTH => 64)
    port map (clk          => clk,
              rst          => rst_emu,
              bits_x_demod => bits_x_demod,
              bits_y_demod => bits_y_demod,
              bits_x_ref   => bits_x_ref,
              bits_y_ref   => bits_y_ref,
              valid_in     => valid_bits,
              bits_cnt     => bits_cnt,
              errors_cnt   => errors_cnt);

end architecture arch;
