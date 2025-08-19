library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity system is
  generic (PAR            : positive              := 2;
           WIDTH          : positive              := 8;
           MAX_AMP        : real range 0.0 to 1.0 := 0.5;
           MOD_TYPE       : string                := "16QAM";
           MOD_BITS       : positive              := 4;
           PN_PHASE_WIDTH : positive              := 16;
           PN_LUT_WIDTH   : positive              := 16);
  port(clk              : in  std_logic;
       rst              : in  std_logic;
       awgn_scaling     : in  std_logic_vector(15 downto 0);
       pn_scaling       : in  std_logic_vector(15 downto 0);
       -- 正常输出（保持不变）
       bits_demod       : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
       bits_ref         : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
       valid_out        : out std_logic;
       -- BPS对比输出（延迟对齐后）
       bits_awgn_demod  : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
       bits_pn_demod    : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
       bits_bps_demod   : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
       valid_bps_comp   : out std_logic);
end entity system;

architecture arch of system is

  constant BITS : positive := PAR*MOD_BITS;

  -- ★ 关键修改：延迟常数定义 ★
  -- 你可能需要根据实际情况调整这些值
  constant DSP_DELAY         : integer := 2;   -- DSP模块延迟
  constant BPS_DELAY         : integer := 18;  -- BPS处理延迟
  constant DEMOD_DELAY       : integer := 1;   -- 解调器延迟
  
  -- 计算总延迟
  constant TOTAL_BPS_DELAY   : integer := DSP_DELAY + BPS_DELAY + DEMOD_DELAY; -- 21
  constant PN_DELAY_NEEDED   : integer := BPS_DELAY + DEMOD_DELAY;             -- 19  
  constant AWGN_DELAY_NEEDED : integer := TOTAL_BPS_DELAY;                     -- 21

  -- 组件声明
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
          valid_out    : out std_logic;
          i_awgn_ref   : out std_logic_vector(PAR*WIDTH-1 downto 0);
          q_awgn_ref   : out std_logic_vector(PAR*WIDTH-1 downto 0);
          bits_awgn_ref: out std_logic_vector(BITS-1 downto 0);
          valid_awgn_ref:out std_logic;
          i_pn_ref     : out std_logic_vector(PAR*WIDTH-1 downto 0);
          q_pn_ref     : out std_logic_vector(PAR*WIDTH-1 downto 0);
          bits_pn_ref  : out std_logic_vector(BITS-1 downto 0);
          valid_pn_ref : out std_logic);
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

  -- 信号定义
  signal i_tx, q_tx     : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal bits_tx        : std_logic_vector(PAR*MOD_BITS-1 downto 0);
  signal valid_tx       : std_logic;

  signal i_ch, q_ch     : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal bits_ch        : std_logic_vector(PAR*MOD_BITS-1 downto 0);
  signal valid_ch       : std_logic;

  -- BPS对比信号
  signal i_awgn_ref, q_awgn_ref     : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal bits_awgn_ref               : std_logic_vector(PAR*MOD_BITS-1 downto 0);
  signal valid_awgn_ref              : std_logic;
  
  signal i_pn_ref, q_pn_ref         : std_logic_vector(PAR*WIDTH-1 downto 0);
  signal bits_pn_ref                : std_logic_vector(PAR*MOD_BITS-1 downto 0);
  signal valid_pn_ref               : std_logic;

  -- 解调结果（未延迟对齐）
  signal bits_awgn_demod_raw : std_logic_vector(PAR*MOD_BITS-1 downto 0);
  signal bits_pn_demod_raw   : std_logic_vector(PAR*MOD_BITS-1 downto 0);
  signal bits_bps_demod_raw  : std_logic_vector(PAR*MOD_BITS-1 downto 0);
  signal valid_awgn_raw, valid_pn_raw, valid_bps_raw : std_logic;

  -- ★ 新增：延迟线信号 ★
  type delay_array is array (0 to AWGN_DELAY_NEEDED) of std_logic_vector(PAR*MOD_BITS-1 downto 0);
  signal awgn_delay_line : delay_array := (others => (others => '0'));
  signal pn_delay_line   : delay_array := (others => (others => '0'));
  
  type valid_delay_array is array (0 to AWGN_DELAY_NEEDED) of std_logic;
  signal awgn_valid_delay : valid_delay_array := (others => '0');
  signal pn_valid_delay   : valid_delay_array := (others => '0');

begin

  -- 发射机（保持不变）
  transmitter_inst : component transmitter
    generic map (PAR => PAR, WIDTH => WIDTH, MAX_AMP => MAX_AMP,
                 MOD_TYPE => MOD_TYPE, MOD_BITS => MOD_BITS)
    port map (clk => clk, rst => rst,
              i_out => i_tx, q_out => q_tx,
              bits_out => bits_tx, valid_out => valid_tx);

  -- 信道（保持不变）
  channel_inst : component channel
    generic map (PAR => PAR, WIDTH => WIDTH, BITS => BITS,
                 PN_PHASE_WIDTH => PN_PHASE_WIDTH, PN_LUT_WIDTH => PN_LUT_WIDTH)
    port map (clk => clk, rst => rst,
              i_in => i_tx, q_in => q_tx, bits_in => bits_tx, valid_in => valid_tx,
              awgn_scaling => awgn_scaling, pn_scaling => pn_scaling,
              i_out => i_ch, q_out => q_ch, bits_out => bits_ch, valid_out => valid_ch,
              i_awgn_ref => i_awgn_ref, q_awgn_ref => q_awgn_ref, 
              bits_awgn_ref => bits_awgn_ref, valid_awgn_ref => valid_awgn_ref,
              i_pn_ref => i_pn_ref, q_pn_ref => q_pn_ref,
              bits_pn_ref => bits_pn_ref, valid_pn_ref => valid_pn_ref);

  -- 正常接收机（BPS路径）- 保持不变
  receiver_inst : component receiver
    generic map (PAR => PAR, WIDTH => WIDTH, MOD_BITS => MOD_BITS,
                 MOD_TYPE => MOD_TYPE, MAX_AMP => MAX_AMP)
    port map (clk => clk, rst => rst,
              i_in => i_ch, q_in => q_ch, bits_in => bits_ch, valid_in => valid_ch,
              demod_out => bits_bps_demod_raw, bits_out => bits_ref, valid_out => valid_bps_raw);

  -- AWGN参考解调器
  demod_awgn_inst : component demodulator
    generic map (PAR => PAR, WIDTH => WIDTH, MOD_BITS => MOD_BITS,
                 MOD_TYPE => MOD_TYPE, MAX_AMP => MAX_AMP)
    port map (clk => clk, rst => rst,
              i_in => i_awgn_ref, q_in => q_awgn_ref, 
              bits_in => bits_awgn_ref, valid_in => valid_awgn_ref,
              demod_out => bits_awgn_demod_raw, bits_out => open, valid_out => valid_awgn_raw);

  -- PN解调器（无BPS）
  demod_pn_inst : component demodulator
    generic map (PAR => PAR, WIDTH => WIDTH, MOD_BITS => MOD_BITS,
                 MOD_TYPE => MOD_TYPE, MAX_AMP => MAX_AMP)
    port map (clk => clk, rst => rst,
              i_in => i_pn_ref, q_in => q_pn_ref,
              bits_in => bits_pn_ref, valid_in => valid_pn_ref,
              demod_out => bits_pn_demod_raw, bits_out => open, valid_out => valid_pn_raw);

  -- ★ 关键新增：延迟对齐处理 ★
  delay_alignment_proc : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        awgn_delay_line <= (others => (others => '0'));
        pn_delay_line <= (others => (others => '0'));
        awgn_valid_delay <= (others => '0');
        pn_valid_delay <= (others => '0');
      else
        -- AWGN路径延迟线（最长延迟）
        for i in AWGN_DELAY_NEEDED downto 1 loop
          awgn_delay_line(i) <= awgn_delay_line(i-1);
          awgn_valid_delay(i) <= awgn_valid_delay(i-1);
        end loop;
        awgn_delay_line(0) <= bits_awgn_demod_raw;
        awgn_valid_delay(0) <= valid_awgn_raw;

        -- PN路径延迟线（中等延迟）
        for i in PN_DELAY_NEEDED downto 1 loop
          pn_delay_line(i) <= pn_delay_line(i-1);
          pn_valid_delay(i) <= pn_valid_delay(i-1);
        end loop;
        pn_delay_line(0) <= bits_pn_demod_raw;
        pn_valid_delay(0) <= valid_pn_raw;
      end if;
    end if;
  end process;

  -- ★ 输出延迟对齐的数据 ★
  bits_awgn_demod <= awgn_delay_line(AWGN_DELAY_NEEDED);  -- 延迟21周期
  bits_pn_demod   <= pn_delay_line(PN_DELAY_NEEDED);      -- 延迟19周期
  bits_bps_demod  <= bits_bps_demod_raw;                  -- 无额外延迟（基准）

  -- 输出统一的valid信号
  valid_bps_comp <= awgn_valid_delay(AWGN_DELAY_NEEDED) and 
                    pn_valid_delay(PN_DELAY_NEEDED) and 
                    valid_bps_raw;

  -- 正常输出（保持不变）
  bits_demod <= bits_bps_demod_raw;
  valid_out <= valid_bps_raw;

end architecture arch;