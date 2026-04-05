# OSC Addressing

## Generic classroom mode

- **/bandTrigger** (event pulse): `i f f f f f i`
  - `idx, fLo, fHi, energy, threshold, hysteresis, cooldownMs`

- **/bandEnergy** (continuous): `i f f f`
  - `idx, fLo, fHi, energyN` where `energyN` is 0..1 smoothed.

## Rig-tuned mode

Rig-tuned mode preserves the legacy addresses above and adds semantic aliases for sibling-repo alignment:

- **/analysis/low_band**
  - `f` → normalized low-band energy `0..1`
- **/analysis/mid_band**
  - `f` → normalized mid-band energy `0..1`
- **/analysis/upper_mid_band**
  - `f` → normalized upper-mid energy `0..1`
- **/analysis/high_band**
  - `f` → normalized high-band energy `0..1`
- **/analysis/trigger/<band>**
  - `f` → normalized energy for the triggered semantic band

Default rig-tuned loopback:

- output: `127.0.0.1:8000`
- input: `127.0.0.1:8001`
