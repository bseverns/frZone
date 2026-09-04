# frZone physical control surface firmware

This directory contains the incremental Raspberry Pi Pico WH control-surface
prototype. Stage 1 intentionally does only two things:

- reads potentiometer `A0` through channel `C0` of a CD74HC4067; and
- reads momentary button `B0` with a 20 ms stable-state debounce.

Both controls emit normalized `0..65535` events over USB serial. USB MIDI,
Wi-Fi OSC, LEDs, mappings, and frZone integration are later stages.

## Stage 1 wiring

Use only 3.3 V for the potentiometer and multiplexer signal path.

| Pico WH connection | Physical pin | CD74HC4067 / control connection |
| --- | ---: | --- |
| GP2 | 4 | `S0` |
| GP3 | 5 | `S1` |
| GP4 | 6 | `S2` |
| GP5 | 7 | `S3` |
| GP6 | 9 | Button `B0`; other button terminal to ground |
| GP26 / ADC0 | 31 | Mux `SIG` / common output |
| AGND | 33 | Potentiometer ground terminal |
| 3V3 OUT | 36 | Mux `VCC` and potentiometer high terminal |
| GND | any ground pin | Mux `GND` and `EN` |

Connect the 10 kOhm linear potentiometer wiper to mux channel `C0`. Place a
100 nF ceramic bypass capacitor close to the mux between `VCC` and `GND`.
Leave mux channels `C1..C15` unconnected for this stage.

## Build and monitor

From the repository root:

```sh
pio run -d firmware
pio device monitor -d firmware
```

Expected output resembles:

```text
frzone-surface stage=1 controls=A0,B0 adc_bits=12
event t_ms=21 id=A0 type=value value=32631 normalized=0.4979
event t_ms=1840 id=B0 type=pressed value=65535 normalized=1.0000
event t_ms=2012 id=B0 type=released value=0 normalized=0.0000
```

## Bench acceptance checklist

- `A0` approaches `0.0000` and `1.0000` at the two ends of its travel.
- A slow sweep is monotonic and does not exhibit large discontinuities.
- An untouched pot produces no continuing event stream after it settles.
- Each physical press produces one `pressed` and one `released` event.
- Firmware begins scanning when no serial monitor is attached.

Record any observed idle event chatter before changing the 10-count deadband or
the EWMA filter constant.
