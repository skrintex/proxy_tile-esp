library ieee;
use ieee.std_logic_1164.all;

package esp_global is
  constant COH_NOC_FLIT_SIZE  : positive := 66;
  constant DMA_NOC_FLIT_SIZE  : positive := 66;
  constant MISC_NOC_FLIT_SIZE : positive := 64;

  subtype coh_noc_flit_type  is std_logic_vector(COH_NOC_FLIT_SIZE - 1 downto 0);
  subtype dma_noc_flit_type  is std_logic_vector(DMA_NOC_FLIT_SIZE - 1 downto 0);
  subtype misc_noc_flit_type is std_logic_vector(MISC_NOC_FLIT_SIZE - 1 downto 0);

  constant coh_noc_flit_pad : std_logic_vector(0 downto 0) := "0";
  constant dma_noc_flit_pad : std_logic_vector(0 downto 0) := "0";
end package;

package body esp_global is
end package body;