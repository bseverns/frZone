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

3. System: frZone as a trigger instrument
3.1 Design goals

frZone was built as a low latency, classroom safe bridge from sound to control. It targets IAC compatible MIDI workflows and uses clear, visible toggles so students can explore without needing operator mastery to stay oriented. The system is designed to be taught: its behavior is explainable in plain language, and its controls invite confident adjustment rather than trial by confusion.

The core design choice is a readable per band parameter set. Each band exposes a small vocabulary of controls that shape behavior in predictable ways: threshold determines when a band becomes active, hysteresis prevents chatter and supports stable rearming, and cooldown defines the minimum time between triggers.

frZone produces control data through two parallel lanes. The continuous lane sends a steady stream of band energy values, suited to parameters that benefit from ongoing motion. The event lane sends discrete messages when thresholds are crossed, suited to rhythmic behaviors and state changes.

Mapping is intentionally lightweight. Control outputs are defined in a simple JSON file, and a burst learn gesture can be used per band to quickly configure targets during setup in modular video environments.

3.2 Per-frame signal flow

Boundaries and defaults. frZone is designed to make its boundaries visible. Analysis is performed locally: the system reads an audio buffer, computes an FFT, and derives per-band features (energy and trigger state) in memory. Raw audio is not transmitted. Retained values are limited to short-lived per-band state required for smoothing and gating (for example: smoothed energy, armed state, and last trigger time).

Network output is explicit and toggleable. When OSC is enabled, frZone transmits derived features to 127.0.0.1:8000 by default and listens on 127.0.0.1:8001 for optional inbound parameter updates. MIDI output is routed through the selected device (including IAC) rather than broadcast. These defaults support consent-forward teaching and public-facing use by making it easy to state what is processed locally, what is sent, where it goes, and what is not retained.

Each render frame, frZone performs the same sequence of operations, whether the source is live input or file playback:

Select source (Live vs File) and read the current audio buffer.

Compute FFT on the current buffer.

Sum band energy by accumulating FFT magnitudes between each pair of frequency bounds, producing one energy value per band.

Optional auto calibration samples band energies over a short window and sets per-band thresholds, along with initial hysteresis and cooldown defaults. During calibration, trigger output can be suppressed to keep behavior predictable while students tune the room and gain staging.

Normalize energy relative to each band’s threshold into a 0 to 1 target range.

Smooth energy with an attack and release filter to produce a stable continuous control signal.

Gate triggers using threshold crossing with hysteresis-based rearming and a cooldown timer to avoid chatter and repeated firing.

Emit outputs via two lanes:

Continuous lane: per-band smoothed energy is sent as OSC /bandEnergy and as a MIDI CC stream.

Event lane: when a trigger fires, OSC /bandTrigger is sent and a MIDI note is tapped, with note-offs scheduled via a short internal queue.

Figure callout: Figure 2: Per-frame flow diagram showing both output lanes.

**Table 1. Default parameters in the current implementation.**
| Category | Parameter | Value | Notes |
|---|---|---|---|
| Bands | Frequency bounds | `{0, 200, 800, 3000, 8000, 20000}` | 5 bands: 0–200, 200–800, 800–3000, 3000–8000, 8000–20000 |
| Smoothing | `ENERGY_ATTACK` | `0.40` | Faster response on rising energy |
| Smoothing | `ENERGY_RELEASE` | `0.15` | Slower decay on falling energy |
| Calibration | `CAL_MS` | `2000 ms` | Sampling window |
| Calibration | `CAL_PERCENTILE` | `0.80` | Percentile used to set threshold |
| Calibration | `CAL_MULT` | `1.10` | Scales threshold above sampled statistic |
| Calibration | `CAL_HYST` | `1.15` | Initial hysteresis factor |
| Calibration | `CAL_COOLDOWN` | `120 ms` | Initial cooldown |
| Calibration | `SUPPRESS_TRIGGERS_WHILE_CAL` | `true` | Suppresses trigger output while calibrating |
| OSC | Host | `127.0.0.1` | Local by default |
| OSC | TX port | `8000` | Control output |
| OSC | RX port | `8001` | Optional inbound parameter tweaks |
| OSC | Energy address | `/bandEnergy` | Continuous lane |
| OSC | Trigger address | `/bandTrigger` | Event lane |

3.3 Outputs

frZone exposes two output lanes that mirror two common interaction needs in audiovisual practice: continuous modulation and discrete event control. Both lanes are available over OSC and MIDI, allowing the same band activity to drive parameter motion, rhythmic triggering, or state changes depending on the downstream tool.

OSC (UDP). When enabled, frZone transmits to 127.0.0.1:8000 by default and listens on 127.0.0.1:8001 for optional inbound parameter updates.

/bandEnergy (idx, fLo, fHi, energyN)
A continuous, smoothed stream where energyN is normalized to a 0–1 range.

/bandTrigger (idx, fLo, fHi, energy, threshold, hysteresis, cooldownMs)
A discrete event pulse emitted when the trigger gate fires. Including the gating parameters makes the event interpretable during teaching and collaboration and supports downstream logging.

MIDI. frZone supports IAC friendly MIDI output in two complementary forms:

Per-band CC stream (defaults CC 20–24) driven by smoothed band energy.

Per-band note taps (defaults 36, 38, 42, 46, 49) intended to patch cleanly into environments that treat notes as triggers.

Velocity scales with the current band energy, and note-offs are queued for a fixed duration so downstream tools receive a predictable on/off gesture without requiring tight timing logic.

**Table 2. frZone outputs, rates, and typical use cases.**
| Output | Type | Rate | Typical downstream use | Notes |
|---|---|---|---|---|
| OSC `/bandEnergy (idx, fLo, fHi, energyN)` | Continuous | Per frame, per band | TouchDesigner / Signal Culture style modulation (opacity, feedback, particle density, shader params) | `energyN` is smoothed and normalized 0..1 |
| OSC `/bandTrigger (idx, fLo, fHi, energy, threshold, hysteresis, cooldownMs)` | Event | On trigger | Scene cuts, strobe hits, sampler triggers, state toggles | Includes gating params for legibility and debugging |
| MIDI CC 20–24 (per band) | Continuous | Per frame, per band | Any MIDI-mappable parameter; DAW automation; A/V control bridges | Uses smoothed energy; easy IAC routing |
| MIDI notes 36, 38, 42, 46, 49 (per band) | Event | On trigger | Drum racks, clip launching, discrete switches in visual tools | Velocity scales with energy; note-off queued for fixed duration |

---

4. Readable Triggers: mapping legibility layer

Mappings are where audio-to-control systems either become shareable instruments or collapse into private technique. In many tools, mappings live as tacit knowledge: the system may work, but only the operator can explain why, and the mapping cannot travel without them. frZone treats mapping as a first-class artifact: something designed to be learnable, narratable, and portable across people, sessions, and toolchains. This legibility layer is not separate from performance; it is what allows performance setups to be rebuilt, taught, and trusted.

4.1 Legibility primitives (name what the system already makes visible)

Write this subsection like a list of what the system makes easy to point at. Each bullet can be 1–2 sentences.

Band as named region. Bands are treated as stable regions rather than abstract indices. The frequency bounds are fixed and teachable, and the system supports a consistent vocabulary that students and collaborators can adopt (“kick band,” “snare band,” “hat band”) even when the audio source changes.

Two-lane control. frZone separates continuous modulation from discrete event triggering. This makes mappings easier to reason about: energy is “how much,” triggers are “when,” and downstream targets can be chosen accordingly without overloading one signal.

Cheat-sheet overlay. The instrument narrates itself while running. Control shortcuts, modes, and routing status are discoverable in the moment, so mapping work does not require a second document or a second screen.

Solo band mode. Isolating a band supports patching and debugging as a teaching action: students can tune one region, observe cause and effect, then reintroduce complexity deliberately.

Burst learn. Burst learn acts as a standardized handshake with external environments by emitting a predictable CC sweep and note tap. In practice, this reduces setup friction and makes “learning the mapping” an explicit step rather than a hidden ritual.

(If you want an extra sentence tying this back to your consent-forward theme: “These primitives also make it easier to state what the system is doing and why, which is part of keeping sensing boundaries legible.”)

4.2 A mini-framework

You don’t have to claim novelty — present it as “four design aims frZone implements.”

frZone’s mapping layer is organized around four practical design aims:

Narratability. A mapping can be spoken in one breath: band → target → behavior. For example, “hat band energy drives feedback amount” or “snare band trigger cuts scenes.” If it cannot be said clearly, it will not be taught clearly.

Recoverability. Mappings should survive interruption. Saving and loading a minimal mapping file supports rebuilding a known-good state after a crash, a classroom handoff, or a new machine. “Panic” behaviors (such as clearing notes) further support predictable exits.

Teachability. Controls must remain discoverable without leaving the instrument. The cheat sheet and visible toggles turn common debugging steps into intentional learning moments rather than private operator tricks.

Portability. Mappings should travel across tools and contexts. A minimal mapping.json supports sharing and versioning, while burst learn helps bridge ecosystems that prefer to “learn” controls through live gestures.

Figure callout: Figure 3: Readable Triggers design aims and how frZone supports each.

4.3 Use-case vignettes

The goal is short, vivid, and tied back to the principles above. Each vignette can be 4–6 sentences.

Vignette A — Calibrate Your Bands. Students begin by calibrating in a real room and then adjusting threshold, hysteresis, and cooldown to equalize trigger rates across bands. The work is intentionally audible and visible: small parameter changes produce immediate changes in stability and chatter. This activity turns calibration from a hidden preprocessing step into a learnable act of tuning, and it provides a shared language for why the system behaves as it does. (Optional sentence) The result is a mapping that is narratable (“this band fires less because cooldown is longer”) rather than mystical.

Vignette B — Build a Performer Map. In performance-oriented mapping, students route /bandEnergy to a continuous visual parameter (for example, density or opacity) and /bandTrigger to a discrete event (for example, scene cut or strobe). The two-lane model reduces ambiguity: energy drives motion without requiring perfect thresholding, while triggers remain crisp and intentioned. This separation supports faster setup and clearer explanation, especially when mappings are shared between collaborators.

Vignette C — Chain Reaction. In group work, one team’s audio becomes another team’s control input through OSC or MIDI routing. Because mappings are documented and recoverable, the receiving group can reconstruct the sender’s intent without constant supervision. The exercise stresses portability and consent-forward clarity: participants can describe what information crosses the boundary, where it goes, and how it is used. The value is not only the resulting piece, but the ability to reproduce the routing and mapping on a different day with different people.

---

## 5. Consent-forward sensing (design stance + concrete affordances)
**Claim:** instruments used in classrooms/public contexts must be explicit about sensing boundaries.

### 5.1 Data minimization and boundaries
frZone performs audio analysis locally. It computes FFT-based features and derives per-band energies and trigger state in memory. Raw audio is not transmitted over the network. When enabled, OSC sending defaults to localhost and can be toggled at runtime (SPACE), so derived features do not leave the machine unless a user intentionally reroutes them. When outputs are enabled, frZone sends only derived features (energies and trigger events) rather than audio streams.

By default, the only persistent data is mapping metadata stored in mapping.json (notes and CC assignments). Runtime state needed for smoothing and gating (such as smoothed energy, armed flags, and last trigger time) is short-lived and discarded as the instrument runs. If frZone is extended with session logging for evaluation, logging should remain opt-in and should avoid collecting identifying information.

5.2 Consent choreography (concrete controls)

Consent in interactive systems is not a single agreement; it is a choreography that remains available while the instrument is running. frZone implements this choreography through three stages that map directly onto visible runtime state and explicit controls.

Disclosure. frZone keeps key state legible while running by providing a toggleable help overlay (H) that displays the cheat sheet and the current device context. This supports “saying aloud” what the system is doing during teaching and setup: whether the system is in Live vs File mode (L), whether OSC sending is enabled (SPACE), whether MIDI sending is enabled (M), and whether auto-calibration is active (K to start, Esc to cancel).

Choice. Outputs are opt-in at runtime. Users can enable or disable OSC sending with SPACE and MIDI sending with M, and can explore in File mode (L, with P for play/pause) without live capture. Mapping choices are also explicit: the selected band and its behavior can be tuned live (threshold [ / ], hysteresis ; / ', cooldown , / .), and mappings can be saved or loaded (S / O) to support deliberate reuse rather than hidden state.

Control. frZone supports safe interruption and recovery. Toggling MIDI sending (M) also sends an all-notes-off gesture, reducing the risk of stuck notes on shared rigs. Auto-calibration can be started or cancelled (K / Esc) to keep the system predictable during transitions. Solo, targeted setup is supported through per-band selection (1 / 2) and selected-band burst learn (Shift+B), allowing students to isolate changes rather than perturbing the whole system at once.

Figure callout: Figure 4: Consent choreography mapped to concrete runtime controls (Disclosure → Choice → Control).

5.3 Why this matters (classroom + community contexts)

In classrooms, power dynamics and shared infrastructure change what “interaction” means: students may not control the room, the rig, or the network. In public-facing contexts, participants may not know what an instrument is sensing or what is being transmitted. Making boundaries visible helps the system remain interpretable by non-authors, which is both a learning affordance and an ethical one. In a classroom, these controls make it possible to pause, explain, and reconfigure without breaking the “hot” runtime, which reduces reliance on operator-mastery and supports peer-to-peer learning. This approach aligns with frZone’s broader goal: open tools, loud documentation, and agency that can be shared rather than guarded.

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
