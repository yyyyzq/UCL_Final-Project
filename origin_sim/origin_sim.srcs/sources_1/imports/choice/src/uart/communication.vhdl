-------------------------------------------------------------------------------
-- Title      : Communication FSM
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : communication.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2019-07-05
-- Last update: 2022-03-03
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- This file contains an example of how to utilize the UART controller to send
-- and receive data from the CHOICE environment. It defines five commands:
--
-- Reset          - 0x00
--                  The rst_emu signal will be asserted for one clock cycle.
-- Store results  - 0x01
--                  The current reults will be captured in the results memory.
-- Get results    - 0x02 0xXX
--                  The controller will respond with the data at address 0xXX
--                  in the results memory.
-- Set parameters - 0x03 0xXX 0xYY
--                  Store 0xYY in the parameter memory at address 0xXX.
-- Empty recorder - 0x04
--                  The controller will stream out the contents of the recorder
--                  memory over UART starting from address 0.
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-07-03  1.0      erikbor Created
-- 2019-09-20  2.0      erikbor Added support for changing awgn and phase noise
--                              settings.
-- 2020-09-01  3.0      erikbor Changed to update uart component.
-- 2022-02-28  4.0      erikbor Rewrite to use parameter and results memory.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity communication is
  generic (REC_WIDTH : positive := 8;
           REC_DEPTH : positive := 32);
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
end entity communication;

architecture arch of communication is

  -- UART commands
  constant CMD_RESET : std_logic_vector(7 downto 0) := x"00";
  constant CMD_STORE : std_logic_vector(7 downto 0) := x"01";
  constant CMD_READ  : std_logic_vector(7 downto 0) := x"02";
  constant CMD_WRITE : std_logic_vector(7 downto 0) := x"03";
  constant CMD_EMPTY : std_logic_vector(7 downto 0) := x"04";

  -- Derived constants
  constant REC_BYTES    : natural := integer(ceil(real(REC_WIDTH)/8.0));

  type state_type is (idle, reset, store, write_wait_addr, write_addr, write_wait_data, write_enable, read_wait_addr, read_addr, read_rdy, read_send, empty_reset, empty_wait_data, empty_send, empty_rdy, empty_inc_byte, empty_inc_addr);
  signal current_state : state_type;
  signal next_state    : state_type;

  signal addr_reg         : std_logic_vector(7 downto 0);
  signal addr_reg_en      : std_logic;
  signal data_reg         : std_logic_vector(7 downto 0);
  signal data_reg_en      : std_logic;
  signal rec_addr_cnt     : integer range 0 to REC_DEPTH-1;
  signal rec_addr_reg     : std_logic_vector(integer(ceil(log2(real(REC_DEPTH))))-1 downto 0);
  signal rec_addr_reg_rst : std_logic;
  signal rec_addr_reg_en  : std_logic;
  signal rec_byte_cnt     : integer range 0 to REC_BYTES;
  signal rec_byte_rst     : std_logic;
  signal rec_byte_en      : std_logic;

  signal rst_int : std_logic;
  signal rst_gen : std_logic;

begin

  rst_emu <= rst or rst_gen;

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        rst_gen <= '1';
      else
        if rst_int = '1' then
          rst_gen <= '1';
        else
          rst_gen <= '0';
        end if;
      end if;
    end if;
  end process;

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        addr_reg     <= (others => '0');
        data_reg     <= (others => '0');
        rec_addr_reg <= (others => '0');
        rec_addr_cnt <= 0;
        rec_byte_cnt <= 0;
      else
        if rx_vld = '1' and addr_reg_en = '1' then
          addr_reg <= rx_data;
        end if;
        if rx_vld = '1' and data_reg_en = '1' then
          data_reg <= rx_data;
        end if;
        if rec_addr_reg_rst = '1' then
          rec_addr_cnt <= 0;
          rec_addr_reg <= (others => '0');
        elsif rec_addr_reg_en = '1' then
          rec_addr_cnt <= rec_addr_cnt + 1;
          rec_addr_reg <= std_logic_vector(unsigned(rec_addr_reg) + 1);
        end if;
        if rec_byte_rst = '1' then
          rec_byte_cnt <= 0;
        elsif rec_byte_en = '1' then
          rec_byte_cnt <= rec_byte_cnt + 1;
        end if;
      end if;
    end if;
  end process;

  rec_addr <= std_logic_vector(to_unsigned(rec_addr_cnt, rec_addr'length));


  fsm_stage_change_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        current_state <= idle;
      else
        current_state <= next_state;
      end if;
    end if;
  end process fsm_stage_change_proc;

  fsm_next_state_proc : process (current_state, rx_vld, rx_data, tx_rdy, rec_addr_cnt, rec_byte_cnt)
  begin
    next_state <= current_state;

    case current_state is

      when idle =>
        if rx_vld = '1' then
          if rx_data = CMD_RESET then
            next_state <= reset;
          elsif rx_data = CMD_STORE then
            next_state <= store;
          elsif rx_data = CMD_READ then
            next_state <= read_wait_addr;
          elsif rx_data = CMD_WRITE then
            next_state <= write_wait_addr;
          elsif rx_data = CMD_EMPTY then
            next_state <= empty_reset;
          end if;
        end if;

      when reset =>
        next_state <= idle;
        if rx_vld = '0' then
          next_state <= idle;
        end if;

      when store =>
        next_state <= idle;
        if rx_vld = '0' then
          next_state <= idle;
        end if;

      when read_wait_addr =>
        if rx_vld = '1' then
          next_state <= read_addr;
        end if;

      when read_addr =>
        if rx_vld = '0' then
          next_state <= read_rdy;
        end if;

      when read_rdy =>
        if tx_rdy = '1' then
          next_state <= read_send;
        end if;

      when read_send =>
        next_state <= idle;

      when write_wait_addr =>
        if rx_vld = '1' then
          next_state <= write_addr;
        end if;

      when write_addr =>
        if rx_vld = '0' then
          next_state <= write_wait_data;
        end if;

      when write_wait_data =>
        if rx_vld = '1' then
          next_state <= write_enable;
        end if;

      when write_enable =>
        if rx_vld = '0' then
          next_state <= idle;
        end if;

      when empty_reset =>
        next_state <= empty_wait_data;

      when empty_wait_data =>
        next_state <= empty_send;

      when empty_send =>
        next_state <= empty_rdy;

      when empty_rdy =>
        if tx_rdy = '1' then
          if rec_byte_cnt < REC_BYTES - 1 then
            next_state <= empty_inc_byte;
          elsif rec_addr_cnt < REC_DEPTH then
            next_state <= empty_inc_addr;
          else
            next_state <= idle;
          end if;
        end if;

      when empty_inc_byte =>
        next_state <= empty_wait_data;

      when empty_inc_addr =>
        next_state <= empty_wait_data;

      when others =>
        null;

    end case;
  end process fsm_next_state_proc;

  fsm_output_proc : process (current_state, rx_data, data_reg, addr_reg, results_data, rec_data, rec_byte_cnt)
  begin
    rst_int          <= '0';
    store_results    <= '0';
    params_en        <= '0';
    params_addr      <= (others => '0');
    params_data      <= (others => '0');
    results_addr     <= (others => '0');
    tx_req           <= '0';
    tx_data          <= (others => '0');
    addr_reg_en      <= '0';
    data_reg_en      <= '0';
    rec_addr_reg_rst <= '0';
    rec_addr_reg_en  <= '0';
    rec_byte_rst     <= '0';
    rec_byte_en      <= '0';

    case current_state is

      when reset =>
        rst_int <= '1';

      when store =>
        store_results <= '1';

      when read_wait_addr =>
        addr_reg_en <= '1';

      when read_rdy =>
        results_addr <= addr_reg;

      when read_send =>
        results_addr <= addr_reg;
        tx_req       <= '1';
        tx_data      <= results_data;

      when write_wait_addr =>
        addr_reg_en <= '1';

      when write_wait_data =>
        data_reg_en <= '1';

      when write_enable =>
        params_en   <= '1';
        params_addr <= addr_reg;
        params_data <= data_reg;

      when empty_reset =>
        rec_addr_reg_rst <= '1';
        rec_byte_rst     <= '1';

      when empty_send =>
        tx_req  <= '1';
        tx_data <= rec_data((rec_byte_cnt+1)*8-1 downto rec_byte_cnt*8);

      when empty_inc_addr =>
        rec_addr_reg_en <= '1';
        rec_byte_rst    <= '1';

      when empty_inc_byte =>
        rec_byte_en <= '1';

      when others =>
        null;

    end case;
  end process fsm_output_proc;

end architecture arch;
