library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity communication is
  generic (REC_WIDTH   : positive := 8;
           REC_DEPTH   : positive := 32;
           CONST_DEPTH : positive := 256);  -- 改为256
  port (
    clk           : in  std_logic;
    rst           : in  std_logic;
    rx_data       : in  std_logic_vector(7 downto 0);
    rx_vld        : in  std_logic;
    tx_data       : out std_logic_vector(7 downto 0);
    tx_req        : out std_logic;
    tx_rdy        : in  std_logic;
    rst_emu       : out std_logic;
    store_results : out std_logic;
    params_en     : out std_logic;
    params_addr   : out std_logic_vector(7 downto 0);
    params_data   : out std_logic_vector(7 downto 0);
    results_addr  : out std_logic_vector(7 downto 0);
    results_data  : in  std_logic_vector(7 downto 0);
    rec_addr      : out std_logic_vector(integer(ceil(log2(real(REC_DEPTH))))-1 downto 0);
    rec_data      : in  std_logic_vector(REC_WIDTH-1 downto 0);
    -- 星座图接口
    const_trig    : out std_logic;
    const_addr    : out std_logic_vector(integer(ceil(log2(real(CONST_DEPTH))))-1 downto 0);
    const_data    : in  std_logic_vector(15 downto 0);
    const_done    : in  std_logic
  );
end entity;

architecture arch of communication is

  -- UART commands
  constant CMD_RESET     : std_logic_vector(7 downto 0) := x"00";
  constant CMD_STORE     : std_logic_vector(7 downto 0) := x"01";
  constant CMD_READ      : std_logic_vector(7 downto 0) := x"02";
  constant CMD_WRITE     : std_logic_vector(7 downto 0) := x"03";
  constant CMD_EMPTY     : std_logic_vector(7 downto 0) := x"04";
  constant CMD_CONST     : std_logic_vector(7 downto 0) := x"05";  -- 星座图命令
  constant CMD_CONST_TRIG: std_logic_vector(7 downto 0) := x"06";  -- 触发采集命令

  -- Derived constants
  constant REC_BYTES    : natural := integer(ceil(real(REC_WIDTH)/8.0));

  type state_type is (idle, reset, store, write_wait_addr, write_addr, write_wait_data, write_enable, 
                     read_wait_addr, read_addr, read_rdy, read_send, empty_reset, empty_wait_data, 
                     empty_send, empty_rdy, empty_inc_byte, empty_inc_addr,
                     -- 星座图相关状态
                     const_wait_addr, const_addr_state, const_rdy, const_send_low, const_send_high,
                     const_trig_cmd);
  signal current_state : state_type;
  signal next_state    : state_type;

  signal addr_reg         : std_logic_vector(7 downto 0);
  signal addr_reg_en      : std_logic;
  signal data_reg         : std_logic_vector(7 downto 0);
  signal data_reg_en      : std_logic;
  signal rec_addr_cnt     : integer range 0 to REC_DEPTH-1;
  signal rec_addr_reg     : std_logic_vector(integer(ceil(log2(real(REC_DEPTH))))-1 downto 0);
  signal rec_addr_reg_rst : std_logic;
  signal rec_addr_reg_en  : std_logic;
  signal rec_byte_cnt     : integer range 0 to REC_BYTES;
  signal rec_byte_rst     : std_logic;
  signal rec_byte_en      : std_logic;

  -- 星座图相关信号
  signal const_addr_cnt     : integer range 0 to CONST_DEPTH-1;
  signal const_addr_reg     : std_logic_vector(integer(ceil(log2(real(CONST_DEPTH))))-1 downto 0);
  signal const_addr_rst     : std_logic;
  signal const_addr_en      : std_logic;
  signal const_trig_reg     : std_logic := '0';
  
  -- 查询地址信号
  signal const_query_addr   : std_logic_vector(integer(ceil(log2(real(CONST_DEPTH))))-1 downto 0) := (others => '0');

  signal rst_int : std_logic;
  signal rst_gen : std_logic;

begin

  rst_emu <= rst or rst_gen;

  -- 寄存器更新进程
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        addr_reg       <= (others => '0');
        data_reg       <= (others => '0');
        rec_addr_reg   <= (others => '0');
        rec_addr_cnt   <= 0;
        rec_byte_cnt   <= 0;
        const_addr_reg <= (others => '0');
        const_addr_cnt <= 0;
        const_query_addr <= (others => '0');
      else
        if rx_vld = '1' and addr_reg_en = '1' then
          addr_reg <= rx_data;
          -- 为查询准备地址
          const_query_addr <= std_logic_vector(resize(unsigned(rx_data), const_query_addr'length));
        end if;
        if rx_vld = '1' and data_reg_en = '1' then
          data_reg <= rx_data;
        end if;
        if rec_addr_reg_rst = '1' then
          rec_addr_cnt <= 0;
          rec_addr_reg <= (others => '0');
        elsif rec_addr_reg_en = '1' then
          rec_addr_cnt <= rec_addr_cnt + 1;
          rec_addr_reg <= std_logic_vector(unsigned(rec_addr_reg) + 1);
        end if;
        if rec_byte_rst = '1' then
          rec_byte_cnt <= 0;
        elsif rec_byte_en = '1' then
          rec_byte_cnt <= rec_byte_cnt + 1;
        end if;
        
        -- 星座图地址管理
        if const_addr_rst = '1' then
          const_addr_cnt <= 0;
          const_addr_reg <= (others => '0');
        elsif const_addr_en = '1' then
          const_addr_cnt <= const_addr_cnt + 1;
          const_addr_reg <= std_logic_vector(unsigned(const_addr_reg) + 1);
        end if;
      end if;
    end if;
  end process;

  rec_addr   <= std_logic_vector(to_unsigned(rec_addr_cnt, rec_addr'length));
  
  -- 在查询状态时使用查询地址
  const_addr <= const_query_addr when (current_state = const_rdy or current_state = const_send_low or current_state = const_send_high) 
                else const_addr_reg;
  
  const_trig <= const_trig_reg;

  -- rst逻辑
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        rst_gen <= '1';
      else
        if rst_int = '1' then
          rst_gen <= '1';
        else
          rst_gen <= '0';
        end if;
      end if;
    end if;
  end process;

  -- 主状态机
  fsm_stage_change_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        current_state <= idle;
      else
        current_state <= next_state;
      end if;
    end if;
  end process fsm_stage_change_proc;

  fsm_next_state_proc : process (current_state, rx_vld, rx_data, tx_rdy, rec_addr_cnt, 
                                rec_byte_cnt, const_addr_cnt)
  begin
    next_state <= current_state;

    case current_state is
      when idle =>
        if rx_vld = '1' then
          if rx_data = CMD_RESET then
            next_state <= reset;
          elsif rx_data = CMD_STORE then
            next_state <= store;
          elsif rx_data = CMD_READ then
            next_state <= read_wait_addr;
          elsif rx_data = CMD_WRITE then
            next_state <= write_wait_addr;
          elsif rx_data = CMD_EMPTY then
            next_state <= empty_reset;
          elsif rx_data = CMD_CONST then
            next_state <= const_wait_addr;
          elsif rx_data = CMD_CONST_TRIG then
            next_state <= const_trig_cmd;
          end if;
        end if;

      when reset =>
        next_state <= idle;

      when store =>
        next_state <= idle;

      when read_wait_addr =>
        if rx_vld = '1' then
          next_state <= read_addr;
        end if;

      when read_addr =>
        if rx_vld = '0' then
          next_state <= read_rdy;
        end if;

      when read_rdy =>
        if tx_rdy = '1' then
          next_state <= read_send;
        end if;

      when read_send =>
        next_state <= idle;

      when write_wait_addr =>
        if rx_vld = '1' then
          next_state <= write_addr;
        end if;

      when write_addr =>
        if rx_vld = '0' then
          next_state <= write_wait_data;
        end if;

      when write_wait_data =>
        if rx_vld = '1' then
          next_state <= write_enable;
        end if;

      when write_enable =>
        if rx_vld = '0' then
          next_state <= idle;
        end if;

      when empty_reset =>
        next_state <= empty_wait_data;

      when empty_wait_data =>
        next_state <= empty_send;

      when empty_send =>
        next_state <= empty_rdy;

      when empty_rdy =>
        if tx_rdy = '1' then
          if rec_byte_cnt < REC_BYTES - 1 then
            next_state <= empty_inc_byte;
          elsif rec_addr_cnt < REC_DEPTH then
            next_state <= empty_inc_addr;
          else
            next_state <= idle;
          end if;
        end if;

      when empty_inc_byte =>
        next_state <= empty_wait_data;

      when empty_inc_addr =>
        next_state <= empty_wait_data;

      -- 星座图相关状态
      when const_trig_cmd =>
        next_state <= idle;

      when const_wait_addr =>
        if rx_vld = '1' then
          next_state <= const_addr_state;
        end if;

      when const_addr_state =>
        if rx_vld = '0' then
          next_state <= const_rdy;
        end if;

      when const_rdy =>
        if tx_rdy = '1' then
          next_state <= const_send_low;
        end if;

      when const_send_low =>
        if tx_rdy = '1' then
          next_state <= const_send_high;
        end if;

      when const_send_high =>
        if tx_rdy = '1' then
          next_state <= idle;
        end if;

      when others =>
        next_state <= idle;

    end case;
  end process fsm_next_state_proc;

  -- const_trig_reg控制进程
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        const_trig_reg <= '0';
      else
        if current_state = const_trig_cmd then
          const_trig_reg <= '1';
        else
          const_trig_reg <= '0';
        end if;
      end if;
    end if;
  end process;

  -- 输出逻辑
  fsm_output_proc : process (
    current_state, rx_data, data_reg, addr_reg, results_data, rec_data, rec_byte_cnt, const_data
  )
  begin
    -- 默认全部拉低
    rst_int          <= '0';
    store_results    <= '0';
    params_en        <= '0';
    params_addr      <= (others => '0');
    params_data      <= (others => '0');
    results_addr     <= (others => '0');
    tx_req           <= '0';
    tx_data          <= (others => '0');
    addr_reg_en      <= '0';
    data_reg_en      <= '0';
    rec_addr_reg_rst <= '0';
    rec_addr_reg_en  <= '0';
    rec_byte_rst     <= '0';
    rec_byte_en      <= '0';
    const_addr_rst   <= '0';
    const_addr_en    <= '0';

    case current_state is
      when reset =>
        rst_int <= '1';
      when store =>
        store_results <= '1';
      when read_wait_addr =>
        addr_reg_en <= '1';
      when read_rdy =>
        results_addr <= addr_reg;
      when read_send =>
        results_addr <= addr_reg;
        tx_req       <= '1';
        tx_data      <= results_data;
      when write_wait_addr =>
        addr_reg_en <= '1';
      when write_wait_data =>
        data_reg_en <= '1';
      when write_enable =>
        params_en   <= '1';
        params_addr <= addr_reg;
        params_data <= data_reg;
      when empty_reset =>
        rec_addr_reg_rst <= '1';
        rec_byte_rst     <= '1';
      when empty_send =>
        tx_req  <= '1';
        tx_data <= rec_data((rec_byte_cnt+1)*8-1 downto rec_byte_cnt*8);
      when empty_inc_addr =>
        rec_addr_reg_en <= '1';
        rec_byte_rst    <= '1';
      when empty_inc_byte =>
        rec_byte_en <= '1';
      -- 星座图相关输出
      when const_wait_addr =>
        addr_reg_en <= '1';
      when const_send_low =>
        tx_req  <= '1';
        tx_data <= const_data(7 downto 0);  -- 发送低8位
      when const_send_high =>
        tx_req  <= '1';
        tx_data <= const_data(15 downto 8); -- 发送高8位
      when others =>
        null;
    end case;
  end process;

end architecture;