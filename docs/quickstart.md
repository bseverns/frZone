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

### Per-band assignment & mapping
- Select a band with **1/2**.
- **- / =** change the band’s **note** (`N##(Name)` shows on screen).
- **c / C** change the band’s **CC** number.
- Tap **i** to **solo** the selected band — only that lane will spew OSC/MIDI while you fine-tune.
- **S / O** save/load a mapping JSON in `data/mapping.json`.
- **t / T** transpose all notes −/+ 1 semitone.
