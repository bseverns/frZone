# Troubleshooting

- **No audio / silent FFT**: Make sure your OS input device is correct. In Processing/Minim, `getLineIn` uses the default system device.
- **No MIDI**: On macOS enable the **IAC Driver** and select it as your DAW input; on Windows create a port with **loopMIDI**; on Linux use **aconnect** to wire ports.
- **Stuck notes**: Sketch sends auto note‑offs; if you stop the sketch mid‑note, use your DAW’s “Panic / All Notes Off”.
- **OSC not received**: Verify IP/port and firewall. Use a network monitor or print from the receiver.
- **Too many triggers**: Increase thresholds and/or cooldown; raise hysteresis (e.g., from 1.1 → 1.3).

If Minim can’t decode your MP3, try converting to 44.1kHz, 16‑bit WAV or use a different encoder.
