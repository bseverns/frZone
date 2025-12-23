# Concepts: FFT → Energy → Threshold → Hysteresis → Cooldown

- **FFT & Bands**: We sum energy between `fLo..fHi` for each band (`BAND_BOUNDS`). Wider bands catch more energy → set thresholds accordingly.
- **Threshold**: Minimum band energy to fire.
- **Hysteresis**: After firing, the band disarms. It re‑arms once energy falls **below** `threshold / hysteresis` to prevent chatter.
- **Cooldown (ms)**: Minimum time between triggers (debounce).
- **Velocity mapping**: Velocity = map(energy, threshold → 4×threshold, 60 → `MIDI_VELOCITY_MAX`).

Try editing `BAND_BOUNDS` to align to kick/snare/hats regions, then recalibrate thresholds.

## Glossary (overlay words ↔ hotkeys)
- **Band select**: choose a lane with **1 / 2**; the overlay shows the active band name so the room knows which slice you’re poking.
- **Threshold**: the tripwire for a trigger. Nudged with **[ / ]**; label shows up as `Thresh` in the overlay.
- **Hysteresis**: how far energy must drop before re-arming. Controlled with **; / '**; overlay reads `Hyst`. Think “stickiness.”
- **Cooldown**: minimum milliseconds between hits. Adjust with **, / .**; overlay reads `Cd`. Think “pace it out.”
- **Solo band**: **i** toggles `Solo` so only one band spews OSC/MIDI while the class watches cause/effect.
