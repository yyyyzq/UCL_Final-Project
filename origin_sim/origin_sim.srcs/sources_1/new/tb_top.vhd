library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_top is
end tb_top;

architecture behavior of tb_top is

  component top
    port (
      clk           : in  std_logic;
      arst          : in  std_logic;
      rx            : in  std_logic;
      tx            : out std_logic;
      awgn_scaling  : in  std_logic_vector(15 downto 0);
      pn_scaling    : in  std_logic_vector(15 downto 0);
      bits_cnt      : out std_logic_vector(63 downto 0);
      errors_cnt    : out std_logic_vector(63 downto 0);
      bits_demed    : out std_logic_vector(7 downto 0);
      valid_out     : out std_logic
    );
  end component;

  -- Signals
  signal clk           : std_logic := '0';
  signal arst          : std_logic := '1';
  signal rx            : std_logic := '1';   -- UART idle, or根据需求可赋值
  signal tx            : std_logic;
  signal awgn_scaling  : std_logic_vector(15 downto 0) := (others => '0');
  signal pn_scaling    : std_logic_vector(15 downto 0) := (others => '0');
  signal bits_cnt      : std_logic_vector(63 downto 0);
  signal errors_cnt    : std_logic_vector(63 downto 0);
  signal bits_demed    : std_logic_vector(7 downto 0);
  signal valid_out     : std_logic;

  file result_file : text open write_mode is "BER_output.txt";

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
      valid_out     => valid_out
    );

  -- Clock process (100MHz)
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

  -- Reset & main stimulus process
  stim_proc: process
    variable L : line;
  begin
    arst <= '1';
    wait for 50 ns;
    arst <= '0';

    -- 可以自行修改这两个参数
    awgn_scaling <= x"0000";
    pn_scaling   <= x"0000";

    -- 可以根据需要赋值rx，比如始终为'1'（空闲），也可以模拟串口激励
    rx <= '1';

    -- 让系统运行一段时间
    wait for 1000 us;

    -- 输出统计量到文件
    write(L, string'("awgn_scaling = "));
    write(L, awgn_scaling);
    writeline(result_file, L);

    write(L, string'("pn_scaling = "));
    write(L, pn_scaling);
    writeline(result_file, L);

    write(L, string'("bits_cnt = "));
    write(L, integer'image(to_integer(unsigned(bits_cnt))));
    writeline(result_file, L);

    write(L, string'("errors_cnt = "));
    write(L, integer'image(to_integer(unsigned(errors_cnt))));
    writeline(result_file, L);

    file_close(result_file);

    report ">>> tb_top_extended simulation completed" severity note;
    std.env.stop;
  end process;

end behavior;
