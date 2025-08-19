-------------------------------------------------------------------------------
-- Title      : Channel with BPS Comparison Outputs (简化版)
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : channel.vhdl
-- Author     : 简化BPS对比，只在channel里增加必要输出
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- 保持原来的channel功能不变，只增加BPS对比需要的输出：
-- 1. awgn_only 输出 (作为参考)
-- 2. pn_only 输出 (AWGN+PN，但未经BPS处理)
-- 3. 正常输出保持不变 (AWGN+PN，会送到BPS处理)
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
        -- 正常输出（保持不变）
        i_out        : out std_logic_vector(PAR*WIDTH-1 downto 0);
        q_out        : out std_logic_vector(PAR*WIDTH-1 downto 0);
        bits_out     : out std_logic_vector(BITS-1 downto 0);
        valid_out    : out std_logic;
        -- BPS对比用的额外输出
        i_awgn_ref   : out std_logic_vector(PAR*WIDTH-1 downto 0);  -- AWGN-only参考
        q_awgn_ref   : out std_logic_vector(PAR*WIDTH-1 downto 0);
        bits_awgn_ref: out std_logic_vector(BITS-1 downto 0);
        valid_awgn_ref:out std_logic;
        i_pn_ref     : out std_logic_vector(PAR*WIDTH-1 downto 0);  -- PN但未经BPS
        q_pn_ref     : out std_logic_vector(PAR*WIDTH-1 downto 0);
        bits_pn_ref  : out std_logic_vector(BITS-1 downto 0);
        valid_pn_ref : out std_logic);
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

  -- 内部信号
  signal i_awgn     : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal q_awgn     : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal bits_awgn  : std_logic_vector(BITS-1 downto 0);
  signal valid_awgn : std_logic;
  
  signal i_pn     : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal q_pn     : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal bits_pn  : std_logic_vector(BITS-1 downto 0);
  signal valid_pn : std_logic;

begin

  -- AWGN处理（同时作为参考和下一级输入）
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

  -- Phase Noise处理
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
             x_i_out    => i_pn,         -- 输出到内部信号
             x_q_out    => q_pn,
             y_i_out    => open,
             y_q_out    => open,
             bits_x_out => bits_pn,
             bits_y_out => open,
             valid_out  => valid_pn);

  -- 输出分配
  -- 正常输出
  i_out     <= i_pn;
  q_out     <= q_pn;
  bits_out  <= bits_pn;
  valid_out <= valid_pn;
  
  -- BPS对比用的输出分配
  -- 1. AWGN参考（未经PN）
  i_awgn_ref    <= i_awgn;
  q_awgn_ref    <= q_awgn;
  bits_awgn_ref <= bits_awgn;
  valid_awgn_ref<= valid_awgn;
  
  -- 2. PN参考（经过PN但未经BPS）
  i_pn_ref      <= i_pn;
  q_pn_ref      <= q_pn;
  bits_pn_ref   <= bits_pn;
  valid_pn_ref  <= valid_pn;

  -- 内部信号用于正常输出

end architecture arch;