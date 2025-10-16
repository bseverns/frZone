# Virtual MIDI (loopback) quick setup

## macOS (IAC Driver)
1. Open **Audio MIDI Setup** → **Window ▸ Show MIDI Studio**.
2. Double‑click **IAC Driver** → check **Device is online**.
3. Add a port (e.g., “Processing→Visuals”). Select this as an **input** in your app.

## Windows (loopMIDI)
1. Install **loopMIDI** by Tobias Erichsen.
2. Create a new port (e.g., “Processing→Visuals”). Select this as an input in your app.

## Linux (ALSA)
- List ports: `aconnect -l`
- Wire: `aconnect sender:port receiver:port`

In the sketch, `MIDI_DEVICE_HINT` controls which device is opened. Press **D** to list available outputs.
