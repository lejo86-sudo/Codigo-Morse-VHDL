-- =============================================================================
-- ARCHIVO: hex_decoder.vhd
-- DESCRIPCIÓN: Decodificador de letra Morse → display de 7 segmentos.
--
--   Recibe la selección de letra (3 bits) y genera el patrón de segmentos
--   para mostrarla en un display de 7 segmentos de ánodo común (activo en bajo).
--
--   DISPLAY DE 7 SEGMENTOS (DE0 - ánodo común, activo en BAJO):
--     '0' = segmento ENCENDIDO
--     '1' = segmento APAGADO
--
--   Numeración de segmentos:
--        aaa
--       f   b
--       f   b
--        ggg
--       e   c
--       e   c
--        ddd
--
--   HEX(0)=a, HEX(1)=b, HEX(2)=c, HEX(3)=d,
--   HEX(4)=e, HEX(5)=f, HEX(6)=g
--
-- LETRAS IMPLEMENTADAS (A-H):
--   A (000): a,b,c,e,f,g ON → "0001000"
--   b (001): c,d,e,f,g ON   → "0000011"  (minuscula)
--   C (010): a,d,e,f ON     → "1000110"
--   d (011): b,c,d,e,g ON   → "0100001"  (minuscula)
--   E (100): a,d,e,f,g ON   → "0000110"
--   F (101): a,e,f,g ON     → "0001110"
--   G (110): a,c,d,e,f,g ON → "0000010"
--   H (111): b,c,e,f,g ON   → "0001001"
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity hex_decoder is
    port (
        letter_select : in  std_logic_vector(2 downto 0);  -- sw[2..0]
        hex_out       : out std_logic_vector(6 downto 0)   -- hex display (activo bajo)
    );
end entity hex_decoder;

architecture rtl of hex_decoder is
begin

    -- proceso combinacional: mapea letra → patrón de 7 segmentos (activo bajo)
    process(letter_select)
    begin
        case letter_select is
            -- gfedcba  (bit 6  g, bit 0  a)
            when "000" => hex_out <= "0001000";  -- a: a,b,c,e,f,g on
            when "001" => hex_out <= "0000011";  -- b: c,d,e,f,g on  (lowercase)
            when "010" => hex_out <= "1000110";  -- c: a,d,e,f on
            when "011" => hex_out <= "0100001";  -- d: b,c,d,e,g on  (lowercase)
            when "100" => hex_out <= "0000110";  -- e: a,d,e,f,g on
            when "101" => hex_out <= "0001110";  -- f: a,e,f,g on
            when "110" => hex_out <= "0000010";  -- g: a,c,d,e,f,g on
            when others => hex_out <= "0001001"; -- h: b,c,e,f,g on
        end case;
    end process;

end architecture rtl;

