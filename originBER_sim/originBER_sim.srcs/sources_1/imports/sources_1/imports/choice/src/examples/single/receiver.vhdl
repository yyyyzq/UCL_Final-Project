-------------------------------------------------------------------------------
-- 使用智能BPS的receiver
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;

entity receiver is
  generic (PAR      : positive              := 2;
           WIDTH    : positive              := 8;
           MOD_BITS : positive              := 2;
           MOD_TYPE : string                := "QPSK";
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
end entity receiver;

architecture arch of receiver is

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
  
  component bps is
    generic(
      PAR     : positive;
      WIDTH   : positive;
      WINLEN  : positive;
      PHASES  : positive
    );
    port(
      clk        : in  std_logic;
      rst        : in  std_logic;
      i_in       : in  std_logic_vector(PAR*WIDTH-1 downto 0);
      q_in       : in  std_logic_vector(PAR*WIDTH-1 downto 0);
      valid_in   : in  std_logic;
      i_out      : out std_logic_vector(PAR*WIDTH-1 downto 0);
      q_out      : out std_logic_vector(PAR*WIDTH-1 downto 0);
      valid_out  : out std_logic
    );
  end component;

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
  
  signal i_bps     : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal q_bps     : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal valid_bps : std_logic;

  -- 延迟匹配demodulator
  constant DEMOD_DELAY : positive := 25;
  type bits_delay_type is array (0 to DEMOD_DELAY-1) of std_logic_vector(PAR*MOD_BITS-1 downto 0);
  signal bits_delay_reg : bits_delay_type := (others => (others => '0'));

begin

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

  -- 使用智能BPS（减少参数，提高稳定性）
  bps_inst : component bps
    generic map(
      PAR     => PAR,
      WIDTH   => WIDTH,
      WINLEN  => 16,    -- 减少窗口长度
      PHASES  => 8      -- 减少相位数
    )
    port map(
      clk        => clk,
      rst        => rst,
      i_in       => i_dsp,
      q_in       => q_dsp,
      valid_in   => valid_dsp,
      i_out      => i_bps,
      q_out      => q_bps,
      valid_out  => valid_bps
    );

  -- 延迟匹配
  delay_proc : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        bits_delay_reg <= (others => (others => '0'));
      else
        for i in DEMOD_DELAY-1 downto 1 loop
          bits_delay_reg(i) <= bits_delay_reg(i-1);
        end loop;
        bits_delay_reg(0) <= bits_dsp;
      end if;
    end if;
  end process;

  -- 解调器
  demodulator_inst : component demodulator
    generic map (PAR      => PAR,
                 WIDTH    => WIDTH,
                 MOD_BITS => MOD_BITS,
                 MOD_TYPE => MOD_TYPE,
                 MAX_AMP  => MAX_AMP)
    port map (clk       => clk,
              rst       => rst,
              i_in      => i_bps,
              q_in      => q_bps,
              bits_in   => bits_dsp,
              valid_in  => valid_bps,
              demod_out => demod_out,
              bits_out  => open,
              valid_out => valid_out);

  -- 自己输出参考数据
  bits_out <= bits_delay_reg(DEMOD_DELAY-1);

end architecture arch;