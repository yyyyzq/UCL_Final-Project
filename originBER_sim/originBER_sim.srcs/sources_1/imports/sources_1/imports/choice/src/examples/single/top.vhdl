-------------------------------------------------------------------------------
-- Title      : Simplified Top-Level Component
-- Project    : CHOICE
-------------------------------------------------------------------------------
-- File       : top.vhdl
-- Author     : 保持原有接口，只增加BPS对比输出
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity top is
  port (clk  : in  std_logic;
        arst : in  std_logic;
        rx   : in  std_logic;
        tx   : out std_logic;
        awgn_scaling  : in  std_logic_vector(15 downto 0);
        pn_scaling    : in  std_logic_vector(15 downto 0);
        -- 原来的BER输出（保持不变）
        bits_cnt      : out std_logic_vector(63 downto 0);
        errors_cnt    : out std_logic_vector(63 downto 0);
        bits_demed    : out std_logic_vector(7 downto 0);
        valid_out     : out std_logic;
        -- BPS对比输出（简化）
        bits_cnt_pn   : out std_logic_vector(63 downto 0);   -- PN vs AWGN
        errors_cnt_pn : out std_logic_vector(63 downto 0);
        bits_cnt_bps  : out std_logic_vector(63 downto 0);   -- BPS vs AWGN
        errors_cnt_bps: out std_logic_vector(63 downto 0)
        );
end entity top;

architecture arch of top is

  -- Settings (保持原来的)
  constant CLK_FREQ       : positive              := 100e6;
  constant BAUDRATE       : positive              := 115200;
  constant REC_WIDTH      : positive              := 8;
  constant REC_DEPTH      : positive              := 32;
  constant PAR            : positive              := 2;
  constant WIDTH          : positive              := 8;
  constant MAX_AMP        : real range 0.0 to 1.0 := 0.5;
  constant MOD_TYPE       : string                := "16QAM";
  constant MOD_BITS       : positive              := 4;
  constant PN_PHASE_WIDTH : positive              := 16;
  constant PN_LUT_WIDTH   : positive              := 16;

  component reset_sync is
    port (clk  : in  std_logic;
          arst : in  std_logic;
          rst  : out std_logic);
  end component reset_sync;

  component control
    generic (CLK_FREQ  : positive := 100e6;
             BAUDRATE  : positive := 115200;
             REC_WIDTH : positive := 8;
             REC_DEPTH : positive := 32);
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
          rec_done     : in  std_logic);
  end component;

  component system
    generic (PAR            : positive;
             WIDTH          : positive;
             MAX_AMP        : real range 0.0 to 1.0;
             MOD_TYPE       : string;
             MOD_BITS       : positive;
             PN_PHASE_WIDTH : positive;
             PN_LUT_WIDTH   : positive);
    port(clk              : in  std_logic;
         rst              : in  std_logic;
         awgn_scaling     : in  std_logic_vector(15 downto 0);
         pn_scaling       : in  std_logic_vector(15 downto 0);
         bits_demod       : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
         bits_ref         : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
         valid_out        : out std_logic;
         bits_awgn_demod  : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
         bits_pn_demod    : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
         bits_bps_demod   : out std_logic_vector(PAR*MOD_BITS-1 downto 0);
         valid_bps_comp   : out std_logic);
  end component;

  component analysis
    generic (BITS             : positive;
             BITS_CNT_WIDTH   : positive;
             ERRORS_CNT_WIDTH : positive);
    port (clk               : in  std_logic;
          rst               : in  std_logic;
          bits_demod        : in  std_logic_vector(BITS-1 downto 0);
          bits_ref          : in  std_logic_vector(BITS-1 downto 0);
          valid_in          : in  std_logic;
          bits_cnt          : out std_logic_vector(BITS_CNT_WIDTH-1 downto 0);
          errors_cnt        : out std_logic_vector(ERRORS_CNT_WIDTH-1 downto 0);
          bits_awgn_demod   : in  std_logic_vector(BITS-1 downto 0);
          bits_pn_demod     : in  std_logic_vector(BITS-1 downto 0);
          bits_bps_demod    : in  std_logic_vector(BITS-1 downto 0);
          valid_bps_comp    : in  std_logic;
          bits_cnt_pn       : out std_logic_vector(BITS_CNT_WIDTH-1 downto 0);
          errors_cnt_pn     : out std_logic_vector(ERRORS_CNT_WIDTH-1 downto 0);
          bits_cnt_bps      : out std_logic_vector(BITS_CNT_WIDTH-1 downto 0);
          errors_cnt_bps    : out std_logic_vector(ERRORS_CNT_WIDTH-1 downto 0));
  end component;

  signal rst        : std_logic;
  signal rst_emu    : std_logic;
  signal bits_cnt_i : std_logic_vector(63 downto 0);
  signal errors_cnt_i : std_logic_vector(63 downto 0);
  signal bits_demod : std_logic_vector(PAR*MOD_BITS-1 downto 0);
  signal bits_ref   : std_logic_vector(PAR*MOD_BITS-1 downto 0);
  signal valid_bits : std_logic;

  -- BPS对比信号
  signal bits_awgn_demod  : std_logic_vector(PAR*MOD_BITS-1 downto 0);
  signal bits_pn_demod    : std_logic_vector(PAR*MOD_BITS-1 downto 0);
  signal bits_bps_demod   : std_logic_vector(PAR*MOD_BITS-1 downto 0);
  signal valid_bps_comp   : std_logic;

begin

  reset_sync_inst : reset_sync
    port map (clk => clk, arst => arst, rst => rst);

  control_inst : control
    generic map (CLK_FREQ => CLK_FREQ, BAUDRATE => BAUDRATE,
                 REC_WIDTH => REC_WIDTH, REC_DEPTH => REC_DEPTH)
    port map (clk => clk, rst => rst, rx => rx, tx => tx,
              rst_emu => rst_emu,
              bits_cnt => bits_cnt_i,
              errors_cnt => errors_cnt_i,
              pn_scaling => open,      -- 使用外部输入
              awgn_scaling => open,    -- 使用外部输入
              rec_addr => open,
              rec_data => (others => '0'),
              rec_done => '0');

  system_inst : system
    generic map (PAR => PAR, WIDTH => WIDTH, MAX_AMP => MAX_AMP,
                 MOD_TYPE => MOD_TYPE, MOD_BITS => MOD_BITS,
                 PN_PHASE_WIDTH => PN_PHASE_WIDTH, PN_LUT_WIDTH => PN_LUT_WIDTH)
    port map (clk => clk, rst => rst_emu, 
              awgn_scaling => awgn_scaling,
              pn_scaling => pn_scaling,
              bits_demod => bits_demod, 
              bits_ref => bits_ref,
              valid_out => valid_bits,
              bits_awgn_demod => bits_awgn_demod,
              bits_pn_demod => bits_pn_demod,
              bits_bps_demod => bits_bps_demod,
              valid_bps_comp => valid_bps_comp);

  analysis_inst : analysis
    generic map (BITS => PAR*MOD_BITS, BITS_CNT_WIDTH => 64, ERRORS_CNT_WIDTH => 64)
    port map (clk => clk, rst => rst_emu,
              bits_demod => bits_demod, 
              bits_ref => bits_ref,
              valid_in => valid_bits,
              bits_cnt => bits_cnt_i, 
              errors_cnt => errors_cnt_i,
              bits_awgn_demod => bits_awgn_demod,
              bits_pn_demod => bits_pn_demod,
              bits_bps_demod => bits_bps_demod,
              valid_bps_comp => valid_bps_comp,
              bits_cnt_pn => bits_cnt_pn,
              errors_cnt_pn => errors_cnt_pn,
              bits_cnt_bps => bits_cnt_bps,
              errors_cnt_bps => errors_cnt_bps);

  -- 输出分配（保持原来的接口）
  bits_cnt    <= bits_cnt_i;
  errors_cnt  <= errors_cnt_i;
  bits_demed  <= bits_demod;
  valid_out   <= valid_bits;

end architecture arch;