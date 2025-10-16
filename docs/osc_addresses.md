# OSC Addressing

This sketch **sends** (does not listen) to a single address:

```
/bandTrigger  i f f f f f i
              | | | | | | |
              | | | | | | └─ cooldownMs
              | | | | | └─── hysteresis
              | | | | └───── threshold
              | | | └─────── energy (current summed band energy)
              | | └───────── fHi (Hz)
              | └─────────── fLo (Hz)
              └───────────── bandIndex (0‑based)
```

Suggested receivers:
- Python (`examples/osc/python_receiver.py`)
- TouchDesigner (OSC In CHOP)
- SuperCollider / Max / Pure Data
