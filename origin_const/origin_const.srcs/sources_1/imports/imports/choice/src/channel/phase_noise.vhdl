-------------------------------------------------------------------------------
-- Title      : Phase Noise Generator
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : phase_noise.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2019-07-03
-- Last update: 2023-09-11
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- Adds phase noise to input symbols.
--
-------------------------------------------------------------------------------
-- Copyright (c) 2019 Erik Börjeson
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-07-03  1.0      erikbor Created
-- 2020-01-19  1.2      erikbor Fix scaling to support lower linewidths
-- 2022-02-28  2.0      erikbor Add support for dual polarizations
-- 2023-09-11  2.1      erikbor Fix typo that had no effect on output
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.phase_noise_pkg.all;

entity phase_noise is
  generic (PAR         : positive := 1;    -- Parallelism
           WIDTH       : positive := 8;    -- Word length of input signal
           BITS        : positive := 2;    -- Number of bits in original data
           PHASE_WIDTH : positive := 16;   -- Internal word length of the phase
           LUT_WIDTH   : positive := 16);  -- Internal word length of the lut
  port (clk        : in  std_logic;
        rst        : in  std_logic;
        x_i_in     : in  std_logic_vector(PAR*WIDTH-1 downto 0);
        x_q_in     : in  std_logic_vector(PAR*WIDTH-1 downto 0);
        y_i_in     : in  std_logic_vector(PAR*WIDTH-1 downto 0) := (others => '0');
        y_q_in     : in  std_logic_vector(PAR*WIDTH-1 downto 0) := (others => '0');
        bits_x_in  : in  std_logic_vector(BITS-1 downto 0);
        bits_y_in  : in  std_logic_vector(BITS-1 downto 0);
        valid_in   : in  std_logic;
        scaling    : in  std_logic_vector(15 downto 0);
        x_i_out    : out std_logic_vector(PAR*WIDTH-1 downto 0);
        x_q_out    : out std_logic_vector(PAR*WIDTH-1 downto 0);
        y_i_out    : out std_logic_vector(PAR*WIDTH-1 downto 0);
        y_q_out    : out std_logic_vector(PAR*WIDTH-1 downto 0);
        bits_x_out : out std_logic_vector(BITS-1 downto 0);
        bits_y_out : out std_logic_vector(BITS-1 downto 0);
        valid_out  : out std_logic);
end entity phase_noise;

architecture arch of phase_noise is

  -- Constant declarations
  constant MAX_PHASE  : signed(PHASE_WIDTH downto 0) := to_signed(integer(floor(MATH_PI * 2.0**(PHASE_WIDTH-3))), PHASE_WIDTH+1);
  constant MIN_PHASE  : signed(PHASE_WIDTH downto 0) := to_signed(integer(floor(-MATH_PI * 2.0**(PHASE_WIDTH-3))), PHASE_WIDTH+1);
  constant PI_TIMES_2 : signed(PHASE_WIDTH downto 0) := to_signed(integer(floor(MATH_2_PI * 2.0**(PHASE_WIDTH-3))), PHASE_WIDTH+1);

  -- Component declarations
  component gng is
    generic (INIT_Z1 : std_logic_vector(63 downto 0);
             INIT_Z2 : std_logic_vector(63 downto 0);
             INIT_Z3 : std_logic_vector(63 downto 0));
    port (clk       : in  std_logic;
          rstn      : in  std_logic;
          ce        : in  std_logic;
          valid_out : out std_logic;
          data_out  : out std_logic_vector(15 downto 0));
  end component gng;

  component ang_to_iq is
    generic (WIDTH       : positive;
             ANGLE_WIDTH : positive);
    port (angle      : in  signed;
          rotation_i : out signed;
          rotation_q : out signed);
  end component ang_to_iq;

  -- Signal declarations
  signal rst_n : std_logic;

  type data_rec is record
    i : signed(WIDTH-1 downto 0);
    q : signed(WIDTH-1 downto 0);
  end record data_rec;
  type data_type is array (0 to PAR-1) of data_rec;
  signal x_in  : data_type;
  signal y_in  : data_type;
  signal x_out : data_type;
  signal y_out : data_type;

  type rotation_rec is record
    i : signed(LUT_WIDTH-1 downto 0);
    q : signed(LUT_WIDTH-1 downto 0);
  end record rotation_rec;
  type rotation_type is array (0 to PAR-1) of rotation_rec;
  signal rotation     : rotation_type;
  signal rotation_reg : rotation_type;

  type valid_type is array (0 to PAR-1) of std_logic;
  signal valid     : valid_type;
  signal valid_reg : valid_type;

  type rand_type is array (0 to PAR-1) of std_logic_vector(15 downto 0);
  signal rand : rand_type;

  type phase_type is array (0 to PAR-1) of signed(PHASE_WIDTH-1 downto 0);
  signal phase : phase_type;

  type scaled_type is array (0 to PAR-1) of signed(PHASE_WIDTH-1 downto 0);
  signal scaled : scaled_type;

  -- Complex multiplication
  function "*" (a, b : data_rec) return data_rec is
    variable i      : signed(2*WIDTH-1 downto 0);
    variable q      : signed(2*WIDTH-1 downto 0);
    variable result : data_rec;
  begin
    i        := a.i*b.i - a.q*b.q;
    q        := a.i*b.q + a.q*b.i;
    result.i := i(2*WIDTH-2 downto WIDTH-1);
    result.q := q(2*WIDTH-2 downto WIDTH-1);
    return result;
  end function "*";

  -- Complex multiplication
  function "*" (a : data_rec; b : rotation_rec) return data_rec is
    variable i      : signed(WIDTH+LUT_WIDTH-1 downto 0);
    variable q      : signed(WIDTH+LUT_WIDTH-1 downto 0);
    variable result : data_rec;
  begin
    i        := a.i*b.i - a.q*b.q;
    q        := a.i*b.q + a.q*b.i;
    result.i := resize(shift_right(i(WIDTH+LUT_WIDTH-2 downto LUT_WIDTH-2) + 1, 1), result.i'length);
    result.q := resize(shift_right(q(WIDTH+LUT_WIDTH-2 downto LUT_WIDTH-2) + 1, 1), result.q'length);
    return result;
  end function "*";
begin

  -- Reset signal for GNG
  rst_n <= not rst;

  par_gen : for p in 0 to PAR-1 generate
    -- Sort i/o signals
    x_in(p).i                             <= signed(x_i_in((p+1)*WIDTH-1 downto p*WIDTH));
    x_in(p).q                             <= signed(x_q_in((p+1)*WIDTH-1 downto p*WIDTH));
    y_in(p).i                             <= signed(y_i_in((p+1)*WIDTH-1 downto p*WIDTH));
    y_in(p).q                             <= signed(y_q_in((p+1)*WIDTH-1 downto p*WIDTH));
    x_i_out((p+1)*WIDTH-1 downto p*WIDTH) <= std_logic_vector(x_out(p).i);
    x_q_out((p+1)*WIDTH-1 downto p*WIDTH) <= std_logic_vector(x_out(p).q);
    y_i_out((p+1)*WIDTH-1 downto p*WIDTH) <= std_logic_vector(y_out(p).i);
    y_q_out((p+1)*WIDTH-1 downto p*WIDTH) <= std_logic_vector(y_out(p).q);

    -- Generate gng components
    gng_inst : gng
      generic map (INIT_Z1 => SEEDS(3*p + 0),
                   INIT_Z2 => SEEDS(3*p + 1),
                   INIT_Z3 => SEEDS(3*p + 2))
      port map(clk       => clk,
               rstn      => rst_n,
               ce        => '1',
               valid_out => valid(p),
               data_out  => rand(p));

    ang_to_iq_inst : ang_to_iq
      generic map (WIDTH       => LUT_WIDTH,
                   ANGLE_WIDTH => LUT_WIDTH)
      port map (angle      => phase(p)(PHASE_WIDTH-1 downto PHASE_WIDTH-LUT_WIDTH),
                rotation_i => rotation(p).i,
                rotation_q => rotation(p).q);

    scaled(p) <= resize(shift_right(shift_right(signed(rand(p))*signed(scaling), 25-(PHASE_WIDTH-3)) + 1, 1), scaled(p)'length);

  end generate par_gen;

  -- Pipeline registers
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        valid_reg <= (others => '0');
      else
        valid_reg    <= valid;
        rotation_reg <= rotation;
      end if;
    end if;
  end process;


  -- Process to calculate the phase vector.
  process (clk)
    variable all_valid : std_logic;
    type new_phase_type is array (0 to PAR-1) of signed(PHASE_WIDTH downto 0);
    variable new_phase : new_phase_type;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        phase <= (others => (others => '0'));
      else
        all_valid := valid_in;
        for p in 0 to PAR-1 loop
          all_valid := all_valid and valid(p);
        end loop;
        if all_valid = '1' then
          new_phase(0) := (phase(PAR-1)(PHASE_WIDTH-1) & phase(PAR-1)) + (scaled(0)(PHASE_WIDTH-1) & scaled(0));
          if new_phase(0) > MAX_PHASE then
            new_phase(0) := new_phase(0) - PI_TIMES_2;
          elsif new_phase(0) < MIN_PHASE then
            new_phase(0) := new_phase(0) + PI_TIMES_2;
          end if;
          for p in 1 to PAR-1 loop
            new_phase(p) := new_phase(p-1) + (scaled(p)(PHASE_WIDTH-1) & scaled(p));
            if new_phase(p) > MAX_PHASE then
              new_phase(p) := new_phase(p) - PI_TIMES_2;
            elsif new_phase(p) < MIN_PHASE then
              new_phase(p) := new_phase(p) + PI_TIMES_2;
            end if;
          end loop;
          for p in 0 to PAR-1 loop
            phase(p) <= resize(new_phase(p), phase(p)'length);
          end loop;
        end if;
      end if;
    end if;
  end process;


  -- Output registers and valid_out control
  process (clk)
    variable all_valid : std_logic;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        x_out      <= (others => (others => (others => '0')));
        y_out      <= (others => (others => (others => '0')));
        bits_x_out <= (others => '0');
        bits_y_out <= (others => '0');
        valid_out  <= '0';
      else
        all_valid := valid_in;
        for p in 0 to PAR-1 loop
          all_valid := all_valid and valid(p);
        end loop;
        if all_valid = '1' then
          for p in 0 to PAR-1 loop
            x_out(p) <= x_in(p)*rotation_reg(p);
            y_out(p) <= y_in(p)*rotation_reg(p);
          end loop;
          bits_x_out <= bits_x_in;
          bits_y_out <= bits_y_in;
          valid_out  <= '1';
        else
          x_out      <= (others => (others => (others => '0')));
          y_out      <= (others => (others => (others => '0')));
          bits_x_out <= (others => '0');
          bits_y_out <= (others => '0');
          valid_out  <= '0';
        end if;
      end if;
    end if;
  end process;

end architecture arch;
