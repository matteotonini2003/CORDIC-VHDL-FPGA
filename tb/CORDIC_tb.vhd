library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity CORDIC_tb is
end entity;

architecture beh of CORDIC_tb is

    --------------------------------------------------------------------
    -- Costanti del testbench
    --------------------------------------------------------------------

    constant TB_DATA_IN       : positive := 16;
    constant TB_DATA_INTERNAL : positive := 20;
    constant TB_ANGLE_WIDTH   : positive := 20;
    constant TB_ITERATIONS    : positive := 16;
    constant CLK_PERIOD : time := 8 ns;

    --------------------------------------------------------------------
    -- Segnali del testbench
    --------------------------------------------------------------------

    signal tb_clk   : std_logic := '0';
    signal tb_reset : std_logic := '0';
    signal tb_start : std_logic := '0';

    signal tb_x_in  : signed(TB_DATA_IN-1 downto 0) := (others => '0');
    signal tb_y_in  : signed(TB_DATA_IN-1 downto 0) := (others => '0');

    signal tb_rho   : signed(TB_DATA_INTERNAL-1 downto 0);
    signal tb_theta : signed(TB_ANGLE_WIDTH-1 downto 0);

    signal tb_valid : std_logic;
    signal testing : boolean := true;
     
    component CORDIC is
	generic (
        DATA_IN        : positive := 16;  -- ingresso signed Q2.14
        DATA_INTERNAL  : positive := 20;  -- segnali interni signed Q4.16
        ANGLE_WIDTH    : positive := 20;  -- larghezza per z/theta
        ITERATIONS     : positive := 16   -- numero di iterazioni CORDIC
    ); 
    port (
        clk    : in  std_logic;
        reset  : in  std_logic;
        start  : in  std_logic;

        x_in   : in  signed(DATA_IN-1 downto 0);
        y_in   : in  signed(DATA_IN-1 downto 0);

        rho    : out signed(DATA_INTERNAL-1 downto 0);
        theta  : out signed(ANGLE_WIDTH-1 downto 0);

        valid  : out std_logic
    );
    end component;

begin

    --------------------------------------------------------------------
    -- Clock generation
    --------------------------------------------------------------------

    tb_clk <= not tb_clk after CLK_PERIOD/2 when testing else '0';

    --------------------------------------------------------------------
    -- Istanza del CORDIC
    --------------------------------------------------------------------

    i_CORDIC: CORDIC
        generic map (
            DATA_IN       => TB_DATA_IN,
            DATA_INTERNAL => TB_DATA_INTERNAL,
            ANGLE_WIDTH   => TB_ANGLE_WIDTH,
            ITERATIONS    => TB_ITERATIONS
        )
        port map (
            clk   => tb_clk,
            reset => tb_reset,
            start => tb_start,

            x_in  => tb_x_in,
            y_in  => tb_y_in,

            rho   => tb_rho,
            theta => tb_theta,

            valid => tb_valid
        );
    
    --------------------------------------------------------------------
    -- Stimulus process
    --------------------------------------------------------------------
    p_STIM : process

        procedure wait_clocks(constant n : integer) is
            begin
                for k in 0 to n-1 loop
                    wait until rising_edge(tb_clk);
                end loop;
        end procedure;

        procedure apply_input(
            constant x_val : integer;
            constant y_val : integer
            ) is
        begin
            -- Carico gli ingressi
            tb_x_in <= to_signed(x_val, TB_DATA_IN);
            tb_y_in <= to_signed(y_val, TB_DATA_IN);

            -- Impulso di start di 1 clock
            tb_start <= '1';
            wait until rising_edge(tb_clk);
            tb_start <= '0';

            -- Aspetto che il CORDIC finisca
            wait_clocks(50);
            wait until rising_edge(tb_clk);

            -- Pausa tra due test
            wait for 3 * CLK_PERIOD;
        end procedure;

    begin

        ----------------------------------------------------------------
        -- Reset iniziale
        ----------------------------------------------------------------
        tb_reset <= '1';
        tb_start <= '0';
        tb_x_in <= (others => '0');
        tb_y_in <= (others => '0');

        wait for 5 * CLK_PERIOD;

        tb_reset <= '0';

        wait for 2 * CLK_PERIOD;

        ---------------------------------------------------------------------------------
        -- La procedure apply_input prende in ingresso degli integer, si deve notare che:
        -- rho è Q4.16  → valore reale = rho / 65536
        -- theta è Q4.16 → valore reale in radianti = theta / 65536
        -- Esempi attesi:
        -- theta = pi/4    ≈ 0.785398 → fixed ≈ 51472
        -- theta = -pi/4   ≈ -0.785398 → fixed ≈ -51472
        -- theta = 3pi/4   ≈ 2.356194 → fixed ≈ 154416
        -- theta = -3pi/4  ≈ -2.356194 → fixed ≈ -154416
        -- rho = 1         → fixed ≈ 65536
        -- rho = sqrt(2)   → fixed ≈ 92781

        ----------------------------------------------------------------
        -- Test 1: punto sull'asse x positivo
        -- x = 1, y = 0
        -- Atteso: rho ≈ 1, theta ≈ 0
        ----------------------------------------------------------------
        apply_input(16384, 0);

        ----------------------------------------------------------------
        -- Test 2: primo quadrante
        -- x = 1, y = 1
        -- Atteso: rho ≈ sqrt(2), theta ≈ +pi/4
        ----------------------------------------------------------------
        apply_input(16384, 16384);

        ----------------------------------------------------------------
        -- Test 3: quarto quadrante
        -- x = 1, y = -1
        -- Atteso: rho ≈ sqrt(2), theta ≈ -pi/4
        ----------------------------------------------------------------
        apply_input(16384, -16384);

        ----------------------------------------------------------------
        -- Test 4: secondo quadrante
        -- x = -1, y = 1
        -- Atteso: rho ≈ sqrt(2), theta ≈ +3pi/4
        ----------------------------------------------------------------
        apply_input(-16384, 16384);

        ----------------------------------------------------------------
        -- Test 5: terzo quadrante
        -- x = -1, y = -1
        -- Atteso: rho ≈ sqrt(2), theta ≈ -3pi/4
        ----------------------------------------------------------------
        apply_input(-16384, -16384);

        ----------------------------------------------------------------
        -- Test 6: punto nullo
        -- x = 0, y = 0
        -- Atteso: rho = 0, theta = 0, valid = 1
        ----------------------------------------------------------------
        apply_input(0, 0);

        ----------------------------------------------------------------
        -- Test 7: valore generico nel primo quadrante
        -- x = 0.5, y = 1
        -- Atteso: rho ≈ 1.118, theta ≈ atan(2)
        ----------------------------------------------------------------
        apply_input(8192, 16384);

        ----------------------------------------------------------------
        -- Test 8: valore generico nel quarto quadrante
        -- x = 1, y = -0.5
        -- Atteso: rho ≈ 1.118, theta ≈ atan(-0.5)
        ----------------------------------------------------------------
        apply_input(16384, -8192);

        ----------------------------------------------------------------
        -- Test 9: start durante elaborazione
        -- Il secondo start deve essere ignorato perché il CORDIC non è in IDLE
        ----------------------------------------------------------------

        tb_x_in <= to_signed(16384, TB_DATA_IN);   -- x = 1
        tb_y_in <= to_signed(16384, TB_DATA_IN);   -- y = 1

        tb_start <= '1';
        wait until rising_edge(tb_clk);
        tb_start <= '0';

        -- Dopo pochi clock cambio ingresso e provo a rilanciare start
        -- mentre il CORDIC è ancora in RUN
        wait for 4 * CLK_PERIOD;

        tb_x_in <= to_signed(-16384, TB_DATA_IN);  -- x = -1
        tb_y_in <= to_signed(-16384, TB_DATA_IN);  -- y = -1

        tb_start <= '1';
        wait until rising_edge(tb_clk);
        tb_start <= '0';

        -- Aspetto risultato: deve riferirsi al primo input, non al secondo
        wait_clocks(50);
        wait until rising_edge(tb_clk);

        wait for 5 * CLK_PERIOD;

        ----------------------------------------------------------------
        -- Fine simulazione
        ----------------------------------------------------------------
        testing <= false;
        wait until rising_edge(tb_clk); -- blocked here

    end process;

end architecture;