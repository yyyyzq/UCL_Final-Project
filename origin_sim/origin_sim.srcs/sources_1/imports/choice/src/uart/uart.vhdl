-------------------------------------------------------------------------------
-- Title      : UART Controller
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : uart.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2019-07-04
-- Last update: 2022-02-24
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- UART Controller that can be used with the CHOICE system. Set system clock
-- frequency and the UART baudrate with the generics. 
--
-- To send data, check that the host_tx_rdy flag is '0' and set host_tx_data
-- to the data you want to send. Set host_tx_req to '1' for one clock cycle.
-- The controller will set hos_tx_rdy to '0' until the transmission is 
-- finished.
--
---The receiver sets host_rx_rdy to '1' for one clock cycle when there is new
-- data available on the host_rx_data port.
--
-------------------------------------------------------------------------------
-- Copyright (c) 2019 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-07-04  1.0      erikbor Created
-- 2020-09-01  2.0      erikbor Rewrite
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity uart is
  generic(CLK_FREQ  : positive := 100e6;
          BAUDRATE : positive := 9600);
  port (clk          : in  std_logic;
        rst          : in  std_logic;
        uart_rx      : in  std_logic;
        uart_tx      : out std_logic;
        host_rx_data : out std_logic_vector(7 downto 0);
        host_rx_vld  : out std_logic;
        host_tx_data : in  std_logic_vector(7 downto 0);
        host_tx_req  : in  std_logic;
        host_tx_rdy  : out std_logic);
end entity uart;

architecture arch of uart is

  -- Constant declarations
  constant CLK_DIV : positive := CLK_FREQ/BAUDRATE/16;

  -- Component declarations
  component tx is
    port (clk          : in  std_logic;
          clk_en       : in  std_logic;
          rst          : in  std_logic;
          uart_tx      : out std_logic;
          host_tx_data : in  std_logic_vector;
          host_tx_req  : in  std_logic;
          host_tx_rdy  : out std_logic);
  end component tx;

  component rx is
    port (clk          : in  std_logic;
          clk_en       : in  std_logic;
          rst          : in  std_logic;
          uart_rx      : in  std_logic;
          host_rx_data : out std_logic_vector(7 downto 0);
          host_rx_vld  : out std_logic);
  end component rx;

  -- Signal declarations
  signal clk_en     : std_logic;
  signal clk_en_cnt : integer range 0 to CLK_DIV-1;

begin

  -- Clock enable generator, 16 cycles per bit
  clk_en_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        clk_en     <= '0';
        clk_en_cnt <= 0;
      else
        if clk_en_cnt = CLK_DIV-1 then
          clk_en     <= '1';
          clk_en_cnt <= 0;
        else
          clk_en     <= '0';
          clk_en_cnt <= clk_en_cnt + 1;
        end if;
      end if;
    end if;
  end process clk_en_proc;


  tx_inst : tx
    port map(clk          => clk,
             clk_en       => clk_en,
             rst          => rst,
             uart_tx      => uart_tx,
             host_tx_data => host_tx_data,
             host_tx_req  => host_tx_req,
             host_tx_rdy  => host_tx_rdy);

  rx_inst : rx
    port map (clk          => clk,
              clk_en       => clk_en,
              rst          => rst,
              uart_rx      => uart_rx,
              host_rx_data => host_rx_data,
              host_rx_vld  => host_rx_vld);



end architecture arch;

