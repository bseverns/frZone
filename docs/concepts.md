# Concepts: FFT → Energy → Threshold → Hysteresis → Cooldown

- **FFT & Bands**: We sum energy between `fLo..fHi` for each band (`BAND_BOUNDS`). Wider bands catch more energy → set thresholds accordingly.
- **Threshold**: Minimum band energy to fire.
- **Hysteresis**: After firing, the band disarms. It re‑arms once energy falls **below** `threshold / hysteresis` to prevent chatter.
- **Cooldown (ms)**: Minimum time between triggers (debounce).
- **Velocity mapping**: Velocity = map(energy, threshold → 4×threshold, 60 → `MIDI_VELOCITY_MAX`).

Try editing `BAND_BOUNDS` to align to kick/snare/hats regions, then recalibrate thresholds.
