-------------------------------------------------------------------------------
-- Title      : Demodulator
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : demodulator.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2019-07-03
-- Last update: 2022-02-28
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- Demodulator top component, instantiates the specified demodulator and
-- performs demodulation of the input symbols.
--
-------------------------------------------------------------------------------
-- Copyright (c) 2019 Erik Börjeson
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-07-03  1.0      erikbor Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity demodulator is
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
end entity demodulator;

architecture arch of demodulator is

  -- Component declarations
  component demod_BPSK is
    generic (WIDTH   : positive;
             MAX_AMP : real);
    port (i      : in  std_logic_vector;
          q      : in  std_logic_vector;
          binary : out std_logic);
  end component demod_BPSK;

  component demod_QPSK is
    generic (WIDTH   : positive;
             MAX_AMP : real);
    port (i      : in  std_logic_vector;
          q      : in  std_logic_vector;
          binary : out std_logic_vector);
  end component demod_QPSK;

  component demod_16QAM is
    generic (WIDTH   : positive;
             MAX_AMP : real);
    port (i      : in  std_logic_vector;
          q      : in  std_logic_vector;
          binary : out std_logic_vector);
  end component demod_16QAM;

  component demod_64QAM is
    generic (WIDTH   : positive;
             MAX_AMP : real);
    port (i      : in  std_logic_vector;
          q      : in  std_logic_vector;
          binary : out std_logic_vector);
  end component demod_64QAM;

  component demod_256QAM is
    generic (WIDTH   : positive;
             MAX_AMP : real);
    port (i      : in  std_logic_vector;
          q      : in  std_logic_vector;
          binary : out std_logic_vector);
  end component demod_256QAM;

  -- Signal declarations
  signal demod : std_logic_vector(MOD_BITS*PAR-1 downto 0);

begin

  -- Check for correct parameter values
  assert (MOD_TYPE = "BPSK" or
          MOD_TYPE = "QPSK" or
          MOD_TYPE = "16QAM" or
          MOD_TYPE = "64QAM" or
          MOD_TYPE = "246QAM")
    report "Invalid demodulator type: " & MOD_TYPE
    severity failure;

  -- Instantiate demodulator
  BPSK : if MOD_TYPE = "BPSK" generate
    assert MOD_BITS = 1
      report "Invalid number of bits for BPSK demodulation."
      severity failure;
    Demodulators : for p in 0 to PAR-1 generate
      Demodulator : demod_BPSK
        generic map (WIDTH   => WIDTH,
                     MAX_AMP => MAX_AMP)
        port map (i      => i_in((p+1)*WIDTH -1 downto p*WIDTH),
                  q      => q_in((p+1)*WIDTH -1 downto p*WIDTH),
                  binary => demod(p));
    end generate Demodulators;
  end generate BPSK;


  QPSK : if MOD_TYPE = "QPSK" generate
    assert MOD_BITS = 2
      report "Invalid number of bits for QPSK demodulation."
      severity failure;
    Demodulators : for p in 0 to PAR-1 generate
      Demodulator : demod_QPSK
        generic map (WIDTH   => WIDTH,
                     MAX_AMP => MAX_AMP)
        port map (i      => i_in((p+1)*WIDTH -1 downto p*WIDTH),
                  q      => q_in((p+1)*WIDTH -1 downto p*WIDTH),
                  binary => demod((p+1)*2-1 downto p*2));
    end generate Demodulators;
  end generate QPSK;

  QAM16 : if MOD_TYPE = "16QAM" generate
    assert MOD_BITS = 4
      report "Invalid number of bits for 16QAM demodulation."
      severity failure;
    Demodulators : for p in 0 to PAR-1 generate
      Demodulator : demod_16QAM
        generic map (WIDTH   => WIDTH,
                     MAX_AMP => MAX_AMP)
        port map (i      => i_in((p+1)*WIDTH -1 downto p*WIDTH),
                  q      => q_in((p+1)*WIDTH -1 downto p*WIDTH),
                  binary => demod((p+1)*4-1 downto p*4));
    end generate Demodulators;
  end generate QAM16;

  QAM64 : if MOD_TYPE = "64QAM" generate
    assert MOD_BITS = 6
      report "Invalid number of bits for 64QAM demodulation."
      severity failure;
    Demodulators : for p in 0 to PAR-1 generate
      Demodulator : demod_64QAM
        generic map (WIDTH   => WIDTH,
                     MAX_AMP => MAX_AMP)
        port map (i      => i_in((p+1)*WIDTH -1 downto p*WIDTH),
                  q      => q_in((p+1)*WIDTH -1 downto p*WIDTH),
                  binary => demod((p+1)*6-1 downto p*6));
    end generate Demodulators;
  end generate QAM64;

  QAM256 : if MOD_TYPE = "256QAM" generate
    assert MOD_BITS = 8
      report "Invalid number of bits for 256QAM demodulation."
      severity failure;
    Demodulators : for p in 0 to PAR-1 generate
      Demodulator : demod_256QAM
        generic map (WIDTH   => WIDTH,
                     MAX_AMP => MAX_AMP)
        port map (i      => i_in((p+1)*WIDTH -1 downto p*WIDTH),
                  q      => q_in((p+1)*WIDTH -1 downto p*WIDTH),
                  binary => demod((p+1)*8-1 downto p*8));
    end generate Demodulators;
  end generate QAM256;

  -- Output registers
  output_proc : process (rst, clk)
  begin
    if rst = '1' then
      demod_out <= (others => '0');
      bits_out  <= (others => '0');
      valid_out <= '0';
    elsif rising_edge(clk) then
      if valid_in = '1' then
        demod_out <= demod;
        bits_out  <= bits_in;
        valid_out <= '1';
      end if;
    end if;
  end process output_proc;

end architecture arch;




