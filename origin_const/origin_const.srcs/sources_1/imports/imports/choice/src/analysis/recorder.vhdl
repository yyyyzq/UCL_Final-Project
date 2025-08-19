-------------------------------------------------------------------------------
-- Title      : Data Recorder
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : recorder.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2021-12-17
-- Last update: 2022-01-10
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- The recorder will store the data at data_in every rising edge of the clock
-- if en = '1' and a trigger condition has be met. A trigger is detected if
-- en = '1' and trig = '1' at a rising edge of the clock. The done signal is
-- set when the storage memory is full. To arm the recorder for a new trigger,
-- the component needs to be reset. There are three modes of operation, set
-- using the MODE generic 
--
-- 1) The memory store the DEPTH latest data samples received before a detected
-- trigger event.
--
-- 2) The memory will store DEPTH samples after a trigger event is detected.
--
-- 3) A combination of the two previous modes, where DEPTH/2-1 samples are
-- stored before and DEPTH/2 samples are stored after a trigger event. 
--
-- Address 0 always points to the oldest data sample.
--
-- The recorder is optimized for Xilinx FPGAs, which will store the data in
-- Block RAMs. 
--
-------------------------------------------------------------------------------
-- Copyright (c) 2021 Erik Börjeson
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2021-12-17  1.0      erikbor	Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity recorder is
  generic (WIDTH : positive             := 8;
           DEPTH : positive             := 32;
           MODE  : natural range 0 to 2 := 1);
  port (clk      : in  std_logic;
        rst      : in  std_logic;
        en       : in  std_logic;
        data_in  : in  std_logic_vector(WIDTH-1 downto 0);
        trig     : in  std_logic;
        addr     : in  std_logic_vector(integer(ceil(log2(real(DEPTH))))-1 downto 0);
        data_out : out std_logic_vector(WIDTH-1 downto 0);
        done     : out std_logic);
end entity recorder;

architecture arch of recorder is

  signal counter  : natural range 0 to DEPTH-1;
  signal cnt_stop : natural range 0 to DEPTH-1;
  signal trigged  : std_logic;
  signal run      : std_logic;
  signal full     : std_logic;

  signal en_w   : std_logic;
  signal en_r   : std_logic;
  signal addr_w : std_logic_vector(integer(ceil(log2(real(DEPTH))))-1 downto 0);
  signal addr_r : std_logic_vector(integer(ceil(log2(real(DEPTH))))-1 downto 0);
  signal data_w : std_logic_vector(WIDTH-1 downto 0);
  signal data_r : std_logic_vector(WIDTH-1 downto 0);

  signal start_addr : std_logic_vector(integer(ceil(log2(real(DEPTH))))-1 downto 0);

  type ram_type is array (0 to DEPTH-1) of std_logic_vector(WIDTH-1 downto 0);
  signal ram : ram_type;
begin

  -- Fill memory pre trigger
  pre_gen : if MODE = 0 generate
    process (clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          counter    <= 0;
          run        <= '1';
          full       <= '0';
          start_addr <= (others => '0');
        elsif en = '1' then
          if trig = '1' then
            run  <= '0';
            full <= '1';
            if counter < DEPTH-1 then
              start_addr <= std_logic_vector(to_unsigned(counter + 1, start_addr'length));
            else
              start_addr <= (others => '0');
            end if;
          elsif run = '1' then
            if counter >= DEPTH-1 then
              counter <= 0;
            else
              counter <= counter + 1;
            end if;
          end if;
        end if;
      end if;
    end process;
  end generate pre_gen;

  -- Fill memory post trigger
  post_gen : if MODE = 1 generate
    process (clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          counter    <= 0;
          run        <= '0';
          full       <= '0';
          start_addr <= (others => '0');
          trigged    <= '0';
        elsif en = '1' then
          if run = '1' then
            if counter >= DEPTH-1 then
              counter <= 0;
              run     <= '0';
              full    <= '1';
              if counter < DEPTH-1 then
                start_addr <= std_logic_vector(to_unsigned(counter + 1, start_addr'length));
              else
                start_addr <= (others => '0');
              end if;
            else
              counter <= counter + 1;
            end if;
          elsif trig = '1' and trigged = '0' then
            run     <= '1';
            full    <= '0';
            trigged <= '1';
          end if;
        end if;
      end if;
    end process;
  end generate post_gen;

  -- Trigger defines center of memory
  prepost_gen : if MODE = 2 generate
    process (clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          counter    <= 0;
          run        <= '1';
          full       <= '0';
          start_addr <= (others => '0');
          trigged    <= '0';
        elsif en = '1' then
          if run = '1' then
            if trigged = '1' and counter = cnt_stop then
              counter <= 0;
              run     <= '0';
              full    <= '1';
              if counter < DEPTH-1 then
                start_addr <= std_logic_vector(to_unsigned(counter + 1, start_addr'length));
              else
                start_addr <= (others => '0');
              end if;
            elsif counter >= DEPTH-1 then
              counter <= 0;
            else
              counter <= counter + 1;
            end if;
          end if;
        end if;
        if trigged = '0' and trig = '1' then
          trigged <= '1';
          if counter > (DEPTH-1)/2 then
            cnt_stop <= counter - DEPTH/2;
          else
            cnt_stop <= counter + DEPTH/2;
          end if;
          report(integer'image(cnt_stop));
        end if;
      end if;
    end process;
  end generate prepost_gen;

  mem_ctrl_proc : process (clk)
  begin
    if rising_edge(clk) then
      if en = '1' and run = '1' then
        en_w   <= '1';
        addr_w <= std_logic_vector(to_unsigned(counter, addr_w'length));
        data_w <= data_in;
      else
        en_w   <= '0';
        addr_w <= (others => '0');
        data_w <= (others => '0');
      end if;
    end if;
  end process;

  done_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        done <= '0';
      else
        done <= full;
      end if;
    end if;
  end process;

  addr_r <= std_logic_vector(unsigned(start_addr) + unsigned(addr));

  -- Memory
  mem_write_proc : process (clk)
  begin
    if rising_edge(clk) then
      if en_w = '1' then
        ram(to_integer(unsigned(addr_w))) <= data_w;
      end if;
    end if;
  end process;

  mem_read_proc : process (clk)
  begin
    if rising_edge(clk) then
      data_out <= ram(to_integer(unsigned(addr_r)));
    end if;
  end process;

end architecture arch;