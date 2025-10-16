# Troubleshooting

- **No MIDI**: Ensure **IAC Driver** is online (macOS), then press **D** in the sketch to verify it's listed. The sketch matches by substring in `MIDI_DEVICE_HINT`.
- **No OSC**: Check firewall and port. Use Python example receiver or TouchDesigner.
- **Chatter**: Increase threshold or cooldown; raise hysteresis (e.g., 1.1 → 1.3).
- **Stuck notes**: Use your DAW’s “Panic/All Notes Off” or stop the sketch; it queues note‑offs and closes the device in `stop()`.
