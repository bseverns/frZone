# frZone physical control surface firmware

This directory contains the incremental Raspberry Pi Pico WH control-surface
prototype. Stage 2:

- scans potentiometers `A0..A7` through channels `C0..C7` of a CD74HC4067;
- reads primary buttons `B0..B3` and `SHIFT` from direct GPIO pins; and
- emits normalized `0..65535` control events over USB serial.

USB MIDI, Wi-Fi OSC, LEDs, mappings, and frZone integration remain later
stages.

## Stage 2 wiring

Use only 3.3 V for the potentiometer and multiplexer signal path.

| Pico WH connection | Physical pin | CD74HC4067 / control connection |
| --- | ---: | --- |
| GP2 | 4 | Mux `S0` |
| GP3 | 5 | Mux `S1` |
| GP4 | 6 | Mux `S2` |
| GP5 | 7 | Mux `S3` |
| GP6 | 9 | Button `B0`; other terminal to ground |
| GP7 | 10 | Button `B1`; other terminal to ground |
| GP8 | 11 | Button `B2`; other terminal to ground |
| GP9 | 12 | Button `B3`; other terminal to ground |
| GP10 | 14 | `SHIFT`; other terminal to ground |
| GP26 / ADC0 | 31 | Mux `SIG` / common output |
| AGND | 33 | All potentiometer ground terminals |
| 3V3 OUT | 36 | Mux `VCC` and all potentiometer high terminals |
| GND | any ground pin | Mux `GND`, mux `EN`, and button ground bus |

Use eight 10 kOhm linear potentiometers. Connect each wiper to the matching mux
channel: `A0` to `C0`, `A1` to `C1`, through `A7` to `C7`. Place a 100 nF
ceramic bypass capacitor close to the mux between `VCC` and `GND`. Leave
channels `C8..C15` unconnected.

The firmware enables the Pico's internal pull-ups for all buttons, so no
external button resistors are required for this breadboard stage.

## Scanner behavior

The scanner visits one mux channel every 1 ms, giving each potentiometer a
nominal 125 Hz update rate. Each visit discards the first ADC conversion,
averages four conversions, applies a per-control EWMA, and reports movement at
or above a 10-count ADC deadband. The first real reading seeds each filter.

All five buttons are sampled on each loop pass. A transition is emitted only
after the raw input remains unchanged for 20 ms.

## Build and monitor

From the repository root:

```sh
pio run -d firmware
pio device monitor -d firmware
```

Expected output resembles:

```text
frzone-surface stage=2 controls=A0-A7,B0-B3,SHIFT adc_bits=12
event t_ms=21 id=A0 type=value value=32631 normalized=0.4979
event t_ms=29 id=A7 type=value value=65535 normalized=1.0000
event t_ms=1840 id=B2 type=pressed value=65535 normalized=1.0000
event t_ms=2012 id=B2 type=released value=0 normalized=0.0000
```

## Bench acceptance checklist

- Startup produces one initial value for each of `A0..A7`.
- Every pot approaches `0.0000` and `1.0000` at the ends of its travel.
- A slow sweep of each pot is monotonic and does not move another channel.
- Untouched pots produce no continuing event stream after settling.
- Every button produces exactly one `pressed` and one `released` event.
- Holding two buttons produces independent events for both controls.
- Firmware begins scanning when no serial monitor is attached.

Record which channel exhibits any idle chatter or cross-talk before changing
the shared deadband, filter constant, or mux settling delay.
