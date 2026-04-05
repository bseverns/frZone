# MIDI Map

## Generic classroom mode

Default per‑band notes (General MIDI‑ish drums; channel 1 by default). You can change them live with **- / =**.

| Band | Range (Hz)        | Note | Meaning      |
|-----:|-------------------|-----:|--------------|
| 1    | 0–200             | 36   | Kick (C1)    |
| 2    | 200–800           | 38   | Snare (D1)   |
| 3    | 800–3000          | 42   | Closed Hat   |
| 4    | 3000–8000         | 46   | Open Hat     |
| 5    | 8000–20000        | 49   | Crash        |

**CCs for visuals** (default): 20–24, one per band. Adjust with **c/C**.

## Rig-tuned mode

When `RIG_TUNED_MODE = true`, `frZone` stops behaving like an editable MIDI sketch and instead publishes the canonical `live-rig` analysis lane:

| Semantic ID                | Raw Band | MIDI Ch | CC |
|---------------------------|---------:|:-------:|---:|
| `analysis.low_band`       | 0        |   15    | 20 |
| `analysis.mid_band`       | 2        |   15    | 22 |
| `analysis.upper_mid_band` | 3        |   15    | 23 |
| `analysis.high_band`      | 4        |   15    | 24 |

Raw band 1 (`200–800 Hz`) remains available for on-screen diagnostics and legacy `/bandEnergy` output, but it is intentionally omitted from the canonical analysis lane.
