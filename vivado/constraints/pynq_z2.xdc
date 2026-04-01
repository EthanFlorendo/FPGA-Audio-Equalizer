#==============================================================================
# pynq_z2.xdc – Pin constraints for PYNQ-Z2 Audio Equalizer
#
# References:
#   PYNQ-Z2 schematic rev. 1.0
#   ADAU1761 datasheet
#
# Clock period is set to 8 ns (125 MHz PL clock from Zynq FCLK_CLK0).
#==============================================================================

# ─── System Clock ─────────────────────────────────────────────────────────────
# PL clock is driven by the Zynq PS; the constraint below covers timing closure.
create_clock -period 8.000 -name clk_125 [get_ports clk_125]

# ─── Audio Codec – I2C (ADAU1761 configuration) ───────────────────────────────
# PYNQ-Z2 routes the codec I2C to the Zynq MIO pins (PS-side I2C).
# If routing through PL, use the pins below.
# set_property PACKAGE_PIN  <pin>  [get_ports iic_scl_io]
# set_property IOSTANDARD   LVCMOS33 [get_ports iic_scl_io]
# set_property PACKAGE_PIN  <pin>  [get_ports iic_sda_io]
# set_property IOSTANDARD   LVCMOS33 [get_ports iic_sda_io]

# ─── Audio Codec – I2S (ADAU1761 audio data) ──────────────────────────────────
# The PYNQ-Z2 audio codec is connected via the following PL pins.
# Schematic net names are shown in parentheses.

# BCLK  – Bit clock (output from FPGA to codec in master mode)
set_property PACKAGE_PIN  R19  [get_ports audio_bclk]
set_property IOSTANDARD   LVCMOS33 [get_ports audio_bclk]

# LRCLK / ADC_LRCLK – Left/Right word-select clock
set_property PACKAGE_PIN  R18  [get_ports audio_lrclk]
set_property IOSTANDARD   LVCMOS33 [get_ports audio_lrclk]

# ADC_SDATA – Serial data from codec ADC to FPGA (RX)
set_property PACKAGE_PIN  T19  [get_ports audio_adc_sdata]
set_property IOSTANDARD   LVCMOS33 [get_ports audio_adc_sdata]

# DAC_SDATA – Serial data from FPGA to codec DAC (TX)
set_property PACKAGE_PIN  R16  [get_ports audio_dac_sdata]
set_property IOSTANDARD   LVCMOS33 [get_ports audio_dac_sdata]

# MCLK – Master clock to codec (generated from FCLK_CLK1 ≈ 12.288 MHz)
set_property PACKAGE_PIN  U18  [get_ports audio_mclk]
set_property IOSTANDARD   LVCMOS33 [get_ports audio_mclk]

# ─── Timing Constraints ───────────────────────────────────────────────────────
# I2S bit clock derived from FCLK_CLK1 (48.828 MHz / 16 = 3.052 MHz ≈ 3.072 MHz)
create_clock -period 325.521 -name bclk [get_ports audio_bclk]

# False path between async clock domains (AXI 125 MHz ↔ I2S 3 MHz)
set_false_path -from [get_clocks clk_125] -to [get_clocks bclk]
set_false_path -from [get_clocks bclk]    -to [get_clocks clk_125]

# ─── I/O Timing ───────────────────────────────────────────────────────────────
set_input_delay  -clock bclk  2.0 [get_ports audio_adc_sdata]
set_output_delay -clock bclk  2.0 [get_ports audio_dac_sdata]
set_output_delay -clock bclk  2.0 [get_ports audio_lrclk]
