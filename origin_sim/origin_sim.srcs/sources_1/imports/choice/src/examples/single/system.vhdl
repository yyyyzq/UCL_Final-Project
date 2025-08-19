-------------------------------------------------------------------------------
-- Title      : Single Polarization System 
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : system.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2022-03-01
-- Last update: 2022-03-02
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- Description of the complete fiber-optic system including transmitter,
-- channel and receiver.
--
-------------------------------------------------------------------------------
-- Copyright (c) 2022 Erik Börjeson
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2022-03-01  1.0      erikbor Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity system is
  generic (PAR            : positive              := 2;
           WIDTH          : positive              := 8;
           MAX_AMP        : real range 0.0 to 1.0 := 0.5;
           MOD_TYPE       : string                := "QPSK";
           MOD_BITS       : positive              := 2;
           PN_PHASE_WIDTH : positive              := 16;
           PN_LUT_WIDTH   : positive              := 16);
  port(clk          : in  std_logic;
       rst          : in  std_logic;
       awgn_scaling : in  std_logic_vector(15 downto 0);
       pn_scaling   : in  std_logic_vector(15 downto 0);
       bits_demod   : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
       bits_ref     : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
       valid_out    : out std_logic);
end entity system;

architecture arch of system is

  constant BITS : positive := PAR*MOD_BITS;

  component transmitter is
    generic (PAR      : positive;
             WIDTH    : positive;
             MAX_AMP  : real range 0.0 to 1.0;
             MOD_TYPE : string;
             MOD_BITS : positive);
    port (clk       : in  std_logic;
          rst       : in  std_logic;
          i_out     : out std_logic_vector(PAR*WIDTH-1 downto 0);
          q_out     : out std_logic_vector(PAR*WIDTH-1 downto 0);
          bits_out  : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
          valid_out : out std_logic);
  end component transmitter;

  component channel is
    generic (PAR            : positive;
             WIDTH          : positive;
             BITS           : positive;
             PN_PHASE_WIDTH : positive;
             PN_LUT_WIDTH   : positive);
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
  end component channel;

  component receiver is
    generic (PAR      : positive;
             WIDTH    : positive;
             MOD_BITS : positive;
             MOD_TYPE : string;
             MAX_AMP  : real range 0.0 to 1.0);
    port (clk       : in  std_logic;
          rst       : in  std_logic;
          i_in      : in  std_logic_vector(PAR*WIDTH-1 downto 0);
          q_in      : in  std_logic_vector(PAR*WIDTH-1 downto 0);
          bits_in   : in  std_logic_vector(PAR*MOD_BITS-1 downto 0);
          valid_in  : in  std_logic;
          demod_out : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
          bits_out  : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
          valid_out : out std_logic);
  end component receiver;

  signal i_tx     : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal q_tx     : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal bits_tx  : std_logic_vector(PAR*MOD_BITS-1 downto 0);
  signal valid_tx : std_logic;

  signal i_ch     : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal q_ch     : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal bits_ch  : std_logic_vector(PAR*MOD_BITS-1 downto 0);
  signal valid_ch : std_logic;

begin

  transmitter_inst : component transmitter
    generic map (PAR      => PAR,
                 WIDTH    => WIDTH,
                 MAX_AMP  => MAX_AMP,
                 MOD_TYPE => MOD_TYPE,
                 MOD_BITS => MOD_BITS)
    port map (clk       => clk,
              rst       => rst,
              i_out     => i_tx,
              q_out     => q_tx,
              bits_out  => bits_tx,
              valid_out => valid_tx);

  channel_inst : component channel
    generic map (PAR            => PAR,
                 WIDTH          => WIDTH,
                 BITS           => BITS,
                 PN_PHASE_WIDTH => PN_PHASE_WIDTH,
                 PN_LUT_WIDTH   => PN_LUT_WIDTH)
    port map (clk          => clk,
              rst          => rst,
              i_in         => i_tx,
              q_in         => q_tx,
              bits_in      => bits_tx,
              valid_in     => valid_tx,
              awgn_scaling => awgn_scaling,
              pn_scaling   => pn_scaling,
              i_out        => i_ch,
              q_out        => q_ch,
              bits_out     => bits_ch,
              valid_out    => valid_ch);

  receiver_inst : component receiver
    generic map (PAR      => PAR,
                 WIDTH    => WIDTH,
                 MOD_BITS => MOD_BITS,
                 MOD_TYPE => MOD_TYPE,
                 MAX_AMP  => MAX_AMP)
    port map (clk       => clk,
              rst       => rst,
              i_in      => i_ch,
              q_in      => q_ch,
              bits_in   => bits_ch,
              valid_in  => valid_ch,
              demod_out => bits_demod,
              bits_out  => bits_ref,
              valid_out => valid_out);

end architecture arch;
