library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity CORDIC_WRAPPER is 
    port (
        clk       : in  std_logic;
        
        ------------------------------------------------------------------
        -- Ingressi fisici dalla scheda
        ------------------------------------------------------------------
        btn_reset : in  std_logic;
        btn_start : in  std_logic;

        sw        : in  std_logic_vector(3 downto 0);

        ------------------------------------------------------------------
        -- Uscite fisiche sulla scheda
        ------------------------------------------------------------------
        led_out   : out std_logic_vector(3 downto 0)
    );
end entity;


architecture structural of CORDIC_WRAPPER is

    ------------------------------------------------------------------
    -- Segnali interni per pilotare il CORDIC
    ------------------------------------------------------------------

    signal x_in_s  : signed(15 downto 0);
    signal y_in_s  : signed(15 downto 0);

    signal rho_s   : signed(19 downto 0);
    signal theta_s : signed(19 downto 0);

    signal valid_s : std_logic;

    ------------------------------------------------------------------
    -- Segnale selezionato per la visualizzazione
    ------------------------------------------------------------------

    signal selected_value : signed(19 downto 0);

    ------------------------------------------------------------------
    -- Start impulsivo
    ------------------------------------------------------------------

    signal start_reg   : std_logic := '0';
    signal start_pulse : std_logic := '0';

    ------------------------------------------------------------------
    -- Valid memorizzato per renderlo visibile sui LED
    ------------------------------------------------------------------

    signal valid_latched : std_logic := '0';

    ------------------------------------------------------------------
    -- Component CORDIC
    ------------------------------------------------------------------

    component CORDIC is 
        generic (
            DATA_IN       : positive := 16;
            DATA_INTERNAL : positive := 20;
            ANGLE_WIDTH   : positive := 20;
            ITERATIONS    : positive := 16
        );
        port (
            clk   : in  std_logic;
            reset : in  std_logic;
            start : in  std_logic;

            x_in  : in  signed(DATA_IN-1 downto 0);
            y_in  : in  signed(DATA_IN-1 downto 0);

            rho   : out signed(DATA_INTERNAL-1 downto 0);
            theta : out signed(ANGLE_WIDTH-1 downto 0);

            valid : out std_logic
        );
    end component;

begin

    ------------------------------------------------------------------
    -- Generazione impulso di start di un solo ciclo di clock
    ------------------------------------------------------------------
    -- Il pulsante fisico può restare premuto per molti clock.
    -- start_pulse invece rimane alto solo per un ciclo.
    ------------------------------------------------------------------

    p_start_pulse : process(clk, btn_reset)
    begin
        if btn_reset = '1' then
            start_reg   <= '0';
            start_pulse <= '0';

        elsif rising_edge(clk) then
            start_reg   <= btn_start;
            start_pulse <= btn_start and not start_reg;
        end if;
    end process;


    ------------------------------------------------------------------
    -- Selezione dei due test tramite SW0
    ------------------------------------------------------------------
    -- sw(0) = 0 -> Test 1: x = -1, y = 0
    -- sw(0) = 1 -> Test 2: x = 1, y = 1
    --
    -- Formato ingressi Q2.14:
    -- 1.0 = 16384
    ------------------------------------------------------------------

    p_test_vectors : process(sw)
    begin
        if sw(0) = '0' then

            --------------------------------------------------------------
            -- Test 1: asse X negativo
            -- x = -1, y = 0
            -- Atteso: rho circa 1, theta circa 0
            --------------------------------------------------------------
            x_in_s <= to_signed(-16384, 16);
            y_in_s <= to_signed(0, 16);

        else

            --------------------------------------------------------------
            -- Test 2: primo quadrante
            -- x = 1, y = 1
            -- Atteso: rho circa sqrt(2), theta circa pi/4
            --------------------------------------------------------------
            x_in_s <= to_signed(16384, 16);
            y_in_s <= to_signed(16384, 16);

        end if;
    end process;


    ------------------------------------------------------------------
    -- Istanza del core CORDIC
    ------------------------------------------------------------------

    CORDIC_inst : CORDIC
        generic map (
            DATA_IN       => 16,
            DATA_INTERNAL => 20,
            ANGLE_WIDTH   => 20,
            ITERATIONS    => 16
        )
        port map (
            clk   => clk,
            reset => btn_reset,
            start => start_pulse,

            x_in  => x_in_s,
            y_in  => y_in_s,

            rho   => rho_s,
            theta => theta_s,

            valid => valid_s
        );


    ------------------------------------------------------------------
    -- Valid latched
    ------------------------------------------------------------------
    -- valid_s dura solo un ciclo di clock.
    -- valid_latched resta alto finché non si resetta o parte un nuovo start.
    ------------------------------------------------------------------

    p_valid_latch : process(clk, btn_reset)
    begin
        if btn_reset = '1' then
            valid_latched <= '0';

        elsif rising_edge(clk) then

            if start_pulse = '1' then
                valid_latched <= '0';

            elsif valid_s = '1' then
                valid_latched <= '1';

            end if;

        end if;
    end process;


    ------------------------------------------------------------------
    -- Selezione tra rho e theta tramite SW1
    ------------------------------------------------------------------
    -- sw(1) = 0 -> rho
    -- sw(1) = 1 -> theta
    ------------------------------------------------------------------

    selected_value <= rho_s when sw(1) = '0' else theta_s;


    ------------------------------------------------------------------
    -- Visualizzazione sui 4 LED
    ------------------------------------------------------------------
    -- sw(3) = 0 -> mostra risultato selezionato
    -- sw(3) = 1 -> mostra valid_latched su LED0
    --
    -- Se sw(3) = 0:
    --   sw(2) = 0 -> bit 19..16, parte intera / segno
    --   sw(2) = 1 -> bit 15..12, parte frazionaria alta
    ------------------------------------------------------------------

    p_display : process(sw, selected_value, valid_latched)
    begin
        if sw(3) = '1' then

            -- Visualizzazione del valid su LED0
            led_out <= "000" & valid_latched;

        else

            -- Visualizzazione del risultato rho/theta
            if sw(2) = '0' then
                led_out <= std_logic_vector(selected_value(19 downto 16));
            else
                led_out <= std_logic_vector(selected_value(15 downto 12));
            end if;

        end if;
    end process;

end architecture;