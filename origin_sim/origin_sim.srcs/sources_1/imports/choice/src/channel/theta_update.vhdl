-------------------------------------------------------------------------------
-- Title      : Theta Update
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : theta_update.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2022-01-24
-- Last update: 2022-02-24
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- Emulates a time dependent rotation of the theta angle.
--
-------------------------------------------------------------------------------
-- Copyright (c) 2022 Erik Börjeson
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2022-01-24  1.0      erikbor Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity theta_update is
  generic (THETA_WIDTH   : positive := 10;
           COUNTER_WIDTH : positive := 24);
  port (clk       : in  std_logic;
        rst       : in  std_logic;
        count_max : in  std_logic_vector(COUNTER_WIDTH-1 downto 0);
        start     : in  std_logic_vector(THETA_WIDTH-1 downto 0);
        direction : in  std_logic;
        theta     : out std_logic_vector(THETA_WIDTH-1 downto 0));
end entity theta_update;


architecture arch of theta_update is

  constant PI : signed(THETA_WIDTH-1 downto 0) := to_signed(integer(round(MATH_PI*2.0**(THETA_WIDTH-3))), THETA_WIDTH);

  signal counter : unsigned(COUNTER_WIDTH-1 downto 0);
  signal angle   : signed(THETA_WIDTH-1 downto 0);
  
begin

  counter_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        counter <= (others => '0');
      else
        if counter >= unsigned(count_max)-1 then
          counter <= (others => '0');
        else
          counter <= counter + 1;
        end if;
      end if;
    end if;
  end process;

  theta_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        angle <= signed(start);
      else
        if unsigned(count_max) > 0 then
          if counter >= unsigned(count_max)-1 then
            if direction = '0' then
              if angle >= PI then
                angle <= -PI+1;
              else
                angle <= angle + 1;
              end if;
            else
              if angle <= -PI then
                angle <= PI-1;
              elsif angle = -PI then
                angle <= angle + 1;
              else
                angle <= angle - 1;
              end if;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process theta_proc;

  theta <= std_logic_vector(angle);
  
end architecture arch;


