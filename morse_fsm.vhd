-- =============================================================================
-- ARCHIVO: morse_fsm.vhd
-- DESCRIPCIÓN: Máquina de Estados Finitos (FSM) del codificador Morse.
--
--   Implementa una FSM de 3 procesos (registro de estado, lógica de próximo
--   estado, lógica de salida) para evitar inferencia de latches.
--
--   La FSM consume "ticks" del temporizador base (cada tick = 0.5 segundos)
--   para temporizar los puntos (1 tick = 0.5s), rayas (3 ticks = 1.5s) y
--   las pausas entre símbolos (1 tick = 0.5s).
--
-- ALFABETO MORSE (SW[2..0]):
--   A (000): .-         (dot, dash)
--   B (001): -...       (dash, dot, dot, dot)
--   C (010): -.-.       (dash, dot, dash, dot)
--   D (011): -..        (dash, dot, dot)
--   E (100): .          (dot)
--   F (101): ..-.       (dot, dot, dash, dot)
--   G (110): --.        (dash, dash, dot)
--   H (111): ....       (dot, dot, dot, dot)
--
-- TEMPORIZACIÓN:
--   DOT  : morse_out = '1' durante 1 tick (0.5 s)
--   DASH : morse_out = '1' durante 3 ticks (1.5 s)
--   PAUSE: morse_out = '0' durante 1 tick (0.5 s) entre símbolos
--   IDLE : morse_out = '0', espera nueva pulsación de start
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity morse_fsm is
    port (
        clk           : in  std_logic;
        reset         : in  std_logic;  -- activo en bajo (key[0])
        tick          : in  std_logic;  -- pulso cada 0.5 s del clock_divider
        start         : in  std_logic;  -- pulsador inicio (key[1], activo en bajo)
        letter_select : in  std_logic_vector(2 downto 0);  -- sw[2..0]
        morse_out     : out std_logic;  -- ledr[0]
        active        : out std_logic   -- '1' cuando no esta en s_idle
    );
end entity morse_fsm;

architecture rtl of morse_fsm is

    -- tipos y constantes

    -- tipo enumerado de estados de la fsm
    type state_t is (
        S_IDLE,   -- espera que se presione start; led apagado (dormido)
        S_LOAD,   -- carga el código morse de la letra seleccionada
        S_DOT,    -- emite un punto: led encendido 1 tick
        S_DASH,   -- emite una raya: led encendido 3 ticks
        S_PAUSE,  -- pausa entre símbolos: led apagado (dormido) 1 tick
        S_DONE    -- transmisión completada; vuelve a idle
    );

    -- máximo de símbolos por letra (h tiene 4 puntos)
    constant MAX_SYMBOLS : integer := 4;

    -- tipo para almacenar el patrón de una letra:
    -- symbol_seq(i)  '0' → punto, '1' → raya
    type symbol_array_t is array (0 to MAX_SYMBOLS - 1) of std_logic;

    -- tipo registro para una letra: secuencia y longitud válida
    type letter_t is record
        seq    : symbol_array_t;
        length : integer range 1 to MAX_SYMBOLS;
    end record;

    -- función: get_letter
    -- nos devuelve el morse de los switches.
    function get_letter (sel : std_logic_vector(2 downto 0)) return letter_t is
        variable result : letter_t;
    begin
        -- valores por defecto (evita latches implícitos en síntesis)
        result.seq    := (others => '0');
        result.length := 1;

        case sel is
            when "000" =>  -- a: .
                result.seq    := ('0', '1', '0', '0');  -- dot, dash, pad, pad
                result.length := 2;
            when "001" =>  -- b: ...
                result.seq    := ('1', '0', '0', '0');  -- dash, dot, dot, dot
                result.length := 4;
            when "010" =>  -- c: ..
                result.seq    := ('1', '0', '1', '0');  -- dash, dot, dash, dot
                result.length := 4;
            when "011" =>  -- d: ..
                result.seq    := ('1', '0', '0', '0');  -- dash, dot, dot, pad
                result.length := 3;
            when "100" =>  -- e: .
                result.seq    := ('0', '0', '0', '0');  -- dot, pad, pad, pad
                result.length := 1;
            when "101" =>  -- f: ...
                result.seq    := ('0', '0', '1', '0');  -- dot, dot, dash, dot
                result.length := 4;
            when "110" =>  -- g: .
                result.seq    := ('1', '1', '0', '0');  -- dash, dash, dot, pad
                result.length := 3;
            when others =>  -- h (111): ....
                result.seq    := ('0', '0', '0', '0');  -- dot, dot, dot, dot
                result.length := 4;
        end case;

        return result;
    end function;

    -- señales internas

    -- registros de estado (actual y próximo)
    signal state      : state_t := S_IDLE;
    signal next_state : state_t;

    -- patrón morse cargado de la letra actual
    signal letter_reg : letter_t;

    -- índice del símbolo actual en la secuencia (0 a max_symbols1)
    signal sym_idx    : integer range 0 to MAX_SYMBOLS - 1 := 0;

    -- contador de ticks para temporizar dot/dash
    -- dash necesita hasta 3 ticks → rango 0..2
    signal tick_count : integer range 0 to 3 := 0;

    -- señal interna de salida (para lectura dentro del proceso)
    signal morse_sig  : std_logic := '0';

begin

    -- proceso 1: registro de estado (secuencial, sensible a clk y reset)
    P_STATE_REG : process (clk, reset)
    begin
        if reset = '0' then
            -- reset asíncrono activo en bajo
            state      <= S_IDLE;
            sym_idx    <= 0;
            tick_count <= 0;
            letter_reg <= (seq => (others => '0'), length => 1);
        elsif rising_edge(clk) then
            -- actualiza el estado en el flanco 
            state <= next_state;

            -- lógica secuencial de soporte: cargar letra y manejar contadores
            case state is

                when S_IDLE =>
                    -- al detectar start (activo bajo), preparar índice
                    if start = '0' then
                        sym_idx    <= 0;
                        tick_count <= 0;
                    end if;

                when S_LOAD =>
                    -- guardamos la letra y a reiniciar contadores 
                    letter_reg <= get_letter(letter_select);
                    sym_idx    <= 0;
                    tick_count <= 0;

                when S_DOT =>
                    -- 1 tick activo
                    if tick = '1' then
                        tick_count <= 0;
                        -- avanzar al siguiente símbolo o terminar
                        if sym_idx < letter_reg.length - 1 then
                            sym_idx <= sym_idx + 1;
                        end if;
                    end if;

                when S_DASH =>
                    -- 3 ticks activos - contar hasta 2 (0,1,2  3 ticks)
                    if tick = '1' then
                        if tick_count < 2 then
                            tick_count <= tick_count + 1;
                        else
                            tick_count <= 0;
                            -- avanzar al siguiente símbolo o terminar
                            if sym_idx < letter_reg.length - 1 then
                                sym_idx <= sym_idx + 1;
                            end if;
                        end if;
                    end if;

                when S_PAUSE =>
                    -- 1 tick de silencio - nada que contar
                    if tick = '1' then
                        tick_count <= 0;
                    end if;

                when S_DONE =>
                    -- transmisión completada, limpiar
                    sym_idx    <= 0;
                    tick_count <= 0;

                when others =>
                    null;

            end case;
        end if;
    end process P_STATE_REG;

    -- proceso 2: lógica del próximo estado (combinacional)
    P_NEXT_STATE : process (state, start, tick, sym_idx, tick_count,
                            letter_reg, letter_select)
        variable cur_letter : letter_t;
    begin
        -- por defecto nos quedamos parados 
        next_state <= state;

        case state is

            when S_IDLE =>
                -- esperando a que alguien oprima el bendito boton
                if start = '0' then
                    next_state <= S_LOAD;
                end if;

            when S_LOAD =>
                -- siempre avanzamos a emitir el primer símbolo en el siguiente
                -- ciclo. determinamos qué es el primer símbolo con get_letter.
                cur_letter := get_letter(letter_select);
                if cur_letter.seq(0) = '0' then
                    next_state <= S_DOT;
                else
                    next_state <= S_DASH;
                end if;

            when S_DOT =>
                -- esperar 1 tick; luego decidir
                if tick = '1' then
                    -- ¿hay más símbolos?
                    if sym_idx < letter_reg.length - 1 then
                        next_state <= S_PAUSE;   -- pausa antes del siguiente
                    else
                        next_state <= S_DONE;    -- terminamos
                    end if;
                end if;

            when S_DASH =>
                -- esperar 3 ticks (tick_count llega a 2 en el 3er tick)
                if tick = '1' and tick_count = 2 then
                    if sym_idx < letter_reg.length - 1 then
                        next_state <= S_PAUSE;
                    else
                        next_state <= S_DONE;
                    end if;
                end if;

            when S_PAUSE =>
                -- 1 tick de silencio; luego emitir el siguiente símbolo
                if tick = '1' then
                    -- sym_idx ya fue actualizado en el proceso secuencial
                    -- al salir de dot/dash. aquí usamos el valor que tendrá.
                    -- necesitamos inspeccionar el próximo símbolo:
                    -- como sym_idx se actualiza en el proceso secuencial
                    -- en el mismo ciclo de reloj, en este proceso combinacional
                    -- aún no está actualizado. usamos sym_idx directamente
                    -- (será el índice ya actualizado por el proceso reg
                    -- en el ciclo anterior).
                    if letter_reg.seq(sym_idx) = '0' then
                        next_state <= S_DOT;
                    else
                        next_state <= S_DASH;
                    end if;
                end if;

            when S_DONE =>
                -- volver a idle automáticamente en el siguiente ciclo
                next_state <= S_IDLE;

            when others =>
                next_state <= S_IDLE;

        end case;
    end process P_NEXT_STATE;

    -- proceso 3: lógica de salida (depende sólo del estado actual)
    P_OUTPUT : process (state)
    begin
        case state is
            when S_DOT  => morse_sig <= '1';   -- led prendido 
            when S_DASH => morse_sig <= '1';   -- led prendido 
            when others => morse_sig <= '0';   -- led apagado 
        end case;
    end process P_OUTPUT;

    -- asignación de la salida interna al puerto
    morse_out <= morse_sig;
    
    -- señal de sincronización para el divisor de reloj
    active <= '0' when state = S_IDLE else '1';


end architecture rtl;

