-------------------------------------------------------------------------------
-- Title      : Parameter Memory
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : memory_params.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2022-02-28
-- Last update: 2022-03-03
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- Memory used to store parameter settings. The parameter outputs are updated
-- from memory when the rst_emu signal is pulled high.
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
use ieee.math_real.all;

entity memory_params is
  port (clk          : in  std_logic;
        rst          : in  std_logic;
        rst_emu      : in  std_logic;
        enable       : in  std_logic;
        addr         : in  std_logic_vector(7 downto 0);
        data_in      : in  std_logic_vector(7 downto 0);
        awgn_scaling : out std_logic_vector(15 downto 0);
        pn_scaling   : out std_logic_vector(15 downto 0));

end entity memory_params;

architecture arch of memory_params is

  -- Memory settings
  constant MEM_DEPTH : positive := 4;

  -- Start addresses
  constant ADDR_AWGN : natural := 0;
  constant ADDR_PN   : natural := 2;

  type mem_type is array (0 to MEM_DEPTH-1) of std_logic_vector(7 downto 0);
  signal mem : mem_type;

begin

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        mem <= (others => (others => '0'));
      else
        if enable = '1' then
          if to_integer(unsigned(addr)) < MEM_DEPTH then
            mem(to_integer(unsigned(addr))) <= data_in;
          end if;
        end if;
      end if;
    end if;
  end process;

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        awgn_scaling <= (others => '0');
        pn_scaling   <= (others => '0');
      else
        if rst_emu = '1' then
          awgn_scaling(7 downto 0)  <= mem(ADDR_AWGN);
          awgn_scaling(15 downto 8) <= mem(ADDR_AWGN+1);
          pn_scaling(7 downto 0)    <= mem(ADDR_PN);
          pn_scaling(15 downto 8)   <= mem(ADDR_PN+1);
        end if;
      end if;
    end if;
  end process;

end architecture arch;
