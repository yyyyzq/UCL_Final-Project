library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_top_ber_comparison is
end tb_top_ber_comparison;

architecture behavior of tb_top_ber_comparison is

  component top
    port (
      clk           : in  std_logic;
      arst          : in  std_logic;
      rx            : in  std_logic;
      tx            : out std_logic;
      awgn_scaling  : in  std_logic_vector(15 downto 0);
      pn_scaling    : in  std_logic_vector(15 downto 0);
      -- 原有BER输出
      bits_cnt      : out std_logic_vector(63 downto 0);
      errors_cnt    : out std_logic_vector(63 downto 0);
      bits_demed    : out std_logic_vector(7 downto 0);
      valid_out     : out std_logic;
      -- BPS对比输出
      bits_cnt_pn   : out std_logic_vector(63 downto 0);
      errors_cnt_pn : out std_logic_vector(63 downto 0);
      bits_cnt_bps  : out std_logic_vector(63 downto 0);
      errors_cnt_bps: out std_logic_vector(63 downto 0)
    );
  end component;

  -- 信号定义
  signal clk           : std_logic := '0';
  signal arst          : std_logic := '1';
  signal rx            : std_logic := '1';
  signal tx            : std_logic;
  signal awgn_scaling  : std_logic_vector(15 downto 0);
  signal pn_scaling    : std_logic_vector(15 downto 0);
  
  -- 原有输出
  signal bits_cnt      : std_logic_vector(63 downto 0);
  signal errors_cnt    : std_logic_vector(63 downto 0);
  signal bits_demed    : std_logic_vector(7 downto 0);
  signal valid_out     : std_logic;
  
  -- BPS对比输出
  signal bits_cnt_pn   : std_logic_vector(63 downto 0);
  signal errors_cnt_pn : std_logic_vector(63 downto 0);
  signal bits_cnt_bps  : std_logic_vector(63 downto 0);
  signal errors_cnt_bps: std_logic_vector(63 downto 0);

  file result_file : text open write_mode is "BER_comparison_simple.txt";

begin

  uut: top
    port map (
      clk           => clk,
      arst          => arst,
      rx            => rx,
      tx            => tx,
      awgn_scaling  => awgn_scaling,
      pn_scaling    => pn_scaling,
      bits_cnt      => bits_cnt,
      errors_cnt    => errors_cnt,
      bits_demed    => bits_demed,
      valid_out     => valid_out,
      bits_cnt_pn   => bits_cnt_pn,
      errors_cnt_pn => errors_cnt_pn,
      bits_cnt_bps  => bits_cnt_bps,
      errors_cnt_bps=> errors_cnt_bps
    );

  -- 时钟生成 (100MHz)
  clk_process : process
  begin
    while now < 1 ms loop
      clk <= '0';
      wait for 5 ns;
      clk <= '1';
      wait for 5 ns;
    end loop;
    wait;
  end process;

  -- 主仿真过程
  stim_proc: process
    variable L : line;
    variable ber_pn, ber_bps : real;
    variable improvement_factor : real;
    
  begin
    -- 初始复位
    arst <= '1';
    wait for 100 ns;
    arst <= '0';

    -- 设置测试参数
    awgn_scaling <= x"0000";  -- 可以根据需要调整
    pn_scaling   <= x"0000";  -- 可以根据需要调整

    -- 等待系统运行收集数据
    wait for 500 us;

    -- 计算BER
    if to_integer(unsigned(bits_cnt_pn)) > 0 then
      ber_pn := real(to_integer(unsigned(errors_cnt_pn))) / real(to_integer(unsigned(bits_cnt_pn)));
    else
      ber_pn := 0.0;
    end if;
    
    if to_integer(unsigned(bits_cnt_bps)) > 0 then
      ber_bps := real(to_integer(unsigned(errors_cnt_bps))) / real(to_integer(unsigned(bits_cnt_bps)));
    else
      ber_bps := 0.0;
    end if;
    
    -- 计算BPS改善因子
    if ber_bps > 0.0 and ber_pn > 0.0 then
      improvement_factor := ber_pn / ber_bps;
    elsif ber_pn > 0.0 and ber_bps = 0.0 then
      improvement_factor := 999.0;  -- 很大的改善
    else
      improvement_factor := 1.0;
    end if;

    -- 输出结果
    write(L, string'("=== BPS Performance Comparison ==="));
    writeline(result_file, L);
    writeline(result_file, L);

    write(L, string'("AWGN Scaling: 0x"));
    hwrite(L, awgn_scaling);
    writeline(result_file, L);

    write(L, string'("PN Scaling: 0x"));
    hwrite(L, pn_scaling);
    writeline(result_file, L);
    writeline(result_file, L);

    write(L, string'("PN BER (vs AWGN reference): "));
    write(L, real'image(ber_pn));
    writeline(result_file, L);

    write(L, string'("BPS BER (vs AWGN reference): "));
    write(L, real'image(ber_bps));
    writeline(result_file, L);

    write(L, string'("BPS Improvement Factor: "));
    write(L, real'image(improvement_factor));
    write(L, string'("x"));
    writeline(result_file, L);
    writeline(result_file, L);

    -- 详细统计
    write(L, string'("=== Detailed Statistics ==="));
    writeline(result_file, L);
    
    write(L, string'("PN: "));
    write(L, integer'image(to_integer(unsigned(errors_cnt_pn))));
    write(L, string'(" errors in "));
    write(L, integer'image(to_integer(unsigned(bits_cnt_pn))));
    write(L, string'(" bits"));
    writeline(result_file, L);

    write(L, string'("BPS: "));
    write(L, integer'image(to_integer(unsigned(errors_cnt_bps))));
    write(L, string'(" errors in "));
    write(L, integer'image(to_integer(unsigned(bits_cnt_bps))));
    write(L, string'(" bits"));
    writeline(result_file, L);

    -- 结论
    if improvement_factor > 2.0 then
      write(L, string'("=> BPS provides significant improvement!"));
    elsif improvement_factor > 1.1 then
      write(L, string'("=> BPS provides modest improvement."));
    else
      write(L, string'("=> BPS shows little or no improvement."));
    end if;
    writeline(result_file, L);

    file_close(result_file);

    report "BPS comparison simulation completed" severity note;
    report "PN BER: " & real'image(ber_pn) severity note;
    report "BPS BER: " & real'image(ber_bps) severity note;
    report "Improvement: " & real'image(improvement_factor) & "x" severity note;
    
    std.env.stop;
  end process;

end behavior;