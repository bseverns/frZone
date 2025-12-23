# Quickstart (Detailed)

1) **Install Processing** (Java mode).  
2) **Install libraries**: **Minim** and **oscP5** via Contribution Manager.  
3) Open `processing/FreqZoneTriggers/FreqZoneTriggers.pde` and press ▶︎.
4) **Live vs File**: Press **L** to toggle. Put an MP3 named `your_audio.mp3` in `data/` for File mode.
5) **Routing**: MIDI defaults to the macOS **IAC Driver** (`MIDI_DEVICE_HINT = "IAC"`). Tap **d / D** to spit out the available outputs. Set `MIDI_STRICT=false` if you want a system default fallback.

If you want the blow-by-blow of what happens each frame (source selection → FFT → band energy → smoothing → hysteresis/cooldown → OSC/MIDI sends), read **[Per-frame signal flow](architecture.md)**. It’s the punk‑rock notebook version of the `draw()` loop with search-friendly identifiers.

### Visual workflows
- **Signal Culture** (Interstream / Re:Trace / Maelstrom): use **MIDI Learn** and the per‑band CCs (20–24 by default). Press **B** to send a learn burst.
- **TouchDesigner**: OSC In CHOP on port 9000; listen to `/bandEnergy` (0..1) or `/bandTrigger` for pulses.
- Want a zero-setup listener? Open `examples/osc/signal_culture_osc_listener.maxpat` (Max patch). It mirrors `python_receiver.py` so you can route frZone straight into Signal Culture tools or TouchDesigner without wiring the OSC plumbing yourself.

### Why these defaults?
- **Band edges** (`{0, 200, 800, 3000, 8000, 20000}`) aim for “classroom intelligibility” rather than golden-ear mixing. 0–200Hz catches kicks and breath noise; 200–800Hz is the vowel/core voice band; 800–3000Hz tracks consonants and snare crack; 3–8k picks up hats and synth bite; 8–20k is cymbal fizz and room air. Students see those anchors on the overlay so they can say “hat band is spiking” out loud.
- **Thresholds** ship conservative so a mic’ed room doesn’t false-fire when you cough. Treat them as the “sensitivity” knob: back them down if you’re feeding stems, raise them if the class is loud and live.
- **Hysteresis + cooldown** are defaults on purpose, not afterthoughts. They’re tuned to keep voice-led sessions from machine-gunning triggers. When the overlay says `;/'` for hysteresis or `,/.` for cooldown, that’s your classroom handle for “make the trigger pickier” versus “slow the trigger down.”

### Per-band assignment & mapping
- Select a band with **1/2**.
- **- / =** change the band’s **note** (`N##(Name)` shows on screen).
- **c / C** change the band’s **CC** number.
- Tap **i** to **solo** the selected band — only that lane will spew OSC/MIDI while you fine-tune.
- **S / O** save/load a mapping JSON in `data/mapping.json`.
- **t / T** transpose all notes −/+ 1 semitone.
