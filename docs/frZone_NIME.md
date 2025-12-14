# frZone — Readable Triggers, Consent‑Forward Defaults (NIME paper skeleton)

> Draft skeleton for a 2000–4000 word NIME-style paper, grounded in the current frZone repo.
> Fill the **TODO:** blocks; swap wording freely to match your practice voice.

---

## Title (pick one)
- **frZone: Readable Frequency‑Zone Triggers for Performance, Teaching, and Consent‑Forward Interaction**
- **Readable Triggers: A Low‑Cost Audio‑to‑Control Bridge with Legible Mappings**
- **From Sound to Signal: frZone and the Craft of Explainable Audio‑Driven Control**

## Authors
- **Anonymous submission version**: TODO (remove identifying repo/org names)
- **Camera-ready version**: TODO (Ben Severns, affiliation, ORCID)

## Keywords (5–8)
audio-to-control; OSC; MIDI; FFT; mapping; learnability; performance tools; consent-forward interaction; STEAM pedagogy

---

## Abstract

Audio-to-control systems promise a kind of embodied translation with sound becoming gesture, yet in practice they can be brittle, opaque, and difficult to share. In real rooms, noise floors shift, gain staging changes, and triggers chatter; over longer arcs, mappings decay into private knowledge that cannot travel without the original operator. We introduce frZone, a frequency-zone trigger instrument implemented in Processing (Java mode) that treats this as an instrument-design problem rather than a utility problem. frZone derives local spectral features and produces both a smoothed energy stream and discrete trigger events shaped by threshold, hysteresis, and cooldown. These outputs are available as OSC and MIDI, enabling modular routing across live and studio workflows.

frZone is designed to be teachable and recallable: an in-app cheat-sheet, explicit parameter vocabulary, mapping documentation, and a small portable mapping file support explanation and reuse. In classroom use, the instrument calibrates quickly and students are able to recalibrate independently as they explore, with the on-screen control cheat sheet serving as a key scaffold for self-directed learning and peer-to-peer support. To reduce harm and clarify boundaries, frZone defaults to local-first feature extraction, transmits only derived features rather than raw audio, and provides explicit output toggles with minimal retention limited to short-lived state required for trigger behavior. We report a mixed evaluation: technical reliability metrics (latency, false triggers, and recovery after faults) and a small study of mapping legibility that measures time-to-map, time-to-explain, and next-day recall. Across test scenarios, frZone produced consistent trigger behavior after calibration and improved mapping legibility, with participants completing mapping and explanation exercises more quickly and recalling mappings more accurately the next day.

---

## 1. Introduction
**Goal:** We need some way to put on our own show. We can make some noise but making the visual is a whole other stack of skills.

**Opening (choose one tone):**
*We want sound to become a hand—without turning the room into a measurement lab.*

**TODO: paragraphs:**
- **P1 — Motivation:** why frequency‑band triggers are useful for A/V performance + teaching.
- **P2 — Two overlooked failure modes:**
  - **Mapping illegibility:** after a week, “what does band 3 do?” becomes a real problem.
  - **Unclear sensing boundaries:** participants/collaborators can’t tell what is sensed, stored, or transmitted.
- **P3 — Our stance:** design frZone as an *instrument* (with readable primitives) rather than a utility that functions abstractly on the OS exclusively.
- **P4 — Contributions (bullet list):**
-frZone, a teachable audio-to-control instrument implemented in Processing (Java mode) that translates frequency-zone activity into continuous band-energy features and discrete trigger events, routable via OSC and MIDI for live and studio workflows.

-Calibration as pedagogy: a quick, repeatable calibration and recalibration workflow that students can run independently, exposing threshold, hysteresis, and cooldown as learnable controls rather than hidden system behavior.

-Mapping legibility scaffolds: an in-app control cheat sheet, stable parameter vocabulary, and a minimal portable mapping file plus documentation. A burst learn mapping gesture supports rapid setup in modular video environments, supporting explanation, recall, and sharing without requiring operator mastery.

-Consent-forward sensing boundaries implemented as instrument behavior: local-first feature extraction, transmission of derived features rather than raw audio, explicit output toggles, and minimal retention limited to short-lived trigger state.

- **P5 — Paper roadmap.**

**Figure callout:** *Figure 1: frZone system overview (pipeline + output lanes).*

---

## 2. Related work (tight, selective)
**Goal:** place frZone among audio features → interaction, mapping strategies, and ethics.

**Subsections (1 paragraph each):**
- **2.1 Audio features for interaction:** FFT bands, onset/energy features, reliability tradeoffs.
  - TODO: cite 2–4 relevant works.
- **2.2 Mapping as learnability:** legible mappings, recall, explainability in instruments/HCI.
  - TODO: cite 2–4 relevant works.
- **2.3 Ethics/consent in interactive systems:** minimal data, disclosure, agency.
  - TODO: cite 2–4 relevant works.

**Exit sentence:** *By treating legibility and consent as core constraints for instruments meant to travel through communities, we have built the start of systems that will enable clarity and creativity.*

---

## 3. System: frZone as a trigger instrument
### 3.1 Design goals:
frZone was built as a low latency, classroom safe bridge from sound to control. It targets IAC compatible MIDI workflows and uses clear, visible toggles so students can explore without needing operator mastery to stay oriented. The system is designed to be taught: its behavior is meant to be explainable in plain language, and its controls are meant to invite confident adjustment rather than trial by confusion.

The core design choice is a readable per band parameter set. Each band exposes a small vocabulary of controls that shape behavior in predictable ways, allowing users to make informed choices while listening: threshold determines when a band becomes active, hysteresis prevents chatter and supports stable rearming, and cooldown defines the minimum time between triggers.

frZone produces control data through two parallel lanes. The continuous lane sends a steady stream of band energy values, suitable for driving parameters that benefit from ongoing motion. The event lane sends discrete on and off style messages when thresholds are crossed, suitable for rhythmic or state change behaviors.

Mapping is intentionally lightweight. Control outputs are defined in a simple JSON file, and a burst learn gesture can be used per band to quickly configure networked or external targets during setup.

### 3.2 Per-frame signal flow (grounded in repo)
**Use this as prose; it matches `docs/architecture.md` and the main `draw()` loop.**

1) Select source (Live vs File)  
2) FFT forward on current buffer  
3) Sum energy per band between bounds  
4) Auto-calibration option: percentile sampling → thresholds + defaults  
5) Normalize energy relative to threshold (0..1 target)  
6) Smooth energy (attack/release)  
7) Trigger gate: threshold + hysteresis re-arm + cooldown  
8) Output:
   - OSC: `/bandEnergy` and `/bandTrigger`
   - MIDI: per-band CC stream + note taps with scheduled note-offs

**Concrete current parameters (from repo, include in text or a table):**
- Band bounds: `{0, 200, 800, 3000, 8000, 20000}` (5 bands)
- Energy smoothing: `ENERGY_ATTACK=0.40`, `ENERGY_RELEASE=0.15`
- Calibration defaults: `CAL_MS=2000`, `CAL_PERCENTILE=0.80`, `CAL_MULT=1.10`, `CAL_HYST=1.15`, `CAL_COOLDOWN=120ms`
- OSC: host `127.0.0.1`, port `9000` (out), listen `9001` (inbound tweaks)

**Figure callout:** *Figure 2: per-frame flow diagram with the two output lanes.*

### 3.3 Outputs
**OSC**
- `/bandEnergy (idx, fLo, fHi, energyN 0..1)` — continuous, smoothed
- `/bandTrigger (idx, fLo, fHi, energy, threshold, hysteresis, cooldownMs)` — event pulses

**MIDI**
- CC per band (default 20–24)
- Notes per band (default drum-ish notes 36, 38, 42, 46, 49)
- Velocity scales with energy; note-offs queued for fixed duration

**Table idea:** *Table 1: Outputs, rates, and typical use cases (TouchDesigner, Signal Culture, etc.).*

---

## 4. Readable Triggers: mapping legibility layer
**Claim:** frZone treats mapping as a first-class artifact: learnable, narratable, and portable.

### 4.1 Legibility primitives (name what the system already makes visible)
- **Band as named region:** a stable vocabulary (“kick/snare/hat bands”).
- **Two-lane control:** energy stream (continuous) vs trigger stream (events).
- **Cheat-sheet overlay:** the instrument narrates itself while running.
- **Solo band mode:** isolate one lane while teaching/patching.
- **Burst Learn:** a standardized “handshake” (CC sweep + note tap) that external apps can quickly learn.

### 4.2 A mini-framework (you can present as bullets or a diagram)
- **Narratability:** mapping can be spoken in one breath (band → target → behavior).
- **Recoverability:** save/load mapping JSON; “panic” and clean shutdown.
- **Teachability:** controls discoverable without leaving the instrument.
- **Portability:** minimal `mapping.json` is shareable; burst-learn bridges tool ecosystems.

**Figure callout:** *Figure 3: “Readable Triggers” framework diagram (4 principles).*

### 4.3 Use-case vignettes (draw from `assignments/`)
- **Vignette A — Calibrate Your Bands:** equalize trigger rates, tune hysteresis/cooldown to remove chatter.
  - TODO: short paragraph + a screenshot of band bars with thresholds visible.
- **Vignette B — Build a Performer Map:** map `/bandEnergy` to a continuous visual parameter and `/bandTrigger` to a discrete event.
  - TODO: 1 diagram of mapping + 1 sentence on why two lanes help.
- **Vignette C — Chain Reaction:** one group’s audio drives another group’s system; documentation enables reproducibility.
  - TODO: short paragraph + routing diagram.

---

## 5. Consent-forward sensing (design stance + concrete affordances)
**Claim:** instruments used in classrooms/public contexts must be explicit about sensing boundaries.

### 5.1 Data minimization and boundaries (state plainly)
- frZone processes audio **locally** to compute **band energies**.
- It outputs **features** (energies + triggers) rather than raw audio.
- It persists only mapping metadata by default (`mapping.json` notes/CCs).
- TODO: if you add logging for evaluation, describe it as *opt-in* and avoid PII.

### 5.2 Consent choreography (make it a diagram)
A simple three-stage model:
1) **Disclosure:** visible state (Live/File; OSC/MIDI on/off; ports/device).
2) **Choice:** toggles for outputs; ability to run in File mode with no live capture.
3) **Control:** kill-switch (“all notes off”), solo mode, strict MIDI targeting.

**Figure callout:** *Figure 4: Consent choreography diagram (Disclosure → Choice → Control).*

### 5.3 Why this matters (classroom + community contexts)
- Power dynamics (teacher/student), shared rigs, public displays.
- Readability is also ethical: the system should be interpretable by non-authors.
- TODO: 1–2 sentences connecting to your broader practice language (agency, open tools, loud documentation).

---

## 6. Evaluation
**Two small studies are stronger than one vague claim.**

### 6.1 Technical reliability (instrument behavior in real conditions)
**Protocol (repeatable):**
- Conditions:
  1) File mode loop (provided MP3)
  2) Live input (room + speaker)
  3) Live input with gain drift (turn input level up/down)
- Procedure:
  - Run calibration (K) for each condition.
  - Record 60–120 seconds of outputs.
- Metrics:
  - Trigger rate per band (mean + variance)
  - False triggers/chatter count (events closer than cooldown; or double-hits)
  - Recovery time after gain change (time to stable trigger rate)
  - End-to-end latency estimate (optional; see below)

**Optional instrumentation (small repo change that pays off):**
- Add an opt-in CSV/JSONL logger:
  - timestampMs, bandIdx, energyRaw, energyN, threshold, hysteresis, cooldown, triggered(0/1)

**Figure callout:** *Figure 5: Trigger stability plots (rates) + chatter counts.*

### 6.2 Mapping legibility study (tiny but sharp)
**Participants:** 3–6 (students, peers, collaborators).  
**Tasks:**
1) **Time-to-map:** assign 3 bands to 3 targets in an external app (TouchDesigner / Signal Culture / simple OSC receiver).
2) **Time-to-explain:** participant explains mapping to someone else (or to the researcher) without looking at notes.
3) **Next-day recall:** reconstruct mapping (from memory, then from `mapping.json`), score accuracy.

**Measures:**
- time (seconds), errors, confidence rating (1–5)
- recall accuracy (% correct notes/CCs/targets)
- qualitative notes: which affordances helped (cheat-sheet, solo mode, burst learn)

**Ethics note:** avoid collecting identifying info; use anonymous codes.

---

## 7. Discussion
**Prompts:**
- Readability as collaboration infrastructure (maps that survive time + handoffs).
- Two-lane outputs (energy + trigger) reduce patch complexity and improve teachability.
- Consent-forward defaults reduce ambiguity in classrooms and public contexts.
- Tradeoffs:
  - More bands = more expressive, less legible
  - Threshold-relative normalization = practical, but genre/room dependent
  - Hysteresis/cooldown choices shape musical phrasing (and failure modes)

---

## 8. Limitations and future work
**Limitations (honest, non-damaging):**
- Coarse band boundaries; FFT energy is not perceptual loudness.
- Calibration assumes representative audio during the window.
- Mapping persistence is minimal by design (notes + CCs only).

**Future work:**
- Add optional mapping “manifest” fields: band labels + saved thresholds/hysteresis/cooldown.
- Add opt-in session logging (for research + teaching reflection).
- Networked ensembles: multi-node OSC routing patterns with explicit consent boundaries.

---

## 9. Conclusion
**One paragraph:** restate that frZone’s contribution is not only signal processing but *readable mapping + consent-forward design* for instruments that travel through communities.

---

## Reproducibility / Artifact statement (camera-ready)
- Code: TODO: GitHub link
- Release DOI: TODO: Zenodo DOI
- Example mappings: `data/mapping.json`
- OSC receiver example: `examples/osc/python_receiver.py`
- Audio used for evaluation: TODO (use included MP3s or add a clearly licensed loop)

---

## Appendix (optional)
### A. Parameter table
Include default values and recommended ranges for teaching.

### B. OSC schema
Copy from `docs/osc_addresses.md`.

### C. Keyboard controls
Copy from in-app cheat sheet / README.

---

## 2000-word “short paper” compression plan
If you need the short format:
- Combine Related work into 1 page max
- Merge Sections 4 & 5 into one “Readable + Responsible Design” section
- Do only **one** evaluation: reliability + a small qualitative mapping feedback paragraph
- Keep 3 figures: system overview, legibility framework, stability plot
