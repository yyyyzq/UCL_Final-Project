-------------------------------------------------------------------------------
-- Title      : PMD Delay
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : pmd_delay.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2022-01-24
-- Last update: 2022-01-24
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- Adds a fractional delay to the input symbols using an FIR filter.
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

entity pmd_delay is
  generic (WIDTH     : positive := 8;
           BITS      : positive := 2;
           TAP_WIDTH : positive := 12;
           TAPS_N    : positive := 5);
  port (clk        : in  std_logic;
        rst        : in  std_logic;
        x_i_in     : in  std_logic_vector(2*WIDTH-1 downto 0);
        x_q_in     : in  std_logic_vector(2*WIDTH-1 downto 0);
        y_i_in     : in  std_logic_vector(2*WIDTH-1 downto 0);
        y_q_in     : in  std_logic_vector(2*WIDTH-1 downto 0);
        bits_x_in  : in  std_logic_vector(BITS-1 downto 0);
        bits_y_in  : in  std_logic_vector(BITS-1 downto 0);
        valid_in   : in  std_logic;
        taps       : in  std_logic_vector(TAPS_N*TAP_WIDTH-1 downto 0);
        x_i_out    : out std_logic_vector(2*WIDTH-1 downto 0);
        x_q_out    : out std_logic_vector(2*WIDTH-1 downto 0);
        y_i_out    : out std_logic_vector(2*WIDTH-1 downto 0);
        y_q_out    : out std_logic_vector(2*WIDTH-1 downto 0);
        bits_x_out : out std_logic_vector(BITS-1 downto 0);
        bits_y_out : out std_logic_vector(BITS-1 downto 0);
        valid_out  : out std_logic);
end entity pmd_delay;

architecture arch of pmd_delay is

  -- Type declarations
  type io_iq_rec is record
    i : signed(WIDTH-1 downto 0);
    q : signed(WIDTH-1 downto 0);
  end record io_iq_rec;
  type io_pol_rec is record
    x : io_iq_rec;
    y : io_iq_rec;
  end record io_pol_rec;
  type io_type is array (0 to 1) of io_pol_rec;
  type input_dly_type is array (0 to TAPS_N/2-1) of io_type;

  type res_iq_rec is record
    i : signed(WIDTH+TAP_WIDTH-1 downto 0);
    q : signed(WIDTH+TAP_WIDTH-1 downto 0);
  end record res_iq_rec;
  type res_pol_iq_rec is record
    x : res_iq_rec;
    y : res_iq_rec;
  end record res_pol_iq_rec;
  type prod_type is array(0 to TAPS_N-1, 0 to 1) of res_pol_iq_rec;
  type sum_type is array(0 to (TAPS_N+1)/2-1, 0 to 1) of res_pol_iq_rec;

  type taps_arr_type is array (0 to TAPS_N-1) of signed(TAP_WIDTH-1 downto 0);

  type valid_dly_type is array (0 to (TAPS_N+1)/4+1) of std_logic;
  type bits_dly_type is array (0 to (TAPS_N+1)/4+1) of std_logic_vector(1 downto 0);


  -- Function definitions
  function "+" (a, b : res_pol_iq_rec) return res_pol_iq_rec is
    variable result : res_pol_iq_rec;
  begin
    result.x.i := a.x.i + b.x.i;
    result.x.q := a.x.q + b.x.q;
    result.y.i := a.y.i + b.y.i;
    result.y.q := a.y.q + b.y.q;
    return result;
  end function "+";


  -- Signal declarations
  signal input      : io_type;
  signal output     : io_type;
  signal prod       : prod_type;
  signal prod_reg   : prod_type;
  signal sum        : sum_type;
  signal taps_arr   : taps_arr_type;
  signal valid_dly  : valid_dly_type;
  signal bits_x_dly : bits_dly_type;
  signal bits_y_dly : bits_dly_type;

begin

  -- Sort inputs
  io_par_gen : for par_idx in 0 to 1 generate
    input(par_idx).x.i <= signed(x_i_in((par_idx+1)*WIDTH-1 downto par_idx*WIDTH));
    input(par_idx).x.q <= signed(x_q_in((par_idx+1)*WIDTH-1 downto par_idx*WIDTH));
    input(par_idx).y.i <= signed(y_i_in((par_idx+1)*WIDTH-1 downto par_idx*WIDTH));
    input(par_idx).y.q <= signed(y_q_in((par_idx+1)*WIDTH-1 downto par_idx*WIDTH));
  end generate io_par_gen;
  io_tap_gen : for tap_idx in 0 to TAPS_N-1 generate
    taps_arr(tap_idx) <= signed(taps((tap_idx+1)*TAP_WIDTH-1 downto tap_idx*TAP_WIDTH));
  end generate io_tap_gen;

  -- Sort outputs
  x_i_out <= std_logic_vector(output(1).x.i) & std_logic_vector(output(0).x.i);
  x_q_out <= std_logic_vector(output(1).x.q) & std_logic_vector(output(0).x.q);
  y_i_out <= std_logic_vector(output(1).y.i) & std_logic_vector(output(0).y.i);
  y_q_out <= std_logic_vector(output(1).y.q) & std_logic_vector(output(0).y.q);

  -- Product calculations
  prod_gen : for tap_idx in 0 to TAPS_N-1 generate
    prod(tap_idx, 0).x.i <= input(0).x.i * taps_arr(tap_idx);
    prod(tap_idx, 0).x.q <= input(0).x.q * taps_arr(tap_idx);
    prod(tap_idx, 0).y.i <= input(0).y.i * taps_arr(TAPS_N-1-tap_idx);
    prod(tap_idx, 0).y.q <= input(0).y.q * taps_arr(TAPS_N-1-tap_idx);
    prod(tap_idx, 1).x.i <= input(1).x.i * taps_arr(tap_idx);
    prod(tap_idx, 1).x.q <= input(1).x.q * taps_arr(tap_idx);
    prod(tap_idx, 1).y.i <= input(1).y.i * taps_arr(TAPS_N-1-tap_idx);
    prod(tap_idx, 1).y.q <= input(1).y.q * taps_arr(TAPS_N-1-tap_idx);
  end generate prod_gen;


  -- Pipeline registers
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        prod_reg <= (others => (others => (others => (others => (others => '0')))));
      else
        prod_reg <= prod;
      end if;
    end if;
  end process;

  -- Sum registers
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        sum <= (others => (others => (others => (others => (others => '0')))));
      else
        sum(0, 0) <= sum(1, 0) + prod_reg(0, 0);
        sum(0, 1) <= (sum(1, 1) + prod_reg(1, 0)) + prod_reg(0, 1);
        for sum_idx in 1 to (TAPS_N+1)/2-1 loop
          if sum_idx < (TAPS_N+1)/2-1 then
            sum(sum_idx, 0) <= (sum(sum_idx+1, 0) + prod_reg(sum_idx*2, 0)) + prod_reg(sum_idx*2-1, 1);
            sum(sum_idx, 1) <= (sum(sum_idx+1, 1) + prod_reg(sum_idx*2, 1)) + prod_reg(sum_idx*2+1, 0);
          else
            sum(sum_idx, 0) <= prod_reg(sum_idx*2, 0) + prod_reg(sum_idx*2-1, 1);
            sum(sum_idx, 1) <= prod_reg(sum_idx*2, 1);
          end if;
        end loop;
      end if;
    end if;
  end process;

  even_gen : if TAPS_N/2 mod 2 = 0 generate
    output(0).x.i <= resize(shift_right(shift_right(sum(0, 0).x.i, TAP_WIDTH-3) + 1, 1), output(0).x.i'length);
    output(0).x.q <= resize(shift_right(shift_right(sum(0, 0).x.q, TAP_WIDTH-3) + 1, 1), output(0).x.q'length);
    output(0).y.i <= resize(shift_right(shift_right(sum(0, 0).y.i, TAP_WIDTH-3) + 1, 1), output(0).y.i'length);
    output(0).y.q <= resize(shift_right(shift_right(sum(0, 0).y.q, TAP_WIDTH-3) + 1, 1), output(0).y.q'length);
    output(1).x.i <= resize(shift_right(shift_right(sum(0, 1).x.i, TAP_WIDTH-3) + 1, 1), output(1).x.i'length);
    output(1).x.q <= resize(shift_right(shift_right(sum(0, 1).x.q, TAP_WIDTH-3) + 1, 1), output(1).x.q'length);
    output(1).y.i <= resize(shift_right(shift_right(sum(0, 1).y.i, TAP_WIDTH-3) + 1, 1), output(1).y.i'length);
    output(1).y.q <= resize(shift_right(shift_right(sum(0, 1).y.q, TAP_WIDTH-3) + 1, 1), output(1).y.q'length);
  end generate even_gen;

  odd_gen : if TAPS_N/2 mod 2 = 1 generate
    output(1).x.i <= resize(shift_right(shift_right(sum(0, 0).x.i, TAP_WIDTH-3) + 1, 1), output(0).x.i'length);
    output(1).x.q <= resize(shift_right(shift_right(sum(0, 0).x.q, TAP_WIDTH-3) + 1, 1), output(0).x.q'length);
    output(1).y.i <= resize(shift_right(shift_right(sum(0, 0).y.i, TAP_WIDTH-3) + 1, 1), output(0).y.i'length);
    output(1).y.q <= resize(shift_right(shift_right(sum(0, 0).y.q, TAP_WIDTH-3) + 1, 1), output(0).y.q'length);
    process(clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          output(0).x.i <= (others => '0');
          output(0).x.q <= (others => '0');
          output(0).y.i <= (others => '0');
          output(0).y.q <= (others => '0');
        else
          output(0).x.i <= resize(shift_right(shift_right(sum(0, 1).x.i, TAP_WIDTH-3) + 1, 1), output(0).x.i'length);
          output(0).x.q <= resize(shift_right(shift_right(sum(0, 1).x.q, TAP_WIDTH-3) + 1, 1), output(0).x.q'length);
          output(0).y.i <= resize(shift_right(shift_right(sum(0, 1).y.i, TAP_WIDTH-3) + 1, 1), output(0).y.i'length);
          output(0).y.q <= resize(shift_right(shift_right(sum(0, 1).y.q, TAP_WIDTH-3) + 1, 1), output(0).y.q'length);
        end if;
      end if;
    end process;
  end generate odd_gen;


  -- Bits and valid registers
  valid_proc : process (rst, clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        bits_x_dly <= (others => (others => '0'));
        bits_y_dly <= (others => (others => '0'));
        valid_dly  <= (others => '0');
      else
        bits_x_dly(0) <= bits_x_in;
        bits_y_dly(0) <= bits_y_in;
        valid_dly(0)  <= valid_in;
        for dly_idx in 1 to (TAPS_N+1)/4+1 loop
          bits_x_dly(dly_idx) <= bits_x_dly(dly_idx-1);
          bits_y_dly(dly_idx) <= bits_y_dly(dly_idx-1);
          valid_dly(dly_idx)  <= valid_dly(dly_idx-1);
        end loop;
      end if;
    end if;
  end process valid_proc;

  bits_x_out <= bits_x_dly((TAPS_N+1)/4+1);
  bits_y_out <= bits_y_dly((TAPS_N+1)/4+1);
  valid_out  <= valid_dly((TAPS_N+1)/4+1);

end architecture arch;
