-------------------------------------------------------------------------------
-- Title      : PMD Rotation
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : pmd_rotation.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2022-01-11
-- Last update: 2022-05-16
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- Adds PMD rotation to the input symbols. The PMD rotation is described by the
-- Jones matrix:
--
--  R_k  = [ cos(theta)  sin(theta)
--          -sin(theta)  cos(theta)]
--
-------------------------------------------------------------------------------
-- Copyright (c) 2022 Erik Börjeson
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2022-01-11  1.0      erikbor Created
-- 2022-05-16  1.1      erikbor Increase resolution of cos and sin signals
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity pmd_rotation is
  generic (WIDTH       : positive := 8;
           BITS        : positive := 2;
           THETA_WIDTH : positive := 10);
  port (clk        : in  std_logic;
        rst        : in  std_logic;
        x_i_in     : in  std_logic_vector(2*WIDTH-1 downto 0);
        x_q_in     : in  std_logic_vector(2*WIDTH-1 downto 0);
        y_i_in     : in  std_logic_vector(2*WIDTH-1 downto 0);
        y_q_in     : in  std_logic_vector(2*WIDTH-1 downto 0);
        bits_x_in  : in  std_logic_vector(BITS-1 downto 0);
        bits_y_in  : in  std_logic_vector(BITS-1 downto 0);
        valid_in   : in  std_logic;
        theta      : in  std_logic_vector(THETA_WIDTH-1 downto 0);
        x_i_out    : out std_logic_vector(2*WIDTH-1 downto 0);
        x_q_out    : out std_logic_vector(2*WIDTH-1 downto 0);
        y_i_out    : out std_logic_vector(2*WIDTH-1 downto 0);
        y_q_out    : out std_logic_vector(2*WIDTH-1 downto 0);
        bits_x_out : out std_logic_vector(BITS-1 downto 0);
        bits_y_out : out std_logic_vector(BITS-1 downto 0);
        valid_out  : out std_logic);
end entity pmd_rotation;


architecture arch of pmd_rotation is

  constant PI_OVER_TWO : signed(THETA_WIDTH-1 downto 0) := to_signed(integer(round(MATH_PI/2.0*2.0**(THETA_WIDTH-3))), THETA_WIDTH);
  constant PI          : signed(THETA_WIDTH-1 downto 0) := to_signed(integer(round(MATH_PI*2.0**(THETA_WIDTH-3))), THETA_WIDTH);

  type lut_type is array (0 to to_integer(PI_OVER_TWO)+1) of signed(WIDTH+1 downto 0);
-- WIDTH+1 OK
  function generate_lut return lut_type is
    variable result : lut_type;
  begin
    for idx in 0 to to_integer(PI_OVER_TWO)+1 loop
      result(idx) := to_signed(integer(round(sin(real(idx) / 2.0**(THETA_WIDTH-3)) * (2.0**(WIDTH)))), WIDTH+2);
    end loop;
    return result;
  end function generate_lut;
  constant LUT : lut_type := generate_lut;

  function limit_theta(theta : std_logic_vector(THETA_WIDTH-1 downto 0)) return signed is
    variable theta_limited : signed(THETA_WIDTH-1 downto 0);
  begin
    theta_limited := signed(theta);
    if theta_limited > PI then
      theta_limited := theta_limited - PI - PI;
    elsif theta_limited < -PI then
      theta_limited := theta_limited + PI + PI;
    end if;
    return theta_limited;
  end function limit_theta;

  function get_sin(theta : signed(THETA_WIDTH-1 downto 0)) return signed is
    variable result : signed(WIDTH+1 downto 0);
  begin
    if theta >= 0 then
      if theta <= PI_OVER_TWO then
        result := LUT(to_integer(theta));
      else
        result := LUT(to_integer(-theta+PI));
      end if;
    else
      if theta < -PI_OVER_TWO then
        result := -LUT(to_integer(theta+PI));
      else
        result := -LUT(to_integer(-theta));
      end if;
    end if;
    return result;
  end function get_sin;

  function get_cos(theta : signed(THETA_WIDTH-1 downto 0)) return signed is
    variable result : signed(WIDTH+1 downto 0);
  begin
    if theta >= 0 then
      if theta < PI_OVER_TWO then
        result := LUT(to_integer(-theta + PI_OVER_TWO));
      else
        result := -LUT(to_integer(theta - PI_OVER_TWO));
      end if;
    else
      if theta < -PI_OVER_TWO then
        result := -LUT(to_integer(-theta - PI_OVER_TWO));
      else
        result := LUT(to_integer(theta + PI_OVER_TWO));
      end if;
    end if;
    return result;
  end function get_cos;

  type iq_rec is record
    i : signed(WIDTH-1 downto 0);
    q : signed(WIDTH-1 downto 0);
  end record iq_rec;

  type pol_rec is record
    x : iq_rec;
    y : iq_rec;
  end record pol_rec;

  type par_type is array (0 to 1) of pol_rec;

  signal input  : par_type;
  signal output : par_type;

  signal sin_theta     : signed(WIDTH+1 downto 0);
  signal cos_theta     : signed(WIDTH+1 downto 0);

  signal bits_x : std_logic_vector(BITS-1 downto 0);
  signal bits_y : std_logic_vector(BITS-1 downto 0);
  signal valid  : std_logic;


begin

  -- Pipeline registers
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        sin_theta <= (others => '0');
        cos_theta <= (others => '0');
        input     <= (others => (others => (others => (others => '0'))));
      else
        sin_theta <= get_sin(limit_theta(theta));
        cos_theta <= get_cos(limit_theta(theta));
        for par_idx in 0 to 1 loop
          input(par_idx).x.i <= signed(x_i_in((par_idx+1)*WIDTH-1 downto par_idx*WIDTH));
          input(par_idx).x.q <= signed(x_q_in((par_idx+1)*WIDTH-1 downto par_idx*WIDTH));
          input(par_idx).y.i <= signed(y_i_in((par_idx+1)*WIDTH-1 downto par_idx*WIDTH));
          input(par_idx).y.q <= signed(y_q_in((par_idx+1)*WIDTH-1 downto par_idx*WIDTH));
        end loop;
      end if;
    end if;
  end process;

  -- PMD rotation
  par_gen : for par_idx in 0 to 1 generate
    output(par_idx).x.i <= resize(shift_right(shift_right(cos_theta * input(par_idx).x.i - sin_theta * input(par_idx).y.i, WIDTH-1) + 1, 1), output(par_idx).x.i'length);
    output(par_idx).x.q <= resize(shift_right(shift_right(cos_theta * input(par_idx).x.q - sin_theta * input(par_idx).y.q, WIDTH-1) + 1, 1), output(par_idx).x.i'length);
    output(par_idx).y.i <= resize(shift_right(shift_right(cos_theta * input(par_idx).y.i + sin_theta * input(par_idx).x.i, WIDTH-1) + 1, 1), output(par_idx).x.i'length);
    output(par_idx).y.q <= resize(shift_right(shift_right(cos_theta * input(par_idx).y.q + sin_theta * input(par_idx).x.q, WIDTH-1) + 1, 1), output(par_idx).x.i'length);
  end generate;

  -- Output and delay registers
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        bits_x     <= (others => '0');
        bits_y     <= (others => '0');
        valid      <= '0';
        x_i_out    <= (others => '0');
        x_q_out    <= (others => '0');
        y_i_out    <= (others => '0');
        y_q_out    <= (others => '0');
        bits_x_out <= (others => '0');
        bits_y_out <= (others => '0');
        valid_out  <= '0';
      else
        bits_x     <= bits_x_in;
        bits_y     <= bits_y_in;
        valid      <= valid_in;
        x_i_out    <= std_logic_vector(output(1).x.i) & std_logic_vector(output(0).x.i);
        x_q_out    <= std_logic_vector(output(1).x.q) & std_logic_vector(output(0).x.q);
        y_i_out    <= std_logic_vector(output(1).y.i) & std_logic_vector(output(0).y.i);
        y_q_out    <= std_logic_vector(output(1).y.q) & std_logic_vector(output(0).y.q);
        bits_x_out <= bits_x;
        bits_y_out <= bits_y;
        valid_out  <= valid;
      end if;
    end if;
  end process;

end architecture arch;
