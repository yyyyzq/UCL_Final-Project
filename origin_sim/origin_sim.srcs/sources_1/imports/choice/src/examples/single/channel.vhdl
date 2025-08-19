-------------------------------------------------------------------------------
-- Title      : Channel for a Single Polarization Setup
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : channel.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2022-02-28
-- Last update: 2022-03-03
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- Channel a dual polarization setup, including AWGN and phase noise.
--
-------------------------------------------------------------------------------
-- Copyright (c) 2022 Erik Börjeson
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2022-02-28  1.0      erikbor Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity channel is
  generic (PAR            : positive := 2;
           WIDTH          : positive := 8;
           BITS           : positive := 4;
           PN_PHASE_WIDTH : positive := 16;
           PN_LUT_WIDTH   : positive := 16);
  port (clk          : in  std_logic;
        rst          : in  std_logic;
        i_in         : in  std_logic_vector(PAR*WIDTH-1 downto 0);
        q_in         : in  std_logic_vector(PAR*WIDTH-1 downto 0);
        bits_in      : in  std_logic_vector(BITS-1 downto 0);
        valid_in     : in  std_logic;
        awgn_scaling : in  std_logic_vector(15 downto 0);
        pn_scaling   : in  std_logic_vector(15 downto 0);
        i_out        : out std_logic_vector(PAR*WIDTH-1 downto 0);
        q_out        : out std_logic_vector(PAR*WIDTH-1 downto 0);
        bits_out     : out std_logic_vector(BITS-1 downto 0);
        valid_out    : out std_logic);
end entity channel;

architecture arch of channel is

  component awgn is
    generic (PAR   : positive;
             WIDTH : positive;
             BITS  : positive);
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
  end component awgn;

  component phase_noise is
    generic (PAR         : positive;
             WIDTH       : positive;
             BITS        : positive;
             PHASE_WIDTH : positive;
             LUT_WIDTH   : positive);
    port (clk        : in  std_logic;
          rst        : in  std_logic;
          x_i_in     : in  std_logic_vector(PAR*WIDTH-1 downto 0);
          x_q_in     : in  std_logic_vector(PAR*WIDTH-1 downto 0);
          y_i_in     : in  std_logic_vector(PAR*WIDTH-1 downto 0) := (others => '0');
          y_q_in     : in  std_logic_vector(PAR*WIDTH-1 downto 0) := (others => '0');
          bits_x_in  : in  std_logic_vector(BITS-1 downto 0);
          bits_y_in  : in  std_logic_vector(BITS-1 downto 0)      := (others => '0');
          valid_in   : in  std_logic;
          scaling    : in  std_logic_vector(15 downto 0);
          x_i_out    : out std_logic_vector(PAR*WIDTH-1 downto 0);
          x_q_out    : out std_logic_vector(PAR*WIDTH-1 downto 0);
          y_i_out    : out std_logic_vector(PAR*WIDTH-1 downto 0);
          y_q_out    : out std_logic_vector(PAR*WIDTH-1 downto 0);
          bits_x_out : out std_logic_vector(BITS-1 downto 0);
          bits_y_out : out std_logic_vector(BITS-1 downto 0);
          valid_out  : out std_logic);
  end component phase_noise;
  


  signal i_awgn     : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal q_awgn     : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal bits_awgn  : std_logic_vector(BITS-1 downto 0);
  signal valid_awgn : std_logic;

  signal i_pn     : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal q_pn     : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal bits_pn  : std_logic_vector(BITS-1 downto 0);
  signal valid_pn : std_logic;


begin

  awgn_inst : component awgn
    generic map (PAR   => PAR,
                 WIDTH => WIDTH,
                 BITS  => BITS)
    port map(clk       => clk,
             rst       => rst,
             i_in      => i_in,
             q_in      => q_in,
             bits_in   => bits_in,
             valid_in  => valid_in,
             scaling   => awgn_scaling,
             i_out     => i_awgn,
             q_out     => q_awgn,
             bits_out  => bits_awgn,
             valid_out => valid_awgn);

  phase_noise_inst : component phase_noise
    generic map (PAR         => PAR,
                 WIDTH       => WIDTH,
                 BITS        => BITS,
                 PHASE_WIDTH => PN_PHASE_WIDTH,
                 LUT_WIDTH   => PN_LUT_WIDTH)
    port map(clk        => clk,
             rst        => rst,
             x_i_in     => i_awgn,
             x_q_in     => q_awgn,
             y_i_in     => open,
             y_q_in     => open,
             bits_x_in  => bits_awgn,
             bits_y_in  => open,
             valid_in   => valid_awgn,
             scaling    => pn_scaling,
             x_i_out    => i_pn,
             x_q_out    => q_pn,
             y_i_out    => open,
             y_q_out    => open,
             bits_x_out => bits_pn,
             bits_y_out => open,
             valid_out  => valid_pn);
    

    
  i_out     <= i_pn;
  q_out     <= q_pn;
  bits_out  <= bits_pn;
  valid_out <= valid_pn;

end architecture arch;
