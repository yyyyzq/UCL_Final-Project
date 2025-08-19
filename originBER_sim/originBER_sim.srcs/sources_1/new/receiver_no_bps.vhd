-------------------------------------------------------------------------------
-- File: receiver_no_bps.vhdl
-- Description: Receiver with DSP but without BPS (for PN comparison)
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity receiver_no_bps is
  generic (PAR      : positive              := 2;
           WIDTH    : positive              := 8;
           MOD_BITS : positive              := 4;
           MOD_TYPE : string                := "16QAM";
           MAX_AMP  : real range 0.0 to 1.0 := 1.0);
  port (clk       : in  std_logic;
        rst       : in  std_logic;
        i_in      : in  std_logic_vector(PAR*WIDTH-1 downto 0);
        q_in      : in  std_logic_vector(PAR*WIDTH-1 downto 0);
        bits_in   : in  std_logic_vector(PAR*MOD_BITS-1 downto 0);
        valid_in  : in  std_logic;
        demod_out : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
        bits_out  : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
        valid_out : out std_logic);
end entity receiver_no_bps;

architecture arch of receiver_no_bps is

  constant BITS : positive := PAR*MOD_BITS;

  component dsp is
    generic(PAR   : positive;
            WIDTH : positive;
            BITS  : positive);
    port (clk       : in  std_logic;
          rst       : in  std_logic;
          i_in      : in  std_logic_vector(PAR*WIDTH-1 downto 0);
          q_in      : in  std_logic_vector(PAR*WIDTH-1 downto 0);
          bits_in   : in  std_logic_vector(BITS-1 downto 0);
          valid_in  : in  std_logic;
          i_out     : out std_logic_vector(PAR*WIDTH-1 downto 0);
          q_out     : out std_logic_vector(PAR*WIDTH-1 downto 0);
          bits_out  : out std_logic_vector(BITS-1 downto 0);
          valid_out : out std_logic);
  end component dsp;

  component demodulator is
    generic (PAR      : positive;
             MOD_BITS : positive;
             MOD_TYPE : string;
             WIDTH    : positive;
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
  end component demodulator;

  signal i_dsp     : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal q_dsp     : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal bits_dsp  : std_logic_vector(BITS-1 downto 0);
  signal valid_dsp : std_logic;

begin

  -- DSP processing but no BPS
  dsp_inst : component dsp
    generic map(PAR   => PAR,
                WIDTH => WIDTH,
                BITS  => BITS)
    port map (clk       => clk,
              rst       => rst,
              i_in      => i_in,
              q_in      => q_in,
              bits_in   => bits_in,
              valid_in  => valid_in,
              i_out     => i_dsp,
              q_out     => q_dsp,
              bits_out  => bits_dsp,
              valid_out => valid_dsp);

  -- Direct demodulation without BPS
  demodulator_inst : component demodulator
    generic map (PAR      => PAR,
                 WIDTH    => WIDTH,
                 MOD_BITS => MOD_BITS,
                 MOD_TYPE => MOD_TYPE,
                 MAX_AMP  => MAX_AMP)
    port map (clk       => clk,
              rst       => rst,
              i_in      => i_dsp,
              q_in      => q_dsp,
              bits_in   => bits_dsp,
              valid_in  => valid_dsp,
              demod_out => demod_out,
              bits_out  => bits_out,
              valid_out => valid_out);

end architecture arch;