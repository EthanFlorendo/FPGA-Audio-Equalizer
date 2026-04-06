#ifndef AUDIO_EQUALIZER_H
#define AUDIO_EQUALIZER_H

#include <ap_fixed.h>
#include <ap_int.h>
#include <hls_stream.h>
#include <ap_axi_sdata.h>

// ─── Audio Parameters ────────────────────────────────────────────────────────
#define SAMPLE_RATE     48000       // Hz
#define FFT_SIZE        1024        // must be power of 2
#define FFT_SIZE_LOG2   10          // log2(FFT_SIZE)
#define NUM_CHANNELS    1           // mono

// ─── Frequency Band Bin Boundaries ───────────────────────────────────────────
// Resolution = SAMPLE_RATE / FFT_SIZE = 46.875 Hz/bin
// Low  band:  0   –  250 Hz  → bins 0   to LOW_HIGH_BIN
// Mid  band:  250 – 4000 Hz  → bins LOW_HIGH_BIN+1 to MID_HIGH_BIN
// High band:  4000 – 24000 Hz→ bins MID_HIGH_BIN+1 to FFT_SIZE/2
#define LOW_HIGH_BIN    5           // floor(250  / 46.875)
#define MID_HIGH_BIN    85          // floor(4000 / 46.875)

// ─── Fixed-Point Types ───────────────────────────────────────────────────────
// 24-bit audio sample: Q1.23 (1 sign + 7 integer + 16 fractional)
typedef ap_fixed<24, 8>  sample_t;

// Gain: Q4.12 – supports 0.0 to ~15.9, enough for ±12 dB boost/cut
typedef ap_fixed<16, 4>  gain_t;

// Complex sample for FFT (real + imag)
typedef ap_fixed<24, 8>  fft_data_t;

// AXI Stream sample: 32-bit word carries a 24-bit signed audio sample
typedef ap_axiu<32, 1, 1, 1> audio_sample_t;

// ─── Gain Defaults ───────────────────────────────────────────────────────────
#define DEFAULT_GAIN    1.0f

// ─── Function Prototype ──────────────────────────────────────────────────────
void audio_equalizer(
    hls::stream<audio_sample_t> &s_axis_audio_in,
    hls::stream<audio_sample_t> &m_axis_audio_out,
    gain_t gain_low,
    gain_t gain_mid,
    gain_t gain_high
);

#endif // AUDIO_EQUALIZER_H
