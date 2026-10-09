# =============================================================================
# ARCHIVO: sim.do
# DESCRIPCIÓN: Script de automatización para ModelSim
# =============================================================================

# 1. Crear y mapear la librería de trabajo
vlib work
vmap work work

# 2. Compilar todos los archivos VHDL en el orden correcto
vcom -work work clock_divider.vhd
vcom -work work morse_fsm.vhd
vcom -work work hex_decoder.vhd
vcom -work work proyecto_fsm.vhd
vcom -work work tb_morse.vhd

# 3. Iniciar la simulación del testbench
vsim -t 1ns work.tb_morse

# 4. Configurar la ventana de ondas (Waveform)
view wave
delete wave *

# Agregar las señales más importantes a la gráfica
add wave -noupdate -divider "Entradas del Sistema"
add wave -noupdate -label "Reloj (50 MHz)" /tb_morse/clk_tb
add wave -noupdate -label "Reset (KEY 0)" /tb_morse/key_tb(0)
add wave -noupdate -label "Start (KEY 1)" /tb_morse/key_tb(1)
add wave -noupdate -label "Letra (SW)" -radix binary /tb_morse/sw_tb

add wave -noupdate -divider "Salida Morse"
add wave -noupdate -color "Red" -label "MORSE OUT (LEDR 0)" /tb_morse/ledr_tb(0)

# Ajustar la vista
configure wave -timelineunits ns
WaveRestoreZoom {0 ns} {3000 ns}

# 5. Ejecutar toda la simulación
run -all
