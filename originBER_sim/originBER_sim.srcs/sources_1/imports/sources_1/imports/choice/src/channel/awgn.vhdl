-------------------------------------------------------------------------------
-- Title      : Additive White Gaussian Noise Generator
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : awgn.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2019-07-03
-- Last update: 2021-12-17
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- Adds additive white Gaussian noise to input symbols.
--
-------------------------------------------------------------------------------
-- Copyright (c) 2019 Erik Börjeson
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-07-03  1.0      erikbor Created
-- 2021-12-17  2.0      erikbor Remove rounding of noise signal, since the
--                              full length fits in a DSP slice. Move rounding
--                              to before saturation.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.awgn_pkg.all;

entity awgn is
  generic (PAR   : positive := 1;       -- Parallelism
           WIDTH : positive := 8;       -- Word length of input signal
           BITS  : positive := 2);      -- Number of bits in original data
  port (clk       : in  std_logic;
        rst       : in  std_logic;
        i_in      : in  std_logic_vector(PAR*WIDTH-1 downto 0);
        q_in      : in  std_logic_vector(PAR*WIDTH-1 downto 0);
        bits_in   : in  std_logic_vector(BITS-1 downto 0);
        valid_in  : in  std_logic;
        scaling   : in  std_logic_vector(15 downto 0);
        i_out     : out std_logic_vector(PAR*WIDTH-1 downto 0);
        q_out     : out std_logic_vector(PAR*WIDTH-1 downto 0);
        bits_out  : out std_logic_vector(BITS-1 downto 0);
        valid_out : out std_logic);
end entity awgn;


architecture arch of awgn is

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

  -- Signal declarations
  signal rst_n : std_logic;

  type valid_rec is record
    i : std_logic;
    q : std_logic;
  end record valid_rec;
  type valid_type is array (0 to PAR-1) of valid_rec;
  signal valid : valid_type;

  type rand_rec is record               -- format: 5.11
    i : std_logic_vector(15 downto 0);
    q : std_logic_vector(15 downto 0);
  end record rand_rec;
  type rand_type is array (0 to PAR-1) of rand_rec;
  signal rand : rand_type;

  type noise_rec is record              -- format: 5.27
    i : signed(31 downto 0);
    q : signed(31 downto 0);
  end record noise_rec;
  type noise_type is array (0 to PAR-1) of noise_rec;
  signal noise     : noise_type;

  type data_rec is record               -- format: 1.WIDTH-1
    i : signed(WIDTH-1 downto 0);
    q : signed(WIDTH-1 downto 0);
  end record data_rec;
  type data_type is array (0 to PAR-1) of data_rec;
  signal input  : data_type;
  signal output : data_type;

begin

  -- Reset signal for GNG IP
  rst_n <= not rst;

  par_gen : for p in 0 to PAR-1 generate
    -- Sort i/o signals
    input(p).i                          <= signed(i_in((p+1)*WIDTH-1 downto p*WIDTH));
    input(p).q                          <= signed(q_in((p+1)*WIDTH-1 downto p*WIDTH));
    i_out((p+1)*WIDTH-1 downto p*WIDTH) <= std_logic_vector(output(p).i);
    q_out((p+1)*WIDTH-1 downto p*WIDTH) <= std_logic_vector(output(p).q);

    -- Generate gng instances
    gng_i : gng
      generic map (INIT_Z1 => SEEDS(6*p + 0),
                   INIT_Z2 => SEEDS(6*p + 1),
                   INIT_Z3 => SEEDS(6*p + 2))
      port map(clk       => clk,
               rstn      => rst_n,
               ce        => '1',
               valid_out => valid(p).i,
               data_out  => rand(p).i);


    gng_q : gng
      generic map (INIT_Z1 => SEEDS(6*p + 3),
                   INIT_Z2 => SEEDS(6*p + 4),
                   INIT_Z3 => SEEDS(6*p + 5))
      port map(clk       => clk,
               rstn      => rst_n,
               ce        => '1',
               valid_out => valid(p).q,
               data_out  => rand(p).q);

    -- Calculate noise 
    noise(p).i <= resize(signed(rand(p).i) * signed('0' & scaling), noise(p).i'length);
    noise(p).q <= resize(signed(rand(p).q) * signed('0' & scaling), noise(p).q'length);
  end generate par_gen;

  -- Output regisers
  output_proc : process (clk)
    variable all_valid : std_logic;
    variable i_sum     : signed(31 downto 0);  -- format: 5.27
    variable q_sum     : signed(31 downto 0);  -- format: 5.27
    variable i_check   : std_logic;
    variable q_check   : std_logic_vector(2 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        output    <= (others => (others => (others => '0')));
        bits_out  <= (others => '0');
        valid_out <= '0';
      else
        all_valid := valid_in;
        for p in 0 to PAR-1 loop
          all_valid := all_valid and valid(p).i and valid(p).q;
        end loop;
        if all_valid = '1' then
          valid_out <= '1';
          for p in 0 to PAR-1 loop
            i_sum := resize(input(p).i & (27-WIDTH downto 0 => '0'), noise(p).i'length) + noise(p).i;
            q_sum := resize(input(p).q & (27-WIDTH downto 0 => '0'), noise(p).q'length) + noise(p).q;
            -- Rouding
            i_sum := shift_right(shift_right(i_sum, 27-WIDTH) + 1, 1);
            q_sum := shift_right(shift_right(q_sum, 27-WIDTH) + 1, 1);
            -- Check for overflow and saturate output
            if i_sum(i_sum'left downto WIDTH-1) > 0 then
              output(p).i(WIDTH-1)          <= '0';
              output(p).i(WIDTH-2 downto 0) <= (others => '1');
              report("Positive Overflow in i ");
            elsif i_sum(i_sum'left downto WIDTH-1) < -1 then
              output(p).i(WIDTH-1)          <= '1';
              output(p).i(WIDTH-2 downto 0) <= (others => '0');
              report("Negative Overflow in i ");
            else
              output(p).i <= resize(i_sum, output(p).i'length);
            end if;
            if q_sum(q_sum'left downto WIDTH-1) > 0 then
              output(p).q(WIDTH-1)          <= '0';
              output(p).q(WIDTH-2 downto 0) <= (others => '1');
              report("Positive Overflow in q ");
            elsif q_sum(q_sum'left downto WIDTH-1) < -1 then
              output(p).q(WIDTH-1)          <= '1';
              output(p).q(WIDTH-2 downto 0) <= (others => '0');
              report("Negative Overflow in q ");
            else
              output(p).q <= resize(q_sum, output(p).q'length);
            end if;
          end loop;
          bits_out <= bits_in;
        else
          valid_out <= '0';
          output    <= (others => (others => (others => '0')));
          bits_out  <= (others => '0');
        end if;
      end if;
    end if;
  end process output_proc;

end architecture arch;

