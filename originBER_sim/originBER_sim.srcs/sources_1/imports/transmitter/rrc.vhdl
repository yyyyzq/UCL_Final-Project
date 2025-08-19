library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity rrc is
  generic (WIDTH     : positive := 8;
           TAP_WIDTH : positive := 12;
           BITS      : positive := 2);
  port (clk       : in  std_logic;
        rst       : in  std_logic;
        i_in      : in  std_logic_vector(WIDTH-1 downto 0);
        q_in      : in  std_logic_vector(WIDTH-1 downto 0);
        bits_in   : in  std_logic_vector(BITS-1 downto 0);
        valid_in  : in  std_logic;
        i_out     : out std_logic_vector(2*WIDTH-1 downto 0);
        q_out     : out std_logic_vector(2*WIDTH-1 downto 0);
        bits_out  : out std_logic_vector(BITS-1 downto 0);
        valid_out : out std_logic);
end entity rrc;


architecture arch of rrc is

  constant TAPS_N : positive := 51;     
  type taps_type is array (0 to integer(ceil(real(TAPS_N)/2.0))-1) of signed(TAP_WIDTH-1 downto 0);

  -- One side of symmetric filter
  constant TAPS : taps_type := (to_signed(integer(round(-0.00212217556204961 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(0.00280469451518057 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(0.0011624927123446 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(-0.00431951220276716 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(0.00042599188151861 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(0.00600241892317459 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(-0.00278919846097423 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(-0.00780586403432466 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(0.00610516978101017 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(0.00967305288807964 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(-0.010610877810248 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(-0.011540438765156 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(0.0166569978589492 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(0.0133407015776044 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(-0.0248255103017151 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(-0.0150060473079365 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(0.0362066567753822 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(0.016471637638393 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(-0.0531521319583287 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(-0.0176789468993771 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(0.0818352170959651 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(0.0185788443667458 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(-0.145045692246617 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(-0.0191342141762809 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(0.448493917745964 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH),
                                to_signed(integer(round(0.72646527160508 *(2.0**(TAP_WIDTH-1)))), TAP_WIDTH));

  type data_rec is record
    i : signed(WIDTH-1 downto 0);
    q : signed(WIDTH-1 downto 0);
  end record data_rec;

  type prod_rec is record
    i : signed(WIDTH+TAP_WIDTH-1 downto 0);
    q : signed(WIDTH+TAP_WIDTH-1 downto 0);
  end record prod_rec;
  type prod_type is array (0 to integer(ceil(real(TAPS_N)/2.0))-1) of prod_rec;

  type sum_rec is record
    i : signed(WIDTH+TAP_WIDTH+integer(ceil(log2(real(TAPS_N-1))))-1 downto 0);
    q : signed(WIDTH+TAP_WIDTH+integer(ceil(log2(real(TAPS_N-1))))-1 downto 0);
  end record sum_rec;
  type sum_type is array (0 to TAPS_N-1) of sum_rec;
  type sum_reg_type is array (0 to TAPS_N-3) of sum_rec;

  type valid_delay_type is array (0 to TAPS_N/4+1) of std_logic;
  type bits_delay_type is array (0 to TAPS_N/4+1) of std_logic_vector(BITS-1 downto 0);
  
  signal input_reg   : data_rec;
  signal prod        : prod_type;
  signal sum         : sum_type;
  signal sum_reg     : sum_reg_type;
  signal output_even : data_rec;
  signal output_odd  : data_rec;

  signal valid_delay : valid_delay_type;
  signal bits_delay  : bits_delay_type;

  -- Avoid wasting DSP slices if necessary 
  attribute USE_DSP         : string;
  attribute USE_DSP of sum  : signal is "no";
  attribute USE_DSP of prod : signal is "no";

begin

  -- I/O registers
  io_reg_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        input_reg <= (others => (others => '0'));
        i_out     <= (others => '0');
        q_out     <= (others => '0');
      else
        input_reg.i <= signed(i_in);
        input_reg.q <= signed(q_in);
        i_out       <= std_logic_vector(output_odd.i) & std_logic_vector(output_even.i);
        q_out       <= std_logic_vector(output_odd.q) & std_logic_vector(output_even.q);
      end if;
    end if;
  end process io_reg_proc;

  -- Product calculations
  products_gen : for tap_idx in 0 to integer(ceil(real(TAPS_N)/2.0))-1 generate
    prod(tap_idx).i <= input_reg.i * TAPS(tap_idx);
    prod(tap_idx).q <= input_reg.q * TAPS(tap_idx);
  end generate products_gen;

  -- Sum registers
  sum_reg_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        sum_reg <= (others => (others => (others => '0')));
      else
        for sum_idx in 0 to TAPS_N-3 loop
          sum_reg(sum_idx) <= sum(sum_idx);
        end loop;
      end if;
    end if;
  end process sum_reg_proc;

  -- Summations, first two are directly connected
  sum(0).i <= resize(prod(0).i, sum(0).i'length);
  sum(0).q <= resize(prod(0).q, sum(0).q'length);
  sum(1).i <= resize(prod(1).i, sum(1).i'length);
  sum(1).q <= resize(prod(1).q, sum(1).q'length);
  -- From 2 to center tap
  sum1_gen : for sum_idx in 2 to integer(ceil(real(TAPS_N)/2.0))-1 generate
    sum(sum_idx).i <= sum_reg(sum_idx-2).i + resize(prod(sum_idx).i, sum(sum_idx).i'length);
    sum(sum_idx).q <= sum_reg(sum_idx-2).q + resize(prod(sum_idx).q, sum(sum_idx).q'length);
  end generate sum1_gen;
  -- From center tap+1 to end
  sum2_gen : for sum_idx in integer(ceil(real(TAPS_N)/2.0)) to TAPS_N-1 generate
    sum(sum_idx).i <= sum_reg(sum_idx-2).i + resize(prod(TAPS_N-1-sum_idx).i, sum(sum_idx).i'length);
    sum(sum_idx).q <= sum_reg(sum_idx-2).q + resize(prod(TAPS_N-1-sum_idx).q, sum(sum_idx).q'length);
  end generate sum2_gen;

  -- Round output data
  output_even.i <= resize(shift_right(shift_right(sum(TAPS_N-1).i, TAP_WIDTH-2) + 1, 1), output_even.i'length);
  output_even.q <= resize(shift_right(shift_right(sum(TAPS_N-1).q, TAP_WIDTH-2) + 1, 1), output_even.q'length);
  output_odd.i  <= resize(shift_right(shift_right(sum(TAPS_N-2).i, TAP_WIDTH-2) + 1, 1), output_odd.i'length);
  output_odd.q  <= resize(shift_right(shift_right(sum(TAPS_N-2).q, TAP_WIDTH-2) + 1, 1), output_odd.q'length);

  -- Delay for bits and valid signals
  delay_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        bits_delay  <= (others => (others => '0'));
        valid_delay <= (others => '0');
      else
        bits_delay(0)  <= bits_in;
        valid_delay(0) <= valid_in;
        for idx in 1 to TAPS_N/4+1 loop
          bits_delay(idx)  <= bits_delay(idx-1);
          valid_delay(idx) <= valid_delay(idx-1);
        end loop;
      end if;
    end if;
  end process delay_proc;

  bits_out  <= bits_delay(TAPS_N/4+1);
  valid_out <= valid_delay(TAPS_N/4+1);

end architecture arch;
