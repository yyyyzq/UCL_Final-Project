-------------------------------------------------------------------------------
-- Title      : Bits and Error Counter
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : error_counter.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2019-07-03
-- Last update: 2022-03-03
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- Counter for the number of processed bits and the number bits with
-- transmission errors. The errors are detected by comparing the two bit
-- vector inputs using xor-gates and couting the number of ones.
--
-------------------------------------------------------------------------------
-- Copyright (c) 2019 Erik Börjeson
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-07-03  1.0      erikbor	Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity error_counter is
  generic (BITS             : positive := 4;
           BITS_CNT_WIDTH   : positive := 16;
           ERRORS_CNT_WIDTH : positive := 16);
  port (clk        : in  std_logic;
        rst        : in  std_logic;
        input0     : in  std_logic_vector(BITS-1 downto 0);
        input1     : in  std_logic_vector(BITS-1 downto 0);
        valid_in0  : in  std_logic;
        valid_in1  : in  std_logic;
        bits_cnt   : out std_logic_vector(BITS_CNT_WIDTH-1 downto 0);
        errors_cnt : out std_logic_vector(ERRORS_CNT_WIDTH-1 downto 0));
end entity error_counter;

architecture arch of error_counter is
  signal bits_cnt_us   : unsigned(BITS_CNT_WIDTH-1 downto 0);
  signal errors_cnt_us : unsigned(ERRORS_CNT_WIDTH-1 downto 0);
begin

  process (rst, clk)
    variable xor_input : std_logic_vector(BITS-1 downto 0);
    variable xor_cnt   : natural range 0 to BITS;
  begin
    if rst = '1' then
      bits_cnt_us   <= (others => '0');
      errors_cnt_us <= (others => '0');
    elsif rising_edge(clk) then
      if valid_in0 = '1' and valid_in1 = '1' then
        xor_input := input0 xor input1;
        xor_cnt   := 0;
        for i in 0 to BITS-1 loop
          if xor_input(i) = '1' then
            xor_cnt := xor_cnt + 1;
          end if;
        end loop;
        bits_cnt_us   <= bits_cnt_us + to_unsigned(BITS, bits_cnt_us'length);
        errors_cnt_us <= errors_cnt_us + to_unsigned(xor_cnt, errors_cnt_us'length);
      end if;
    end if;
  end process;

  bits_cnt   <= std_logic_vector(bits_cnt_us);
  errors_cnt <= std_logic_vector(errors_cnt_us);

end architecture arch;
