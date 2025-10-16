# Freq‑Zone Peak Triggers (Live/File) + OSC + MIDI

_A Processing (Java) sketch that slices the spectrum into student‑tweakable bands and fires OSC + MIDI when peaks occur. Built for teaching signal flow, thresholding, hysteresis, and performance routing._

## What this repo gives you
- **Processing sketch** with live/file switch, per‑band threshold/hysteresis/cooldown, OSC + MIDI out, and a lightweight visualizer.
- **Rabbit‑holes**: curated links into Processing/Minim/oscP5, Java MIDI, OSC, and DAW/tool integrations.
- **Examples**: Python OSC receiver, SuperCollider snippet, and platform‑specific MIDI loopback notes.
- **Class scaffolding**: three assignment briefs to get from calibration → performance.

## Quick start
1) **Install Processing (Java mode)** and run it once.  
2) **Install libraries** via Processing’s Contribution Manager: search for **Minim** and **oscP5**.  
3) `File → Open...` and choose `processing/FreqZoneTriggers/FreqZoneTriggers.pde`.  
4) Optional: put an mp3 into `processing/FreqZoneTriggers/data/` named `your_audio.mp3` and press **P** to play when in File mode.  
5) Hit **L** to toggle Live/File. Use **1/2** to select a band and **[, ], ;, ', ,, .** to tune it.  
6) Toggle **SPACE** (OSC) and **M** (MIDI). See `docs/osc_addresses.md` and `docs/midi_map.md`.

> Tip: On macOS use the **IAC Driver** for a virtual MIDI loopback; on Windows use **loopMIDI**; on Linux use **aconnect** (ALSA). See `examples/midi/virtual_midi.md` for step‑by‑step.

## Controls (cheatsheet)
- **1 / 2**: select prev / next band  
- **[ / ]**: decrease / increase **threshold**  
- **; / '**: decrease / increase **hysteresis**  
- **, / .**: decrease / increase **cooldown (ms)**  
- **L**: live vs file input  
- **P**: play/pause file (file mode)  
- **SPACE**: OSC on/off  
- **M**: MIDI on/off  

## OSC + MIDI
- **OSC Address**: `/bandTrigger`  
  **Args**: `int bandIndex, float fLo, float fHi, float energy, float threshold, float hysteresis, int cooldownMs`  
- **MIDI**: Note‑on mapped per band (see `docs/midi_map.md`). Velocity scales with energy; auto note‑off after `MIDI_NOTE_LEN_MS`.

## Teaching ideas
- **Calibrate**: Make students normalize band thresholds so that each layer is “fair” under pink noise vs. a drum loop.  
- **Map**: Route low band → lights, mid bands → drums, highs → FX. Students justify their mapping in a short write‑up.  
- **Perform**: Small groups build a 2‑minute structure where one group’s triggers drive another group’s visuals/sampler.

## Repo layout
```
freq-zone-triggers/
├─ processing/
│  └─ FreqZoneTriggers/
│     ├─ FreqZoneTriggers.pde
│     └─ data/ (put audio here)
├─ examples/
│  ├─ osc/python_receiver.py
│  └─ midi/virtual_midi.md
├─ docs/
│  ├─ quickstart.md
│  ├─ concepts.md
│  ├─ midi_map.md
│  ├─ osc_addresses.md
│  ├─ troubleshooting.md
│  └─ links.md
├─ assignments/
│  ├─ 01_calibrate_bands.md
│  ├─ 02_build_performer.md
│  └─ 03_chain_reaction.md
├─ LICENSE
└─ .gitignore
```

## Credits
- Original sketch authored by **Ben**. Repo scaffolding by ChatGPT (“BS Sound Studio” context).

---

If this helps, consider adding student forks / examples to a class gallery in your course LMS or a GitHub org.
