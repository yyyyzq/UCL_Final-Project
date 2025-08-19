-------------------------------------------------------------------------------
-- Title      : PMD Emulator
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : pmd.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2022-02-24
-- Last update: 2022-02-24
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- Emulates PMD using a waveplate model with SECTIONS_N sections.
--
-------------------------------------------------------------------------------
-- Copyright (c) 2022 Erik Börjeson
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2022-02-24  1.0      erikbor Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pmd is
  generic (WIDTH         : positive := 8;
           BITS          : positive := 2;
           SECTIONS_N    : positive := 10;
           THETA_WIDTH   : positive := 10;
           COUNTER_WIDTH : positive := 24;
           TAP_WIDTH     : positive := 10;
           TAPS_N        : positive := 5;
           PHI_WIDTH     : positive := 10);
  port (clk         : in  std_logic;
        rst         : in  std_logic;
        x_i_in      : in  std_logic_vector(2*WIDTH-1 downto 0);
        x_q_in      : in  std_logic_vector(2*WIDTH-1 downto 0);
        y_i_in      : in  std_logic_vector(2*WIDTH-1 downto 0);
        y_q_in      : in  std_logic_vector(2*WIDTH-1 downto 0);
        bits_x_in   : in  std_logic_vector(BITS-1 downto 0);
        bits_y_in   : in  std_logic_vector(BITS-1 downto 0);
        valid_in    : in  std_logic;
        theta_start : in  std_logic_vector((SECTIONS_N+1)*THETA_WIDTH-1 downto 0);
        count_max   : in  std_logic_vector((SECTIONS_N+1)*COUNTER_WIDTH-1 downto 0);
        direction   : in  std_logic_vector(SECTIONS_N downto 0);
        taps        : in  std_logic_vector(TAPS_N*TAP_WIDTH-1 downto 0);
        phi         : in  std_logic_vector(SECTIONS_N*PHI_WIDTH-1 downto 0);
        x_i_out     : out std_logic_vector(2*WIDTH-1 downto 0);
        x_q_out     : out std_logic_vector(2*WIDTH-1 downto 0);
        y_i_out     : out std_logic_vector(2*WIDTH-1 downto 0);
        y_q_out     : out std_logic_vector(2*WIDTH-1 downto 0);
        bits_x_out  : out std_logic_vector(BITS-1 downto 0);
        bits_y_out  : out std_logic_vector(BITS-1 downto 0);
        valid_out   : out std_logic);
end entity pmd;

architecture arch of pmd is

  component theta_update is
    generic (THETA_WIDTH   : positive;
             COUNTER_WIDTH : positive);
    port (clk       : in  std_logic;
          rst       : in  std_logic;
          count_max : in  std_logic_vector(COUNTER_WIDTH-1 downto 0);
          start     : in  std_logic_vector(THETA_WIDTH-1 downto 0);
          direction : in  std_logic;
          theta     : out std_logic_vector(THETA_WIDTH-1 downto 0));
  end component theta_update;

  component pmd_rotation is
    generic (WIDTH       : positive;
             BITS        : positive;
             THETA_WIDTH : positive);
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
  end component pmd_rotation;

  component pmd_delay is
    generic (WIDTH     : positive;
             BITS      : positive;
             TAP_WIDTH : positive;
             TAPS_N    : positive);
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
  end component pmd_delay;

  component pmd_phase is
    generic (WIDTH     : positive;
             BITS      : positive;
             PHI_WIDTH : positive);
    port (clk        : in  std_logic;
          rst        : in  std_logic;
          x_i_in     : in  std_logic_vector(2*WIDTH-1 downto 0);
          x_q_in     : in  std_logic_vector(2*WIDTH-1 downto 0);
          y_i_in     : in  std_logic_vector(2*WIDTH-1 downto 0);
          y_q_in     : in  std_logic_vector(2*WIDTH-1 downto 0);
          bits_x_in  : in  std_logic_vector(BITS-1 downto 0);
          bits_y_in  : in  std_logic_vector(BITS-1 downto 0);
          valid_in   : in  std_logic;
          phi        : in  std_logic_vector(PHI_WIDTH-1 downto 0);
          x_i_out    : out std_logic_vector(2*WIDTH-1 downto 0);
          x_q_out    : out std_logic_vector(2*WIDTH-1 downto 0);
          y_i_out    : out std_logic_vector(2*WIDTH-1 downto 0);
          y_q_out    : out std_logic_vector(2*WIDTH-1 downto 0);
          bits_x_out : out std_logic_vector(BITS-1 downto 0);
          bits_y_out : out std_logic_vector(BITS-1 downto 0);
          valid_out  : out std_logic);
  end component pmd_phase;

  type count_max_arr_type is array (0 to SECTIONS_N) of std_logic_vector(COUNTER_WIDTH-1 downto 0);
  type theta_type is array (0 to SECTIONS_N) of std_logic_vector(THETA_WIDTH-1 downto 0);
  type phi_type is array (1 to SECTIONS_N) of std_logic_vector(PHI_WIDTH-1 downto 0);
  type data_rot_type is array (0 to SECTIONS_N) of std_logic_vector(2*WIDTH-1 downto 0);
  type bits_rot_type is array (0 to SECTIONS_N) of std_logic_vector(BITS-1 downto 0);
  type valid_rot_type is array (0 to SECTIONS_N) of std_logic;
  type data_dly_type is array (1 to SECTIONS_N) of std_logic_vector(2*WIDTH-1 downto 0);
  type bits_dly_type is array (1 to SECTIONS_N) of std_logic_vector(BITS-1 downto 0);
  type valid_dly_type is array (1 to SECTIONS_N) of std_logic;
  type data_phase_type is array (1 to SECTIONS_N) of std_logic_vector(2*WIDTH-1 downto 0);
  type bits_phase_type is array (1 to SECTIONS_N) of std_logic_vector(BITS-1 downto 0);
  type valid_phase_type is array (1 to SECTIONS_N) of std_logic;

  signal x_i_rot    : data_rot_type;
  signal x_q_rot    : data_rot_type;
  signal y_i_rot    : data_rot_type;
  signal y_q_rot    : data_rot_type;
  signal bits_x_rot : bits_rot_type;
  signal bits_y_rot : bits_rot_type;
  signal valid_rot  : valid_rot_type;

  signal x_i_dly    : data_dly_type;
  signal x_q_dly    : data_dly_type;
  signal y_i_dly    : data_dly_type;
  signal y_q_dly    : data_dly_type;
  signal bits_x_dly : bits_dly_type;
  signal bits_y_dly : bits_dly_type;
  signal valid_dly  : valid_dly_type;

  signal x_i_phase    : data_phase_type;
  signal x_q_phase    : data_phase_type;
  signal y_i_phase    : data_phase_type;
  signal y_q_phase    : data_phase_type;
  signal bits_x_phase : bits_phase_type;
  signal bits_y_phase : bits_phase_type;
  signal valid_phase  : valid_phase_type;

  signal count_max_arr   : count_max_arr_type;
  signal theta           : theta_type;
  signal theta_start_arr : theta_type;
  signal phi_arr         : phi_type;

begin

  -- Sort parameter inputs
  theta_sort_gen : for sec_idx in 0 to SECTIONS_N generate
    count_max_arr(sec_idx)   <= count_max((sec_idx+1)*COUNTER_WIDTH-1 downto sec_idx*COUNTER_WIDTH);
    theta_start_arr(sec_idx) <= theta_start((sec_idx+1)*THETA_WIDTH-1 downto sec_idx*THETA_WIDTH);
  end generate theta_sort_gen;

  phi_sort_gen : for sec_idx in 0 to SECTIONS_N-1 generate
    phi_arr(sec_idx+1) <= phi((sec_idx+1)*PHI_WIDTH-1 downto sec_idx*PHI_WIDTH);
  end generate phi_sort_gen;

  -- PMD rotation generator
  theta_update_gen : for inst_idx in 0 to SECTIONS_N generate
    theta_update_inst : component theta_update
      generic map (THETA_WIDTH   => THETA_WIDTH,
                   COUNTER_WIDTH => COUNTER_WIDTH)
      port map (clk       => clk,
                rst       => rst,
                count_max => count_max_arr(inst_idx),
                start     => theta_start_arr(inst_idx),
                direction => direction(inst_idx),
                theta     => theta(inst_idx));
  end generate theta_update_gen;


  -- First PMD rotation
  pmd_rotation_inst : component pmd_rotation
    generic map (WIDTH       => WIDTH,
                 BITS        => BITS,
                 THETA_WIDTH => THETA_WIDTH)
    port map (clk        => clk,
              rst        => rst,
              x_i_in     => x_i_in,
              x_q_in     => x_q_in,
              y_i_in     => y_i_in,
              y_q_in     => y_q_in,
              bits_x_in  => bits_x_in,
              bits_y_in  => bits_y_in,
              valid_in   => valid_in,
              theta      => theta(0),
              x_i_out    => x_i_rot(0),
              x_q_out    => x_q_rot(0),
              y_i_out    => y_i_rot(0),
              y_q_out    => y_q_rot(0),
              bits_x_out => bits_x_rot(0),
              bits_y_out => bits_y_rot(0),
              valid_out  => valid_rot(0));


  -- PMD sections
  sections_gen : for inst_idx in 1 to SECTIONS_N generate
    
    pmd_delay_inst : component pmd_delay
      generic map (WIDTH     => WIDTH,
                   BITS      => BITS,
                   TAP_WIDTH => TAP_WIDTH,
                   TAPS_N    => TAPS_N)
      port map (clk        => clk,
                rst        => rst,
                x_i_in     => x_i_rot(inst_idx-1),
                x_q_in     => x_q_rot(inst_idx-1),
                y_i_in     => y_i_rot(inst_idx-1),
                y_q_in     => y_q_rot(inst_idx-1),
                bits_x_in  => bits_x_rot(inst_idx-1),
                bits_y_in  => bits_y_rot(inst_idx-1),
                valid_in   => valid_rot(inst_idx-1),
                taps       => taps,
                x_i_out    => x_i_dly(inst_idx),
                x_q_out    => x_q_dly(inst_idx),
                y_i_out    => y_i_dly(inst_idx),
                y_q_out    => y_q_dly(inst_idx),
                bits_x_out => bits_x_dly(inst_idx),
                bits_y_out => bits_y_dly(inst_idx),
                valid_out  => valid_dly(inst_idx));

    pmd_phase_inst : component pmd_phase
      generic map (WIDTH     => WIDTH,
                   BITS      => BITS,
                   PHI_WIDTH => PHI_WIDTH)
      port map (clk        => clk,
                rst        => rst,
                x_i_in     => x_i_dly(inst_idx),
                x_q_in     => x_q_dly(inst_idx),
                y_i_in     => y_i_dly(inst_idx),
                y_q_in     => y_q_dly(inst_idx),
                bits_x_in  => bits_x_dly(inst_idx),
                bits_y_in  => bits_y_dly(inst_idx),
                valid_in   => valid_dly(inst_idx),
                phi        => phi_arr(inst_idx),
                x_i_out    => x_i_phase(inst_idx),
                x_q_out    => x_q_phase(inst_idx),
                y_i_out    => y_i_phase(inst_idx),
                y_q_out    => y_q_phase(inst_idx),
                bits_x_out => bits_x_phase(inst_idx),
                bits_y_out => bits_y_phase(inst_idx),
                valid_out  => valid_phase(inst_idx));

    pmd_rotation_inst : component pmd_rotation
      generic map (WIDTH       => WIDTH,
                   BITS        => BITS,
                   THETA_WIDTH => THETA_WIDTH)
      port map (clk        => clk,
                rst        => rst,
                x_i_in     => x_i_phase(inst_idx),
                x_q_in     => x_q_phase(inst_idx),
                y_i_in     => y_i_phase(inst_idx),
                y_q_in     => y_q_phase(inst_idx),
                bits_x_in  => bits_x_phase(inst_idx),
                bits_y_in  => bits_y_phase(inst_idx),
                valid_in   => valid_phase(inst_idx),
                theta      => theta(inst_idx),
                x_i_out    => x_i_rot(inst_idx),
                x_q_out    => x_q_rot(inst_idx),
                y_i_out    => y_i_rot(inst_idx),
                y_q_out    => y_q_rot(inst_idx),
                bits_x_out => bits_x_rot(inst_idx),
                bits_y_out => bits_y_rot(inst_idx),
                valid_out  => valid_rot(inst_idx));

  end generate sections_gen;

  x_i_out    <= x_i_rot(SECTIONS_N);
  x_q_out    <= x_q_rot(SECTIONS_N);
  y_i_out    <= y_i_rot(SECTIONS_N);
  y_q_out    <= y_q_rot(SECTIONS_N);
  bits_x_out <= bits_x_rot(SECTIONS_N);
  bits_y_out <= bits_y_rot(SECTIONS_N);
  valid_out  <= valid_rot(SECTIONS_N);

end architecture arch;
