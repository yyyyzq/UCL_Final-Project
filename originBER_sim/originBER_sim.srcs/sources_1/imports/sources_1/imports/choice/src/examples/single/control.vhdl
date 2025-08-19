-------------------------------------------------------------------------------
-- Title      : Emulator Controller
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : control.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2022-02-28
-- Last update: 2022-02-28
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
  generic (CLK_FREQ  : positive := 100e6;
           BAUDRATE  : positive := 115200;
           REC_WIDTH : positive := 8;
           REC_DEPTH : positive := 32);
  port (clk          : in  std_logic;
        rst          : in  std_logic;
        rx           : in  std_logic;
        tx           : out std_logic;
        rst_emu      : out std_logic;
        bits_cnt     : in  std_logic_vector(63 downto 0);
        errors_cnt   : in  std_logic_vector(63 downto 0);
        pn_scaling   : out std_logic_vector(15 downto 0);
        awgn_scaling : out std_logic_vector(15 downto 0);
        rec_addr     : out std_logic_vector(integer(ceil(log2(real(REC_DEPTH))))-1 downto 0);
        rec_data     : in  std_logic_vector(REC_WIDTH-1 downto 0);
        rec_done     : in  std_logic);
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
    port (clk          : in  std_logic;
          rst          : in  std_logic;
          rst_emu      : in  std_logic;
          enable       : in  std_logic;
          addr         : in  std_logic_vector(7 downto 0);
          data_in      : in  std_logic_vector(7 downto 0);
          pn_scaling   : out std_logic_vector(15 downto 0);
          awgn_scaling : out std_logic_vector(15 downto 0));
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
    port map (clk          => clk,
              rst          => rst,
              rst_emu      => rst_emu_int,
              enable       => params_en,
              addr         => params_addr,
              data_in      => params_data,
              pn_scaling   => pn_scaling,
              awgn_scaling => awgn_scaling);

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
