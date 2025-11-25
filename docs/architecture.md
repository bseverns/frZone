# Per-frame signal flow (sketch tour)

> Think of this as the lab notebook page taped above the rig: the order of operations, why each piece exists, and the identifiers you can grep when you want to hack deeper.

## 1) Pick an audio source (live vs file)
- The frame starts by grabbing `AudioSource src = USE_LIVE ? liveIn : player;` inside `draw()`. If you're flipping the **L** key a bunch, `switchSource()` rebuilds the `FFT` to match the input buffer/sample rate so the bins line up.
- `USE_LIVE`, `AUDIO_FILE`, and `AUDIO_BUF` live up top as config knobs; they drive the Minim setup in `setup()` and `switchSource()`.

## 2) FFT the incoming buffer
- `fft.forward(src.mix);` runs once per frame using the currently selected source. Buffer length and sample rate are whatever Minim provided for the active input.
- Band edges are set by `BAND_BOUNDS`; `fft.freqToIndex()` turns those into bin indices per band right before energy accumulation.

## 3) Sum energy per band
- For each `BandTrigger` (`bands[b]`), `iLo/iHi` wrap the FFT bin range and a simple loop accumulates `sum += fft.getBand(i);`.
- That `sum` is the raw energy used for both continuous output and trigger checks. The sketch also tracks `maxBar` for drawing the UI bars.

## 4) Normalize + smooth continuous energy
- Continuous values are normalized against the per-band threshold: `map(sum, bt.threshold, bt.threshold*4, 0, 1)` then clamped to `0..1`.
- `bt.smooth = lerp(bt.smooth, eN, ENERGY_SMOOTH);` applies a one-pole lowpass so visuals chill out. `ENERGY_SMOOTH` is the single classroom slider for “how twitchy are my CCs/OSC energy streams?”

## 5) Stream OSC/MIDI energy (always-on lanes)
- When OSC is on and `SEND_OSC_ENERGY` is true, each band fires `/bandEnergy` with `(idx, fLo, fHi, smooth)`.
- When MIDI is on and `MIDI_SEND_CCS` is true, `midi.cc()` streams a CC per band (`MIDI_CCS[]`) using the same smoothed 0..1 value mapped to `0..127`.
- `SOLO_SELECTED_BAND` zeroes out all but the focused band for both OSC energy and CCs. Handy when teaching a room full of people staring at the same projector.

## 6) Trigger decision: hysteresis + cooldown
- Each `BandTrigger` tracks `threshold`, `hysteresis`, `cooldownMs`, `lastTrigMs`, and `armed`.
- Re-arming: when energy falls below `threshold / hysteresis`, `armed` flips back to true.
- Firing: when `armed` **and** `(now - lastTrigMs) >= cooldownMs` **and** `sum >= threshold`, the band fires and disarms. Cooldown keeps machine‑gun taps out of the MIDI stream; hysteresis prevents rapid re-trigger when hovering around the threshold.

## 7) OSC trigger payloads
- If OSC is enabled, `sendOscTrigger()` sends `/bandTrigger` with `i f f f f f i` → `(idx, fLo, fHi, energy, threshold, hysteresis, cooldownMs)` every time a band fires.
- The full descriptor ships on every pulse so you can map on the receiving end without digging into the code mid-show.

## 8) MIDI note taps + deferred note-offs
- If MIDI is enabled and `MIDI_SEND_NOTES` is true, firing a band calls `midi.noteOn(bt.midiNote, velocity)` where velocity scales with energy against the threshold.
- Note-offs are deferred via `noteOffQueue` (list of `PendingNoteOff` structs). `processNoteOffs()` walks the queue each frame and sends `midi.noteOff()` when `millis()` passes the stored `whenMs`. `MIDI_NOTE_LEN_MS` sets how long taps ring.

## 9) Frame-end chores and overlays
- After triggers, the sketch processes any due note-offs, draws the spectrum and per-band bars, and renders an overlay that lists the hotkeys (so the whole class can follow along without asking “what was the CC key again?”).

## Bread crumbs (grep targets)
- Class/structs: `BandTrigger`, `PendingNoteOff`
- Config flags: `SEND_OSC_ENERGY`, `MIDI_SEND_CCS`, `MIDI_SEND_NOTES`, `SOLO_SELECTED_BAND`
- Queues/helpers: `noteOffQueue`, `processNoteOffs()`, `burstLearn()`
- OSC: `sendOscTrigger()` (`/bandTrigger`), continuous energy `/bandEnergy`
- MIDI: `midi.noteOn()`, `midi.cc()`, `MIDI_CCS[]`, `MIDI_NOTE_LEN_MS`

Feel free to scribble on this: tweak the thresholds/hysteresis mid‑lecture, comment your discoveries, and leave it better for the next curious hacker.
