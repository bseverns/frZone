# Concepts: FFT → Energy → Threshold → Hysteresis → Cooldown

- **FFT & Bands**: We sum energy between `fLo..fHi` for each band (see `BAND_BOUNDS`). Wider bands catch more energy; keep thresholds proportional.
- **Threshold**: Minimum band energy to fire.
- **Hysteresis**: After firing, the band disarms. It will only re‑arm once energy falls **below** `threshold / hysteresis`. This prevents chatter.
- **Cooldown (ms)**: Minimum time between triggers (debounce).
- **Velocity mapping**: Velocity = map(energy, threshold → 4×threshold, 60 → MIDI_VELOCITY_MAX).
- **Note length**: Auto note‑off after `MIDI_NOTE_LEN_MS` (queued in `noteOffQueue`).

Try editing `BAND_BOUNDS` to shape musical behavior (e.g., kick/snare/hats bands), then re‑calibrate thresholds.
