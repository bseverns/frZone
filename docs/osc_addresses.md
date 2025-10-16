# OSC Addressing

- **/bandTrigger** (event pulse): `i f f f f f i`
  - `idx, fLo, fHi, energy, threshold, hysteresis, cooldownMs`

- **/bandEnergy** (continuous): `i f f f`
  - `idx, fLo, fHi, energyN` where `energyN` is 0..1 smoothed.
