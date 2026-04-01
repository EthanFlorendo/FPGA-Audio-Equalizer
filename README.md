# FPGA-Based Real-Time Audio Equalizer

Class project for Reconfigurable Computing (CSE494).

Team: Daniel Gonzales, Ethan Florendo, Isaak Truong

## Overview

A real-time 3-band audio equalizer implemented on the PYNQ-Z2 FPGA board. Audio is captured through the onboard ADAU1761 codec, processed in the frequency domain via FFT/IFFT on the programmable logic, and output in real time. Gain for the low, mid, and high frequency bands is adjustable at runtime through a Python/Jupyter interface.

## Repository Structure

```
hls/
  src/
    audio_equalizer.h       # Types, constants, FFT size/bin boundaries
    audio_equalizer.cpp     # HLS top-level: FFT → gain → IFFT, AXI interfaces
  scripts/
    gen_lut.py              # Generates cos_lut.h / sin_lut.h twiddle tables
  tb/
    tb_audio_equalizer.cpp  # C simulation testbench

vivado/
  scripts/
    create_project.tcl      # Creates the Vivado project
    block_design.tcl        # Block design: Zynq PS + HLS IP + AXI DMA + IIC
  constraints/
    pynq_z2.xdc             # ADAU1761 I2S pin assignments and timing

pynq/
  equalizer_control.py      # Python driver: loads overlay, writes AXI-Lite gains
  equalizer_overlay.ipynb   # Jupyter notebook with interactive sliders

cpu_reference/
  cpu_equalizer.py          # NumPy reference implementation for benchmarking
```

## Hardware

- **Board:** PYNQ-Z2 (Zynq XC7Z020)
- **Audio Codec:** ADAU1761 (3.5 mm line-in / line-out)
- **Interface:** I2S (BCLK = 3.072 MHz, LRCLK = 48 kHz)

## Signal Processing Pipeline

```
Line-In → ADC → I2S RX → [FFT → Band Gain → IFFT] → I2S TX → DAC → Line-Out
                              (Programmable Logic)
```

| Band | Frequency Range  | FFT Bins (1024-pt @ 48 kHz) |
|------|-----------------|------------------------------|
| Low  | 0 – 250 Hz      | 0 – 5                        |
| Mid  | 250 – 4000 Hz   | 6 – 85                       |
| High | 4000 – 24000 Hz | 86 – 511                     |

## Build Instructions

### 1. Generate twiddle-factor LUTs

```bash
python hls/scripts/gen_lut.py
```

### 2. Synthesize HLS IP (Vitis HLS)

1. Create a new Vitis HLS project targeting `xc7z020clg400-1`.
2. Add `hls/src/` as source files and `hls/tb/` as testbench files.
3. Run C Simulation, then C/RTL Co-simulation.
4. Export RTL as IP to `hls/solution/impl/ip/`.

### 3. Build Vivado project and bitstream

```bash
vivado -mode batch -source vivado/scripts/create_project.tcl
```

Then in Vivado: **Flow → Generate Bitstream**. Copy the resulting `.bit` and `.hwh` files to the PYNQ board.

### 4. Run on PYNQ-Z2

Open `pynq/equalizer_overlay.ipynb` in the board's Jupyter environment and run all cells. Use the sliders to adjust gains in real time.

## Evaluation Metrics

- End-to-end latency
- Sustained sampling rate (throughput)
- FPGA resource utilization (LUT, FF, BRAM, DSP)
- CPU vs. FPGA performance comparison (`cpu_reference/cpu_equalizer.py`)
