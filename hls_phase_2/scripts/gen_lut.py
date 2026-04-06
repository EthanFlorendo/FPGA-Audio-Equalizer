"""
gen_lut.py – Generate cos_lut.h and sin_lut.h for the HLS FFT twiddle factors.

Run once before synthesis:
    python hls/scripts/gen_lut.py

Outputs land in hls/src/ and are #included by audio_equalizer.cpp.
"""

import math
import os

FFT_SIZE = 1024
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "src")


def gen_lut(filename: str, values: list[float]) -> None:
    path = os.path.join(OUT_DIR, filename)
    with open(path, "w") as f:
        for i, v in enumerate(values):
            comma = "," if i < len(values) - 1 else ""
            f.write(f"    {v:.10f}{comma}\n")
    print(f"Written {path}  ({len(values)} entries)")


def main() -> None:
    n_half = FFT_SIZE // 2
    cos_vals = [math.cos(2 * math.pi * k / FFT_SIZE) for k in range(n_half)]
    sin_vals = [math.sin(2 * math.pi * k / FFT_SIZE) for k in range(n_half)]
    gen_lut("cos_lut.h", cos_vals)
    gen_lut("sin_lut.h", sin_vals)


if __name__ == "__main__":
    main()
