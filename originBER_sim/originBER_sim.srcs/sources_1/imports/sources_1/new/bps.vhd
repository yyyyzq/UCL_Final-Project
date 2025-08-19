library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity bps is
  generic (
    PAR     : positive := 2;      -- 并行路数
    WIDTH   : positive := 8;      -- IQ位宽
    PHASES  : positive := 8;      -- BPS相位数
    WINLEN  : positive := 16      -- 滑动窗口长度
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    i_in       : in  std_logic_vector(PAR*WIDTH-1 downto 0);
    q_in       : in  std_logic_vector(PAR*WIDTH-1 downto 0);
    valid_in   : in  std_logic;
    i_out      : out std_logic_vector(PAR*WIDTH-1 downto 0);
    q_out      : out std_logic_vector(PAR*WIDTH-1 downto 0);
    valid_out  : out std_logic
  );
end entity;

architecture rtl of bps is

  -- 查找表类型
  type lut_array      is array (0 to PHASES-1) of std_logic_vector(15 downto 0);
  type buf_array      is array (0 to WINLEN-1) of signed(WIDTH-1 downto 0);
  type metric_array   is array (0 to PHASES-1) of integer;

  -- 查找表生成
  function gen_cos_lut return lut_array is
    variable lut : lut_array;
    constant pi : real := 3.14159265358979323846;
  begin
    for idx in 0 to PHASES-1 loop
      lut(idx) := std_logic_vector(
        to_signed(integer(32767.0 * cos(2.0 * pi * real(idx)/real(PHASES))), 16));
    end loop;
    return lut;
  end function;

  function gen_sin_lut return lut_array is
    variable lut : lut_array;
    constant pi : real := 3.14159265358979323846;
  begin
    for idx in 0 to PHASES-1 loop
      lut(idx) := std_logic_vector(
        to_signed(integer(32767.0 * sin(2.0 * pi * real(idx)/real(PHASES))), 16));
    end loop;
    return lut;
  end function;

  constant cos_lut : lut_array := gen_cos_lut;
  constant sin_lut : lut_array := gen_sin_lut;

  -- sign函数
  function sign(val: integer) return integer is
  begin
    if val >= 0 then
      return 1;
    else
      return -1;
    end if;
  end function;

  -- 缓存信号
  signal i_buf, q_buf : buf_array := (others => (others => '0'));
  signal valid_buf    : std_logic_vector(WINLEN-1 downto 0) := (others => '0');
  signal win_ptr      : integer range 0 to WINLEN-1 := 0;
  signal sample_cnt   : integer range 0 to WINLEN := 0;

begin

  process(clk)
    variable met       : metric_array;
    variable i_rot, q_rot : integer;
    variable i_sym, q_sym : integer;
    variable dist2     : integer;
    variable min_met, min_idx : integer;
    variable k, ph, ch : integer;
    variable cosv, sinv : integer;
    variable improvement_threshold : integer := 1000; -- 改善阈值
  begin
    if rising_edge(clk) then
      if rst = '1' then
        i_buf      <= (others => (others => '0'));
        q_buf      <= (others => (others => '0'));
        valid_buf  <= (others => '0');
        win_ptr    <= 0;
        sample_cnt <= 0;
        i_out      <= (others => '0');
        q_out      <= (others => '0');
        valid_out  <= '0';
      else
        -- 输入缓存
        if valid_in = '1' then
          for ch in 0 to PAR-1 loop
            i_buf(win_ptr)   <= signed(i_in((ch+1)*WIDTH-1 downto ch*WIDTH));
            q_buf(win_ptr)   <= signed(q_in((ch+1)*WIDTH-1 downto ch*WIDTH));
            valid_buf(win_ptr) <= '1';
          end loop;
          win_ptr <= (win_ptr + 1) mod WINLEN;
          if sample_cnt < WINLEN then
            sample_cnt <= sample_cnt + 1;
          end if;
        end if;

        if sample_cnt >= WINLEN then
          for ch in 0 to PAR-1 loop
            -- 1. Metric累加
            for ph in 0 to PHASES-1 loop
              met(ph) := 0;
              for k in 0 to WINLEN-1 loop
                if valid_buf(k) = '1' then
                  cosv := to_integer(signed(cos_lut(ph)));
                  sinv := to_integer(signed(sin_lut(ph)));
                  i_rot := (to_integer(i_buf(k))*cosv - to_integer(q_buf(k))*sinv) / 32768;
                  q_rot := (to_integer(i_buf(k))*sinv + to_integer(q_buf(k))*cosv) / 32768;
                  -- 16QAM判决点（恢复原来的值）
                  if abs(i_rot) < 30 then
                    i_sym := 15 * sign(i_rot);
                  else
                    i_sym := 45 * sign(i_rot);
                  end if;
                  if abs(q_rot) < 30 then
                    q_sym := 15 * sign(q_rot);
                  else
                    q_sym := 45 * sign(q_rot);
                  end if;
                  dist2 := (i_rot - i_sym)*(i_rot - i_sym) + (q_rot - q_sym)*(q_rot - q_sym);
                  met(ph) := met(ph) + dist2;
                end if;
              end loop;
            end loop;
            
            -- 2. 选最优相位
            min_met := met(0);
            min_idx := 0;
            for ph in 1 to PHASES-1 loop
              if met(ph) < min_met then
                min_met := met(ph);
                min_idx := ph;
              end if;
            end loop;
            
            -- 3. 智能判断：只有当BPS能显著改善时才旋转
            if min_idx = 0 or (met(0) - min_met) < improvement_threshold then
              -- 相位误差很小或改善不明显，直通输出
              i_out((ch+1)*WIDTH-1 downto ch*WIDTH) <= 
                std_logic_vector(i_buf((win_ptr+WINLEN-1) mod WINLEN));
              q_out((ch+1)*WIDTH-1 downto ch*WIDTH) <= 
                std_logic_vector(q_buf((win_ptr+WINLEN-1) mod WINLEN));
            else
              -- 有明显相位误差，需要校正
              cosv := to_integer(signed(cos_lut(min_idx)));
              sinv := to_integer(signed(sin_lut(min_idx)));
              i_rot := (to_integer(i_buf((win_ptr+WINLEN-1) mod WINLEN))*cosv -
                        to_integer(q_buf((win_ptr+WINLEN-1) mod WINLEN))*sinv) / 32768;
              q_rot := (to_integer(i_buf((win_ptr+WINLEN-1) mod WINLEN))*sinv +
                        to_integer(q_buf((win_ptr+WINLEN-1) mod WINLEN))*cosv) / 32768;
              i_out((ch+1)*WIDTH-1 downto ch*WIDTH) <= std_logic_vector(to_signed(i_rot, WIDTH));
              q_out((ch+1)*WIDTH-1 downto ch*WIDTH) <= std_logic_vector(to_signed(q_rot, WIDTH));
            end if;
          end loop;
          valid_out <= '1';
        else
          -- 样本不够时直通
          if valid_in = '1' then
            i_out <= i_in;
            q_out <= q_in;
            valid_out <= '1';
          else
            i_out     <= (others => '0');
            q_out     <= (others => '0');
            valid_out <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;

end architecture;