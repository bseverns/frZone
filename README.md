# Freq‑Zone Peak Triggers (Live/File) + OSC + MIDI

A Processing (Java) sketch that slices the spectrum into tweakable bands and fires **OSC**, **MIDI notes**, and **continuous MIDI CC** for visuals (Signal Culture apps, TD, etc.). Built for teaching **thresholds / hysteresis / cooldown** and practical routing.

## Features for visual apps
- **IAC‑targeted MIDI out** (no SoftSynth fallback unless you set `MIDI_STRICT=false`)
- **Continuous per‑band CC** (default CCs 20–24) + **note hits** (for gates/learn taps)
- **OSC energy stream** `/bandEnergy` (idx, fLo, fHi, energyN 0..1)
- **MIDI Learn Burst** (**B**): CC 0→127→0 + a short note tap per band
- **Per‑band note/CC assignment** (keys), **save/load mapping** (`data/mapping.json`)

## Quick start
1. Install **Processing (Java mode)**. In Contribution Manager, add **Minim** and **oscP5**.
2. Open `processing/FreqZoneTriggers/FreqZoneTriggers.pde` and press ▶.
3. Optional: put `your_audio.mp3` in `processing/FreqZoneTriggers/data/`, press **P** in File mode.
4. Enable **IAC Driver** (macOS: Audio MIDI Setup → MIDI Studio). The sketch auto‑targets ports matching `"IAC"`.

**Keys**:  
`1/2` band select · `[ / ]` threshold · `; / '` hysteresis · `, / .` cooldown · `- / =` note · `c/C` CC · `B` burst · `S/O` save/load · `t/T` transpose · `D` list MIDI outs · `L` live/file · `P` play · `SPACE` OSC toggle · `M` MIDI toggle

## Targeting a specific MIDI device
At the top of the sketch:
```java
String  MIDI_DEVICE_HINT = "IAC"; // substring of device name/description/vendor
boolean MIDI_STRICT      = true;  // if not found, MIDI disabled (no SoftSynth)
```
Press **D** to print all outputs that accept Receivers and confirm the exact name.

## OSC + MIDI
- **OSC event**: `/bandTrigger` → `i f f f f f i` (bandIndex, fLo, fHi, energy, threshold, hysteresis, cooldownMs)
- **OSC energy**: `/bandEnergy` → `i f f f` (bandIndex, fLo, fHi, energyN 0..1)
- **MIDI**: Notes per band (editable), velocity scales with energy; CC per band streams `0..127`.

## Repo layout
```
processing/
  FreqZoneTriggers/
    FreqZoneTriggers.pde
    data/
      (place audio + mapping.json here)
docs/
  quickstart.md • concepts.md • midi_map.md • osc_addresses.md • troubleshooting.md • links.md
examples/
  osc/python_receiver.py • midi/virtual_midi.md
assignments/
  01_calibrate_bands.md • 02_build_performer.md • 03_chain_reaction.md
```

---
Made for teaching & performance. Contributions welcome.
