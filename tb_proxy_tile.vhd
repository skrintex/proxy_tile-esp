library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.esp_global.all;
use work.nocpackage.all;
use std.env.all;
entity tb_proxy_tile is
end entity;

architecture sim of tb_proxy_tile is
  signal clk   : std_logic   := '0';
  signal rstn  : std_logic   := '0';

  -- plane 1
  signal noc1_out_data : coh_noc_flit_type := (others => '0');
  signal noc1_out_void : std_ulogic        := '1';
  signal noc1_out_stop : std_ulogic;
  signal noc1_in_data  : coh_noc_flit_type;
  signal noc1_in_void  : std_ulogic;
  signal noc1_in_stop  : std_ulogic        := '0';

  -- plane 2
  signal noc2_out_data : coh_noc_flit_type := (others => '0');
  signal noc2_out_void : std_ulogic        := '1';
  signal noc2_out_stop : std_ulogic;
  signal noc2_in_data  : coh_noc_flit_type;
  signal noc2_in_void  : std_ulogic;
  signal noc2_in_stop  : std_ulogic        := '0';

  -- plane 3
  signal noc3_out_data : coh_noc_flit_type := (others => '0');
  signal noc3_out_void : std_ulogic        := '1';
  signal noc3_out_stop : std_ulogic;
  signal noc3_in_data  : coh_noc_flit_type;
  signal noc3_in_void  : std_ulogic;
  signal noc3_in_stop  : std_ulogic        := '0';

  -- plane 4
  signal noc4_out_data : dma_noc_flit_type := (others => '0');
  signal noc4_out_void : std_ulogic        := '1';
  signal noc4_out_stop : std_ulogic;
  signal noc4_in_data  : dma_noc_flit_type;
  signal noc4_in_void  : std_ulogic;
  signal noc4_in_stop  : std_ulogic        := '0';

  -- plane 5
  signal noc5_out_data : misc_noc_flit_type := (others => '0');
  signal noc5_out_void : std_ulogic         := '1';
  signal noc5_out_stop : std_ulogic;
  signal noc5_in_data  : misc_noc_flit_type;
  signal noc5_in_void  : std_ulogic;
  signal noc5_in_stop  : std_ulogic         := '0';

  -- plane 6
  signal noc6_out_data : dma_noc_flit_type := (others => '0');
  signal noc6_out_void : std_ulogic        := '1';
  signal noc6_out_stop : std_ulogic;
  signal noc6_in_data  : dma_noc_flit_type;
  signal noc6_in_void  : std_ulogic;
  signal noc6_in_stop  : std_ulogic        := '0';

  -- TX link
  signal tx_clk_o   : std_ulogic;
  signal tx_valid_o : std_ulogic;
  signal tx_ready_i : std_ulogic := '1';
  signal tx_plane_o : std_logic_vector(2 downto 0);
  signal tx_flit_o  : std_logic_vector(COH_NOC_FLIT_SIZE - 1 downto 0);

  -- RX link
  signal rx_valid_i : std_ulogic := '0';
  signal rx_ready_o : std_ulogic;
  signal rx_plane_i : std_logic_vector(2 downto 0) := (others => '0');
  signal rx_flit_i  : std_logic_vector(COH_NOC_FLIT_SIZE - 1 downto 0) := (others => '0');

  -- credits
  signal credit_return_i : std_logic := '0';
  signal credit_pulse_o  : std_logic;
  signal dbg_fifo_wr_ptr_0 : integer;
  signal dbg_fifo_count_0  : integer;
  signal dbg_state : integer;
    function mk_hdr(payload : std_logic_vector(63 downto 0))
    return coh_noc_flit_type is
    variable f : coh_noc_flit_type := (others => '0');
  begin
    f(65 downto 64) := "10";   -- header
    f(63 downto 0)  := payload;
    return f;
  end function;

  function mk_body(payload : std_logic_vector(63 downto 0))
    return coh_noc_flit_type is
    variable f : coh_noc_flit_type := (others => '0');
  begin
    f(65 downto 64) := "00";   -- body
    f(63 downto 0)  := payload;
    return f;
  end function;

  function mk_tail(payload : std_logic_vector(63 downto 0))
    return coh_noc_flit_type is
    variable f : coh_noc_flit_type := (others => '0');
  begin
    f(65 downto 64) := "01";   -- tail
    f(63 downto 0)  := payload;
    return f;
  end function;

  

  function mk_1flit(payload : std_logic_vector(63 downto 0))
    return coh_noc_flit_type is
    variable f : coh_noc_flit_type := (others => '0');
  begin
    f(65 downto 64) := "11";   -- one-flit packet
    f(63 downto 0)  := payload;
    return f;
  end function;

begin
  clk <= not clk after 5 ns;

  dut : entity work.proxy_tile
    generic map (
      G_FIFO_DEPTH      => 4,
      G_CREDIT_WIDTH    => 4,
      G_INITIAL_CREDITS => 15
    )
    port map (
      clk   => clk,
      rstn  => rstn,

      noc1_out_data => noc1_out_data,
      noc1_out_void => noc1_out_void,
      noc1_out_stop => noc1_out_stop,
      noc1_in_data  => noc1_in_data,
      noc1_in_void  => noc1_in_void,
      noc1_in_stop  => noc1_in_stop,

      noc2_out_data => noc2_out_data,
      noc2_out_void => noc2_out_void,
      noc2_out_stop => noc2_out_stop,
      noc2_in_data  => noc2_in_data,
      noc2_in_void  => noc2_in_void,
      noc2_in_stop  => noc2_in_stop,

      noc3_out_data => noc3_out_data,
      noc3_out_void => noc3_out_void,
      noc3_out_stop => noc3_out_stop,
      noc3_in_data  => noc3_in_data,
      noc3_in_void  => noc3_in_void,
      noc3_in_stop  => noc3_in_stop,

      noc4_out_data => noc4_out_data,
      noc4_out_void => noc4_out_void,
      noc4_out_stop => noc4_out_stop,
      noc4_in_data  => noc4_in_data,
      noc4_in_void  => noc4_in_void,
      noc4_in_stop  => noc4_in_stop,

      noc5_out_data => noc5_out_data,
      noc5_out_void => noc5_out_void,
      noc5_out_stop => noc5_out_stop,
      noc5_in_data  => noc5_in_data,
      noc5_in_void  => noc5_in_void,
      noc5_in_stop  => noc5_in_stop,

      noc6_out_data => noc6_out_data,
      noc6_out_void => noc6_out_void,
      noc6_out_stop => noc6_out_stop,
      noc6_in_data  => noc6_in_data,
      noc6_in_void  => noc6_in_void,
      noc6_in_stop  => noc6_in_stop,
            dbg_fifo_wr_ptr_0 => dbg_fifo_wr_ptr_0,
      dbg_fifo_count_0  => dbg_fifo_count_0,
      dbg_state => dbg_state,

      tx_clk_o   => tx_clk_o,
      tx_valid_o => tx_valid_o,
      tx_ready_i => tx_ready_i,
      tx_plane_o => tx_plane_o,
      tx_flit_o  => tx_flit_o,

      rx_valid_i => rx_valid_i,
      rx_ready_o => rx_ready_o,
      rx_plane_i => rx_plane_i,
      rx_flit_i  => rx_flit_i,

      credit_return_i => credit_return_i,
      credit_pulse_o  => credit_pulse_o
    );

  stim : process
    variable expected_tx : coh_noc_flit_type;
    variable expected_rx : coh_noc_flit_type;
    variable rd_hdr  : coh_noc_flit_type;
    variable rd_addr : coh_noc_flit_type;
    variable rd_len  : coh_noc_flit_type;
    variable wr_hdr  : coh_noc_flit_type;
    variable wr_addr : coh_noc_flit_type;
    variable wr_len  : coh_noc_flit_type;
    variable wr_data : coh_noc_flit_type;
    variable rr2_hdr    : coh_noc_flit_type;
    variable rr2_addr   : coh_noc_flit_type;
    variable rr2_len    : coh_noc_flit_type;
    variable fifo_fill0 : coh_noc_flit_type;
    variable fifo_fill1 : coh_noc_flit_type;
    variable fifo_fill2 : coh_noc_flit_type;
    variable fifo_fill3 : coh_noc_flit_type;
    variable fifo_over  : coh_noc_flit_type;
  begin
    ----------------------------------------------------------------
    -- reset
    ----------------------------------------------------------------
    rstn <= '0';
    wait for 25 ns;
    rstn <= '1';
    wait for 20 ns;

    

----------------------------------------------------------------
-- TEST 1: local plane 1 READ request -> TX link
----------------------------------------------------------------
tx_ready_i <= '0';

rd_hdr  := mk_hdr (x"1111222233334444");
rd_addr := mk_body(x"0000000000001000");
rd_len  := mk_tail(x"0000000000000004");

-- push header
noc1_out_data <= rd_hdr;
noc1_out_void <= '0';
wait until rising_edge(clk);
noc1_out_void <= '1';

-- push address
noc1_out_data <= rd_addr;
noc1_out_void <= '0';
wait until rising_edge(clk);
noc1_out_void <= '1';

-- push length
noc1_out_data <= rd_len;
noc1_out_void <= '0';
wait until rising_edge(clk);
noc1_out_void <= '1';

-- wait until header TX stage is reached and held by backpressure
   -- S_HDR
wait for 1 ns;
assert dbg_state = 1
  report "FAIL: expected S_HDR while stalled"
  severity error;

assert tx_valid_o = '1'
  report "FAIL: tx_valid_o should be high while stalled in S_HDR"
  severity error;
assert tx_plane_o = "001"
  report "FAIL: transmitted plane ID is not plane 1"
  severity error;
assert tx_flit_o = rd_hdr
  report "FAIL: first transmitted flit should be read header"
  severity error;

-- release stall; header consumed on next rising edge
tx_ready_i <= '1';

wait until rising_edge(clk);
wait for 1 ns;
assert tx_flit_o = rd_addr
  report "FAIL: second transmitted flit should be read address"
  severity error;

wait until rising_edge(clk);
wait for 1 ns;
assert tx_flit_o = rd_len
  report "FAIL: third transmitted flit should be read length"
  severity error;

wait until rising_edge(clk);
wait for 1 ns;
assert dbg_state = 4  -- update if your dbg_state map changed
  report "FAIL: after read request TX, FSM should be in S_RD_WAIT"
  severity error;
report "test1 passed" severity note;
    ----------------------------------------------------------------
    -- TEST 2: RX response -> local plane 1, completes read wait
    ----------------------------------------------------------------
    expected_rx := mk_1flit(x"AAAABBBBCCCCDDDD");

    rx_plane_i <= "001";
    rx_flit_i  <= expected_rx;
    rx_valid_i <= '1';
    wait for 1 ns;

    assert rx_ready_o = '1'
      report "FAIL: RX should be ready when noc1_in_stop = 0"
      severity error;
    assert noc1_in_void = '0'
      report "FAIL: local noc1 input should be valid during RX accept"
      severity error;
    assert noc1_in_data = expected_rx
      report "FAIL: local noc1 input flit does not match RX flit"
      severity error;
    assert credit_pulse_o = '1'
      report "FAIL: credit pulse should assert when RX flit is accepted"
      severity error;

    wait until rising_edge(clk);
    wait for 1 ns;

    rx_valid_i <= '0';
    rx_plane_i <= (others => '0');
    rx_flit_i  <= (others => '0');

    assert dbg_state = 0
      report "FAIL: after read response, FSM should return to S_IDLE"
      severity error;

    report "TEST1 + TEST2 passed" severity note;
    -- clean up / settle one cycle before next test
noc1_out_void <= '1';
rx_valid_i    <= '0';
rx_plane_i    <= (others => '0');
rx_flit_i     <= (others => '0');
tx_ready_i    <= '1';

wait until rising_edge(clk);
wait for 1 ns;

        ----------------------------------------------------------------
    -- TEST 3: TX backpressure during READ meta transmit
    ----------------------------------------------------------------
    rd_hdr  := mk_hdr (x"5555666677778888");
    rd_addr := mk_body(x"0000000000002000");
    rd_len  := mk_tail(x"0000000000000008");

    -- enqueue the 3-flit read request
    noc1_out_data <= rd_hdr;  noc1_out_void <= '0';
    wait until rising_edge(clk);
    noc1_out_void <= '1';

    noc1_out_data <= rd_addr; noc1_out_void <= '0';
    wait until rising_edge(clk);
    noc1_out_void <= '1';

    noc1_out_data <= rd_len;  noc1_out_void <= '0';
    wait until rising_edge(clk);
    noc1_out_void <= '1';

    -- wait until DUT reaches transmit stage and then stall it
    wait until tx_valid_o = '1';
    tx_ready_i <= '0';
    wait for 1 ns;

    assert tx_plane_o = "001"
      report "FAIL: wrong plane while stalled"
      severity error;

    assert tx_flit_o = rd_hdr
      report "FAIL: first stalled TX flit should be read header"
      severity error;

    wait for 20 ns;

    assert tx_valid_o = '1'
      report "FAIL: TX valid should stay high while waiting for ready"
      severity error;

    assert tx_flit_o = rd_hdr
      report "FAIL: TX flit should stay stable while stalled"
      severity error;

    tx_ready_i <= '1';
    wait until rising_edge(clk);
    wait for 1 ns;

    assert tx_flit_o = rd_addr
      report "FAIL: after releasing stall, next flit should advance to address"
      severity error;

    wait until rising_edge(clk);
    wait for 1 ns;
    assert tx_flit_o = rd_len
      report "FAIL: final read meta flit should be length"
      severity error;
      -- one more clock so DUT can leave S_RD_TX
      wait until rising_edge(clk);
      wait for 1 ns;


      assert dbg_state = 5
  report "FAIL: FSM did not move to S_RD_WAIT after final read beat"
  severity error;

report "TEST1 + TEST2 + TEST3 passed" severity note;
----------------------------------------------------------------
    -- TEST 4: RX blocked by local stop
    ----------------------------------------------------------------
    noc1_in_stop <= '1';
    expected_rx := mk_1flit(x"9999AAAABBBBCCCC");

    rx_plane_i <= "001";
    rx_flit_i  <= expected_rx;
    rx_valid_i <= '1';
    wait for 1 ns;

    assert rx_ready_o = '0'
      report "FAIL: RX should not be ready when noc1_in_stop = 1"
      severity error;

    assert credit_pulse_o = '0'
      report "FAIL: no credit pulse should be generated while blocked"
      severity error;

    noc1_in_stop <= '0';
    wait for 1 ns;

    assert rx_ready_o = '1'
      report "FAIL: RX should become ready once noc1_in_stop is released"
      severity error;

    assert noc1_in_void = '0'
      report "FAIL: RX flit should be presented to local noc1 once unblocked"
      severity error;

    wait until rising_edge(clk);
    wait for 1 ns;
    rx_valid_i <= '0';
    rx_plane_i <= (others => '0');
    rx_flit_i  <= (others => '0');
    noc1_in_stop <= '0';
    wait for 1 ns;

    assert dbg_state = 0
      report "FAIL: after TEST 4 RX accept, FSM should return to S_IDLE"
      severity error;

    report "TEST 4 passed" severity note;

    wait until rising_edge(clk);
    wait for 1 ns;

    
 
   ----------------------------------------------------------------
-- TEST 5: local plane 1 WRITE request -> TX link
----------------------------------------------------------------
report "Starting TEST 5" severity note;

tx_ready_i <= '1';

wr_hdr  := mk_hdr (x"DEADBEEF00000001");
wr_addr := mk_body(x"0000000000003000");
wr_len  := mk_body(x"0000000000000001");  -- not tail => write
wr_data := mk_tail(x"CAFEBABE12345678");

noc1_out_data <= wr_hdr;
noc1_out_void <= '0';
wait until rising_edge(clk);
noc1_out_void <= '1';

noc1_out_data <= wr_addr;
noc1_out_void <= '0';
wait until rising_edge(clk);
noc1_out_void <= '1';

noc1_out_data <= wr_len;
noc1_out_void <= '0';
wait until rising_edge(clk);
noc1_out_void <= '1';

noc1_out_data <= wr_data;
noc1_out_void <= '0';
wait until rising_edge(clk);
noc1_out_void <= '1';

-- Give FSM one clock to move from S_LEN -> S_WR_TX_META
wait until rising_edge(clk);
wait for 1 ns;

assert dbg_state = 6
  report "FAIL: write should enter S_WR_TX_META first"
  severity error;

assert tx_valid_o = '1'
  report "FAIL: tx_valid_o should be high on write beat 1"
  severity error;

assert tx_plane_o = "001"
  report "FAIL: write should transmit on plane 1"
  severity error;

assert tx_flit_o = wr_hdr
  report "FAIL: write TX beat 1 should be header"
  severity error;

wait until rising_edge(clk);
wait for 1 ns;
assert dbg_state = 6
  report "FAIL: write beat 2 should still be in S_WR_TX_META"
  severity error;
assert tx_flit_o = wr_addr
  report "FAIL: write TX beat 2 should be address"
  severity error;

wait until rising_edge(clk);
wait for 1 ns;
assert dbg_state = 6
  report "FAIL: write beat 3 should still be in S_WR_TX_META"
  severity error;
assert tx_flit_o = wr_len
  report "FAIL: write TX beat 3 should be length"
  severity error;

wait until rising_edge(clk);
wait for 1 ns;
assert dbg_state = 7
  report "FAIL: write data beat should be in S_WR_TX_DATA"
  severity error;
assert tx_flit_o = wr_data
  report "FAIL: write TX beat 4 should be data tail"
  severity error;

wait until rising_edge(clk);
wait for 1 ns;
assert dbg_state = 0
  report "FAIL: after write tail, FSM should return to S_IDLE"
  severity error;

report "TEST 5 passed" severity note;
    -- hard reset between standalone plane-2 debug test and RR test
    noc1_out_void <= '1';
    noc2_out_void <= '1';
    rx_valid_i    <= '0';
    rx_plane_i    <= (others => '0');
    rx_flit_i     <= (others => '0');
    tx_ready_i    <= '1';
    noc1_in_stop  <= '0';
    noc2_in_stop  <= '0';

    wait until rising_edge(clk);
    wait until rising_edge(clk);

    rstn <= '0';
    wait until rising_edge(clk);
    wait until rising_edge(clk);

    rstn <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
       ----------------------------------------------------------------
    -- TEST 6: round-robin arbitration across plane 1 and plane 2
    ----------------------------------------------------------------
    report "Starting TEST 6" severity note;

    -- settle
    noc1_out_void <= '1';
    noc2_out_void <= '1';
    rx_valid_i    <= '0';
    rx_plane_i    <= (others => '0');
    rx_flit_i     <= (others => '0');
    noc1_in_stop  <= '0';
    noc2_in_stop  <= '0';
    tx_ready_i    <= '1';
    wait until rising_edge(clk);
    wait for 1 ns;

    ----------------------------------------------------------------
    -- Prime last_grant so plane 1 is the previous winner
    ----------------------------------------------------------------
    tx_ready_i <= '0';

    rd_hdr  := mk_hdr (x"0101010101010101");
    rd_addr := mk_body(x"0000000000004000");
    rd_len  := mk_tail(x"0000000000000002");

    noc1_out_data <= rd_hdr;
    noc1_out_void <= '0';
    wait until rising_edge(clk);
    noc1_out_void <= '1';

    noc1_out_data <= rd_addr;
    noc1_out_void <= '0';
    wait until rising_edge(clk);
    noc1_out_void <= '1';

    noc1_out_data <= rd_len;
    noc1_out_void <= '0';
    wait until rising_edge(clk);
    noc1_out_void <= '1';

    wait until dbg_state = 4;
    wait for 1 ns;

    assert tx_valid_o = '1'
      report "FAIL: prime step should reach TX valid"
      severity error;
    assert tx_plane_o = "001"
      report "FAIL: prime step should select plane 1"
      severity error;
    assert tx_flit_o = rd_hdr
      report "FAIL: prime step first flit should be plane 1 header"
      severity error;

    tx_ready_i <= '1';

    wait until rising_edge(clk);
    wait for 1 ns;
    assert tx_plane_o = "001" and tx_flit_o = rd_addr
      report "FAIL: prime step second flit should be plane 1 address"
      severity error;

    wait until rising_edge(clk);
    wait for 1 ns;
    assert tx_plane_o = "001" and tx_flit_o = rd_len
      report "FAIL: prime step third flit should be plane 1 length"
      severity error;

    wait until rising_edge(clk);
    wait for 1 ns;
    assert dbg_state = 5
      report "FAIL: prime step should enter S_RD_WAIT"
      severity error;

    expected_rx := mk_1flit(x"1111000011110000");
    rx_plane_i  <= "001";
    rx_flit_i   <= expected_rx;
    rx_valid_i  <= '1';

    wait until rising_edge(clk);
    wait for 1 ns;

    rx_valid_i <= '0';
    rx_plane_i <= (others => '0');
    rx_flit_i  <= (others => '0');

    assert dbg_state = 0
      report "FAIL: prime step should return to S_IDLE after plane 1 response"
      severity error;

    wait until rising_edge(clk);
    wait for 1 ns;

    ----------------------------------------------------------------
    -- Now queue plane 1 and plane 2 packets simultaneously,
    -- but HOLD tx_ready_i low so both packets are fully present
    -- before arbitration begins transmitting.
    ----------------------------------------------------------------
    tx_ready_i <= '0';

    rd_hdr   := mk_hdr (x"1111222233334444");
    rd_addr  := mk_body(x"0000000000005000");
    rd_len   := mk_tail(x"0000000000000004");

    rr2_hdr  := mk_hdr (x"AAAA222233334444");
    rr2_addr := mk_body(x"0000000000006000");
    rr2_len  := mk_tail(x"0000000000000008");

    -- header cycle
    noc1_out_data <= rd_hdr;
    noc1_out_void <= '0';
    noc2_out_data <= rr2_hdr;
    noc2_out_void <= '0';
    wait until rising_edge(clk);
    noc1_out_void <= '1';
    noc2_out_void <= '1';

    -- address cycle
    noc1_out_data <= rd_addr;
    noc1_out_void <= '0';
    noc2_out_data <= rr2_addr;
    noc2_out_void <= '0';
    wait until rising_edge(clk);
    noc1_out_void <= '1';
    noc2_out_void <= '1';

    -- length cycle
    noc1_out_data <= rd_len;
    noc1_out_void <= '0';
    noc2_out_data <= rr2_len;
    noc2_out_void <= '0';
    wait until rising_edge(clk);
    noc1_out_void <= '1';
    noc2_out_void <= '1';

    -- wait until TX stage is reached while still stalled
    wait until dbg_state = 4;
    wait for 1 ns;

    assert tx_valid_o = '1'
      report "FAIL: RR test should reach TX valid"
      severity error;
    assert tx_plane_o = "010"
      report "FAIL: RR arbitration should pick plane 2 first after plane 1 was previous winner"
      severity error;
    assert tx_flit_o = rr2_hdr
      report "FAIL: first RR transmitted flit should be plane 2 header"
      severity error;

    -- release stall and check remaining 2 metadata beats
    tx_ready_i <= '1';

    wait until rising_edge(clk);
    wait for 1 ns;
    assert tx_valid_o = '1'
      report "FAIL: RR beat 2 should still be valid"
      severity error;
    assert tx_plane_o = "010"
      report "FAIL: RR beat 2 should still be plane 2"
      severity error;
    assert tx_flit_o = rr2_addr
      report "FAIL: second RR transmitted flit should be plane 2 address"
      severity error;

    wait until rising_edge(clk);
    wait for 1 ns;
    assert tx_valid_o = '1'
      report "FAIL: RR beat 3 should still be valid"
      severity error;
    assert tx_plane_o = "010"
      report "FAIL: RR beat 3 should still be plane 2"
      severity error;
    assert tx_flit_o = rr2_len
      report "FAIL: third RR transmitted flit should be plane 2 length"
      severity error;

    wait until rising_edge(clk);
    wait for 1 ns;
    assert dbg_state = 5
      report "FAIL: after plane 2 read request TX, FSM should be in S_RD_WAIT"
      severity error;

    -- complete plane 2 read
    expected_rx := mk_1flit(x"2222000022220000");
    rx_plane_i  <= "010";
    rx_flit_i   <= expected_rx;
    rx_valid_i  <= '1';

    wait until rising_edge(clk);
    wait for 1 ns;

    rx_valid_i <= '0';
    rx_plane_i <= (others => '0');
    rx_flit_i  <= (others => '0');

    assert dbg_state = 0
      report "FAIL: after plane 2 response, FSM should return to S_IDLE"
      severity error;

    -- pending plane 1 packet should go next
    wait until dbg_state = 4;
    wait for 1 ns;

    assert tx_valid_o = '1'
      report "FAIL: rotated request should reach TX valid"
      severity error;
    assert tx_plane_o = "001"
      report "FAIL: RR arbitration should rotate to plane 1 next"
      severity error;
    assert tx_flit_o = rd_hdr
      report "FAIL: rotated RR first flit should be plane 1 header"
      severity error;

    wait until rising_edge(clk);
    wait for 1 ns;
    assert tx_flit_o = rd_addr
      report "FAIL: rotated RR second flit should be plane 1 address"
      severity error;

    wait until rising_edge(clk);
    wait for 1 ns;
    assert tx_flit_o = rd_len
      report "FAIL: rotated RR third flit should be plane 1 length"
      severity error;

    wait until rising_edge(clk);
    wait for 1 ns;
    assert dbg_state = 5
      report "FAIL: after rotated plane 1 TX, FSM should be in S_RD_WAIT"
      severity error;

    expected_rx := mk_1flit(x"3333000033330000");
    rx_plane_i  <= "001";
    rx_flit_i   <= expected_rx;
    rx_valid_i  <= '1';

    wait until rising_edge(clk);
    wait for 1 ns;

    rx_valid_i <= '0';
    rx_plane_i <= (others => '0');
    rx_flit_i  <= (others => '0');

    assert dbg_state = 0
      report "FAIL: after final RR response, FSM should return to S_IDLE"
      severity error;

    report "TEST 6 passed" severity note;
    ----------------------------------------------------------------
    -- TEST 7: FIFO full behavior on plane 1
    ----------------------------------------------------------------
    report "Starting TEST 7" severity note;

    -- Park the FSM in S_RD_WAIT on plane 2 so plane 1 FIFO cannot drain
    rr2_hdr  := mk_hdr (x"BBBB000000000001");
    rr2_addr := mk_body(x"0000000000007000");
    rr2_len  := mk_tail(x"0000000000000001");

    noc2_out_data <= rr2_hdr;
    noc2_out_void <= '0';
    wait until rising_edge(clk);
    noc2_out_void <= '1';

    noc2_out_data <= rr2_addr;
    noc2_out_void <= '0';
    wait until rising_edge(clk);
    noc2_out_void <= '1';

    noc2_out_data <= rr2_len;
    noc2_out_void <= '0';
    wait until rising_edge(clk);
    noc2_out_void <= '1';

    wait until dbg_state = 4;
    wait for 1 ns;
    assert tx_plane_o = "010"
      report "FAIL: TEST 7 setup should transmit plane 2 request"
      severity error;

    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait for 1 ns;

    assert dbg_state = 5
      report "FAIL: TEST 7 setup should leave FSM in S_RD_WAIT"
      severity error;

    assert dbg_fifo_count_0 = 0
      report "FAIL: plane 1 FIFO should start empty before fill test"
      severity error;

    fifo_fill0 := mk_hdr (x"F000000000000001");
    fifo_fill1 := mk_body(x"F000000000000002");
    fifo_fill2 := mk_body(x"F000000000000003");
    fifo_fill3 := mk_tail(x"F000000000000004");
    fifo_over  := mk_1flit(x"F000000000000005");

    -- fill entry 0
    noc1_out_data <= fifo_fill0;
    noc1_out_void <= '0';
    wait until rising_edge(clk);
    noc1_out_void <= '1';
    wait for 1 ns;

    assert dbg_fifo_count_0 = 1
      report "FAIL: plane 1 FIFO count should be 1 after first write"
      severity error;
    assert noc1_out_stop = '0'
      report "FAIL: noc1_out_stop should stay low before FIFO is full"
      severity error;

    -- fill entry 1
    noc1_out_data <= fifo_fill1;
    noc1_out_void <= '0';
    wait until rising_edge(clk);
    noc1_out_void <= '1';
    wait for 1 ns;

    assert dbg_fifo_count_0 = 2
      report "FAIL: plane 1 FIFO count should be 2 after second write"
      severity error;
    assert noc1_out_stop = '0'
      report "FAIL: noc1_out_stop should still be low at count 2"
      severity error;

    -- fill entry 2
    noc1_out_data <= fifo_fill2;
    noc1_out_void <= '0';
    wait until rising_edge(clk);
    noc1_out_void <= '1';
    wait for 1 ns;

    assert dbg_fifo_count_0 = 3
      report "FAIL: plane 1 FIFO count should be 3 after third write"
      severity error;
    assert noc1_out_stop = '0'
      report "FAIL: noc1_out_stop should still be low at count 3"
      severity error;

    -- fill entry 3 => FIFO should become full here
    noc1_out_data <= fifo_fill3;
    noc1_out_void <= '0';
    wait until rising_edge(clk);
    noc1_out_void <= '1';
    wait for 1 ns;

    assert dbg_fifo_count_0 = 4
      report "FAIL: plane 1 FIFO count should be 4 when full"
      severity error;
    assert noc1_out_stop = '1'
      report "FAIL: noc1_out_stop should assert when plane 1 FIFO is full"
      severity error;

    -- try to overfill while stop is high; DUT should ignore the write
    noc1_out_data <= fifo_over;
    noc1_out_void <= '0';
    wait until rising_edge(clk);
    noc1_out_void <= '1';
    wait for 1 ns;

    assert dbg_fifo_count_0 = 4
      report "FAIL: extra flit should not be written when FIFO is full"
      severity error;
    assert noc1_out_stop = '1'
      report "FAIL: noc1_out_stop should remain asserted while FIFO stays full"
      severity error;

    report "TEST 7 passed" severity note;
  stop;
  wait;
  end process;
    
end architecture;
