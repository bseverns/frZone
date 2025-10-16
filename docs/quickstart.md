# Quickstart (Detailed)

1) **Install Processing** (Java mode).  
   - Launch once to create your sketchbook folders.

2) **Install libraries** via **Sketch → Import Library… → Add Library…** (Contribution Manager):
   - Search and install **Minim** (audio I/O + FFT) and **oscP5** (Open Sound Control).

3) **Open** `processing/FreqZoneTriggers/FreqZoneTriggers.pde` and press ▶︎.

4) **Live vs File**:
   - Press **L** to toggle live input vs file playback.
   - Drop an MP3 named `your_audio.mp3` in the sketch’s `data/` folder.

5) **Routing**:
   - OSC defaults to `127.0.0.1:9000`. Change `OSC_HOST`/`OSC_PORT` at the top of the sketch.
   - MIDI uses Java Sound. Set up a virtual port if you’re routing to a DAW (see `examples/midi/virtual_midi.md`).

6) **Tweak** per‑band threshold / hysteresis / cooldown with the keys shown on screen.

> Pro tip: thresholds are in “FFT sum” units. Start higher, come down until you get stable single‑hits, then add a bit of hysteresis.
