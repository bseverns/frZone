# MIDI Map

Default per‑band notes (General MIDI-ish drums; channel 1 by default):

| Band | Range (Hz)        | Note | Meaning |
|-----:|-------------------|-----:|---------|
| 1    | 0–200             | 36   | Kick C1 |
| 2    | 200–800           | 38   | Snare D1 |
| 3    | 800–3000          | 42   | Closed Hat F#1 |
| 4    | 3000–8000         | 46   | Open Hat A#1 |
| 5    | 8000–20000        | 49   | Crash C#2 |

Change the `MIDI_NOTES[]` array at the top of the sketch to suit your rig. You can also change `MIDI_CHANNEL` and `MIDI_NOTE_LEN_MS`.
