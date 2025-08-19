-------------------------------------------------------------------------------
-- Title      : UART TX Component
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : tx.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2019-07-04
-- Last update: 2020-09-01
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- TX component for the UART controller.
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

entity tx is
  port (clk          : in  std_logic;
        clk_en       : in  std_logic;
        rst          : in  std_logic;
        uart_tx      : out std_logic;
        host_tx_data : in  std_logic_vector(7 downto 0);
        host_tx_req  : in  std_logic;
        host_tx_rdy  : out std_logic);
end entity tx;

architecture arch of tx is

  -- Type declarations
  type state_type is (idle, sync, startbit, databits, stopbit);

  -- Signal declarations
  signal current_state : state_type;
  signal next_state    : state_type;
  signal clk_tx_en     : std_logic;
  signal clk_tx_en_cnt : integer range 0 to 15;
  signal clk_tx_en_clr : std_logic;
  signal bit_cnt       : integer range 0 to 7;
  signal bit_cnt_en    : std_logic;
  signal tx_data_reg : std_logic_vector(7 downto 0);
  signal tx_rdy : std_logic;
begin

  -- Readable output signals
  host_tx_rdy <= tx_rdy;

  -- Generate clock enable, divide top-level enable by 16.
  clk_tx_en_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        clk_tx_en     <= '0';
        clk_tx_en_cnt <= 0;
      else    
        if clk_tx_en_clr = '0' then
          if clk_en = '1' then
            if clk_tx_en_cnt = 15 then
              clk_tx_en     <= '1';
              clk_tx_en_cnt <= 0;
            else
              clk_tx_en     <= '0';
              clk_tx_en_cnt <= clk_tx_en_cnt + 1;
            end if;
          else
            clk_tx_en <= '0';
          end if;
        else
          clk_tx_en     <= '0';
          clk_tx_en_cnt <= 0;
        end if;
      end if;
    end if;
  end process clk_tx_en_proc;

  -- Bit position counter
  bit_cnt_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        bit_cnt <= 0;
      else
        if bit_cnt_en = '1' and clk_tx_en = '1' then
          if bit_cnt = 7 then
            bit_cnt <= 0;
          else
            bit_cnt <= bit_cnt + 1;
          end if;
        end if;
      end if;
    end if;
  end process bit_cnt_proc;

  -- Host data register
  tx_data_reg_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        tx_data_reg <= (others => '0');
      else
        if host_tx_req = '1' and tx_rdy = '1' then
          tx_data_reg <= host_tx_data;
        end if;
      end if;
    end if;
  end process tx_data_reg_proc;

  -- UART TX register
  uart_tx_reg_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        uart_tx <= '1';
      else
        if current_state = startbit then
          uart_tx <= '0';
        elsif current_state = databits then
          uart_tx <= tx_data_reg(bit_cnt);
        else
          uart_tx <= '1';
        end if;
      end if;
    end if;
  end process uart_tx_reg_proc;


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
  fsm_output_proc : process (current_state, host_tx_req, clk_tx_en, bit_cnt)
  begin
    case current_state is

      when idle =>
        tx_rdy        <= '1';
        clk_tx_en_clr <= '1';
        bit_cnt_en    <= '0';
        if host_tx_req = '1' then
          next_state <= sync;
        else
          next_state <= idle;
        end if;

      when sync =>
        tx_rdy        <= '0';
        clk_tx_en_clr <= '0';
        bit_cnt_en    <= '0';
        if clk_tx_en = '1' then
          next_state <= startbit;
        else
          next_state <= sync;
        end if;

      when startbit =>
        tx_rdy        <= '0';
        clk_tx_en_clr <= '0';
        bit_cnt_en    <= '0';
        if clk_tx_en = '1' then
          next_state <= databits;
        else
          next_state <= startbit;
        end if;

      when databits =>
        tx_rdy        <= '0';
        clk_tx_en_clr <= '0';
        bit_cnt_en    <= '1';
        if clk_tx_en = '1' and bit_cnt = 7 then
          next_state <= stopbit;
        else
          next_state <= databits;
        end if;

      when stopbit =>
        tx_rdy        <= '1';
        clk_tx_en_clr <= '0';
        bit_cnt_en    <= '0';
        if host_tx_req = '1' then
          next_state <= sync;
        elsif clk_tx_en = '1' then
          next_state <= idle;
        else
          next_state <= stopbit;
        end if;

      when others =>
        tx_rdy        <= '0';
        clk_tx_en_clr <= '1';
        bit_cnt_en    <= '0';
        next_state    <= idle;
        
    end case;
  end process fsm_output_proc;

end architecture arch;

