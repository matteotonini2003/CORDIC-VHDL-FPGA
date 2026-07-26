library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity CORDIC is   
    generic (
        --------------------------------------------------------
        --    Costanti globali
        --------------------------------------------------------
        DATA_IN        : positive := 16;  -- ingresso signed Q2.14
        DATA_INTERNAL  : positive := 20;  -- segnali interni signed Q4.16
        ANGLE_WIDTH    : positive := 20;  -- larghezza per z/theta
        ITERATIONS     : positive := 16   -- numero di iterazioni CORDIC
    );
    port(
        clk    : in  std_logic;
        reset  : in  std_logic;
        start  : in  std_logic;

        x_in   : in  signed(DATA_IN-1 downto 0);
        y_in   : in  signed(DATA_IN-1 downto 0);

        rho    : out signed(DATA_INTERNAL-1 downto 0);
        theta  : out signed(ANGLE_WIDTH-1 downto 0);

        valid  : out std_logic
    );
end entity;

architecture rtl of CORDIC is

    --------------------------------------------------------------------
    -- Costanti fixed-point
    --------------------------------------------------------------------

    -- x_in, y_in: Q2.14
    -- x_reg, y_reg: Q4.16
    -- quindi i segnali interni hanno 16 bit frazionari
    constant FRAC_INTERNAL : natural := 16;

    -- Differenza tra bit frazionari interni e bit frazionari di ingresso:
    -- Q2.14 -> Q4.16, quindi shift sinistra di 2 bit
    constant FRAC_IN       : natural := 14;
    constant INPUT_SHIFT   : natural := FRAC_INTERNAL - FRAC_IN;

    --------------------------------------------------------------------
    -- Costante di correzione del guadagno CORDIC
    --------------------------------------------------------------------

    -- K = 1/AN ≈ 0.607252935 per ITERATIONS = 16
    -- Rappresentato in Q1.16:
    -- K_fixed = round(0.607252935 * 2^16) = 39797
    --
    -- Attenzione: questa costante è corretta per 16 iterazioni.
    -- Se cambia ITERATIONS, si deve rigenerare anche K_CORDIC.
    constant K_WIDTH  : positive := 17;
    constant K_CORDIC : signed(K_WIDTH-1 downto 0) := to_signed(39797, K_WIDTH);

    --------------------------------------------------------------------
    -- Costanti LUT atan
    --------------------------------------------------------------------

    -- Per ITERATIONS = 16 servono indirizzi da 0 a 15, quindi 4 bit.
    -- La LUT contiene atan(2^-0), atan(2^-1), ..., atan(2^-15).
    constant LUT_ADDR_WIDTH : positive := 4;

    --------------------------------------------------------------------
    -- Costanti counter
    --------------------------------------------------------------------

    -- Il counter deve poter rappresentare anche 16, non solo 0..15,
    -- perché può servire per riconoscere la fine delle ITERATIONS.
    -- Con 5 bit rappresenti 0..31.
    constant CNTR_WIDTH : positive := 5;

    -- Incremento unitario del counter
    constant CNTR_INCREMENT : std_logic_vector(CNTR_WIDTH-1 downto 0) :=
        std_logic_vector(to_unsigned(1, CNTR_WIDTH));
    
    --------------------------------------------------------------------
    -- Costanti per correzione quadrante theta
    --------------------------------------------------------------------

    -- pi in Q4.16:
    -- pi_fixed = round(pi * 2^16) = 205887
    constant PI_FIXED : signed(ANGLE_WIDTH-1 downto 0) :=
        to_signed(205887, ANGLE_WIDTH);

    signal theta_offset : signed(ANGLE_WIDTH-1 downto 0);

    --------------------------------------------------------------------
    -- Stati della FSM
    -- IDLE  → aspetto start
    -- LOAD  → carico x_in_reg e y_in_reg nei registri interni x_reg, y_reg
    -- RUN   → eseguo le iterazioni CORDIC
    -- DONE  → produco rho, theta e valid
    --------------------------------------------------------------------

    type state_type is (IDLE, LOAD, RUN, DONE);
    signal state : state_type := IDLE;

    --------------------------------------------------------------------
    -- Segnali di controllo
    --------------------------------------------------------------------

    signal start_load : std_logic;

    -- Enable del counter durante le iterazioni
    signal cntr_en    : std_logic;

    -- Reset del counter, attivo alto 
    signal cntr_reset : std_logic;

    -- zero input per gestire (0,0)
    signal zero_input : std_logic;

    --------------------------------------------------------------------
    -- Registri di ingresso
    --------------------------------------------------------------------

    -- Valori x_in e y_in campionati quando start_load = '1'
    signal x_in_reg : signed(DATA_IN-1 downto 0);
    signal y_in_reg : signed(DATA_IN-1 downto 0);

    --------------------------------------------------------------------
    -- Segnali per controllo convergenza y_N ≈ 0
    --------------------------------------------------------------------

    signal y_abs          : signed(DATA_INTERNAL-1 downto 0);
    signal convergence_ok : std_logic;

    --------------------------------------------------------------------
    -- Registri interni CORDIC
    --------------------------------------------------------------------

    signal x_reg : signed(DATA_INTERNAL-1 downto 0);
    signal y_reg : signed(DATA_INTERNAL-1 downto 0);
    signal z_reg : signed(ANGLE_WIDTH-1 downto 0);

    --------------------------------------------------------------------
    -- Segnali combinatori per la prossima iterazione
    --------------------------------------------------------------------

    signal x_next : signed(DATA_INTERNAL-1 downto 0);
    signal y_next : signed(DATA_INTERNAL-1 downto 0);
    signal z_next : signed(ANGLE_WIDTH-1 downto 0);

    --------------------------------------------------------------------
    -- Segnali per Counter e LUT atan
    --------------------------------------------------------------------

    -- Uscita grezza del counter (il counter usa std_logic_vector)
    signal i_count : std_logic_vector(CNTR_WIDTH-1 downto 0);

    -- Versione integer dell'indice, utile per confronti e shift_right
    signal i : integer range 0 to 2**CNTR_WIDTH - 1;

    -- Indirizzo LUT, usa solo i 4 bit meno significativi del counter
    signal i_addr : unsigned(LUT_ADDR_WIDTH-1 downto 0);

    -- Valore atan(2^-i) letto dalla LUT
    signal atan_i : signed(ANGLE_WIDTH-1 downto 0);

    --------------------------------------------------------------------
    -- Segnale per correzione rho = xN * K_CORDIC
    --------------------------------------------------------------------

    -- x_reg    : Q4.16
    -- K_CORDIC : Q1.16
    -- rho_mult : Q5.32
    signal rho_mult : signed(DATA_INTERNAL + K_WIDTH - 1 downto 0);

    --------------------------------------------------------------------
    -- Component DFF signed
    --------------------------------------------------------------------

    component DFF_N_Signed is
        generic (
            N : positive := 16
        );
        port (
            clk     : in  std_logic;
            reset : in  std_logic;
            en      : in  std_logic;
            d       : in  signed(N-1 downto 0);
            q       : out signed(N-1 downto 0)
        );
    end component;

    --------------------------------------------------------------------
    -- Component LUT arctan
    --------------------------------------------------------------------

    component ATAN_LUT is
        port (
            addr       : in  unsigned(LUT_ADDR_WIDTH-1 downto 0);
            atan_value : out signed(ANGLE_WIDTH-1 downto 0)
        );
    end component;

    --------------------------------------------------------------------
    -- Component Counter
    --------------------------------------------------------------------

    component Counter is
        generic (
            N : natural := 8
        );
        port (
            clk       : in  std_logic;
            reset   : in  std_logic;

            en        : in  std_logic;
            increment : in  std_logic_vector(N - 1 downto 0);
            cntr_out  : out std_logic_vector(N - 1 downto 0)
        );
    end component;

begin
    process(clk, reset)
    begin
        -------------------------------------------
        -- Gestione FSM
        -------------------------------------------
        if reset = '1' then

            state <= IDLE;

            x_reg <= (others => '0');
            y_reg <= (others => '0');
            z_reg <= (others => '0');
            theta_offset <= (others => '0');
            rho   <= (others => '0');
            theta <= (others => '0');
            valid <= '0';

        elsif rising_edge(clk) then

            valid <= '0';

            case state is

                when IDLE =>
                    
                    valid <= '0';

                    x_reg <= (others => '0');
                    y_reg <= (others => '0');
                    z_reg <= (others => '0');
                    theta_offset <= (others => '0');

                    -- rho e theta non li azzero, così mantengono l’ultimo risultato    

                    if start = '1' then
                        state <= LOAD;
                    else    
                        state <= IDLE;
                    end if;

                when LOAD =>

                    z_reg <= (others => '0');

                    if zero_input = '1' then

                        x_reg <= (others => '0');
                        y_reg <= (others => '0');
                        theta_offset <= (others => '0');

                        state <= DONE;

                    elsif x_in_reg < to_signed(0, DATA_IN) then

                        -- Se x < 0, porto il vettore nel semipiano destro
                        -- usando (-x, -y). Il modulo resta uguale.
                        x_reg <= shift_left(-resize(x_in_reg, DATA_INTERNAL), INPUT_SHIFT);
                        y_reg <= shift_left(-resize(y_in_reg, DATA_INTERNAL), INPUT_SHIFT);

                        -- Correzione dell'angolo originale
                        if y_in_reg >= to_signed(0, DATA_IN) then
                            theta_offset <= PI_FIXED;      -- secondo quadrante
                        else
                            theta_offset <= -PI_FIXED;     -- terzo quadrante
                        end if;

                        state <= RUN;

                    else

                        -- x >= 0: nessuna correzione di quadrante
                        x_reg <= shift_left(resize(x_in_reg, DATA_INTERNAL), INPUT_SHIFT);
                        y_reg <= shift_left(resize(y_in_reg, DATA_INTERNAL), INPUT_SHIFT);

                        theta_offset <= (others => '0');

                        state <= RUN;

                    end if;

                when RUN =>

                    if i = ITERATIONS then
                        state <= DONE;

                    else
                        -- aggiorno i valori
                        x_reg <= x_next;
                        y_reg <= y_next;
                        z_reg <= z_next;

                        state <= RUN;
                    end if;

                when DONE =>
                        
                    rho <= resize(shift_right(rho_mult, FRAC_INTERNAL), DATA_INTERNAL); -- lo riporto su 20 bit
                    theta <= z_reg + theta_offset;
                    
                    if convergence_ok = '1' then
                        valid <= '1';
                    else
                        valid <= '0';
                    end if;
                    state <= IDLE;

            end case;
        end if;
    end process;

    process(state, start)
        begin
            if state = IDLE and start = '1' then
                start_load <= '1';
            else
                start_load <= '0';
            end if;
        end process;

    DFF_X_IN : DFF_N_Signed
        generic map (
            N => DATA_IN
        )
        port map (
            clk     => clk,
            reset => reset,
            en      => start_load,  -- così il dato passa solo quando deve
            d       => x_in,
            q       => x_in_reg
        );

    DFF_Y_IN : DFF_N_Signed
        generic map (
            N => DATA_IN
        )
        port map (
            clk     => clk,
            reset => reset,
            en      => start_load,
            d       => y_in,
            q       => y_in_reg
        );
    
    -----------------------------------------------------------
    -- Controllo del counter
    -----------------------------------------------------------
    cntr_reset <= '1' when reset = '1' or state = LOAD else '0';
    cntr_en <= '1' when state = RUN and i < ITERATIONS else '0';
    
    ITERATIONS_COUNTER : Counter
        generic map (
        N => CNTR_WIDTH
        )
        port map (
            clk       => clk,
            reset     => cntr_reset,
            en        => cntr_en,
            increment => CNTR_INCREMENT,
            cntr_out  => i_count
        );
    
    --------------------------------------------------------------------
    -- Conversione counter per LUT e shift
    --------------------------------------------------------------------

    i <= to_integer(unsigned(i_count));
    i_addr <= unsigned(i_count(LUT_ADDR_WIDTH-1 downto 0));

    --------------------------------------------------------------------
    -- Istanza LUT arctan
    --------------------------------------------------------------------

    INSTANCE_ATAN_LUT : ATAN_LUT
        port map (
            addr       => i_addr,
            atan_value => atan_i
        );
    
    -------------------------------------------------------
    -- Process per le iterazioni interne
    -------------------------------------------------------
    p_CORDIC_COMB : process(x_reg, y_reg, z_reg, atan_i, i)
        begin
            x_next <= x_reg;
            y_next <= y_reg;
            z_next <= z_reg;

            if i < ITERATIONS then

                 if y_reg < to_signed(0, DATA_INTERNAL) then
                    -- y è negativo: devo aumentare y verso zero
                    x_next <= x_reg - shift_right(y_reg, i);
                    y_next <= y_reg + shift_right(x_reg, i);
                    z_next <= z_reg - atan_i;

                else
                    -- y è positivo o nullo: devo diminuire y verso zero
                    x_next <= x_reg + shift_right(y_reg, i);
                    y_next <= y_reg - shift_right(x_reg, i);
                    z_next <= z_reg + atan_i;

                end if;

            end if;
        end process;

    -- Gestico la moltiplicazione su rho_mult
    rho_mult <= x_reg * K_CORDIC;

    -- Gestione zero input
    zero_input <= '1' 
        when x_in_reg = to_signed(0, DATA_IN) and y_in_reg = to_signed(0, DATA_IN) 
        else '0';

    --------------------------------------------------------------------
    -- Controllo convergenza: |y_N| <= 4 LSB
    --------------------------------------------------------------------

    y_abs <= -y_reg when y_reg < to_signed(0, DATA_INTERNAL) else y_reg;
    convergence_ok <= '1' when y_abs <= to_signed(4, DATA_INTERNAL) else '0';

end architecture;