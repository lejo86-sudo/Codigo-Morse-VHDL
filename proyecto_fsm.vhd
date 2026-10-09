library ieee;
use ieee.std_logic_1164.all;

entity proyecto_fsm is
    generic (
        -- esto permite cambiar la velocidad solo para la simulacion
        DIV_COUNT : integer := 25_000_000
    );
    port (
        CLOCK_50 : in  std_logic;
        KEY      : in  std_logic_vector(1 downto 0);
        SW       : in  std_logic_vector(2 downto 0);
        LEDR     : out std_logic_vector(0 downto 0);
        HEX0     : out std_logic_vector(6 downto 0);
        HEX1     : out std_logic_vector(6 downto 0)
    );
end entity proyecto_fsm;

architecture structural of proyecto_fsm is
    component clock_divider is
        generic ( CLK_DIV_COUNT : integer := 25_000_000 );
        port (
            clk    : in  std_logic;
            reset  : in  std_logic;
            enable : in  std_logic;
            tick   : out std_logic
        );
    end component;

    component morse_fsm is
        port (
            clk           : in  std_logic;
            reset         : in  std_logic;
            tick          : in  std_logic;
            start         : in  std_logic;
            letter_select : in  std_logic_vector(2 downto 0);
            morse_out     : out std_logic;
            active        : out std_logic
        );
    end component;

    component hex_decoder is
        port (
            letter_select : in  std_logic_vector(2 downto 0);
            hex_out       : out std_logic_vector(6 downto 0)
        );
    end component;

    signal tick_signal : std_logic;
    signal fsm_active  : std_logic;
begin
    U_CLK_DIV : clock_divider
        generic map ( CLK_DIV_COUNT => DIV_COUNT ) -- pasamos el generic aqui
        port map ( clk => CLOCK_50, reset => KEY(0), enable => fsm_active, tick => tick_signal );

    U_MORSE_FSM : morse_fsm
        port map ( clk => CLOCK_50, reset => KEY(0), tick => tick_signal, start => KEY(1), letter_select => SW, morse_out => LEDR(0), active => fsm_active );

    U_HEX0 : hex_decoder port map ( letter_select => SW, hex_out => HEX0 );
    HEX1 <= "1111111";
end architecture structural;

