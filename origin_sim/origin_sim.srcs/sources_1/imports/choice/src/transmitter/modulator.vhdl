-------------------------------------------------------------------------------
-- Title      : Modulator
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : modulator.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2019-07-03
-- Last update: 2022-02-28
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- Modulator top component, instantiates the specified modulator and
-- performs modulation of the input bits.
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

entity modulator is
  generic (PAR      : positive              := 2;
           WIDTH    : positive              := 8;
           MOD_BITS : positive              := 1;
           MOD_TYPE : string                := "BPSK";
           MAX_AMP  : real range 0.0 to 1.0 := 1.0);
  port (clk       : in  std_logic;
        rst       : in  std_logic;
        bits_in   : in  std_logic_vector(PAR*MOD_BITS-1 downto 0);
        valid_in  : in  std_logic;
        i_out     : out std_logic_vector(PAR*WIDTH-1 downto 0);
        q_out     : out std_logic_vector(PAR*WIDTH-1 downto 0);
        bits_out  : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
        valid_out : out std_logic);
end entity modulator;

architecture arch of modulator is

  -- Component declarations
  component mod_BPSK is
    generic (WIDTH   : positive;
             MAX_AMP : real);
    port (binary : in  std_logic;
          i      : out std_logic_vector;
          q      : out std_logic_vector);
  end component mod_BPSK;

  component mod_QPSK is
    generic (WIDTH   : positive;
             MAX_AMP : real);
    port (binary : in  std_logic_vector;
          i      : out std_logic_vector;
          q      : out std_logic_vector);
  end component mod_QPSK;

  component mod_16QAM is
    generic (WIDTH   : positive;
             MAX_AMP : real);
    port (binary : in  std_logic_vector;
          i      : out std_logic_vector;
          q      : out std_logic_vector);
  end component mod_16QAM;

  component mod_64QAM is
    generic (WIDTH   : positive;
             MAX_AMP : real);
    port (binary : in  std_logic_vector;
          i      : out std_logic_vector;
          q      : out std_logic_vector);
  end component mod_64QAM;

  component mod_256QAM is
    generic (WIDTH   : positive;
             MAX_AMP : real);
    port (binary : in  std_logic_vector;
          i      : out std_logic_vector;
          q      : out std_logic_vector);
  end component mod_256QAM;

  -- Signal declarations
  signal mod_i : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal mod_q : std_logic_vector(PAR*WIDTH-1 downto 0);

begin

  -- Check for correct parameter values
  assert (MOD_TYPE = "BPSK" or
          MOD_TYPE = "QPSK" or
          MOD_TYPE = "16QAM" or
          MOD_TYPE = "64QAM" or
          MOD_TYPE = "256QAM")
    report "Invalid modulator type: " & MOD_TYPE
    severity failure;

  -- Instantiate modulator
  BPSK : if MOD_TYPE = "BPSK" generate
    assert MOD_BITS = 1
      report "Invalid number of bits for BPSK modulation."
      severity failure;
    Modulators : for p in 0 to PAR-1 generate
      Modulator : mod_BPSK
        generic map (WIDTH   => WIDTH,
                     MAX_AMP => MAX_AMP)
        port map (binary => bits_in(p),
                  i      => mod_i((p+1)*WIDTH -1 downto p*WIDTH),
                  q      => mod_q((p+1)*WIDTH -1 downto p*WIDTH));
    end generate Modulators;
  end generate BPSK;


  QPSK : if MOD_TYPE = "QPSK" generate
    assert MOD_BITS = 2
      report "Invalid number of bits for QPSK modulation."
      severity failure;
    Modulators : for p in 0 to PAR-1 generate
      Modulator : mod_QPSK
        generic map (WIDTH   => WIDTH,
                     MAX_AMP => MAX_AMP)
        port map (binary => bits_in((p+1)*2-1 downto p*2),
                  i      => mod_i((p+1)*WIDTH -1 downto p*WIDTH),
                  q      => mod_q((p+1)*WIDTH -1 downto p*WIDTH));
    end generate Modulators;
  end generate QPSK;

  QAM16 : if MOD_TYPE = "16QAM" generate
    assert MOD_BITS = 4
      report "Invalid number of bits for 16QAM modulation."
      severity failure;
    Modulators : for p in 0 to PAR-1 generate
      Modulator : mod_16QAM
        generic map (WIDTH   => WIDTH,
                     MAX_AMP => MAX_AMP)
        port map (binary => bits_in((p+1)*4-1 downto p*4),
                  i      => mod_i((p+1)*WIDTH -1 downto p*WIDTH),
                  q      => mod_q((p+1)*WIDTH -1 downto p*WIDTH));
    end generate Modulators;
  end generate QAM16;

  QAM64 : if MOD_TYPE = "64QAM" generate
    assert MOD_BITS = 6
      report "Invalid number of bits for 64QAM modulation."
      severity failure;
    Modulators : for p in 0 to PAR-1 generate
      Modulator : mod_64QAM
        generic map (WIDTH   => WIDTH,
                     MAX_AMP => MAX_AMP)
        port map (binary => bits_in((p+1)*6-1 downto p*6),
                  i      => mod_i((p+1)*WIDTH -1 downto p*WIDTH),
                  q      => mod_q((p+1)*WIDTH -1 downto p*WIDTH));
    end generate Modulators;
  end generate QAM64;

  QAM256 : if MOD_TYPE = "256QAM" generate
    assert MOD_BITS = 8
      report "Invalid number of bits for 256QAM modulation."
      severity failure;
    Modulators : for p in 0 to PAR-1 generate
      Modulator : mod_256QAM
        generic map (WIDTH   => WIDTH,
                     MAX_AMP => MAX_AMP)
        port map (binary => bits_in((p+1)*8-1 downto p*8),
                  i      => mod_i((p+1)*WIDTH -1 downto p*WIDTH),
                  q      => mod_q((p+1)*WIDTH -1 downto p*WIDTH));
    end generate Modulators;
  end generate QAM256;

  -- Output register
  output_proc : process(rst, clk)
  begin
    if rst = '1' then
      i_out     <= (others => '0');
      q_out     <= (others => '0');
      bits_out  <= (others => '0');
      valid_out <= '0';
    elsif rising_edge(clk) then
      if valid_in = '1' then
        i_out     <= mod_i;
        q_out     <= mod_q;
        bits_out  <= bits_in;
        valid_out <= '1';
      end if;
    end if;
  end process output_proc;


end architecture arch;




