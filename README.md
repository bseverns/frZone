# frZone

`frZone` is a Processing instrument for frequency-zone analysis with two deliberate operating modes:

- **Generic classroom mode** keeps the sketch standalone and tweakable for teaching thresholds, hysteresis, cooldown, and routing basics.
- **Rig-tuned mode** turns the sketch into the `live-rig` analysis sibling: a committed, additive analysis lane that mirrors the authority snapshot and emits the canonical Ch 15 controls.

## Features for visual apps
- **Generic classroom mode**
  - IAC-targeted MIDI out with editable per-band notes and CCs
  - Legacy OSC streams `/bandEnergy` and `/bandTrigger`
  - MIDI learn burst for quick patch checks
  - Save/load of classroom mappings in `processing/FreqZone/data/mapping.json`
- **Rig-tuned mode**
  - Canonical **analysis lane on MIDI Ch 15**
  - Canonical CCs **20 / 22 / 23 / 24** for `analysis.low_band`, `analysis.mid_band`, `analysis.upper_mid_band`, and `analysis.high_band`
  - Semantic OSC aliases `/analysis/<band>` plus `/analysis/trigger/<band>`
  - Committed authority mirror at `atlas/live-rig.default.json`
  - Committed rig profile at `interop/frzone.rig.json`

## Quick start
1. Install **Processing (Java mode)**. In Contribution Manager, add **Minim** and **oscP5**.
2. Open `processing/FreqZone/FreqZone.pde` and press ▶.
3. Optional: put `your_audio.mp3` in `processing/FreqZone/data/`, press **P** in File mode.
4. Enable **IAC Driver** (macOS: Audio MIDI Setup → MIDI Studio). The sketch auto‑targets ports matching `"IAC"`.
5. For **rig-tuned mode**, set `RIG_TUNED_MODE = true` near the top of the sketch, then validate the committed contract files with `python3 tools/validate_rig_alignment.py`.

Want the classroom-ready mental model? Start with **[Per-frame signal flow](docs/architecture.md)** — it walks through the exact `draw()` loop and calls out the identifiers you can grep while hacking.

**Keys**:  
`1/2` band select · `[ / ]` threshold · `; / '` hysteresis · `, / .` cooldown · `- / =` note · `c/C` CC · `i` solo selected band (OSC/MIDI only) · `B` burst · `S/O` save/load · `t/T` transpose · `d/D` list MIDI outs (quiet/loud, your call) · `L` live/file · `P` play · `SPACE` OSC toggle · `M` MIDI toggle

In rig-tuned mode the note/CC remap, burst-learn, and save/load controls are intentionally locked so the committed analysis lane stays canonical.

## Teaching notes (for lab leaders, professors, and adventurous students)
- **Start with the comments in the sketch.** Everything documented there reflects the *current* defaults. If you fork this for a class, narrate those comments live so your cohort knows the code matches what they're hearing.
- **Run a "threshold relay" exercise.** Pair students up; one drives the knobs while the other narrates what the sketch reports. Swap roles every five minutes. This keeps the vocabulary honest and matches the hysteresis logic in the code.
- **Use MIDI burst as a signal routing check.** The `B` key fires a known-good CC sweep + note tap—perfect for verifying each learner patched their visual app correctly before you release them into the wild.
- **Document your own band presets.** Have the class export `mapping.json` (press `S`). Stash those files in a shared drive so future cohorts can remix previous work. The defaults are intentionally "good enough" but not perfect, so everyone practices refinement.

## live-rig alignment

`live-rig` treats `frZone` as the analysis sibling only: it owns normalized band analysis and must remain additive rather than scene-defining. The local contract surface for that mode lives here:

- `atlas/live-rig.default.json` — committed mirror of the authority snapshot
- `atlas/interop.yaml` — repo role and interface statement
- `interop/frzone.rig.json` — committed rig profile for the canonical analysis lane
- `tools/sync_live_rig_authority.py` — refresh the local mirror from `../live-rig`
- `tools/validate_rig_alignment.py` — verify the local mirror and rig profile stay aligned

That keeps the sibling contract explicit: if `frZone` disappears, the rest of the rig falls back to scene base plus manual macros instead of losing shared control semantics.

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
- **Rig-tuned OSC aliases**: `/analysis/low_band`, `/analysis/mid_band`, `/analysis/upper_mid_band`, `/analysis/high_band`
- **Rig-tuned trigger aliases**: `/analysis/trigger/<band>` carrying the normalized band energy
- **MIDI**:
  - Generic mode: editable per-band notes plus per-band CC stream
  - Rig-tuned mode: semantic analysis CCs on Ch 15 only

## Repo layout
* **processing/** — The core instrument. Crack open `FreqZone/FreqZone.pde` first to see how thresholds, hysteresis, and cooldowns are narrated in code while you test routing live.
* **docs/** — Cheat sheets for getting moving fast. Start with `docs/quickstart.md`, then `docs/osc_addresses.md` so you can wire OSC without guessing.
* **examples/** — Quick probes to prove the pipes work. Run `examples/osc_listener.py` to sanity‑check OSC output before students start improvising.
* **assignments/** — Guided labs that keep the teaching flow honest. Use them to stage short feedback loops while everyone experiments.
* **atlas/** + **interop/** — The sibling-repo contract surface for rig-tuned mode.

---
Made for teaching & performance. Contributions welcome.
