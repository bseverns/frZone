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
`1/2` band select · `[ / ]` threshold · `; / '` hysteresis · `, / .` cooldown · `- / =` note · `c/C` CC · `i` solo selected band (OSC/MIDI only) · `B` burst · `S/O` save/load · `t/T` transpose · `d/D` list MIDI outs (quiet/loud, your call) · `L` live/file · `P` play · `SPACE` OSC toggle · `M` MIDI toggle

## Teaching notes (for lab leaders, professors, and adventurous students)
- **Start with the comments in the sketch.** Everything documented there reflects the *current* defaults. If you fork this for a class, narrate those comments live so your cohort knows the code matches what they're hearing.
- **Run a "threshold relay" exercise.** Pair students up; one drives the knobs while the other narrates what the sketch reports. Swap roles every five minutes. This keeps the vocabulary honest and matches the hysteresis logic in the code.
- **Use MIDI burst as a signal routing check.** The `B` key fires a known-good CC sweep + note tap—perfect for verifying each learner patched their visual app correctly before you release them into the wild.
- **Document your own band presets.** Have the class export `mapping.json` (press `S`). Stash those files in a shared drive so future cohorts can remix previous work. The defaults are intentionally "good enough" but not perfect, so everyone practices refinement.

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
* **processing/** — The core instrument. Crack open `FreqZoneTriggers/FreqZoneTriggers.pde` first to see how thresholds, hysteresis, and cooldowns are narrated in code while you test routing live.
* **docs/** — Cheat sheets for getting moving fast. Start with `docs/quickstart.md`, then `docs/osc_addresses.md` so you can wire OSC without guessing.
* **examples/** — Quick probes to prove the pipes work. Run `examples/osc_listener.py` to sanity‑check OSC output before students start improvising.
* **assignments/** — Guided labs that keep the teaching flow honest. Use them to stage short feedback loops while everyone experiments.

---
Made for teaching & performance. Contributions welcome.
