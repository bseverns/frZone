# Virtual MIDI (loopback) quick setup

## macOS (IAC Driver)
1. Open **Audio MIDI Setup** → **Window ▸ Show MIDI Studio**.
2. Double‑click **IAC Driver** → check **Device is online**.
3. Add a port (e.g., “Processing→DAW”). Select this as an **input** in your DAW.

## Windows (loopMIDI)
1. Install **loopMIDI** by Tobias Erichsen.
2. Create a new port (e.g., “Processing→DAW”). Select this as an input in your DAW.

## Linux (ALSA)
- List ports: `aconnect -l`
- Wire: `aconnect sender:port receiver:port`

Now run the sketch with **MIDI ON** and arm a track in your DAW to receive notes on the chosen port/channel.
