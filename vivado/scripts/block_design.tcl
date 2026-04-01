#==============================================================================
# block_design.tcl
#
# Creates the Vivado block design for the Audio Equalizer system.
#
# Block design topology:
#
#   ┌──────────────────────────────────────────────────────────────────────┐
#   │  Zynq PS (FCLK_CLK0 = 125 MHz, FCLK_CLK1 = 48.828 MHz for I2S)     │
#   │                                                                        │
#   │  M_AXI_GP0 ──► AXI Interconnect ──► audio_equalizer HLS IP          │
#   │                                 ──► AXI GPIO  (mute / bypass)        │
#   │                                 ──► AXI IIC   (codec config – I2C)   │
#   │                                                                        │
#   │  S_AXI_HP0 ◄── DMA ◄── I2S RX (from ADAU1761 ADC)                   │
#   │  S_AXI_HP1 ──► DMA ──► I2S TX (to   ADAU1761 DAC)                   │
#   └──────────────────────────────────────────────────────────────────────┘
#
# Notes:
#   - I2S timing:  BCLK = 3.072 MHz  (48 kHz × 32 bits × 2 channels)
#                  LRCLK = 48 kHz
#   - Codec config via I2C at boot time (PS or bare-metal driver)
#   - BRAM ping-pong buffers sit between I2S DMA and the HLS equalizer IP
#==============================================================================

# ── Create block design ───────────────────────────────────────────────────────
create_bd_design "audio_eq_bd"
update_compile_order -fileset sources_1

# ── Zynq Processing System ────────────────────────────────────────────────────
set zynq_ps [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 zynq_ps]

# Apply PYNQ-Z2 board preset
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config { make_axi_periph {Enable} make_interrupt_ctrl {Enable} } \
    $zynq_ps

# Enable HP slave ports for DMA
set_property -dict [list \
    CONFIG.PCW_USE_S_AXI_HP0 {1} \
    CONFIG.PCW_USE_S_AXI_HP1 {1} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {125} \
    CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ {48.828} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {1} \
    CONFIG.PCW_IRQ_F2P_INTR {1} \
] $zynq_ps

# ── AXI Interconnect (GP0 → peripherals) ─────────────────────────────────────
set axi_ic [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_ic]
set_property CONFIG.NUM_MI {4} $axi_ic

connect_bd_intf_net [get_bd_intf_pins zynq_ps/M_AXI_GP0] \
                    [get_bd_intf_pins axi_ic/S00_AXI]

# ── Audio Equalizer HLS IP ────────────────────────────────────────────────────
set eq_ip [create_bd_cell -type ip \
    -vlnv xilinx.com:hls:audio_equalizer:1.0 audio_equalizer_0]

# AXI-Lite control port
connect_bd_intf_net [get_bd_intf_pins axi_ic/M00_AXI] \
                    [get_bd_intf_pins audio_equalizer_0/s_axi_CTRL]

# AXI4-Stream I/O ports connect to DMA streams (wired below)

# ── AXI DMA – RX (ADC → DDR / equalizer) ─────────────────────────────────────
set dma_rx [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_rx]
set_property -dict [list \
    CONFIG.c_include_sg         {0} \
    CONFIG.c_sg_include_stscntrl_strm {0} \
    CONFIG.c_include_mm2s       {0} \
    CONFIG.c_include_s2mm       {1} \
    CONFIG.c_s2mm_burst_size    {16} \
] $dma_rx

connect_bd_intf_net [get_bd_intf_pins axi_ic/M01_AXI] \
                    [get_bd_intf_pins axi_dma_rx/S_AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins axi_dma_rx/M_AXI_S2MM] \
                    [get_bd_intf_pins zynq_ps/S_AXI_HP0]

# RX stream: I2S RX → DMA → equalizer input
connect_bd_intf_net [get_bd_intf_pins axi_dma_rx/S_AXIS_S2MM] \
                    [get_bd_intf_pins audio_equalizer_0/s_axis_audio_in]

# ── AXI DMA – TX (equalizer → DAC) ───────────────────────────────────────────
set dma_tx [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_tx]
set_property -dict [list \
    CONFIG.c_include_sg         {0} \
    CONFIG.c_sg_include_stscntrl_strm {0} \
    CONFIG.c_include_mm2s       {1} \
    CONFIG.c_include_s2mm       {0} \
    CONFIG.c_mm2s_burst_size    {16} \
] $dma_tx

connect_bd_intf_net [get_bd_intf_pins axi_ic/M02_AXI] \
                    [get_bd_intf_pins axi_dma_tx/S_AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins axi_dma_tx/M_AXI_MM2S] \
                    [get_bd_intf_pins zynq_ps/S_AXI_HP1]

# TX stream: equalizer output → DMA → I2S TX
connect_bd_intf_net [get_bd_intf_pins audio_equalizer_0/m_axis_audio_out] \
                    [get_bd_intf_pins axi_dma_tx/S_AXIS_MM2S]

# ── AXI IIC (codec config over I2C) ──────────────────────────────────────────
set axi_iic [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic:2.1 axi_iic_0]
connect_bd_intf_net [get_bd_intf_pins axi_ic/M03_AXI] \
                    [get_bd_intf_pins axi_iic_0/S_AXI]

# IIC pins will be connected to external port in constraints

# ── Clocks ────────────────────────────────────────────────────────────────────
# FCLK_CLK0 (125 MHz) → system clock for all AXI logic
apply_bd_automation -rule xilinx.com:bd_rule:clkrst \
    -config { Clk {/zynq_ps/FCLK_CLK0 (125 MHz)} } \
    [get_bd_pins audio_equalizer_0/ap_clk]

apply_bd_automation -rule xilinx.com:bd_rule:clkrst \
    -config { Clk {/zynq_ps/FCLK_CLK0 (125 MHz)} } \
    [get_bd_pins axi_dma_rx/s_axi_lite_aclk]

apply_bd_automation -rule xilinx.com:bd_rule:clkrst \
    -config { Clk {/zynq_ps/FCLK_CLK0 (125 MHz)} } \
    [get_bd_pins axi_dma_tx/s_axi_lite_aclk]

apply_bd_automation -rule xilinx.com:bd_rule:clkrst \
    -config { Clk {/zynq_ps/FCLK_CLK0 (125 MHz)} } \
    [get_bd_pins axi_iic_0/s_axi_aclk]

# ── Address Map ───────────────────────────────────────────────────────────────
assign_bd_address

# ── Validate and save ─────────────────────────────────────────────────────────
validate_bd_design
save_bd_design

puts "Block design 'audio_eq_bd' created and validated."
