library ieee;
use ieee.std_logic_1164.all;
use work.esp_global.all;

package nocpackage is

  constant PREAMBLE_WIDTH : natural := 2;

  -- 67-bit helper type so pad(1) & 66-bit flit matches old ESP-style calls
  subtype max_noc_flit_type is std_logic_vector(COH_NOC_FLIT_SIZE downto 0);
  subtype noc_preamble_type is std_logic_vector(PREAMBLE_WIDTH-1 downto 0);

  constant PREAMBLE_HEADER : noc_preamble_type := "10";
  constant PREAMBLE_TAIL   : noc_preamble_type := "01";
  constant PREAMBLE_BODY   : noc_preamble_type := "00";
  constant PREAMBLE_1FLIT  : noc_preamble_type := "11";

  -- Match the old ESP-style API that proxy_tile.vhd already uses
  function get_preamble(
    constant flit_sz : integer;
    flit : max_noc_flit_type
  ) return noc_preamble_type;

  function get_preamble_misc(
    flit : misc_noc_flit_type
  ) return noc_preamble_type;

  function plane_is_tail(
    plane : natural;
    flit  : std_logic_vector
  ) return boolean;

end package;

package body nocpackage is

  function get_preamble(
    constant flit_sz : integer;
    flit : max_noc_flit_type
  ) return noc_preamble_type is
    variable ret : noc_preamble_type;
  begin
    ret := flit(flit_sz - 1 downto flit_sz - PREAMBLE_WIDTH);
    return ret;
  end function;

  function get_preamble_misc(
    flit : misc_noc_flit_type
  ) return noc_preamble_type is
    variable ret : noc_preamble_type;
  begin
    ret := flit(MISC_NOC_FLIT_SIZE - 1 downto MISC_NOC_FLIT_SIZE - PREAMBLE_WIDTH);
    return ret;
  end function;

  function plane_is_tail(
    plane : natural;
    flit  : std_logic_vector
  ) return boolean is
    variable p : noc_preamble_type;
  begin
    if plane = 4 then
      p := get_preamble_misc(flit(MISC_NOC_FLIT_SIZE - 1 downto 0));
    else
      p := get_preamble(COH_NOC_FLIT_SIZE, coh_noc_flit_pad & flit(COH_NOC_FLIT_SIZE - 1 downto 0));
    end if;

    return (p = PREAMBLE_TAIL) or (p = PREAMBLE_1FLIT);
  end function;

end package body;