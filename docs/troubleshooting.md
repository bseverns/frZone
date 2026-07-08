# Troubleshooting

- **No MIDI**: Ensure **IAC Driver** is online (macOS), then press **d** in the sketch to verify it's listed. The sketch matches by substring in `MIDI_DEVICE_HINT`.
- **Blind MIDI receiver looks dead**: Press **G** for a MIDI hello. If `MIDI device` shows `(none)`, the sketch refreshes CoreMIDI/Java Sound outputs, tries the configured hint plus Interstream/Signal Culture/network-session fallback hints, then sends a short pulse on the active CC lane.
- **Interstream is open but frZone still says `(none)`**: Interstream may be listening to an input such as an IAC bus rather than exposing itself as a sendable output. Press **d** and look for `IAC`, `Interstream`, or `Network/Session`; if none appear, enable an IAC bus in Audio MIDI Setup and select that bus inside Interstream.
- **No OSC**: Check firewall and port. Use Python example receiver or TouchDesigner.
- **Chatter**: Increase threshold or cooldown; raise hysteresis (e.g., 1.1 → 1.3).
- **Stuck notes**: Use your DAW’s “Panic/All Notes Off” or stop the sketch; it queues note‑offs and closes the device in `stop()`.
- **Rig-tuned mode not behaving canonically**: run `python3 tools/validate_rig_alignment.py`. If it fails, refresh `atlas/live-rig.default.json` from the sibling authority repo with `python3 tools/sync_live_rig_authority.py`.
- **Rig-tuned MIDI channel looks wrong**: remember the sketch stores MIDI channels zero-based internally. The committed rig profile still pins the emitted lane to human-facing **Ch 15**.
