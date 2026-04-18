library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.esp_global.all;
use work.nocpackage.all;
entity proxy_tile is
  generic (
    G_FIFO_DEPTH      : positive := 4;
    G_CREDIT_WIDTH    : positive := 4;
    G_INITIAL_CREDITS : natural  := 8
  );

  port (
    clk   : in  std_logic;
    rstn  : in  std_logic;

     -- NoC plane 1 (coherence request)
    noc1_out_data : in  coh_noc_flit_type;
    noc1_out_void : in  std_ulogic;
    noc1_out_stop : out std_ulogic;
    noc1_in_data  : out coh_noc_flit_type;
    noc1_in_void  : out std_ulogic;
    noc1_in_stop  : in  std_ulogic;

    -- NoC plane 2 (coherence forwarded)
    noc2_out_data : in  coh_noc_flit_type;
    noc2_out_void : in  std_ulogic;
    noc2_out_stop : out std_ulogic;
    noc2_in_data  : out coh_noc_flit_type;
    noc2_in_void  : out std_ulogic;
    noc2_in_stop  : in  std_ulogic;

     -- NoC plane 3 (coherence response)
    noc3_out_data : in  coh_noc_flit_type;
    noc3_out_void : in  std_ulogic;
    noc3_out_stop : out std_ulogic;
    noc3_in_data  : out coh_noc_flit_type;
    noc3_in_void  : out std_ulogic;
    noc3_in_stop  : in  std_ulogic;
    -- NoC plane 4
    noc4_out_data : in  dma_noc_flit_type;
    noc4_out_void : in  std_ulogic;
    noc4_out_stop : out std_ulogic;
    noc4_in_data  : out dma_noc_flit_type;
    noc4_in_void  : out std_ulogic;
    noc4_in_stop  : in  std_ulogic;

    -- NoC plane 5 (misc/APB)
    noc5_out_data : in  misc_noc_flit_type;
    noc5_out_void : in  std_ulogic;
    noc5_out_stop : out std_ulogic;
    noc5_in_data  : out misc_noc_flit_type;
    noc5_in_void  : out std_ulogic;
    noc5_in_stop  : in  std_ulogic;


    -- NoC plane 6 (DMA request)
    noc6_out_data : in  dma_noc_flit_type;
    noc6_out_void : in  std_ulogic;
    noc6_out_stop : out std_ulogic;
    noc6_in_data  : out dma_noc_flit_type;
    noc6_in_void  : out std_ulogic;
    noc6_in_stop  : in  std_ulogic;

   -- Forward inter-FPGA link (local -> remote)
    tx_clk_o   : out std_ulogic;
    tx_valid_o : out std_ulogic;
    tx_ready_i : in  std_ulogic;
    tx_plane_o : out std_logic_vector(2 downto 0);
    tx_flit_o  : out std_logic_vector(COH_NOC_FLIT_SIZE-1 downto 0);

    -- Reverse inter-FPGA link (remote -> local)
    rx_valid_i : in  std_ulogic;
    rx_ready_o : out std_ulogic;
    rx_plane_i : in  std_logic_vector(2 downto 0);
    rx_flit_i  : in  std_logic_vector(COH_NOC_FLIT_SIZE-1 downto 0);

     ---------------------------------------------------------------------------
    -- Credit flow control
    ---------------------------------------------------------------------------
    credit_return_i : in  std_logic;
    credit_pulse_o  : out std_logic;
        dbg_fifo_wr_ptr_0 : out integer;
    dbg_fifo_count_0  : out integer;
    dbg_state : out integer
  );
  end entity;
  architecture rtl of proxy_tile is

  constant G_NPLANES       : positive := 6;
  constant G_LINK_WIDTH    : positive := COH_NOC_FLIT_SIZE;
  constant PLANE1_ID       : std_logic_vector(2 downto 0) := "001";
  constant PLANE2_ID       : std_logic_vector(2 downto 0) := "010";
  constant PLANE3_ID       : std_logic_vector(2 downto 0) := "011";
  constant PLANE4_ID       : std_logic_vector(2 downto 0) := "100";
  constant PLANE5_ID       : std_logic_vector(2 downto 0) := "101";
  constant PLANE6_ID       : std_logic_vector(2 downto 0) := "110";
  
  subtype link_flit_t is std_logic_vector(G_LINK_WIDTH - 1 downto 0);
  type link_flit_array_t is array (0 to G_NPLANES - 1) of link_flit_t;
  type fifo_mem_plane_t   is array (0 to G_FIFO_DEPTH - 1) of link_flit_t;
  type fifo_mem_t         is array (0 to G_NPLANES - 1) of fifo_mem_plane_t;
  type ptr_arr_t          is array (0 to G_NPLANES - 1) of integer range 0 to G_FIFO_DEPTH - 1;
  type cnt_arr_t          is array (0 to G_NPLANES - 1) of integer range 0 to G_FIFO_DEPTH;
  type state_t is (
  S_IDLE,
  S_HDR,
  S_ADDR,
  S_LEN,
  S_RD_TX,
  S_RD_WAIT,
  S_WR_TX_META,
  S_WR_TX_DATA
);
type pkt_kind_t is (PKT_NONE, PKT_READ, PKT_WRITE);

-- for to check if the plane has any data
  function has_any(valids : std_logic_vector) return boolean is
  begin
    for i in valids'range loop
      if valids(i) = '1' then
        return true;
      end if;
    end loop;
    return false;
  end function;
-- arbiter logic goes in a circular fashion
  function rr_pick(
    valids     : std_logic_vector;
    last_grant : natural
  ) return natural is
    variable idx : natural := last_grant;
  begin
    for k in 1 to valids'length loop
      idx := (last_grant + k) mod valids'length;
      if valids(idx) = '1' then
        return idx;
      end if;
    end loop;
    return last_grant;
  end function;
-- fifo pointer to increment 
-- 0 → 1
--1 → 2
--2 → 3
--3 → 0
  function inc_ptr(p : integer) return integer is
  begin
    if p = G_FIFO_DEPTH - 1 then
      return 0;
    else
      return p + 1;
    end if;
  end function;
  function flit_preamble(plane : natural; flit : link_flit_t) return noc_preamble_type is
    variable p : noc_preamble_type;
  begin
    case plane is
      when 0 | 1 | 2 =>
        p := get_preamble(
               COH_NOC_FLIT_SIZE,
               coh_noc_flit_pad & flit(COH_NOC_FLIT_SIZE - 1 downto 0)
             );
      when 3 | 5 =>
        p := get_preamble(
               DMA_NOC_FLIT_SIZE,
               dma_noc_flit_pad & flit(DMA_NOC_FLIT_SIZE - 1 downto 0)
             );
      when 4 =>
        p := get_preamble_misc(flit(MISC_NOC_FLIT_SIZE - 1 downto 0));
      when others =>
        p := PREAMBLE_BODY;
    end case;
    return p;
  end function;

  function plane_is_header(plane : natural; flit : link_flit_t) return boolean is
  variable p : noc_preamble_type;
begin
  p := flit_preamble(plane, flit);
  return (p = PREAMBLE_HEADER) or (p = PREAMBLE_1FLIT);
end function;
  function plane_is_tail(plane : natural; flit : link_flit_t) return boolean is
    variable p : noc_preamble_type;
  begin
    p := flit_preamble(plane, flit);
    return (p = PREAMBLE_TAIL) or (p = PREAMBLE_1FLIT);
  end function;

  function plane_to_id(plane : natural) return std_logic_vector is
  begin
    case plane is
      when 0 => return PLANE1_ID;
      when 1 => return PLANE2_ID;
      when 2 => return PLANE3_ID;
      when 3 => return PLANE4_ID;
      when 4 => return PLANE5_ID;
      when 5 => return PLANE6_ID;
      when others => return "000";
    end case;
  end function;
  function id_to_plane(id : std_logic_vector(2 downto 0)) return natural is
  begin
    case id is
      when PLANE1_ID => return 0;
      when PLANE2_ID => return 1;
      when PLANE3_ID => return 2;
      when PLANE4_ID => return 3;
      when PLANE5_ID => return 4;
      when PLANE6_ID => return 5;
      when others    => return 0;
    end case;
  end function;
  


  signal st               : state_t := S_IDLE;
signal pkt_kind_reg     : pkt_kind_t := PKT_NONE;
signal active_plane     : integer range 0 to G_NPLANES - 1 := 0;
signal last_grant       : integer range 0 to G_NPLANES - 1 := 0;
signal grant_valid      : std_ulogic;
signal grant_plane      : integer range 0 to G_NPLANES - 1;

signal fifo_mem         : fifo_mem_t := (others => (others => (others => '0')));
signal fifo_wr_ptr      : ptr_arr_t  := (others => 0);
signal fifo_rd_ptr      : ptr_arr_t  := (others => 0);
signal fifo_count       : cnt_arr_t  := (others => 0);
signal fifo_empty       : std_logic_vector(G_NPLANES - 1 downto 0);
signal fifo_full        : std_logic_vector(G_NPLANES - 1 downto 0);
signal fifo_wr_en       : std_logic_vector(G_NPLANES - 1 downto 0);
signal fifo_rd_en       : std_logic_vector(G_NPLANES - 1 downto 0);
signal plane_has_data   : std_logic_vector(G_NPLANES - 1 downto 0);
signal eligible_planes  : std_logic_vector(G_NPLANES - 1 downto 0);
signal fifo_din_arr     : link_flit_array_t;
signal fifo_dout_arr    : link_flit_array_t;
signal noc_valid_vec    : std_logic_vector(G_NPLANES - 1 downto 0);

signal hdr_reg          : link_flit_t := (others => '0');
signal addr_reg         : link_flit_t := (others => '0');
signal len_reg          : link_flit_t := (others => '0');
signal meta_tx_idx      : integer range 0 to 2 := 0;

signal credits          : unsigned(G_CREDIT_WIDTH - 1 downto 0);
signal tx_credit_ok     : std_ulogic;
signal tx_flit_int      : link_flit_t;
signal tx_valid_int     : std_ulogic;
signal tx_plane_int     : std_logic_vector(2 downto 0);
signal tx_fire          : std_ulogic;

signal req_plane_reg    : integer range 0 to G_NPLANES - 1 := 0;
signal read_pending     : std_logic := '0';
signal rx_ready_int     : std_ulogic;
signal rx_fire          : std_ulogic;
signal credit_pulse_int : std_ulogic;
signal rx_target_plane  : integer range 0 to G_NPLANES - 1;
signal rx_read_done     : std_logic;



  
  begin
    assert COH_NOC_FLIT_SIZE = DMA_NOC_FLIT_SIZE
    report "proxy_tile assumes COH and DMA planes use the same 66-bit link width"
    severity failure;

    ---------------------------------------------------------------------------
  -- Bridge explicit NoC ports to internal vectors/arrays.
  ---------------------------------------------------------------------------
  noc_valid_vec(0) <= not noc1_out_void;
  noc_valid_vec(1) <= not noc2_out_void;
  noc_valid_vec(2) <= not noc3_out_void;
  noc_valid_vec(3) <= not noc4_out_void;
  noc_valid_vec(4) <= not noc5_out_void;
  noc_valid_vec(5) <= not noc6_out_void;

  fifo_din_arr(0) <= std_logic_vector(noc1_out_data);
  fifo_din_arr(1) <= std_logic_vector(noc2_out_data);
  fifo_din_arr(2) <= std_logic_vector(noc3_out_data);
  fifo_din_arr(3) <= std_logic_vector(noc4_out_data);
  fifo_din_arr(5) <= std_logic_vector(noc6_out_data);

  fifo_din_misc_pack : process(all) is
    variable tmp : link_flit_t;
  begin
    tmp := (others => '0');
    tmp(MISC_NOC_FLIT_SIZE - 1 downto 0) := std_logic_vector(noc5_out_data);
    fifo_din_arr(4) <= tmp;
  end process;



  -----------------------------------------------------------------------------
  -- Internal FIFO status / direct read-out from current rd_ptr.
  -----------------------------------------------------------------------------
  gen_fifo_view : for i in 0 to G_NPLANES - 1 generate
  begin
    fifo_empty(i)      <= '1' when fifo_count(i) = 0            else '0';
    fifo_full(i)       <= '1' when fifo_count(i) = G_FIFO_DEPTH else '0';
    plane_has_data(i)  <= not fifo_empty(i);
    fifo_dout_arr(i)   <= fifo_mem(i)(fifo_rd_ptr(i));
    fifo_wr_en(i)      <= noc_valid_vec(i) and (not fifo_full(i));
  end generate;

  noc1_out_stop <= fifo_full(0);
  noc2_out_stop <= fifo_full(1);
  noc3_out_stop <= fifo_full(2);
  noc4_out_stop <= fifo_full(3);
  noc5_out_stop <= fifo_full(4);
  noc6_out_stop <= fifo_full(5);
-- what is it doing, is the fifo empty, it full, does it have data, can it accept input, should current input be written, and what's the current output flit
  -----------------------------------------------------------------------------
  -- FIFO storage update for all planes.
  -----------------------------------------------------------------------------
  process(clk, rstn)
    variable do_write : boolean;
    variable do_read  : boolean;
    variable ncount   : integer range 0 to G_FIFO_DEPTH;
  begin
    if rstn = '0' then
      fifo_wr_ptr <= (others => 0);
      fifo_rd_ptr <= (others => 0);
      fifo_count  <= (others => 0);
    elsif rising_edge(clk) then
      for i in 0 to G_NPLANES - 1 loop
        do_write := (fifo_wr_en(i) = '1') and (fifo_count(i) < G_FIFO_DEPTH);
        do_read  := (fifo_rd_en(i) = '1') and (fifo_count(i) > 0);

        if do_write then
          fifo_mem(i)(fifo_wr_ptr(i)) <= fifo_din_arr(i);
        end if;

        if do_write then
          fifo_wr_ptr(i) <= inc_ptr(fifo_wr_ptr(i));
        end if;

        if do_read then
          fifo_rd_ptr(i) <= inc_ptr(fifo_rd_ptr(i));
        end if;

        ncount := fifo_count(i);
        if do_write and not do_read then
          ncount := fifo_count(i) + 1;
        elsif do_read and not do_write then
          ncount := fifo_count(i) - 1;
        end if;
        fifo_count(i) <= ncount;
      end loop;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Round-robin arbiter over packet heads
  -----------------------------------------------------------------------------
  eligible_gen : for i in 0 to G_NPLANES - 1 generate
  begin
    eligible_planes(i) <= plane_has_data(i) when plane_is_header(i, fifo_dout_arr(i)) else '0';
  end generate;

  process(all)
    variable pick_v : natural range 0 to G_NPLANES - 1;
  begin
    grant_valid <= '0';
    grant_plane <= last_grant;

    if has_any(eligible_planes) then
      pick_v      := rr_pick(eligible_planes, last_grant);
      grant_plane <= pick_v;
      grant_valid <= '1';
    end if;
  end process;


  -----------------------------------------------------------------------------
  -- Credit counter
  -----------------------------------------------------------------------------
  tx_credit_ok <= '1' when credits /= 0 else '0';

  process(clk, rstn)
  begin
    if rstn = '0' then
      credits <= to_unsigned(G_INITIAL_CREDITS, G_CREDIT_WIDTH);
    elsif rising_edge(clk) then
      if credit_return_i = '1' and tx_fire = '1' then
        credits <= credits;
      elsif credit_return_i = '1' then
        credits <= credits + 1;
      elsif tx_fire = '1' then
        credits <= credits - 1;
      end if;
    end if;
  end process;


  -----------------------------------------------------------------------------
  -- TX datapath from LOCKED plane FIFO to inter-FPGA link.
  -- The FSM pops one flit at a time from the active plane FIFO.
  -----------------------------------------------------------------------------
  process(all)
begin
  tx_flit_int  <= (others => '0');
  tx_valid_int <= '0';
  tx_plane_int <= plane_to_id(active_plane);
  fifo_rd_en   <= (others => '0');

  case st is
    -- Parse stages: pop one flit from the selected FIFO
    when S_HDR | S_ADDR | S_LEN =>
      if plane_has_data(active_plane) = '1' then
        fifo_rd_en(active_plane) <= '1';
      end if;

    -- Read TX: send stored header/address/length
    when S_RD_TX =>
      if tx_credit_ok = '1' then
        tx_valid_int <= '1';
        case meta_tx_idx is
          when 0      => tx_flit_int <= hdr_reg;
          when 1      => tx_flit_int <= addr_reg;
          when others => tx_flit_int <= len_reg;
        end case;
      end if;

    -- Write TX metadata: send stored header/address/length
    when S_WR_TX_META =>
      if tx_credit_ok = '1' then
        tx_valid_int <= '1';
        case meta_tx_idx is
          when 0      => tx_flit_int <= hdr_reg;
          when 1      => tx_flit_int <= addr_reg;
          when others => tx_flit_int <= len_reg;
        end case;
      end if;

    -- Write TX data: stream data flits directly from FIFO
    when S_WR_TX_DATA =>
      tx_flit_int <= fifo_dout_arr(active_plane);
      tx_valid_int <= plane_has_data(active_plane) and tx_credit_ok;
      fifo_rd_en(active_plane) <= tx_ready_i and tx_credit_ok and plane_has_data(active_plane);

    when others =>
      null;
  end case;
end process;

tx_fire <= tx_valid_int and tx_ready_i;
  ---------------------------------------------------------------------------
  -- Main FSM: lock a plane, then keep forwarding until TAIL / 1FLIT.
  ---------------------------------------------------------------------------
  process(clk, rstn)
begin
  if rstn = '0' then
    st            <= S_IDLE;
    pkt_kind_reg  <= PKT_NONE;
    active_plane  <= 0;
    last_grant    <= 0;
    hdr_reg       <= (others => '0');
    addr_reg      <= (others => '0');
    len_reg       <= (others => '0');
    meta_tx_idx   <= 0;
    req_plane_reg <= 0;
    read_pending  <= '0';

  elsif rising_edge(clk) then
    case st is

      when S_IDLE =>
        pkt_kind_reg <= PKT_NONE;
        if grant_valid = '1' then
          active_plane <= grant_plane;
          last_grant   <= grant_plane;
          st           <= S_HDR;
        end if;

      when S_HDR =>
        if plane_has_data(active_plane) = '1' then
          hdr_reg <= fifo_dout_arr(active_plane);
          st      <= S_ADDR;
        end if;

      when S_ADDR =>
        if plane_has_data(active_plane) = '1' then
          addr_reg <= fifo_dout_arr(active_plane);
          st       <= S_LEN;
        end if;

      when S_LEN =>
        if plane_has_data(active_plane) = '1' then
          len_reg     <= fifo_dout_arr(active_plane);
          meta_tx_idx <= 0;

          -- Option B rule:
          -- if length flit is tail, this is a read request
          -- otherwise it is a write request followed by data
          if plane_is_tail(active_plane, fifo_dout_arr(active_plane)) then
            pkt_kind_reg <= PKT_READ;
            st           <= S_RD_TX;
          else
            pkt_kind_reg <= PKT_WRITE;
            st           <= S_WR_TX_META;
          end if;
        end if;

      when S_RD_TX =>
        if tx_fire = '1' then
          if meta_tx_idx = 2 then
            req_plane_reg <= active_plane;
            read_pending  <= '1';
            st            <= S_RD_WAIT;
          else
            meta_tx_idx <= meta_tx_idx + 1;
          end if;
        end if;

      when S_RD_WAIT =>
        if rx_read_done = '1' then
          read_pending <= '0';
          pkt_kind_reg <= PKT_NONE;
          st           <= S_IDLE;
        end if;

      when S_WR_TX_META =>
        if tx_fire = '1' then
          if meta_tx_idx = 2 then
            st <= S_WR_TX_DATA;
          else
            meta_tx_idx <= meta_tx_idx + 1;
          end if;
        end if;

      when S_WR_TX_DATA =>
        if (tx_fire = '1') and plane_is_tail(active_plane, fifo_dout_arr(active_plane)) then
          pkt_kind_reg <= PKT_NONE;
          st           <= S_IDLE;
        end if;

    end case;
  end if;
end process;
---------------------------------------------------------------------------
  -- Reverse link routing back into the correct local NoC plane.
  -- The reverse link already preserves packet order; no extra RX FSM needed.
  ---------------------------------------------------------------------------
  rx_target_plane <= id_to_plane(rx_plane_i);

  process(all)
  begin
    noc1_in_data <= (others => '0');
    noc2_in_data <= (others => '0');
    noc3_in_data <= (others => '0');
    noc4_in_data <= (others => '0');
    noc5_in_data <= (others => '0');
    noc6_in_data <= (others => '0');

    noc1_in_void <= '1';
    noc2_in_void <= '1';
    noc3_in_void <= '1';
    noc4_in_void <= '1';
    noc5_in_void <= '1';
    noc6_in_void <= '1';

    rx_ready_int <= '0';

    case rx_target_plane is
      when 0 =>
        noc1_in_data <= coh_noc_flit_type(rx_flit_i(COH_NOC_FLIT_SIZE-1 downto 0));
        noc1_in_void <= not rx_valid_i;
        rx_ready_int <= not noc1_in_stop;
      when 1 =>
        noc2_in_data <= coh_noc_flit_type(rx_flit_i(COH_NOC_FLIT_SIZE-1 downto 0));
        noc2_in_void <= not rx_valid_i;
        rx_ready_int <= not noc2_in_stop;
      when 2 =>
        noc3_in_data <= coh_noc_flit_type(rx_flit_i(COH_NOC_FLIT_SIZE-1 downto 0));
        noc3_in_void <= not rx_valid_i;
        rx_ready_int <= not noc3_in_stop;
      when 3 =>
        noc4_in_data <= dma_noc_flit_type(rx_flit_i(DMA_NOC_FLIT_SIZE-1 downto 0));
        noc4_in_void <= not rx_valid_i;
        rx_ready_int <= not noc4_in_stop;
      when 4 =>
        noc5_in_data <= misc_noc_flit_type(rx_flit_i(MISC_NOC_FLIT_SIZE-1 downto 0));
        noc5_in_void <= not rx_valid_i;
        rx_ready_int <= not noc5_in_stop;
      when 5 =>
        noc6_in_data <= dma_noc_flit_type(rx_flit_i(DMA_NOC_FLIT_SIZE-1 downto 0));
        noc6_in_void <= not rx_valid_i;
        rx_ready_int <= not noc6_in_stop;
      when others =>
        rx_ready_int <= '0';
    end case;
  end process;

  rx_fire          <= rx_valid_i and rx_ready_int;
  credit_pulse_int <= rx_fire;  
  rx_read_done <= '1' when
  (rx_fire = '1') and
  (read_pending = '1') and
  (rx_target_plane = req_plane_reg) and
  plane_is_tail(req_plane_reg, link_flit_t(rx_flit_i))
else
  '0';

  -----------------------------------------------------------------------------
  -- Outputs
  -----------------------------------------------------------------------------
  tx_clk_o       <= clk;
  tx_flit_o      <= tx_flit_int;
  tx_valid_o     <= tx_valid_int;
  tx_plane_o     <= tx_plane_int;

  rx_ready_o     <= rx_ready_int;
  credit_pulse_o <= credit_pulse_int;
    dbg_fifo_wr_ptr_0 <= fifo_wr_ptr(0);
  dbg_fifo_count_0  <= fifo_count(0);

  dbg_state <=
    0  when st = S_IDLE       else
    1  when st = S_HDR        else
    2  when st = S_ADDR       else
    3  when st = S_LEN        else
    4  when st = S_RD_TX      else
    5  when st = S_RD_WAIT    else
    6  when st = S_WR_TX_META else
    7  when st = S_WR_TX_DATA else
    15;


  -- rx_clk_i is intentionally unused in this version. If RX is truly in another
  -- clock domain, insert a proper async FIFO or CDC stage on the RX side.

end architecture;





