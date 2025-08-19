-------------------------------------------------------------------------------
-- Title      : Top-Level Component for a Single Polarization System with Constellation
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : top.vhdl
-- Author     : Erik Börjeson  <erikbor@chalmers.se>
-- Company    : Chalmers University of Technology
-- Created    : 2022-03-02
-- Last update: 2025-07-24
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- Top-level with constellation recording capability - 80MHz版本
-------------------------------------------------------------------------------
-- Copyright (c) 2022 Erik Börjeson
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2022-03-02  1.0      erikbor Created
-- 2025-07-24  1.2      Modified 添加MMCM时钟分频，80MHz工作频率
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
library unisim;
use unisim.vcomponents.all;

entity top is
  port (
        clk_p        : in  std_logic;
        clk_n        : in  std_logic;
        led_clk      : out std_logic;
        led_rst      : out std_logic;
        led_test     : out std_logic;
        arst         : in  std_logic;
        rx           : in  std_logic;
        tx           : out std_logic);
end entity top;

architecture arch of top is

  -- Settings
  constant CLK_FREQ       : positive              := 50e6;   -- 修改为80MHz工作频率
  constant BAUDRATE       : positive              := 9600;
  constant REC_WIDTH      : positive              := 8;
  constant REC_DEPTH      : positive              := 32;
  constant PAR            : positive              := 2;
  constant WIDTH          : positive              := 8;
  constant MAX_AMP        : real range 0.0 to 1.0 := 0.5;
  constant MOD_TYPE       : string                := "16QAM";
  constant MOD_BITS       : positive              := 4;
  constant PN_PHASE_WIDTH : positive              := 16;
  constant PN_LUT_WIDTH   : positive              := 16;
  constant CONST_DEPTH    : positive              := 256;  -- 星座图深度

  component reset_sync is
    port (clk  : in  std_logic;
          arst : in  std_logic;
          rst  : out std_logic);
  end component reset_sync;

  component control is
    generic (CLK_FREQ    : positive;
             BAUDRATE    : positive;
             REC_WIDTH   : positive;
             REC_DEPTH   : positive;
             CONST_DEPTH : positive);
    port (clk          : in  std_logic;
          rst          : in  std_logic;
          rx           : in  std_logic;
          tx           : out std_logic;
          rst_emu      : out std_logic;
          bits_cnt     : in  std_logic_vector(63 downto 0);
          errors_cnt   : in  std_logic_vector(63 downto 0);
          pn_scaling   : out std_logic_vector(15 downto 0);
          awgn_scaling : out std_logic_vector(15 downto 0);
          rec_addr     : out std_logic_vector(integer(ceil(log2(real(REC_DEPTH))))-1 downto 0);
          rec_data     : in  std_logic_vector(REC_WIDTH-1 downto 0);
          rec_done     : in  std_logic;
          -- 星座图接口
          const_trig   : out std_logic;
          const_addr   : out std_logic_vector(integer(ceil(log2(real(CONST_DEPTH))))-1 downto 0);
          const_data   : in  std_logic_vector(15 downto 0);
          const_done   : in  std_logic);
  end component control;

  component system is
    generic (PAR            : positive;
             WIDTH          : positive;
             MAX_AMP        : real range 0.0 to 1.0;
             MOD_TYPE       : string;
             MOD_BITS       : positive;
             PN_PHASE_WIDTH : positive;
             PN_LUT_WIDTH   : positive;
             CONST_DEPTH    : positive);
    port(clk          : in  std_logic;
         rst          : in  std_logic;
         awgn_scaling : in  std_logic_vector(15 downto 0);
         pn_scaling   : in  std_logic_vector(15 downto 0);
         bits_demod   : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
         bits_ref     : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
         valid_out    : out std_logic;
         const_trig   : in  std_logic;
         const_addr   : in  std_logic_vector(integer(ceil(log2(real(CONST_DEPTH))))-1 downto 0);
         const_data   : out std_logic_vector(15 downto 0);
         const_done   : out std_logic);
  end component system;

  component analysis is
    generic (BITS             : positive;
             BITS_CNT_WIDTH   : positive;
             ERRORS_CNT_WIDTH : positive);
    port (clk        : in  std_logic;
          rst        : in  std_logic;
          bits_demod : in  std_logic_vector(BITS-1 downto 0);
          bits_ref   : in  std_logic_vector(BITS-1 downto 0);
          valid_in   : in  std_logic;
          bits_cnt   : out std_logic_vector(BITS_CNT_WIDTH-1 downto 0);
          errors_cnt : out std_logic_vector(ERRORS_CNT_WIDTH-1 downto 0));
  end component analysis;

  -- 时钟和复位信号
  signal clk_200      : std_logic;  -- 200MHz输入时钟
  signal clk_80       : std_logic;  -- 80MHz工作时钟
  signal rst          : std_logic;
  signal rst_emu      : std_logic;
  signal locked       : std_logic;  -- MMCM锁定信号
  
  -- 其他信号
  signal bits_cnt     : std_logic_vector(63 downto 0);
  signal errors_cnt   : std_logic_vector(63 downto 0);
  signal pn_scaling   : std_logic_vector(15 downto 0);
  signal awgn_scaling : std_logic_vector(15 downto 0);
  signal bits_demod   : std_logic_vector(PAR*MOD_BITS-1 downto 0);
  signal bits_ref     : std_logic_vector(PAR*MOD_BITS-1 downto 0);
  signal valid_bits   : std_logic;
  
  signal clk_div : std_logic_vector(25 downto 0) := (others => '0');

  -- 星座图信号
  signal const_trig : std_logic;
  signal const_addr : std_logic_vector(integer(ceil(log2(real(CONST_DEPTH))))-1 downto 0);
  signal const_data : std_logic_vector(15 downto 0);
  signal const_done : std_logic;
  
  signal arst_combined : std_logic;

  -- MMCM反馈时钟
  signal clkfb : std_logic;

begin

  -- ===========================================
  -- 时钟管理：200MHz输入 → 80MHz工作时钟
  -- ===========================================
  
  -- 差分时钟输入缓冲器
  clk_ibufds_inst : IBUFDS
    port map (
      O  => clk_200,
      I  => clk_p,
      IB => clk_n
    );

  -- MMCM时钟管理单元：200MHz → 80MHz
  mmcm_inst : MMCME2_BASE
    generic map (
      BANDWIDTH          => "OPTIMIZED",
      CLKFBOUT_MULT_F    => 5.0,        -- 反馈倍频系数
      CLKIN1_PERIOD      => 5.0,        -- 输入周期：200MHz = 5ns
      CLKOUT0_DIVIDE_F   => 20.0,       -- 输出分频：200*5/12.5 = 80MHz
      DIVCLK_DIVIDE      => 1,
      REF_JITTER1        => 0.010,
      STARTUP_WAIT       => FALSE       -- 布尔值，不使用引号
    )
    port map (
      CLKFBOUT => clkfb,
      CLKFBIN  => clkfb,
      CLKOUT0  => clk_80,               -- 80MHz输出时钟
      CLKIN1   => clk_200,              -- 200MHz输入时钟
      LOCKED   => locked,               -- 锁定指示
      PWRDWN   => '0',
      RST      => arst
    );

  -- ===========================================
  -- LED时钟分频（使用80MHz时钟）
  -- ===========================================
  clk_div_proc : process(clk_80, arst)
  begin
    if arst = '1' then
      clk_div <= (others => '0');
    elsif rising_edge(clk_80) then
      clk_div <= std_logic_vector(unsigned(clk_div) + 1);
    end if;
  end process;

  -- LED 驱动
  led_clk      <= clk_div(23);  -- 80MHz ÷ 2^24 ≈ 5Hz
  led_rst      <= rst_emu;
  led_test     <= const_done and locked;   -- 显示星座图采集完成状态和时钟锁定
  
  -- 组合复位信号
  arst_combined <= arst or (not locked);

  -- ===========================================
  -- 复位同步（基于80MHz时钟）
  -- ===========================================
  reset_sync_inst : component reset_sync
    port map (clk  => clk_80,
              arst => arst_combined,
              rst  => rst);

  -- ===========================================
  -- 功能模块实例化（全部使用80MHz时钟）
  -- ===========================================
  control_inst : component control
    generic map (CLK_FREQ    => CLK_FREQ,
                 BAUDRATE    => BAUDRATE,
                 REC_WIDTH   => REC_WIDTH,
                 REC_DEPTH   => REC_DEPTH,
                 CONST_DEPTH => CONST_DEPTH)
    port map (clk          => clk_80,       -- 使用80MHz时钟
              rst          => rst,
              rx           => rx,
              tx           => tx,
              rst_emu      => rst_emu,
              bits_cnt     => bits_cnt,
              errors_cnt   => errors_cnt,
              pn_scaling   => pn_scaling,
              awgn_scaling => awgn_scaling,
              rec_addr     => open,
              rec_data     => (others => '0'),
              rec_done     => '0',
              const_trig   => const_trig,
              const_addr   => const_addr,
              const_data   => const_data,
              const_done   => const_done);

  system_inst : component system
    generic map (PAR            => PAR,
                 WIDTH          => WIDTH,
                 MAX_AMP        => MAX_AMP,
                 MOD_TYPE       => MOD_TYPE,
                 MOD_BITS       => MOD_BITS,
                 PN_PHASE_WIDTH => PN_PHASE_WIDTH,
                 PN_LUT_WIDTH   => PN_LUT_WIDTH,
                 CONST_DEPTH    => CONST_DEPTH)
    port map (clk          => clk_80,       -- 使用80MHz时钟
              rst          => rst_emu,
              awgn_scaling => awgn_scaling,
              pn_scaling   => pn_scaling,
              bits_demod   => bits_demod,
              bits_ref     => bits_ref,
              valid_out    => valid_bits,
              const_trig   => const_trig,
              const_addr   => const_addr,
              const_data   => const_data,
              const_done   => const_done);

  analysis_int : component analysis
    generic map (BITS             => PAR*MOD_BITS,
                 BITS_CNT_WIDTH   => 64,
                 ERRORS_CNT_WIDTH => 64)
    port map (clk        => clk_80,         -- 使用80MHz时钟
              rst        => rst_emu,
              bits_demod => bits_demod,
              bits_ref   => bits_ref,
              valid_in   => valid_bits,
              bits_cnt   => bits_cnt,
              errors_cnt => errors_cnt);

end architecture arch;