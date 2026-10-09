-- =============================================================================
-- ARCHIVO: clock_divider.vhd
-- DESCRIPCIÓN: Divisor de frecuencia / Temporizador base.
--              Genera un pulso de habilitación (tick) de 1 ciclo de duración
--              cada 0.5 segundos a partir de un reloj de entrada de 50 MHz.
--
--              Cálculo:
--                Ciclos por 0.5s = 50,000,000 Hz * 0.5 s = 25,000,000 ciclos
--                Contador de 0 a 24,999,999 (25 millones de cuentas)
--
-- ENTRADAS:
--   clk   : Reloj principal 50 MHz
--   reset : Reset asíncrono activo en nivel bajo (pulsador KEY[0])
--
-- SALIDAS:
--   tick  : Pulso de '1' durante 1 ciclo de reloj cada 0.5 segundos
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clock_divider is
    generic (
        -- número de ciclos de reloj para generar un tick de 0.5 segundos.
        -- para simulación rápida, este valor se puede reducir.
        CLK_DIV_COUNT : integer := 25_000_000
    );
    port (
        clk    : in  std_logic;
        reset  : in  std_logic;  -- activo en bajo (key es activo en bajo)
        enable : in  std_logic;  -- habilita y sincroniza el contador
        tick   : out std_logic   -- pulso cada 0.5 segundos
    );
end entity clock_divider;

architecture rtl of clock_divider is

    -- contador interno: necesita llegar hasta clk_div_count  1
    signal count : integer range 0 to CLK_DIV_COUNT - 1 := 0;

begin

    -- proceso de conteo con reset asíncrono
    process (clk, reset)
    begin
        if reset = '0' then
            -- reset asíncrono activo en bajo: reinicia el contador
            count <= 0;
            tick  <= '0';
        elsif rising_edge(clk) then
            if enable = '0' then
                -- si no hay transmision, reseteamos el tiempo pa no gastar luz
                count <= 0;
                tick  <= '0';
            else
                if count = CLK_DIV_COUNT - 1 then
                    -- llegamos al límite: emitir tick y reiniciar
                    count <= 0;
                    tick  <= '1';
                else
                    -- seguir contando
                    count <= count + 1;
                    tick  <= '0';
                end if;
            end if;
        end if;
    end process;

end architecture rtl;

