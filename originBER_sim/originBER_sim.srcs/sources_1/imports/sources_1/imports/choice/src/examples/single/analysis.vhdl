-------------------------------------------------------------------------------
-- Title      : Simplified Analysis with BPS Comparison
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : analysis.vhdl
-- Author     : 简化的BPS对比分析
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- 1. 保持原来的正常BER统计（bits_demod vs bits_ref）
-- 2. 增加BPS对比：PN vs AWGN, BPS vs AWGN
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity analysis is
  generic (BITS             : positive := 8;
           BITS_CNT_WIDTH   : positive := 64;
           ERRORS_CNT_WIDTH : positive := 64);
  port (clk               : in  std_logic;
        rst               : in  std_logic;
        -- 正常BER统计（保持不变）
        bits_demod        : in  std_logic_vector(BITS-1 downto 0);
        bits_ref          : in  std_logic_vector(BITS-1 downto 0);
        valid_in          : in  std_logic;
        bits_cnt          : out std_logic_vector(BITS_CNT_WIDTH-1 downto 0);
        errors_cnt        : out std_logic_vector(ERRORS_CNT_WIDTH-1 downto 0);
        -- BPS对比统计（简化）
        bits_awgn_demod   : in  std_logic_vector(BITS-1 downto 0);
        bits_pn_demod     : in  std_logic_vector(BITS-1 downto 0);
        bits_bps_demod    : in  std_logic_vector(BITS-1 downto 0);
        valid_bps_comp    : in  std_logic;
        bits_cnt_pn       : out std_logic_vector(BITS_CNT_WIDTH-1 downto 0);
        errors_cnt_pn     : out std_logic_vector(ERRORS_CNT_WIDTH-1 downto 0);
        bits_cnt_bps      : out std_logic_vector(BITS_CNT_WIDTH-1 downto 0);
        errors_cnt_bps    : out std_logic_vector(ERRORS_CNT_WIDTH-1 downto 0));
end entity analysis;

architecture arch of analysis is

  component error_counter is
    generic (BITS             : positive;
             BITS_CNT_WIDTH   : positive;
             ERRORS_CNT_WIDTH : positive);
    port (clk        : in  std_logic;
          rst        : in  std_logic;
          input0     : in  std_logic_vector(BITS-1 downto 0);
          input1     : in  std_logic_vector(BITS-1 downto 0);
          valid_in0  : in  std_logic;
          valid_in1  : in  std_logic;
          bits_cnt   : out std_logic_vector(BITS_CNT_WIDTH-1 downto 0);
          errors_cnt : out std_logic_vector(ERRORS_CNT_WIDTH-1 downto 0));
  end component error_counter;

begin

  -- 正常BER统计（保持不变）
  error_counter_normal_inst : component error_counter
    generic map (BITS => BITS, BITS_CNT_WIDTH => BITS_CNT_WIDTH, 
                 ERRORS_CNT_WIDTH => ERRORS_CNT_WIDTH)
    port map (clk => clk, rst => rst,
              input0 => bits_demod, input1 => bits_ref,
              valid_in0 => valid_in, valid_in1 => valid_in,
              bits_cnt => bits_cnt, errors_cnt => errors_cnt);

  -- PN vs AWGN对比
  error_counter_pn_inst : component error_counter
    generic map (BITS => BITS, BITS_CNT_WIDTH => BITS_CNT_WIDTH,
                 ERRORS_CNT_WIDTH => ERRORS_CNT_WIDTH)
    port map (clk => clk, rst => rst,
              input0 => bits_pn_demod,     -- PN解调结果
              input1 => bits_awgn_demod,   -- AWGN参考
              valid_in0 => valid_bps_comp, valid_in1 => valid_bps_comp,
              bits_cnt => bits_cnt_pn, errors_cnt => errors_cnt_pn);

  -- BPS vs AWGN对比
  error_counter_bps_inst : component error_counter
    generic map (BITS => BITS, BITS_CNT_WIDTH => BITS_CNT_WIDTH,
                 ERRORS_CNT_WIDTH => ERRORS_CNT_WIDTH)
    port map (clk => clk, rst => rst,
              input0 => bits_bps_demod,    -- BPS解调结果
              input1 => bits_awgn_demod,   -- AWGN参考
              valid_in0 => valid_bps_comp, valid_in1 => valid_bps_comp,
              bits_cnt => bits_cnt_bps, errors_cnt => errors_cnt_bps);

end architecture arch;