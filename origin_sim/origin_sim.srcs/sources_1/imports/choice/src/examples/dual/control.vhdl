-------------------------------------------------------------------------------
-- Title      : Emulator Controller
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : control.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2022-02-28
-- Last update: 2022-03-03
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- This file is the top-level of the controller sub-system. It utilizes UART to
-- control the emulator from the outside world. The different commands are
-- defined in communication.vhdl.
--
-------------------------------------------------------------------------------
-- Copyright (c) 2022
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2022-02-28  1.0      erikbor Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity control is
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
end entity control;


architecture arch of control is

  component uart is
    generic(CLK_FREQ : positive;
            BAUDRATE : positive);
    port (clk          : in  std_logic;
          rst          : in  std_logic;
          uart_rx      : in  std_logic;
          uart_tx      : out std_logic;
          host_rx_data : out std_logic_vector(7 downto 0);
          host_rx_vld  : out std_logic;
          host_tx_data : in  std_logic_vector(7 downto 0);
          host_tx_req  : in  std_logic;
          host_tx_rdy  : out std_logic);
  end component uart;

  component communication is
    generic (REC_WIDTH : positive;
             REC_DEPTH : positive);
    port (clk           : in  std_logic;
          rst           : in  std_logic;
          rx_data       : in  std_logic_vector(7 downto 0);
          rx_vld        : in  std_logic;
          tx_data       : out std_logic_vector(7 downto 0);
          tx_req        : out std_logic;
          tx_rdy        : in  std_logic;
          rst_emu       : out std_logic;
          store_results : out std_logic;
          params_en     : out std_logic;
          params_addr   : out std_logic_vector(7 downto 0);
          params_data   : out std_logic_vector(7 downto 0);
          results_addr  : out std_logic_vector(7 downto 0);
          results_data  : in  std_logic_vector(7 downto 0);
          rec_addr      : out std_logic_vector(integer(ceil(log2(real(REC_DEPTH))))-1 downto 0);
          rec_data      : in  std_logic_vector(REC_WIDTH-1 downto 0));
  end component communication;

  component memory_params is
    generic (PMD_SECTIONS_N    : positive;
             PMD_THETA_WIDTH   : positive;
             PMD_COUNTER_WIDTH : positive;
             PMD_TAP_WIDTH     : positive;
             PMD_TAPS_N        : positive;
             PMD_PHI_WIDTH     : positive);
    port (clk             : in  std_logic;
          rst             : in  std_logic;
          rst_emu         : in  std_logic;
          enable          : in  std_logic;
          addr            : in  std_logic_vector(7 downto 0);
          data_in         : in  std_logic_vector(7 downto 0);
          pn_scaling      : out std_logic_vector(15 downto 0);
          awgn_scaling    : out std_logic_vector(15 downto 0);
          pmd_theta_start : out std_logic_vector((PMD_SECTIONS_N+1)*PMD_THETA_WIDTH-1 downto 0);
          pmd_count_max   : out std_logic_vector((PMD_SECTIONS_N+1)*PMD_COUNTER_WIDTH-1 downto 0);
          pmd_direction   : out std_logic_vector(PMD_SECTIONS_N downto 0);
          pmd_taps        : out std_logic_vector(PMD_TAPS_N*PMD_TAP_WIDTH-1 downto 0);
          pmd_phi         : out std_logic_vector(PMD_SECTIONS_N*PMD_PHI_WIDTH-1 downto 0));
  end component memory_params;

  component memory_results is
    port (clk           : in  std_logic;
          rst           : in  std_logic;
          store_results : in  std_logic;
          addr          : in  std_logic_vector(7 downto 0);
          rec_done      : in  std_logic;
          bits_cnt      : in  std_logic_vector(63 downto 0);
          errors_cnt    : in  std_logic_vector(63 downto 0);
          data_out      : out std_logic_vector(7 downto 0));
  end component memory_results;

  signal rst_emu_int   : std_logic;
  signal store_results : std_logic;
  signal params_en     : std_logic;
  signal params_addr   : std_logic_vector(7 downto 0);
  signal params_data   : std_logic_vector(7 downto 0);
  signal results_addr  : std_logic_vector(7 downto 0);
  signal results_data  : std_logic_vector(7 downto 0);
  signal flags         : std_logic_vector(7 downto 0);
  signal rx_data       : std_logic_vector(7 downto 0);
  signal rx_vld        : std_logic;
  signal tx_data       : std_logic_vector(7 downto 0);
  signal tx_req        : std_logic;
  signal tx_rdy        : std_logic;

begin

  rst_emu <= rst_emu_int;

  uart_inst : component uart
    generic map (CLK_FREQ => CLK_FREQ,
                 BAUDRATE => BAUDRATE)
    port map (clk          => clk,
              rst          => rst,
              uart_rx      => rx,
              uart_tx      => tx,
              host_rx_data => rx_data,
              host_rx_vld  => rx_vld,
              host_tx_data => tx_data,
              host_tx_req  => tx_req,
              host_tx_rdy  => tx_rdy);

  communication_inst : component communication
    generic map (REC_WIDTH => REC_WIDTH,
                 REC_DEPTH => REC_DEPTH)
    port map (clk           => clk,
              rst           => rst,
              rx_data       => rx_data,
              rx_vld        => rx_vld,
              tx_data       => tx_data,
              tx_req        => tx_req,
              tx_rdy        => tx_rdy,
              rst_emu       => rst_emu_int,
              store_results => store_results,
              params_en     => params_en,
              params_addr   => params_addr,
              params_data   => params_data,
              results_addr  => results_addr,
              results_data  => results_data,
              rec_addr      => rec_addr,
              rec_data      => rec_data);

  memory_params_inst : component memory_params
    generic map (PMD_SECTIONS_N    => PMD_SECTIONS_N,
                 PMD_THETA_WIDTH   => PMD_THETA_WIDTH,
                 PMD_COUNTER_WIDTH => PMD_COUNTER_WIDTH,
                 PMD_TAP_WIDTH     => PMD_TAP_WIDTH,
                 PMD_TAPS_N        => PMD_TAPS_N,
                 PMD_PHI_WIDTH     => PMD_PHI_WIDTH)
    port map (clk             => clk,
              rst             => rst,
              rst_emu         => rst_emu_int,
              enable          => params_en,
              addr            => params_addr,
              data_in         => params_data,
              pn_scaling      => pn_scaling,
              awgn_scaling    => awgn_scaling,
              pmd_theta_start => pmd_theta_start,
              pmd_count_max   => pmd_count_max,
              pmd_direction   => pmd_direction,
              pmd_taps        => pmd_taps,
              pmd_phi         => pmd_phi);

  memory_results_ints : component memory_results
    port map (clk           => clk,
              rst           => rst,
              store_results => store_results,
              addr          => results_addr,
              rec_done      => rec_done,
              bits_cnt      => bits_cnt,
              errors_cnt    => errors_cnt,
              data_out      => results_data);

end architecture arch;
