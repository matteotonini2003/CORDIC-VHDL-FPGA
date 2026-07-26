library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity DFF_N_Signed is
    generic (
        N : positive := 16
    );
    port (
        clk   : in  std_logic;
        reset : in  std_logic;  -- reset asincrono attivo alto
        en    : in  std_logic;  -- enable di caricamento
        d     : in  signed(N-1 downto 0);
        q     : out signed(N-1 downto 0)
    );
end entity;

architecture rtl of DFF_N_Signed is
begin

    p_DFF : process(clk, reset)
    begin
        if reset = '1' then
            q <= (others => '0');

        elsif rising_edge(clk) then
            if en = '1' then
                q <= d;
            end if;
        end if;
    end process;

end architecture;