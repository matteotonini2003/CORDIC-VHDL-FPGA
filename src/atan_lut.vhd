library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ATAN_LUT is
    port(
        addr       : in  unsigned(3 downto 0);
        atan_value : out signed(19 downto 0)
    );
end entity ATAN_LUT;

architecture rtl of ATAN_LUT is
begin

    process(addr)
    begin
        case to_integer(addr) is
            when  0 => atan_value <= to_signed( 51472, 20); -- atan(2^-0) = 0.785398163397 rad, fixed = 51472
            when  1 => atan_value <= to_signed( 30386, 20); -- atan(2^-1) = 0.463647609001 rad, fixed = 30386
            when  2 => atan_value <= to_signed( 16055, 20); -- atan(2^-2) = 0.244978663127 rad, fixed = 16055
            when  3 => atan_value <= to_signed(  8150, 20); -- atan(2^-3) = 0.124354994547 rad, fixed = 8150
            when  4 => atan_value <= to_signed(  4091, 20); -- atan(2^-4) = 0.062418809996 rad, fixed = 4091
            when  5 => atan_value <= to_signed(  2047, 20); -- atan(2^-5) = 0.031239833430 rad, fixed = 2047
            when  6 => atan_value <= to_signed(  1024, 20); -- atan(2^-6) = 0.015623728620 rad, fixed = 1024
            when  7 => atan_value <= to_signed(   512, 20); -- atan(2^-7) = 0.007812341060 rad, fixed = 512
            when  8 => atan_value <= to_signed(   256, 20); -- atan(2^-8) = 0.003906230132 rad, fixed = 256
            when  9 => atan_value <= to_signed(   128, 20); -- atan(2^-9) = 0.001953122516 rad, fixed = 128
            when 10 => atan_value <= to_signed(    64, 20); -- atan(2^-10) = 0.000976562190 rad, fixed = 64
            when 11 => atan_value <= to_signed(    32, 20); -- atan(2^-11) = 0.000488281211 rad, fixed = 32
            when 12 => atan_value <= to_signed(    16, 20); -- atan(2^-12) = 0.000244140620 rad, fixed = 16
            when 13 => atan_value <= to_signed(     8, 20); -- atan(2^-13) = 0.000122070312 rad, fixed = 8
            when 14 => atan_value <= to_signed(     4, 20); -- atan(2^-14) = 0.000061035156 rad, fixed = 4
            when 15 => atan_value <= to_signed(     2, 20); -- atan(2^-15) = 0.000030517578 rad, fixed = 2
            when others => atan_value <= (others => '0');
        end case;
    end process;

end architecture rtl;
