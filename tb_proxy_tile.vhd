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
      G_INITIAL_CREDITS => 2
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
  begin
    ----------------------------------------------------------------
    -- reset
    ----------------------------------------------------------------
    rstn <= '0';
    wait for 25 ns;
    rstn <= '1';
    wait for 20 ns;

    ----------------------------------------------------------------
    -- TEST 1: local plane 1 -> TX link
    ----------------------------------------------------------------
    expected_tx := mk_1flit(x"1111222233334444");

    noc1_out_data <= expected_tx;
    noc1_out_void <= '0';
    wait until rising_edge(clk);
    noc1_out_void <= '1';

    wait until tx_valid_o = '1';
    wait for 1 ns;

    assert tx_plane_o = "001"
      report "FAIL: transmitted plane ID is not plane 1"
      severity error;

    assert tx_flit_o = expected_tx
      report "FAIL: transmitted flit does not match local input flit"
      severity error;

    wait until rising_edge(clk);

    ----------------------------------------------------------------
    -- TEST 2: RX link -> local plane 1
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
      report "FAIL: local noc1 input should be valid during RX injection"
      severity error;

    assert noc1_in_data = expected_rx
      report "FAIL: local noc1 input flit does not match RX flit"
      severity error;

    assert credit_pulse_o = '1'
      report "FAIL: credit pulse should assert when RX flit is accepted"
      severity error;

    wait until rising_edge(clk);
    rx_valid_i <= '0';
    wait for 10 ns;

    ----------------------------------------------------------------
    -- TEST 3: TX backpressure
    ----------------------------------------------------------------
    tx_ready_i <= '0';
    expected_tx := mk_1flit(x"5555666677778888");

    noc1_out_data <= expected_tx;
    noc1_out_void <= '0';
    wait until rising_edge(clk);
    noc1_out_void <= '1';

    wait for 20 ns;

    assert tx_valid_o = '1'
      report "FAIL: TX valid should stay high while waiting for ready"
      severity error;

    tx_ready_i <= '1';
    wait until rising_edge(clk);
    wait for 1 ns;

    assert tx_plane_o = "001"
      report "FAIL: wrong plane after TX stall release"
      severity error;

    assert tx_flit_o = expected_tx
      report "FAIL: wrong flit after TX stall release"
      severity error;

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
    rx_valid_i <= '0';

    report "tb_proxy_tile completed successfully" severity note;
    stop;
    wait;
  end process;
end architecture;
