-------------------------------------------------------------------------------
-- File: receiver_awgn_only.vhdl
-- Description: Receiver for AWGN-only path (no DSP, no BPS)
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity receiver_awgn_only is
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
end entity receiver_awgn_only;

architecture arch of receiver_awgn_only is

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

begin

  -- Direct demodulation without any DSP processing
  demodulator_inst : component demodulator
    generic map (PAR      => PAR,
                 WIDTH    => WIDTH,
                 MOD_BITS => MOD_BITS,
                 MOD_TYPE => MOD_TYPE,
                 MAX_AMP  => MAX_AMP)
    port map (clk       => clk,
              rst       => rst,
              i_in      => i_in,
              q_in      => q_in,
              bits_in   => bits_in,
              valid_in  => valid_in,
              demod_out => demod_out,
              bits_out  => bits_out,
              valid_out => valid_out);

end architecture arch;