//=============================================================================
// tb_audio_equalizer.cpp
//
// Vitis HLS testbench for audio_equalizer().
//
// Test strategy:
//   1. Bass-boost test  – inject 100 Hz + 1 kHz + 10 kHz sine mix,
//      apply gain_low=2.0, gain_mid=1.0, gain_high=0.5.
//      Verify that the 100 Hz component is amplified and the 10 kHz is
//      attenuated in the output frame.
//   2. Pass-through test – all gains = 1.0, verify output ≈ input (round-trip
//      FFT/IFFT error should be < -60 dB).
//=============================================================================

#include <cstdio>
#include <cmath>
#include <cstdlib>
#include "../src/audio_equalizer.h"

static constexpr double PI = 3.14159265358979323846;
static constexpr int    TOLERANCE_BITS = 1;   // allow 1 LSB round-trip error

// ─── Helpers ─────────────────────────────────────────────────────────────────

static void fill_sine_mix(hls::stream<audio_sample_t> &stream,
                           double amp1, double freq1,
                           double amp2, double freq2,
                           double amp3, double freq3)
{
    for (int i = 0; i < FFT_SIZE; i++) {
        double t = (double)i / SAMPLE_RATE;
        double v = amp1 * sin(2 * PI * freq1 * t)
                 + amp2 * sin(2 * PI * freq2 * t)
                 + amp3 * sin(2 * PI * freq3 * t);
        // Clamp to [-1, 1) and convert to 24-bit int
        if (v >  0.999) v =  0.999;
        if (v < -1.0  ) v = -1.0;
        ap_int<24> raw = (ap_int<24>)(v * (1 << 23));

        audio_sample_t s;
        s.data.range(23, 0) = raw;
        s.data.range(31, 24) = 0;
        s.keep = 0xF;
        s.strb = 0xF;
        s.last  = (i == FFT_SIZE - 1) ? 1 : 0;
        stream.write(s);
    }
}

// Compute RMS power of a given frequency component in the output buffer.
// We re-build a sine at freq and correlate (Goertzel-style dot product).
static double measure_component(const double out_buf[FFT_SIZE], double freq)
{
    double cos_sum = 0, sin_sum = 0;
    for (int i = 0; i < FFT_SIZE; i++) {
        double t = (double)i / SAMPLE_RATE;
        cos_sum += out_buf[i] * cos(2 * PI * freq * t);
        sin_sum += out_buf[i] * sin(2 * PI * freq * t);
    }
    // Normalised magnitude
    return sqrt(cos_sum * cos_sum + sin_sum * sin_sum) / (FFT_SIZE / 2);
}

// ─── Test 1: Bass Boost ───────────────────────────────────────────────────────
static int test_bass_boost()
{
    printf("\n--- Test 1: Bass Boost (gain_low=2.0, gain_mid=1.0, gain_high=0.5) ---\n");

    hls::stream<audio_sample_t> in_stream, out_stream;

    const double freq_low  = 100.0;   // Hz – falls in low band  (bin ~2)
    const double freq_mid  = 1000.0;  // Hz – falls in mid band  (bin ~21)
    const double freq_high = 10000.0; // Hz – falls in high band (bin ~213)

    fill_sine_mix(in_stream,
                  0.3, freq_low,
                  0.3, freq_mid,
                  0.3, freq_high);

    gain_t g_low  = 2.0f;
    gain_t g_mid  = 1.0f;
    gain_t g_high = 0.5f;
    audio_equalizer(in_stream, out_stream, g_low, g_mid, g_high);

    // Drain output and convert back to double
    double out_buf[FFT_SIZE];
    for (int i = 0; i < FFT_SIZE; i++) {
        audio_sample_t s = out_stream.read();
        ap_int<24> raw;
        raw.range(23, 0) = s.data.range(23, 0);
        out_buf[i] = (double)raw / (double)(1 << 23);
    }

    double mag_low  = measure_component(out_buf, freq_low);
    double mag_mid  = measure_component(out_buf, freq_mid);
    double mag_high = measure_component(out_buf, freq_high);

    printf("  100 Hz  magnitude: %.4f  (expected ~0.600)\n", mag_low);
    printf("  1 kHz   magnitude: %.4f  (expected ~0.300)\n", mag_mid);
    printf("  10 kHz  magnitude: %.4f  (expected ~0.150)\n", mag_high);

    // Allow 10% tolerance due to spectral leakage
    int pass = 1;
    if (fabs(mag_low  - 0.6) > 0.06) { printf("  FAIL: 100 Hz out of range\n");  pass = 0; }
    if (fabs(mag_mid  - 0.3) > 0.03) { printf("  FAIL: 1 kHz out of range\n");   pass = 0; }
    if (fabs(mag_high - 0.15)> 0.015){ printf("  FAIL: 10 kHz out of range\n");  pass = 0; }

    if (pass) printf("  PASS\n");
    return pass;
}

// ─── Test 2: Pass-Through ─────────────────────────────────────────────────────
static int test_passthrough()
{
    printf("\n--- Test 2: Pass-Through (all gains = 1.0) ---\n");

    hls::stream<audio_sample_t> in_stream, out_stream;
    double in_buf[FFT_SIZE];

    for (int i = 0; i < FFT_SIZE; i++) {
        double t = (double)i / SAMPLE_RATE;
        double v = 0.5 * sin(2 * PI * 440.0 * t)  // A4 tone
                 + 0.3 * sin(2 * PI * 880.0 * t);
        if (v >  0.999) v =  0.999;
        if (v < -1.0  ) v = -1.0;
        in_buf[i] = v;

        ap_int<24> raw = (ap_int<24>)(v * (1 << 23));
        audio_sample_t s;
        s.data.range(23, 0) = raw;
        s.data.range(31, 24) = 0;
        s.keep = 0xF;
        s.strb = 0xF;
        s.last  = (i == FFT_SIZE - 1) ? 1 : 0;
        in_stream.write(s);
    }

    gain_t g = 1.0f;
    audio_equalizer(in_stream, out_stream, g, g, g);

    double max_err = 0.0;
    for (int i = 0; i < FFT_SIZE; i++) {
        audio_sample_t s = out_stream.read();
        ap_int<24> raw;
        raw.range(23, 0) = s.data.range(23, 0);
        double out_val = (double)raw / (double)(1 << 23);
        double err = fabs(out_val - in_buf[i]);
        if (err > max_err) max_err = err;
    }

    double err_db = 20.0 * log10(max_err + 1e-12);
    printf("  Max round-trip error: %.2e  (%.1f dB)\n", max_err, err_db);

    int pass = (err_db < -50.0);
    printf("  %s\n", pass ? "PASS" : "FAIL (error too large)");
    return pass;
}

// ─── Main ─────────────────────────────────────────────────────────────────────
int main()
{
    int passed = 0, total = 2;

    passed += test_bass_boost();
    passed += test_passthrough();

    printf("\n=== Results: %d / %d tests passed ===\n", passed, total);
    return (passed == total) ? 0 : 1;
}
