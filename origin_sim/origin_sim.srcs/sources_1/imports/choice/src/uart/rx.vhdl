-------------------------------------------------------------------------------
-- Title      : UART RX Component
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : rx.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2019-07-04
-- Last update: 2020-09-01
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- RX component for the UART controller.
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

entity rx is
  port (clk          : in  std_logic;
        clk_en       : in  std_logic;
        rst          : in  std_logic;
        uart_rx      : in  std_logic;
        host_rx_data : out std_logic_vector(7 downto 0);
        host_rx_vld  : out std_logic);
end entity rx;

architecture arch of rx is

  -- Type declarations
  type state_type is (idle, startbit, databits, stopbit);

  -- Signal declarations
  signal current_state : state_type;
  signal next_state    : state_type;
  signal clk_rx_en     : std_logic;
  signal clk_rx_en_cnt : integer range 0 to 15;
  signal clk_rx_en_clr : std_logic;
  signal bit_cnt       : integer range 0 to 7;
  signal bit_cnt_en    : std_logic;
  signal rx_data       : std_logic_vector(7 downto 0);
  signal rx_vld        : std_logic;

begin

  -- Readable output signals
  host_rx_data <= rx_data;
  host_rx_vld  <= rx_vld and clk_rx_en;

  -- Generate rx clock enable, divide top-level enable by 16.
  clk_rx_en_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        clk_rx_en     <= '0';
        clk_rx_en_cnt <= 8;
      else
        if clk_rx_en_clr = '0' then
          if clk_en = '1' then
            if clk_rx_en_cnt = 15 then
              clk_rx_en     <= '1';
              clk_rx_en_cnt <= 0;
            else
              clk_rx_en     <= '0';
              clk_rx_en_cnt <= clk_rx_en_cnt + 1;
            end if;
          else
            clk_rx_en <= '0';
          end if;
        else
          clk_rx_en     <= '0';
          clk_rx_en_cnt <= 8;
        end if;
      end if;
    end if;
  end process clk_rx_en_proc;

  -- RX Shift register
  rx_data_reg_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        rx_data <= (others => '0');
      else
        if clk_rx_en = '1' and bit_cnt_en = '1' then
          rx_data <= uart_rx & rx_data(7 downto 1);
        end if;
      end if;
    end if;
  end process rx_data_reg_proc;

  -- Bit position counter
  bit_cnt_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        bit_cnt <= 0;
      else
        if bit_cnt_en = '1' and clk_rx_en = '1' then
          if bit_cnt = 7 then
            bit_cnt <= 0;
          else
            bit_cnt <= bit_cnt + 1;
          end if;
        end if;
      end if;
    end if;
  end process bit_cnt_proc;

  -- FSM control for state change
  fsm_state_change_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        current_state <= idle;
      else  
        current_state <= next_state;
      end if;
    end if;
  end process fsm_state_change_proc;

  -- FSM control for outputs and next stage 
  fsm_output_proc : process (current_state, uart_rx, clk_rx_en, bit_cnt)
  begin
    case current_state is
      when idle =>
        clk_rx_en_clr <= '1';
        bit_cnt_en    <= '0';
        rx_vld        <= '0';
        if uart_rx = '0' then
          next_state <= startbit;
        else
          next_state <= idle;
        end if;

      when startbit =>
        clk_rx_en_clr <= '0';
        bit_cnt_en    <= '0';
        rx_vld        <= '0';
        if clk_rx_en = '1' then
          next_state <= databits;
        else
          next_state <= startbit;
        end if;

      when databits =>
        clk_rx_en_clr <= '0';
        bit_cnt_en    <= '1';
        rx_vld        <= '0';
        if clk_rx_en = '1' and bit_cnt = 7 then
          next_state <= stopbit;
        else
          next_state <= databits;
        end if;

      when stopbit =>
        clk_rx_en_clr <= '0';
        bit_cnt_en    <= '0';
        rx_vld        <= '1';
        if clk_rx_en = '1' then
          next_state <= idle;
        else
          next_state <= stopbit;
        end if;

      when others =>
        clk_rx_en_clr <= '1';
        bit_cnt_en    <= '0';
        rx_vld        <= '0';
        next_state    <= idle;
    end case;
  end process fsm_output_proc;

end architecture arch;

