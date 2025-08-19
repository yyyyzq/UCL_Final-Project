-------------------------------------------------------------------------------
-- Title      : Angle to I/Q Conversion
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : ang_to_iq.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2019-07-03
-- Last update: 2021-01-19
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- Convert the angle input to an I/Q rotation vector of unit length.
--
-------------------------------------------------------------------------------
-- Copyright (c) 2019 Erik Börjeson
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-07-03  1.0      erikbor	Created
-- 2020-01-19  1.2      erikbor Minor fix
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity ang_to_iq is
  generic (WIDTH       : positive := 8;
           ANGLE_WIDTH : positive := 8);
  port (angle      : in  signed(ANGLE_WIDTH-1 downto 0);
        rotation_i : out signed(WIDTH-1 downto 0);
        rotation_q : out signed(WIDTH-1 downto 0));
end entity ang_to_iq;

architecture arch of ang_to_iq is

  constant PI_OVER_2 : integer                  := integer(round(MATH_PI/2.0 * 2.0**(ANGLE_WIDTH-3)));
  constant MAX_VAL   : signed(WIDTH-1 downto 0) := to_signed(integer(floor(2.0**(real(WIDTH)-1.0)-1.0)), WIDTH);

  function get_quadrant(angle : signed(ANGLE_WIDTH-1 downto 0)) return integer is
  begin
    if to_integer(angle) <= -PI_OVER_2 then
      return 2;
    elsif to_integer(angle) < 0 then
      return 3;
    elsif to_integer(angle) >= PI_OVER_2 then
      return 1;
    else
      return 0;
    end if;
  end function get_quadrant;

  function get_lut_idx(angle : signed(ANGLE_WIDTH-1 downto 0)) return integer is
  begin
    if to_integer(angle) <= -2*PI_OVER_2 then
      return PI_OVER_2;
    elsif to_integer(angle) >= 2*PI_OVER_2 then
      return PI_OVER_2;
    elsif to_integer(angle) <= -PI_OVER_2 then
      return -to_integer(angle) - PI_OVER_2;
    elsif to_integer(angle) < 0 then
      return -to_integer(angle);
    elsif to_integer(angle) >= PI_OVER_2 then
      return to_integer(angle) - PI_OVER_2;
    else
      return to_integer(angle);
    end if;
  end function get_lut_idx;

  type lut_type is array (0 to PI_OVER_2) of signed(WIDTH-1 downto 0);

  function generate_lut return lut_type is
    variable result : lut_type;
  begin
    for i in 0 to PI_OVER_2 loop
      result(i) := to_signed(integer(round(cos(real(i)/2.0**(ANGLE_WIDTH-3)) * (2.0**(WIDTH - 1) - 1.0))), result(i)'length);
    end loop;
    return result;
  end generate_LUT;

  constant LUT : lut_type := generate_lut;
  
  signal quadrant : integer := 0;
  signal lut_idx  : integer := 0;
begin

  quadrant <= get_quadrant(angle);
  lut_idx  <= get_lut_idx(angle);

  with quadrant select rotation_i <=
    -lut(PI_OVER_2 - lut_idx) when 1,
    -lut(PI_OVER_2 - lut_idx) when 2,
    lut(lut_idx)              when 3,
    lut(lut_idx)              when others;
  with quadrant select rotation_q <=
    lut(lut_idx)              when 1,
    -lut(lut_idx)             when 2,
    -lut(PI_OVER_2 - lut_idx) when 3,
    lut(PI_OVER_2 - lut_idx)  when others;

end architecture arch;
