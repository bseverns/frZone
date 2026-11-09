# Flexible zones: operating and verification guide

## Compatibility boundary

- **Rig-tuned mode:** always uses the original five canonical, summed bands and the committed semantic routing. Flexible mode cannot be enabled.
- **Generic mode:** starts in **legacy summed** analysis. Press **F** to enter **flexible mean** analysis.
- `mapping.json` remains notes/CCs only and is still saved/loaded with **S/O**. Flexible analysis uses the separate, versioned `zones.json` file (**Y/U**). Neither file overwrites the other.

## Controls

In flexible generic mode, select a zone with **1/2**. Drag its middle on the logarithmic spectrum to move it; drag an edge to resize it. **Z/X** moves its center by one semitone; **V/N** narrows/widens it by a musical ratio. **A/a** and **W/w** adjust that zone’s attack/release. The mouse wheel zooms the displayed frequency viewport only; it never changes measured bounds. **Q** toggles the legacy linear comparison view.

Five zones are present by default, but they are listeners rather than a partition: they may overlap or leave gaps. The view’s top limit is the active input’s actual Nyquist frequency, and source changes clamp zone limits to the newly valid range.

## Measurement and calibration

Legacy mode measures `sum = Σ m[i]` for all FFT bins in a zone. Flexible mode measures `mean = Σ m[i] / N`, where `N` is the number of inclusive bins. Flexible thresholds therefore have different units/scale from legacy thresholds; do not copy values between modes without calibrating.

Frequency edges are converted to integer bins. A zone owns `[lo, hi)` in frequency/bin-boundary terms, except the final Nyquist bin remains reachable. Narrow zones can share a bin; the UI reports requested Hz, not impossible sub-bin spectral resolution.

Any bounds edit clears smoothing, disarms the zone, and marks it `CAL?`. It cannot trigger again until the observed energy falls below its hysteresis release level, preventing an edit from creating an immediate repeated trigger. Use **K** to calibrate after a meaningful retune; calibration remains output-suppressed as before.

## Physical verification checklist

Run each test in both generic legacy and flexible modes, logging with **e/r** where useful. Do not infer these from automated tests.

1. Play a sustained tone inside, then outside, a narrow zone; record trigger/re-arm behavior.
2. Sweep a tone across two separated zones, then two overlapping zones; verify each listener acts independently.
3. Feed broadband noise and widen a zone; compare mean response before/after changing bin count.
4. Test a low tone at approximately one FFT-bin width; note leakage and resolution limits.
5. Move an active zone while MIDI/OSC are on; confirm it disarms rather than storms and requires release/re-arm.
6. Switch live/file input; confirm the display Nyquist changes and out-of-range bounds clamp visibly.
7. Save `zones.json`, restart the sketch, load it, and compare all five zone bounds, thresholds, smoothing parameters, notes, and CCs.
8. In rig-tuned mode, confirm CC 20/22/23/24 and semantic OSC outputs are unchanged, and that **F/Y/U** cannot alter that lane.

## Known limitations

The current Minim FFT/window settings are unchanged. Leakage, window shape, and resolution affect narrow-zone readings; there is no weighting, retuning, or sub-bin interpolation. Automated verification covers deterministic zone math and rig profile data, and Processing 4.5.7 compiles the sketch on this Apple Silicon host. GUI/audio/MIDI tests remain physical verification work because a compile does not exercise live devices or sound.
