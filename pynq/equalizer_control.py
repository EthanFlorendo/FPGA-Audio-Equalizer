"""
equalizer_control.py

Python interface layer for the FPGA Audio Equalizer overlay on the PYNQ-Z2.

Usage (from Jupyter or a script):
    from equalizer_control import AudioEqualizer
    eq = AudioEqualizer("audio_equalizer.bit")
    eq.set_gains(low=2.0, mid=1.0, high=0.5)
    eq.start()
"""

from pynq import Overlay, MMIO
import time

# ─── AXI-Lite Register Offsets ────────────────────────────────────────────────
# These offsets match the Vitis HLS-generated register map for audio_equalizer.
# Check the generated header (hls/solution/impl/ip/.../audio_equalizer_hw.h)
# for the canonical values.
REG_CTRL       = 0x00   # ap_ctrl: bit0=start, bit1=done, bit7=auto-restart
REG_GAIN_LOW   = 0x10   # gain_low  (ap_fixed<16,4> packed into 32-bit word)
REG_GAIN_MID   = 0x18   # gain_mid
REG_GAIN_HIGH  = 0x20   # gain_high

# Fixed-point scaling: Q4.12 → integer representation
# gain value 1.0 = (1 << 12) = 4096
_FRAC_BITS = 12
_SCALE     = 1 << _FRAC_BITS

# Gain limits
GAIN_MIN = 0.0
GAIN_MAX = 15.9375   # max representable in Q4.12


class AudioEqualizer:
    """High-level driver for the HLS audio equalizer IP core."""

    def __init__(self, bitfile: str = "audio_equalizer.bit"):
        """
        Load the overlay and locate the equalizer IP.

        Parameters
        ----------
        bitfile : str
            Path to the .bit file (and accompanying .hwh) on the PYNQ board.
        """
        self.overlay = Overlay(bitfile)
        # The IP core is named 'audio_equalizer_0' in the block design
        self.ip = self.overlay.audio_equalizer_0
        # Default gains (unity – pass-through)
        self._gain_low  = 1.0
        self._gain_mid  = 1.0
        self._gain_high = 1.0
        self.set_gains(1.0, 1.0, 1.0)

    # ── Gain Control ──────────────────────────────────────────────────────────

    @staticmethod
    def _float_to_fixed(value: float) -> int:
        """Convert a float gain to the Q4.12 fixed-point integer representation."""
        value = max(GAIN_MIN, min(GAIN_MAX, value))
        return int(value * _SCALE)

    def set_gain_low(self, gain: float) -> None:
        """Set the bass (low-frequency) band gain (0.0 – 15.9)."""
        self._gain_low = gain
        self.ip.write(REG_GAIN_LOW, self._float_to_fixed(gain))

    def set_gain_mid(self, gain: float) -> None:
        """Set the mid-frequency band gain (0.0 – 15.9)."""
        self._gain_mid = gain
        self.ip.write(REG_GAIN_MID, self._float_to_fixed(gain))

    def set_gain_high(self, gain: float) -> None:
        """Set the treble (high-frequency) band gain (0.0 – 15.9)."""
        self._gain_high = gain
        self.ip.write(REG_GAIN_HIGH, self._float_to_fixed(gain))

    def set_gains(self, low: float, mid: float, high: float) -> None:
        """Set all three band gains at once."""
        self.set_gain_low(low)
        self.set_gain_mid(mid)
        self.set_gain_high(high)

    def get_gains(self) -> dict:
        """Return the currently applied gain values."""
        return {
            "low":  self._gain_low,
            "mid":  self._gain_mid,
            "high": self._gain_high,
        }

    # ── Preset Profiles ───────────────────────────────────────────────────────

    def preset_flat(self) -> None:
        """Flat EQ – all bands unity gain."""
        self.set_gains(1.0, 1.0, 1.0)

    def preset_bass_boost(self) -> None:
        """Boost bass, reduce treble."""
        self.set_gains(low=2.0, mid=1.0, high=0.6)

    def preset_treble_boost(self) -> None:
        """Boost treble, reduce bass."""
        self.set_gains(low=0.6, mid=1.0, high=2.0)

    def preset_voice_enhance(self) -> None:
        """Attenuate sub-bass and boost upper-mids for speech clarity."""
        self.set_gains(low=0.5, mid=1.8, high=1.2)

    # ── IP Core Control ───────────────────────────────────────────────────────

    def start(self) -> None:
        """Enable continuous (auto-restart) processing in the HLS core."""
        ctrl = self.ip.read(REG_CTRL)
        # bit7 = auto_restart, bit0 = start
        self.ip.write(REG_CTRL, ctrl | 0x81)

    def stop(self) -> None:
        """Clear the auto-restart bit; the core finishes its current frame."""
        ctrl = self.ip.read(REG_CTRL)
        self.ip.write(REG_CTRL, ctrl & ~0x80)

    def is_idle(self) -> bool:
        """Return True if the core is not currently processing a frame."""
        return bool(self.ip.read(REG_CTRL) & 0x04)  # bit2 = idle

    def __repr__(self) -> str:
        g = self.get_gains()
        return (f"AudioEqualizer(low={g['low']:.2f}, "
                f"mid={g['mid']:.2f}, high={g['high']:.2f})")
