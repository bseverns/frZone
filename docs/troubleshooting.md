# Troubleshooting

- **No MIDI**: Ensure **IAC Driver** is online (macOS), then press **D** in the sketch to verify it's listed. The sketch matches by substring in `MIDI_DEVICE_HINT`.
- **No OSC**: Check firewall and port. Use Python example receiver or TouchDesigner.
- **Chatter**: Increase threshold or cooldown; raise hysteresis (e.g., 1.1 → 1.3).
- **Stuck notes**: Use your DAW’s “Panic/All Notes Off” or stop the sketch; it queues note‑offs and closes the device in `stop()`.
- **Rig-tuned mode not behaving canonically**: run `python3 tools/validate_rig_alignment.py`. If it fails, refresh `atlas/live-rig.default.json` from the sibling authority repo with `python3 tools/sync_live_rig_authority.py`.
- **Rig-tuned MIDI channel looks wrong**: remember the sketch stores MIDI channels zero-based internally. The committed rig profile still pins the emitted lane to human-facing **Ch 15**.
