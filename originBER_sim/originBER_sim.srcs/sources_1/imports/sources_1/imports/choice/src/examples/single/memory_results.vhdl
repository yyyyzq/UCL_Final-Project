-------------------------------------------------------------------------------
-- Title      : Results Memory
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : memory_results.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2022-02-28
-- Last update: 2022-02-28
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- Memory used to store emulation results. The results are stored in memory at
-- the rising edge of clk when store_results = '1'.
--
-------------------------------------------------------------------------------
-- Copyright (c) 2022
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2022-02-22  1.0      erikbor Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity memory_results is
  port (clk           : in  std_logic;
        rst           : in  std_logic;
        store_results : in  std_logic;
        addr          : in  std_logic_vector(7 downto 0);
        rec_done      : in  std_logic;
        bits_cnt      : in  std_logic_vector(63 downto 0);
        errors_cnt    : in  std_logic_vector(63 downto 0);
        data_out      : out std_logic_vector(7 downto 0));
end entity memory_results;

architecture arch of memory_results is

  -- Memory settings
  constant MEM_DEPTH : positive := 17;

  -- Start addresses
  constant ADDR_FLAGS      : natural := 0;
  constant ADDR_BITS_CNT   : natural := 1;
  constant ADDR_ERRORS_CNT : natural := 9;

  type mem_type is array (0 to MEM_DEPTH-1) of std_logic_vector(7 downto 0);
  signal mem : mem_type;

begin

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        mem      <= (others => (others => '0'));
        data_out <= (others => '0');
      else
        if store_results = '1' then
          mem <= (others => (others => '0'));
          for idx in 0 to 7 loop
            mem(ADDR_BITS_CNT+idx)   <= bits_cnt((idx+1)*8-1 downto idx*8);
            mem(ADDR_ERRORS_CNT+idx) <= errors_cnt((idx+1)*8-1 downto idx*8);
          end loop;
        end if;
        MEM(ADDR_FLAGS)(0) <= rec_done;
        data_out <= mem(to_integer(unsigned(addr)));
      end if;
    end if;
  end process;

end architecture arch;
