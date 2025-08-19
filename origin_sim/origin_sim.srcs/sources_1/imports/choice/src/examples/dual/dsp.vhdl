-------------------------------------------------------------------------------
-- Title      : Dummy DSP Component for a Dual Polarization Setup
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : dsp.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2022-02-29
-- Last update: 2022-03-01
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- An example DSP component used to illustrate how to interface with the rest
-- of the CHOICE components and how to implement a circular buffer for the
-- reference bits.
--
-- It splits the input symbols into arrays where the index represents the
-- parallel track number and delays the symbols before reconstructing the
-- strided output vectors.
--
-- To emulate the down sampling typically performed in the adaptive equalizer,
-- the component drops every other sample, so that the correct sample rate is
-- used at the output.
--
-------------------------------------------------------------------------------
-- Copyright (c) 2022 Erik Börjeson
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2022-02-29  1.0      erikbor Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity dsp is
  generic(WIDTH : positive := 8;
          BITS  : positive := 64);
  port (clk        : in  std_logic;
        rst        : in  std_logic;
        x_i_in     : in  std_logic_vector(2*WIDTH-1 downto 0);
        x_q_in     : in  std_logic_vector(2*WIDTH-1 downto 0);
        y_i_in     : in  std_logic_vector(2*WIDTH-1 downto 0);
        y_q_in     : in  std_logic_vector(2*WIDTH-1 downto 0);
        bits_x_in  : in  std_logic_vector(BITS-1 downto 0);
        bits_y_in  : in  std_logic_vector(BITS-1 downto 0);
        valid_in   : in  std_logic;
        x_i_out    : out std_logic_vector(WIDTH-1 downto 0);
        x_q_out    : out std_logic_vector(WIDTH-1 downto 0);
        y_i_out    : out std_logic_vector(WIDTH-1 downto 0);
        y_q_out    : out std_logic_vector(WIDTH-1 downto 0);
        bits_x_out : out std_logic_vector(BITS-1 downto 0);
        bits_y_out : out std_logic_vector(BITS-1 downto 0);
        valid_out  : out std_logic);
end entity dsp;

architecture arch of dsp is

  -- Constant declarations
  constant BITS_DELAY : positive := 2;

  -- Type declarations
  type iq_rec is record
    i : std_logic_vector(WIDTH-1 downto 0);
    q : std_logic_vector(WIDTH-1 downto 0);
  end record iq_rec;

  type pol_rec is record
    x : iq_rec;
    y : iq_rec;
  end record pol_rec;

  type par_type is array (0 to 1) of pol_rec;

  type bits_buff_type is array (0 to BITS_DELAY-1) of std_logic_vector(BITS-1 downto 0);

  -- Signal declarations
  signal symb_in          : par_type;
  signal symb_out         : par_type;
  signal symb_0, symb_1   : par_type;
  signal valid_0, valid_1 : std_logic;

  signal bits_x_buff   : bits_buff_type;
  signal bits_y_buff   : bits_buff_type;
  signal bits_buff_ptr : integer range 0 to BITS_DELAY-1;
begin

  -- Sort input and output symbols.
  par_gen : for p in 0 to 1 generate
    symb_in(p).x.i <= x_i_in((p+1)*WIDTH-1 downto p*WIDTH);
    symb_in(p).x.q <= x_q_in((p+1)*WIDTH-1 downto p*WIDTH);
    symb_in(p).y.i <= y_i_in((p+1)*WIDTH-1 downto p*WIDTH);
    symb_in(p).y.q <= y_q_in((p+1)*WIDTH-1 downto p*WIDTH);
  end generate;
  x_i_out <= symb_out(1).x.i;
  x_q_out <= symb_out(1).x.q;
  y_i_out <= symb_out(1).y.i;
  y_q_out <= symb_out(1).y.q;

  -- Registers used to delay input symbols and valid signal with two cycles
  symb_dly_proc : process (rst, clk)
  begin
    if rst = '1' then
      symb_0    <= (others => (others => (others => (others => '0'))));
      symb_1    <= (others => (others => (others => (others => '0'))));
      symb_out  <= (others => (others => (others => (others => '0'))));
      valid_0   <= '0';
      valid_1   <= '0';
      valid_out <= '0';
    elsif rising_edge(clk) then
      if valid_in <= '1' then
        symb_0    <= symb_in;
        symb_1    <= symb_0;
        symb_out  <= symb_1;
        valid_0   <= valid_in;
        valid_1   <= valid_0;
        valid_out <= valid_1;
      end if;
    end if;
  end process;

  -- Circular buffer to delay input bits with the specified
  -- number of cycles.
  bits_dly_proc : process (rst, clk)
  begin
    if rst = '1' then
      bits_x_buff   <= (others => (others => '0'));
      bits_y_buff   <= (others => (others => '0'));
      bits_buff_ptr <= 0;
      bits_x_out    <= (others => '0');
      bits_y_out    <= (others => '0');
    elsif rising_edge(clk) then
      if valid_in = '1' then
        bits_x_buff(bits_buff_ptr) <= bits_x_in;
        bits_y_buff(bits_buff_ptr) <= bits_y_in;
        bits_x_out                 <= bits_x_buff(bits_buff_ptr);
        bits_y_out                 <= bits_y_buff(bits_buff_ptr);
        if bits_buff_ptr = BITS_DELAY-1 then
          bits_buff_ptr <= 0;
        else
          bits_buff_ptr <= bits_buff_ptr + 1;
        end if;
      end if;
    end if;
  end process;

end architecture arch;
