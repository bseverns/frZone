# Adaptive frequency zones: design and compatibility boundary

**Baseline:** `e491fd873d63cb92cb896c6d46778ed23222bc5d` (`main`, captured 2026-11-06).  `python3 tools/validate_rig_alignment.py` passed before this work. The installed legacy `processing-java` cannot start on this host because its Java executable reports `Bad CPU type in executable`; this is an environment limitation, not a sketch result.

## Observed baseline coupling

`BAND_BOUNDS` defines five contiguous zones in `FreqZone.pde`. `setup()` constructs one `BandTrigger` per adjacent pair. In `draw()`, each pair is independently converted with `FFT.freqToIndex()` and all inclusive bins are **summed**. That sum drives threshold comparison, hysteresis re-arm, calibration samples, smoothing, display bars, `/bandEnergy`, `/bandTrigger`, and generic MIDI CC/note output. `drawSpectrum()` also colors each FFT bin by its enclosing contiguous band. Thus wider legacy bands mechanically accumulate more magnitude and need differently scaled thresholds.

`switchSource()` correctly rebuilds the FFT for the active source, but the existing limits are still fixed configuration values. `mapping.json` stores only generic note/CC transport bindings. Rig mode loads `interop/frzone.rig.json`; its canonical semantic outputs select fixed raw band indexes 0, 2, 3, and 4, leaving raw band 1 local-only.

## Smallest safe design

Keep the legacy path intact and introduce flexible zones only in **generic** mode. Rig-tuned mode always remains legacy/canonical, so configurable zone IDs cannot acquire `analysis.*` meaning by accident.

A small dependency-free `ZoneMath` class owns the deterministic parts:

- validation/clamping against the current FFT Nyquist limit;
- half-open bin ownership `[lo, hi)`, except that the final available bin remains reachable;
- legacy `sum` and flexible normalized `mean` measurements;
- finite ordered center/width edits that reset detector runtime state.

The sketch owns Processing/Minim integration, detector state, OSC/MIDI routing, UI, and JSON persistence. No second FFT is calculated. Flexible zones retain five defaults, arbitrary overlap, and gaps. New `zones.json` is versioned and separate from legacy `mapping.json`; saving it never rewrites transport bindings.

## Measurement and migration

For FFT-bin magnitudes `m[i]` over an integer span `[iLo, iHi]`, legacy energy is

`sum = Σ m[i]`.

Flexible energy is

`mean = (Σ m[i]) / N`, where `N = iHi - iLo + 1`.

The mean has the same magnitude unit as an FFT bin and is not mechanically amplified merely by adding bins. Boundaries are quantized to FFT bins; requested Hz values remain visible but do not imply sub-bin precision. Thresholds are mode-specific: legacy thresholds are never reused in flexible mode. Editing flexible bounds invalidates calibration feedback, clears smoothing, sets the detector unarmed, and gives it one release observation before it may re-arm; this prevents an edit from creating a trigger storm.

Windowing, spectral leakage, and FFT resolution remain properties of Minim’s FFT/window configuration. Narrow zones near DC or below a bin width may share a bin or become one-bin zones. This change documents that limitation rather than adding weighting or retuning DSP.

## Performance and compatibility risks

The main added per-frame work is a bounded scan of each zone’s already-computed FFT bins; no per-frame zone allocation or additional FFT occurs. Flexible zone count remains five by default. The explicit mode boundary preserves legacy OSC argument order/types, generic mapping semantics, canonical rig CCs/OSC aliases, and source-band indexes.

## Testable gates

A standalone Java test exercises boundary conversion, overlap/gap independence, normalized measurement, invalid input clamping, and edit-state reset without Processing libraries. Repository validation continues to prove the committed rig profile. Runtime audio/MIDI behavior, source switching in Minim, rendering, and physical control are listed in the physical verification checklist because this host cannot run the installed Processing Java runtime.
