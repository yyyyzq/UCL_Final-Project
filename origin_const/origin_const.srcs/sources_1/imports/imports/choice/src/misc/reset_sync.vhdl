-------------------------------------------------------------------------------
-- Title      : Reset Synchronizer
-- Project    : CHOICEs
-------------------------------------------------------------------------------
-- File       : reset_sync.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2020-09-01
-- Last update: 2022-03-03
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- Circuit to synchronize an asynchronous reset (e.g. a button) to the internal
-- clock.
--
-------------------------------------------------------------------------------
-- Copyright (c) 2019 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-08-01  1.0      erikbor Created
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity reset_sync is
  port (clk  : in  std_logic;
        arst : in  std_logic;
        rst  : out std_logic);
end entity reset_sync;

architecture arch of reset_sync is
  signal rst_sync : std_logic;
begin

  process (arst, clk)
  begin
    if arst = '1' then
      rst_sync <= '1';
      rst <= '1';
    elsif rising_edge(clk) then
      rst_sync <= '0';
      rst <= rst_sync;
    end if;
  end process;


end architecture arch;
