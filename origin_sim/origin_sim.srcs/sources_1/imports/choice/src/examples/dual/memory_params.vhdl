-------------------------------------------------------------------------------
-- Title      : Parameter Memory for Dual Polarization System
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : memory_params.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2022-02-28
-- Last update: 2022-03-04
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
  generic (PMD_SECTIONS_N    : positive := 10;
           PMD_THETA_WIDTH   : positive := 10;
           PMD_COUNTER_WIDTH : positive := 32;
           PMD_TAP_WIDTH     : positive := 10;
           PMD_TAPS_N        : positive := 5;
           PMD_PHI_WIDTH     : positive := 10);
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
end entity memory_params;

architecture arch of memory_params is

  -- Derived constants
  constant BYTES_PMD_THETA_START : positive := integer(ceil(real(PMD_THETA_WIDTH)/8.0));
  constant BYTES_PMD_COUNT_MAX   : positive := integer(ceil(real(PMD_COUNTER_WIDTH)/8.0));
  constant BYTES_PMD_DIRECTION   : positive := integer(ceil(real(PMD_SECTIONS_N+1)/8.0));
  constant BYTES_PMD_TAPS        : positive := integer(ceil(real(PMD_TAP_WIDTH)/8.0));
  constant BYTES_PMD_PHI         : positive := integer(ceil(real(PMD_PHI_WIDTH)/8.0));

  -- Start addresses
  constant ADDR_AWGN            : natural := 0;
  constant ADDR_PN              : natural := 2;
  constant ADDR_PMD_THETA_START : natural := 4;
  constant ADDR_PMD_COUNT_MAX   : natural := ADDR_PMD_THETA_START + (PMD_SECTIONS_N+1)*BYTES_PMD_THETA_START;
  constant ADDR_PMD_DIRECTION   : natural := ADDR_PMD_COUNT_MAX + (PMD_SECTIONS_N+1)*BYTES_PMD_COUNT_MAX;
  constant ADDR_PMD_TAPS        : natural := ADDR_PMD_DIRECTION + BYTES_PMD_DIRECTION;
  constant ADDR_PMD_PHI         : natural := ADDR_PMD_TAPS + PMD_TAPS_N*BYTES_PMD_TAPS;

  -- Memory settings
  constant MEM_DEPTH : positive := ADDR_PMD_PHI + PMD_SECTIONS_N*BYTES_PMD_PHI;

  type mem_type is array (0 to MEM_DEPTH-1) of std_logic_vector(7 downto 0);
  signal mem : mem_type;

begin

  process
  begin
    report(integer'image(ADDR_PMD_PHI));
    wait;
  end process;


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
        awgn_scaling    <= (others => '0');
        pn_scaling      <= (others => '0');
        pmd_theta_start <= (others => '0');
        pmd_count_max   <= (others => '0');
        pmd_direction   <= (others => '0');
        pmd_taps        <= (others => '0');
        pmd_phi         <= (others => '0');
      else
        if rst_emu = '1' then
          -- AWGN 
          awgn_scaling(7 downto 0)  <= mem(ADDR_AWGN);
          awgn_scaling(15 downto 8) <= mem(ADDR_AWGN+1);
          -- Phase noise
          pn_scaling(7 downto 0)    <= mem(ADDR_PN);
          pn_scaling(15 downto 8)   <= mem(ADDR_PN+1);
          -- PMD theta start
          for sec_idx in 0 to PMD_SECTIONS_N loop
            for byte_idx in 0 to BYTES_PMD_THETA_START-1 loop
              if (byte_idx+1)*8 > PMD_THETA_WIDTH then
                pmd_theta_start((sec_idx+1)*PMD_THETA_WIDTH-1 downto sec_idx*PMD_THETA_WIDTH+byte_idx*8) <= mem(ADDR_PMD_THETA_START+sec_idx*BYTES_PMD_THETA_START+byte_idx)(PMD_THETA_WIDTH-1-byte_idx*8 downto 0);
              else
                pmd_theta_start(sec_idx*PMD_THETA_WIDTH+(byte_idx+1)*8-1 downto sec_idx*PMD_THETA_WIDTH+byte_idx*8) <= mem(ADDR_PMD_THETA_START+sec_idx*BYTES_PMD_THETA_START+byte_idx);
              end if;
            end loop;
          end loop;
          -- PMD count max
          for sec_idx in 0 to PMD_SECTIONS_N loop
            for byte_idx in 0 to BYTES_PMD_COUNT_MAX-1 loop
              if (byte_idx+1)*8 > PMD_COUNTER_WIDTH then
                pmd_count_max((sec_idx+1)*PMD_COUNTER_WIDTH-1 downto sec_idx*PMD_COUNTER_WIDTH+byte_idx*8) <= mem(ADDR_PMD_COUNT_MAX+sec_idx*BYTES_PMD_COUNT_MAX+byte_idx)(PMD_COUNTER_WIDTH-1-byte_idx*8 downto 0);
              else
                pmd_count_max(sec_idx*PMD_COUNTER_WIDTH+(byte_idx+1)*8-1 downto sec_idx*PMD_COUNTER_WIDTH+byte_idx*8) <= mem(ADDR_PMD_COUNT_MAX+sec_idx*BYTES_PMD_COUNT_MAX+byte_idx);
              end if;
            end loop;
          end loop;
          -- PMD direction
          for byte_idx in 0 to BYTES_PMD_DIRECTION-1 loop
            if (byte_idx+1)*8 > PMD_SECTIONS_N+1 then
              pmd_direction(PMD_SECTIONS_N downto byte_idx*8) <= mem(ADDR_PMD_DIRECTION+byte_idx)(PMD_SECTIONS_N-byte_idx*8 downto 0);
            else
              pmd_direction((byte_idx+1)*8-1 downto byte_idx*8) <= mem(ADDR_PMD_DIRECTION+byte_idx);
            end if;
          end loop;
          -- PMD taps
          for tap_idx in 0 to PMD_TAPS_N-1 loop
            for byte_idx in 0 to BYTES_PMD_TAPS-1 loop
              if (byte_idx+1)*8 > PMD_TAP_WIDTH then
                pmd_taps((tap_idx+1)*PMD_TAP_WIDTH-1 downto tap_idx*PMD_TAP_WIDTH+byte_idx*8) <= mem(ADDR_PMD_TAPS+tap_idx*BYTES_PMD_TAPS+byte_idx)(PMD_TAP_WIDTH-1-byte_idx*8 downto 0);
              else
                pmd_taps(tap_idx*PMD_TAP_WIDTH+(byte_idx+1)*8-1 downto tap_idx*PMD_TAP_WIDTH+byte_idx*8) <= mem(ADDR_PMD_TAPS+tap_idx*BYTES_PMD_TAPS+byte_idx);
              end if;
            end loop;
          end loop;
          -- PMD phi
          for sec_idx in 0 to PMD_SECTIONS_N-1 loop
            for byte_idx in 0 to BYTES_PMD_PHI-1 loop
              if (byte_idx+1)*8 > PMD_PHI_WIDTH then
                pmd_phi((sec_idx+1)*PMD_PHI_WIDTH-1 downto sec_idx*PMD_PHI_WIDTH+byte_idx*8) <= mem(ADDR_PMD_PHI+sec_idx*BYTES_PMD_PHI+byte_idx)(PMD_PHI_WIDTH-1-byte_idx*8 downto 0);
              else
                pmd_phi(sec_idx*PMD_PHI_WIDTH+(byte_idx+1)*8-1 downto sec_idx*PMD_PHI_WIDTH+byte_idx*8) <= mem(ADDR_PMD_PHI+sec_idx*BYTES_PMD_PHI+byte_idx);
              end if;
            end loop;
          end loop;
        end if;
      end if;
    end if;
  end process;

end architecture arch;
