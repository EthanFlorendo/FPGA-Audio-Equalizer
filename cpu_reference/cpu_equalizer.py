"""
cpu_reference/cpu_equalizer.py

Software (CPU) reference implementation of the audio equalizer.

Implements the same FFT → band-gain → IFFT pipeline as the HLS design,
using NumPy. Used for:
  1. Algorithm verification – outputs should match the FPGA within quantization error.
  2. Performance benchmarking – latency and throughput vs. the FPGA implementation.

Run standalone:
    python cpu_reference/cpu_equalizer.py

Requires: numpy, scipy (optional, for WAV I/O demo), matplotlib (optional)
"""

import time
import numpy as np

# ─── Parameters (must match hls/src/audio_equalizer.h) ───────────────────────
SAMPLE_RATE   = 48_000      # Hz
FFT_SIZE      = 1024        # samples per frame
LOW_HIGH_BIN  = 5           # bin index at 250 Hz boundary
MID_HIGH_BIN  = 85          # bin index at 4 kHz boundary


# ─── Core Equalizer ───────────────────────────────────────────────────────────

def build_gain_mask(gain_low: float, gain_mid: float, gain_high: float) -> np.ndarray:
    """
    Build a full-length FFT gain mask (length FFT_SIZE) from the three band gains.

    The mask is symmetric so that the IFFT produces a real-valued output.
    """
    mask = np.ones(FFT_SIZE, dtype=np.float64)

    # Positive frequencies: bins 0 … FFT_SIZE//2
    for i in range(FFT_SIZE // 2 + 1):
        if i <= LOW_HIGH_BIN:
            g = gain_low
        elif i <= MID_HIGH_BIN:
            g = gain_mid
        else:
            g = gain_high
        mask[i] = g
        # Mirror for negative frequencies (except DC and Nyquist)
        if 0 < i < FFT_SIZE // 2:
            mask[FFT_SIZE - i] = g

    return mask


def equalize_frame(frame: np.ndarray,
                   gain_low: float,
                   gain_mid: float,
                   gain_high: float) -> np.ndarray:
    """
    Apply the 3-band equalizer to one FFT_SIZE-sample frame.

    Parameters
    ----------
    frame      : 1-D array of float64, length FFT_SIZE
    gain_low   : linear gain for 0–250 Hz
    gain_mid   : linear gain for 250–4000 Hz
    gain_high  : linear gain for 4000–24000 Hz

    Returns
    -------
    Processed frame, same shape and dtype as input.
    """
    assert len(frame) == FFT_SIZE, f"Expected {FFT_SIZE} samples, got {len(frame)}"

    spectrum = np.fft.fft(frame)
    mask     = build_gain_mask(gain_low, gain_mid, gain_high)
    spectrum *= mask
    return np.fft.ifft(spectrum).real


def equalize_stream(samples: np.ndarray,
                    gain_low:  float = 1.0,
                    gain_mid:  float = 1.0,
                    gain_high: float = 1.0,
                    hop_size:  int   = FFT_SIZE) -> np.ndarray:
    """
    Process a variable-length audio stream frame by frame.

    Uses non-overlapping frames (hop_size == FFT_SIZE) to match the FPGA
    pipeline. Overlap-add can be enabled by setting hop_size < FFT_SIZE.

    Parameters
    ----------
    samples   : 1-D float64 array of audio samples (any length)
    gain_*    : per-band linear gains
    hop_size  : frame advance in samples

    Returns
    -------
    Processed samples, same length as input.
    """
    n = len(samples)
    out = np.zeros(n, dtype=np.float64)
    mask = build_gain_mask(gain_low, gain_mid, gain_high)

    pos = 0
    while pos + FFT_SIZE <= n:
        frame = samples[pos : pos + FFT_SIZE]
        spectrum = np.fft.fft(frame)
        spectrum *= mask
        out[pos : pos + FFT_SIZE] = np.fft.ifft(spectrum).real
        pos += hop_size

    return out


# ─── Benchmark ───────────────────────────────────────────────────────────────

def benchmark(duration_s: float = 1.0) -> dict:
    """
    Measure CPU throughput and latency for the equalizer.

    Parameters
    ----------
    duration_s : how many seconds of synthetic audio to process

    Returns
    -------
    dict with keys: frames, total_seconds, fps, real_time_factor, latency_ms
    """
    n_frames = int(duration_s * SAMPLE_RATE / FFT_SIZE)
    rng      = np.random.default_rng(42)
    frames   = [rng.uniform(-1.0, 1.0, FFT_SIZE) for _ in range(n_frames)]
    mask     = build_gain_mask(2.0, 1.0, 0.5)

    # Time the inner loop only
    t0 = time.perf_counter()
    for frame in frames:
        spectrum = np.fft.fft(frame)
        spectrum *= mask
        np.fft.ifft(spectrum).real
    elapsed = time.perf_counter() - t0

    frame_time_s = FFT_SIZE / SAMPLE_RATE          # 1 frame = 21.3 ms at 48 kHz
    return {
        "frames":            n_frames,
        "total_audio_s":     duration_s,
        "cpu_time_s":        elapsed,
        "fps":               n_frames / elapsed,
        "real_time_factor":  duration_s / elapsed,  # >1 means faster than real-time
        "latency_ms":        frame_time_s * 1000,   # inherent algorithmic latency
    }


# ─── Quick Demo ───────────────────────────────────────────────────────────────

def _demo() -> None:
    print("=== CPU Audio Equalizer Reference ===\n")

    # Generate a 3-tone test signal (100 Hz + 1 kHz + 10 kHz)
    t = np.arange(FFT_SIZE) / SAMPLE_RATE
    test_frame = (
        0.3 * np.sin(2 * np.pi * 100  * t) +
        0.3 * np.sin(2 * np.pi * 1000 * t) +
        0.3 * np.sin(2 * np.pi * 10000 * t)
    )

    print("Input  peak: {:.4f}".format(np.max(np.abs(test_frame))))

    # Bass boost
    out = equalize_frame(test_frame, gain_low=2.0, gain_mid=1.0, gain_high=0.5)
    print("Output peak: {:.4f}  (bass boost applied)".format(np.max(np.abs(out))))

    # Pass-through
    pt = equalize_frame(test_frame, gain_low=1.0, gain_mid=1.0, gain_high=1.0)
    err_db = 20 * np.log10(np.max(np.abs(pt - test_frame)) + 1e-12)
    print(f"Round-trip error: {err_db:.1f} dB  (should be < -100 dB for float64)")

    # Benchmark
    print("\n--- Benchmark (1 second of audio) ---")
    bm = benchmark(1.0)
    print(f"  Frames processed : {bm['frames']}")
    print(f"  CPU time         : {bm['cpu_time_s']*1000:.2f} ms")
    print(f"  Real-time factor : {bm['real_time_factor']:.1f}x")
    print(f"  Algorithmic latency: {bm['latency_ms']:.1f} ms")


if __name__ == "__main__":
    _demo()
