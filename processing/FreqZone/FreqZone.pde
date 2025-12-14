/**
 * Freq-Zone Trigger Instrument (Live/File) + OSC + MIDI
 * Classroom build: frequency-band triggers with IAC-friendly MIDI, CC streams,
 * non-blocking auto-calibration, and an in-app cheat sheet overlay.
 *
 * Controls (teach from here; keep the runtime hot while reading aloud):
 *   1 / 2          : select previous / next band
 *   [ / ]          : decrease / increase threshold of selected band
 *   ; / '          : decrease / increase hysteresis of selected band
 *   , / .          : decrease / increase cooldown (ms) of selected band
 *   - / =          : selected band note down / up
 *   c / C          : selected band CC down / up
 *   t / T          : transpose all notes -1 / +1
 *   S / O          : Save / Load mapping (to data/mapping.json)
 *   B              : burst learn (all bands); Shift+B = selected band only
 *   d / D          : list / cycle MIDI outputs in console
 *   L              : toggle Live vs File playback
 *   P              : play/pause file (when in file mode)
 *   SPACE          : toggle OSC sending
 *   M              : toggle MIDI sending (also sends all-notes-off)
 *   H              : toggle help overlay (cheat sheet + device name)
 *   K / Esc        : start / cancel auto-calibration
 */

import ddf.minim.*;
import ddf.minim.analysis.*;
import oscP5.*;
import netP5.*;
import javax.sound.midi.*;
import java.util.*;
import processing.data.*;
import java.io.*;

// ======================= CONFIG =========================

// --- Source config
// These values double as a micro-lesson plan: start students here so they can flip
// between live input and a looping file without chasing phantom settings.
// When tweaking for class demos, narrate what each line does *as written*—that
// accuracy keeps the comments trustworthy.
boolean USE_LIVE   = true;                // default input (toggle 'L')
String  AUDIO_FILE = "ReadySet.mp3";     // put in data/ folder
int     AUDIO_BUF  = 2048;
float   AUDIO_SR   = 44100;

// --- Frequency bands (Hz) - endpoints; N bands = bounds.length-1
// Treat this like a lab knob: have students sketch their target spectrum, then
// set these cut points and listen for what actually happens.
float[] BAND_BOUNDS = { 0, 200, 800, 3000, 8000, 20000 };

// --- Initial band configs (threshold, hysteresis, cooldown, MIDI note)
// These arrays are intentionally imperfect so folks can hear the difference after
// adjusting them. Keep them in sync with any handouts you share so students can
// confirm they're starting from the same baseline.
float[] INIT_THRESH     = { 9, 6, 4, 3, 2 };
float[] INIT_HYSTERESIS = { 1.5, 1.2, 1.1, 1.1, 1.0 };
int[]   INIT_COOLDOWNMS = { 120, 120, 120, 140, 160 };
int[]   MIDI_NOTES      = { 36, 38, 42, 46, 49 };

// --- OSC config
// Default loopback works out of the box in class. Encourage students to change
// the host only after they can explain (to a rubber duck or to you) why.
boolean OSC_ENABLED      = true;
boolean SEND_OSC_ENERGY  = true;
String  OSC_HOST         = "127.0.0.1";
int     OSC_PORT         = 9000;
int     OSC_LISTEN_PORT  = 9001;          // optional inbound tweaks
String  OSC_ENERGY_ADDR  = "/bandEnergy"; // idx, fLo, fHi, energyN (0..1)

// --- MIDI config
// Direct device targeting (macOS IAC Driver or other port). Leave this noisy so
// beginners see why notes are or are not flying.
boolean MIDI_ENABLED      = true;
int     MIDI_CHANNEL      = 0;            // [0..15]
int     MIDI_VELOCITY_MAX = 110;
int     MIDI_NOTE_LEN_MS  = 100;
String  MIDI_DEVICE_HINT  = "IAC";        // e.g., "IAC", "IAC Driver", "Bus 1"
boolean MIDI_STRICT       = true;         // true: disable MIDI if not found
boolean MIDI_SEND_NOTES   = true;         // gates for drums/learn taps
boolean MIDI_SEND_CCS     = true;         // continuous per-band CC stream
int[]   MIDI_CCS          = {20, 21, 22, 23, 24};
int     MIDI_CC_MIN       = 0;
int     MIDI_CC_MAX       = 127;

// --- Energy smoothing
// This is the lever that makes the visuals chill out. Have learners set attack
// and release to extremes and watch the strobe vs. glide, then creep them back
// toward the defaults.
float ENERGY_MAP_MAX_MULT = 4.0f;         // map threshold..threshold*mult -> 0..1
float ENERGY_ATTACK       = 0.40f;
float ENERGY_RELEASE      = 0.15f;

// --- Viz config
boolean SHOW_SPECTRUM = true;
boolean SHOW_HELP     = true;

// --- Output control
boolean SOLO_SELECTED_BAND = false;       // when true, only the selected band drives OSC/MIDI
float   VELOCITY_CURVE     = 1.0f;        // pow(eN, curve)

// --- Event logging (opt-in, CSV, one line per trigger)
// Keep the file lightweight so you can email logs around or hand them to
// students mid-lab without a second thought. Toggle with 'e', drop markers
// with 'r'.
boolean EVENT_LOG_ENABLED      = false;
String  EVENT_LOG_CONDITION    = "baseline"; // rename per run to tag which tweak set you tested
String  EVENT_LOG_DIR          = "logs";     // lives under data/
String  EVENT_LOG_FILE_PREFIX  = "triggerlog";

// --- Auto calibration
// Treat this like a studio timer: call it out, wait for the countdown, then talk
// about how thresholds move based on the percentile math below.
int   CAL_MS          = 2000;
float CAL_PERCENTILE  = 0.80f;
float CAL_MULT        = 1.10f;
float CAL_HYST        = 1.15f;
int   CAL_COOLDOWN    = 120;
boolean SUPPRESS_TRIGGERS_WHILE_CAL = true;

// ========================================================

Minim minim;
AudioInput liveIn;
AudioPlayer player;
FFT fft;

OscP5 osc;
NetAddress oscDest;

MidiOut midi;
ArrayList<PendingNoteOff> noteOffQueue = new ArrayList<PendingNoteOff>();

PrintWriter eventLogWriter;
String      eventLogPath = "";
int         eventMarkerCount = 0;

// per-band trigger state
// Think of BandTrigger as the worksheet for each frequency slice—every concept
// we demo (threshold, hysteresis, cooldown) lives here with the running history.
class BandTrigger {
  int idx;
  float fLo, fHi;
  float threshold;
  float hysteresis;
  int   cooldownMs;
  long  lastTrigMs;
  boolean armed;
  int   midiNote;
  float smooth;        // smoothed normalized energy 0..1

  BandTrigger(int idx, float fLo, float fHi, float thr, float hyst, int cdMs, int note) {
    this.idx = idx;
    this.fLo = fLo;
    this.fHi = fHi;
    this.threshold = thr;
    this.hysteresis = hyst;
    this.cooldownMs = cdMs;
    this.lastTrigMs = -999999;
    this.armed = true;
    this.midiNote = note;
    this.smooth = 0;
  }
}

BandTrigger[] bands;
int selectedBand = 0;

// Calibration state
boolean isCalibrating = false;
long    calStartMs = 0;
ArrayList<Float>[] calSamples;

void settings() {
  size(1450, 500);
}

void setup() {
  surface.setTitle("Freq-Zone Triggers - L("+USE_LIVE+")  OSC("+OSC_ENABLED+")  MIDI("+MIDI_ENABLED+")");
  minim = new Minim(this);

  if (USE_LIVE) {
    liveIn = minim.getLineIn(Minim.MONO, AUDIO_BUF, AUDIO_SR);
    fft = new FFT(liveIn.bufferSize(), liveIn.sampleRate());
  } else {
    player = minim.loadFile(AUDIO_FILE, AUDIO_BUF);
    if (player != null) player.loop();
    fft = new FFT(player.bufferSize(), player.sampleRate());
  }

  // Initialize band triggers as if they were lab worksheets—students can check
  // each band independently before layering on MIDI/OSC outputs.
  int nBands = BAND_BOUNDS.length - 1;
  bands = new BandTrigger[nBands];
  for (int i = 0; i < nBands; i++) {
    float flo = BAND_BOUNDS[i];
    float fhi = BAND_BOUNDS[i+1];
    float thr = INIT_THRESH[min(i, INIT_THRESH.length-1)];
    float hy  = INIT_HYSTERESIS[min(i, INIT_HYSTERESIS.length-1)];
    int   cd  = INIT_COOLDOWNMS[min(i, INIT_COOLDOWNMS.length-1)];
    int   note = MIDI_NOTES[min(i, MIDI_NOTES.length-1)];
    bands[i] = new BandTrigger(i, flo, fhi, thr, hy, cd, note);
  }

  osc = new OscP5(this, OSC_LISTEN_PORT);
  oscDest = new NetAddress(OSC_HOST, OSC_PORT);

  midi = new MidiOut(MIDI_DEVICE_HINT, MIDI_CHANNEL, MIDI_STRICT);
  MidiOut.listOutputs();

  loadMapping("mapping.json");

  textFont(createFont("Menlo", 12));
  frameRate(60);
}

void draw() {
  background(12);

  AudioSource src = USE_LIVE ? (AudioSource) liveIn : (AudioSource) player;
  if (src == null) return;
  fft.forward(src.mix);

  float maxBar = 0;
  float[] energies = new float[bands.length];

  boolean allowOutput = !(isCalibrating && SUPPRESS_TRIGGERS_WHILE_CAL);

  for (int b = 0; b < bands.length; b++) {
    BandTrigger bt = bands[b];

    int iLo = fft.freqToIndex(bt.fLo);
    int iHi = fft.freqToIndex(bt.fHi);
    if (iHi < iLo) { int tmp = iHi; iHi = iLo; iLo = tmp; }

    float sum = 0;
    for (int i = iLo; i <= iHi; i++) {
      sum += fft.getBand(i);
    }
    energies[b] = sum;
    if (sum > maxBar) maxBar = sum;

    // Continuous energy: normalize around threshold and apply asymmetric smooth.
    // This leans on the current threshold so students immediately hear/see why
    // moving thresholds matters beyond "it triggers more".
    float eNormTarget = constrain(map(sum, bt.threshold, bt.threshold * ENERGY_MAP_MAX_MULT, 0, 1), 0, 1);
    float smooth = bt.smooth;
    if (eNormTarget > smooth) {
      smooth = lerp(smooth, eNormTarget, ENERGY_ATTACK);
    } else {
      smooth = lerp(smooth, eNormTarget, ENERGY_RELEASE);
    }
    bt.smooth = smooth;

    boolean outputsActive = (!SOLO_SELECTED_BAND || b == selectedBand) && allowOutput;

    if (MIDI_ENABLED && MIDI_SEND_CCS && midi != null && outputsActive) {
      int ccIndex = min(b, MIDI_CCS.length - 1);
      int ccNum   = MIDI_CCS[ccIndex];
      int ccVal   = (int)round(lerp(MIDI_CC_MIN, MIDI_CC_MAX, bt.smooth));
      midi.cc(ccNum, ccVal);
    }

    if (OSC_ENABLED && SEND_OSC_ENERGY && outputsActive) {
      OscMessage em = new OscMessage(OSC_ENERGY_ADDR);
      em.add(bt.idx);
      em.add(bt.fLo);
      em.add(bt.fHi);
      em.add(bt.smooth);
      osc.send(em, oscDest);
    }

    long now = millis();

    // Re-arm when energy falls sufficiently below threshold / hysteresis.
    if (!bt.armed && sum < (bt.threshold / bt.hysteresis)) {
      bt.armed = true;
    }

    boolean cooled = (now - bt.lastTrigMs) >= bt.cooldownMs;
    if (bt.armed && cooled && sum >= bt.threshold && outputsActive) {
      // Fire! These eight lines are the heart of the lesson—walk through them
      // slowly and have learners narrate the state changes while you hold a note.
      bt.lastTrigMs = now;
      bt.armed = false;

      if (OSC_ENABLED) sendOscTrigger(bt, sum);

      if (MIDI_ENABLED && MIDI_SEND_NOTES && midi != null) {
        float velNorm = pow(bt.smooth, VELOCITY_CURVE);
        int vel = constrain(round(map(velNorm, 0, 1, 60, MIDI_VELOCITY_MAX)), 1, 127);
        midi.noteOn(bt.midiNote, vel);
        noteOffQueue.add(new PendingNoteOff(bt.midiNote, now + MIDI_NOTE_LEN_MS));
      }

      logTriggerEvent(bt, bt.smooth);
    }
  }

  if (isCalibrating) {
    updateCalibration(energies);
  }

  processNoteOffs();

  if (SHOW_SPECTRUM) drawSpectrum(fft);
  drawBandBars(energies, maxBar);

  drawOverlay();
}

// ---------- Visualization ----------

void drawSpectrum(FFT fft) {
  stroke(80);
  noFill();
  int w = width;
  int h = height/4;
  // Keep the zero-line comfortably above the band bars drawn in drawBandBars().
  int bandBaseY = height/2 - 35;
  int baselineY = max(30, bandBaseY - 60);
  float amplitude = h * 0.5f;

  int nBands = BAND_BOUNDS.length - 1;
  int[] bandHiIdx = new int[nBands];
  for (int b = 0; b < nBands; b++) {
    bandHiIdx[b] = fft.freqToIndex(BAND_BOUNDS[b+1]);
  }
  pushMatrix();
  translate(0, baselineY);
  beginShape();
  int currentBand = 0;
  for (int i = 0; i < fft.specSize(); i++) {
    while (currentBand < nBands - 1 && i > bandHiIdx[currentBand]) {
      currentBand++;
    }

    BandTrigger bt = bands[min(currentBand, bands.length - 1)];
    float smoothValue = bt.smooth;
    float gamma = sqrt(fft.getBand(i)); // gentle gamma softens spikes for projectors
    float dynamicAmplitude = amplitude * constrain(gamma, 0, 1);
    float y = lerp(dynamicAmplitude, -dynamicAmplitude, smoothValue);
    float x = map(i, 0, fft.specSize()-1, 0, w);
    vertex(x, y);
  }

  endShape();
  popMatrix();
}

void drawBandBars(float[] energies, float maxBar) {
  int h0 = height/2 + 8;
  int hAvail = height - h0 - 30;
  int n = bands.length;
  float gap = 6;
  float bw = (width - (n+1)*gap) / (float) n;

  for (int b = 0; b < n; b++) {
    BandTrigger bt = bands[b];
    float e = energies[b];
    float norm = (maxBar > 0) ? (e / maxBar) : 0;

    float x = gap + b*(bw+gap);
    float barH = norm * hAvail;

    // band bg
    noStroke();
    fill(30);
    rect(x, h0, bw, hAvail);

    // bar
    fill(b == selectedBand ? color(140, 220, 255) : color(90, 200, 120));
    rect(x, h0 + (hAvail - barH), bw, barH);

    // threshold line (as a proportion of current max for visibility)
    float threshN = (maxBar > 0) ? (bt.threshold / maxBar) : 0;
    stroke(240, 160, 60);
    line(x, h0 + (hAvail - threshN*hAvail), x + bw, h0 + (hAvail - threshN*hAvail));

    // labels
    fill(220);
    textAlign(CENTER, TOP);
    text(nf(bt.fLo, 0, 0) + "-" + nf(bt.fHi, 0, 0) + " Hz", x + bw/2, h0 + hAvail + 4);

    textAlign(CENTER, BOTTOM);
    String s = String.format("T%.1f H%.2f C%dms N%d(%s) CC%d", bt.threshold, bt.hysteresis, bt.cooldownMs, bt.midiNote, noteName(bt.midiNote), MIDI_CCS[min(b, MIDI_CCS.length-1)]);
    fill(b == selectedBand ? color(180, 240, 255) : 180);
    text(s, x + bw/2, h0 - 4);
  }
}

void drawOverlay() {
  // Overlay lives at the end of draw() so we can narrate live values while the
  // loop keeps running. Invite students to toggle it with 'H' once they're comfy.
  fill(255);
  textAlign(LEFT, TOP);
  String src = USE_LIVE ? "LIVE" : "FILE";
  String play = (!USE_LIVE && player != null && player.isPlaying()) ? "PLAY" : "PAUSE";
  text("Source: " + src + (USE_LIVE ? "" : "  " + play) +
       "   OSC: " + (OSC_ENABLED ? "ON" : "off") +
       "   MIDI: " + (MIDI_ENABLED ? "ON" : "off") +
       "   Solo: " + (SOLO_SELECTED_BAND ? "SELECTED" : "all") +
       "   Band: " + (selectedBand+1) + "/" + bands.length,
       10, 10);

  String logLine = EVENT_LOG_ENABLED ?
    ("Event log: " + (eventLogPath.equals("") ? "(pending)" : new File(eventLogPath).getName()) + "  (r = MARK)") :
    "Event log: off (press e to start)";
  text(logLine, 10, 26);

  if (!SHOW_HELP) return;

  int boxX = 10;
  int boxY = 32;
  int boxW = width - 20;
  int boxH = 170;
  noStroke();
  fill(0, 180);
  rect(boxX, boxY, boxW, boxH, 6);

  fill(230);
  textAlign(LEFT, TOP);
  int y = boxY + 8;
  text("MIDI device: " + (midi != null ? midi.getCurrentName() : "(none)"), boxX + 10, y); y += 18;
  text("Keyboard: 1/2 band  |  [/] threshold  |  ;/' hysteresis  |  ,/. cooldown  |  -/= note  |  c/C CC  |  t/T transpose  |  S/O save/load", boxX + 10, y); y += 18;
  text("Toggles: L live/file  |  P play/pause file  |  SPACE OSC  |  M MIDI  |  H help", boxX + 10, y); y += 18;
  text("Logging: e start/stop CSV in data/" + EVENT_LOG_DIR + "  |  r drop MARK rows for recovery tests", boxX + 10, y); y += 18;
  text("Burst learn: B all bands, Shift+B selected  |  MIDI outputs: D list, Shift+D cycle", boxX + 10, y); y += 18;
  text("Calibration (K start, Esc cancels): duration " + CAL_MS + "ms  perc " + CAL_PERCENTILE + "  mult " + CAL_MULT + "  H " + CAL_HYST + "  cooldown " + CAL_COOLDOWN + "ms", boxX + 10, y); y += 22;

  if (isCalibrating) {
    float elapsed = millis() - calStartMs;
    float remaining = max(0, CAL_MS - elapsed);
    float progress = constrain(elapsed / (float) CAL_MS, 0, 1);
    text("Calibrating... hold steady (" + nf(remaining/1000.0f, 0, 2) + "s)", boxX + 10, y);
    noFill();
    stroke(200);
    rect(boxX + 170, y + 2, boxW - 190, 14);
    noStroke();
    fill(120, 200, 255);
    rect(boxX + 170, y + 3, (boxW - 192) * progress, 12);
    y += 20;
  }
}

// ---------- Event logging ----------

void toggleEventLog() {
  if (EVENT_LOG_ENABLED) {
    closeEventLog();
    EVENT_LOG_ENABLED = false;
    println("Event log stopped.");
  } else {
    ensureEventLogWriter();
    if (eventLogWriter != null) {
      EVENT_LOG_ENABLED = true;
      eventMarkerCount = 0;
      println("Event log -> " + eventLogPath);
    }
  }
}

void ensureEventLogWriter() {
  if (eventLogWriter != null) return;
  try {
    File dir = new File(dataPath(EVENT_LOG_DIR));
    if (!dir.exists()) dir.mkdirs();

    String fname = String.format("%s-%d.csv", EVENT_LOG_FILE_PREFIX, System.currentTimeMillis());
    eventLogPath = new File(dir, fname).getAbsolutePath();
    eventLogWriter = createWriter(eventLogPath);
    eventLogWriter.println("t_ms,condition,mode,band,f_lo,f_hi,energyN,threshold,hysteresis,cooldown_ms");
    eventLogWriter.flush();
  } catch (Exception e) {
    println("Failed to open event log: " + e);
    eventLogWriter = null;
    eventLogPath = "";
  }
}

void logTriggerEvent(BandTrigger bt, float energyNorm) {
  if (!EVENT_LOG_ENABLED || eventLogWriter == null) return;
  String mode = USE_LIVE ? "LIVE" : "FILE";
  String line = String.format("%d,%s,%s,%d,%.2f,%.2f,%.6f,%.3f,%.3f,%d",
                              millis(), EVENT_LOG_CONDITION, mode, bt.idx,
                              bt.fLo, bt.fHi, energyNorm, bt.threshold, bt.hysteresis, bt.cooldownMs);
  eventLogWriter.println(line);
  eventLogWriter.flush();
}

void logMarker(String label) {
  if (!EVENT_LOG_ENABLED || eventLogWriter == null) return;
  String cleanLabel = label.replace(",", " ");
  String line = String.format("%d,MARK,%s", millis(), cleanLabel);
  eventLogWriter.println(line);
  eventLogWriter.flush();
}

void closeEventLog() {
  if (eventLogWriter != null) {
    try { eventLogWriter.flush(); eventLogWriter.close(); } catch (Exception ignore) {}
  }
  eventLogWriter = null;
  eventLogPath = "";
}

// ---------- OSC ----------

void sendOscTrigger(BandTrigger bt, float energy) {
  OscMessage m = new OscMessage("/bandTrigger");
  m.add(bt.idx);
  m.add(bt.fLo);
  m.add(bt.fHi);
  m.add(energy);
  m.add(bt.threshold);
  m.add(bt.hysteresis);
  m.add(bt.cooldownMs);
  osc.send(m, oscDest);
}

void oscEvent(OscMessage msg) {
  if (msg == null) return;
  String addr = msg.addrPattern();
  if (addr == null) return;
  if (!addr.startsWith("/band/")) return;
  String[] parts = split(addr, '/');
  if (parts.length < 3) return;
  String param = parts[2];
  if (msg.typetag().length() < 2) return;
  int idx = constrain(msg.get(0).intValue(), 0, bands.length - 1);
  float val = msg.get(1).floatValue();
  BandTrigger bt = bands[idx];
  if (param.equals("threshold")) bt.threshold = max(0.1f, val);
  if (param.equals("hysteresis")) bt.hysteresis = max(1.01f, val);
  if (param.equals("cooldown")) bt.cooldownMs = max(1, (int)val);
  if (param.equals("note")) bt.midiNote = clamp127((int)val);
  if (param.equals("cc")) { int ccIdx = min(idx, MIDI_CCS.length-1); MIDI_CCS[ccIdx] = clamp127((int)val); }
}

// ---------- Calibration ----------

void startCalibration() {
  if (isCalibrating) return;
  // Start an on-the-side sample collector; draw() keeps running so you can talk
  // through what "percentile" means while it counts down.
  isCalibrating = true;
  calStartMs = millis();
  calSamples = (ArrayList<Float>[]) new ArrayList[bands.length];
  for (int i = 0; i < bands.length; i++) {
    calSamples[i] = new ArrayList<Float>();
  }
  println("Calibration started for " + CAL_MS + " ms");
}

void updateCalibration(float[] energies) {
  if (!isCalibrating) return;
  for (int i = 0; i < bands.length; i++) {
    calSamples[i].add(energies[i]);
  }
  if (millis() - calStartMs >= CAL_MS) {
    finalizeCalibration();
  }
}

void finalizeCalibration() {
  if (!isCalibrating) return;
  for (int i = 0; i < bands.length; i++) {
    ArrayList<Float> vals = calSamples[i];
    Collections.sort(vals);
    float pct = vals.size() > 0 ? vals.get((int)floor((vals.size()-1) * CAL_PERCENTILE)) : bands[i].threshold;
    float thr = max(0.1f, pct * CAL_MULT);
    bands[i].threshold = thr;
    bands[i].hysteresis = CAL_HYST;
    bands[i].cooldownMs = CAL_COOLDOWN;
    bands[i].armed = true;
  }
  println("Calibration done. Thresholds, hysteresis, and cooldown updated.");
  isCalibrating = false;
}

void cancelCalibration() {
  if (!isCalibrating) return;
  isCalibrating = false;
  println("Calibration canceled.");
}

// ---------- Note helpers ----------

String noteName(int note) {
  String[] names = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"};
  int n = constrain(note, 0, 127);
  int pc = n % 12;
  int oct = (n / 12) - 1;
  return names[pc] + oct;
}
int clamp127(int v) { return max(0, min(127, v)); }

// ---------- MIDI helpers ----------

class PendingNoteOff {
  int note;
  long whenMs;
  PendingNoteOff(int note, long whenMs) { this.note = note; this.whenMs = whenMs; }
}

void processNoteOffs() {
  long now = millis();
  for (int i = noteOffQueue.size()-1; i >= 0; i--) {
    PendingNoteOff p = noteOffQueue.get(i);
    if (now >= p.whenMs) {
      if (midi != null) midi.noteOff(p.note);
      noteOffQueue.remove(i);
    }
  }
}

void allNotesOff() {
  if (midi == null) return;
  for (int n = 0; n < 128; n++) {
    midi.noteOff(n);
  }
  noteOffQueue.clear();
}

// ---------- Save/Load mapping ----------

void saveMapping(String fname) {
  try {
    // Keep it tiny on purpose: just notes + CCs. This leaves room for a follow-up
    // lesson on thresholds/hysteresis persistence without rewriting the basics.
    JSONObject root = new JSONObject();
    JSONArray jnotes = new JSONArray();
    for (int i = 0; i < bands.length; i++) jnotes.setInt(i, clamp127(bands[i].midiNote));
    root.setJSONArray("notes", jnotes);
    JSONArray jcc = new JSONArray();
    for (int i = 0; i < min(bands.length, MIDI_CCS.length); i++) jcc.setInt(i, clamp127(MIDI_CCS[i]));
    root.setJSONArray("ccs", jcc);
    String path = dataPath(fname);
    saveJSONObject(root, path);
    println("Saved mapping -> " + path);
  } catch (Exception e) {
    println("Save mapping error: " + e);
  }
}

void loadMapping(String fname) {
  try {
    String path = dataPath(fname);
    File f = new File(path);
    if (!f.exists()) { println("No mapping file at " + path); return; }
    JSONObject root = loadJSONObject(path);
    if (root.hasKey("notes")) {
      JSONArray jnotes = root.getJSONArray("notes");
      for (int i = 0; i < min(bands.length, jnotes.size()); i++) {
        bands[i].midiNote = clamp127(jnotes.getInt(i));
      }
    }
    if (root.hasKey("ccs")) {
      JSONArray jcc = root.getJSONArray("ccs");
      for (int i = 0; i < min(bands.length, jcc.size()); i++) {
        MIDI_CCS[i] = clamp127(jcc.getInt(i));
      }
    }
    println("Loaded mapping from " + path);
  } catch (Exception e) {
    println("Load mapping error: " + e);
  }
}

// ---------- MIDI Learn Burst ----------

void burstLearn(boolean onlySelected) {
  if (!(MIDI_ENABLED && midi != null)) {
    println("Burst: MIDI not enabled or device not open.");
    return;
  }
  // Designed for DAWs or VJ tools that learn both CC and note in one swoop.
  // Encourage students to watch the console so they know which device caught it.
  final int n = onlySelected ? 1 : min(bands.length, MIDI_CCS.length);
  final int[] ccNums = new int[n];
  final int[] notes = new int[n];
  if (onlySelected) {
    ccNums[0] = MIDI_CCS[min(selectedBand, MIDI_CCS.length-1)];
    notes[0] = bands[selectedBand].midiNote;
  } else {
    for (int i = 0; i < n; i++) ccNums[i] = MIDI_CCS[i];
    for (int i = 0; i < n; i++) notes[i] = bands[i].midiNote;
  }

  new Thread(new Runnable() {
    public void run() {
      try {
        System.out.println("Sending MIDI learn burst on " + n + " band(s) via " + (midi.getCurrentName()));
        for (int i = 0; i < n; i++) {
          int cc = ccNums[i];
          midi.cc(cc, 0);      Thread.sleep(15);
          midi.cc(cc, 127);    Thread.sleep(15);
          midi.cc(cc, 0);      Thread.sleep(60);
          if (MIDI_SEND_NOTES) {
            int note = notes[i];
            midi.noteOn(note, 100);
            Thread.sleep(50);
            midi.noteOff(note);
          }
          Thread.sleep(100);
        }
        System.out.println("Burst complete.");
      } catch (Exception e) {
        System.out.println("Burst error: " + e);
      }
    }
  }).start();
}

// ---------- Controls ----------

void keyPressed() {
  if (key == ESC) { key = 0; cancelCalibration(); return; }

  if (key == '1') { selectedBand = (selectedBand - 1 + bands.length) % bands.length; }
  if (key == '2') { selectedBand = (selectedBand + 1) % bands.length; }

  BandTrigger bt = bands[selectedBand];

  if (key == '[') bt.threshold = max(0.1f, bt.threshold * 0.9f);
  if (key == ']') bt.threshold = bt.threshold * 1.1f;

  if (key == ';') bt.hysteresis = max(1.01f, bt.hysteresis * 0.95f);
  if (key == '\'') bt.hysteresis = bt.hysteresis * 1.05f;

  if (key == ',') bt.cooldownMs = max(10, int(bt.cooldownMs * 0.9f));
  if (key == '.') bt.cooldownMs = int(bt.cooldownMs * 1.1f);

  if (key == '-') { bt.midiNote = clamp127(bt.midiNote - 1); println("Band " + (selectedBand+1) + " note -> " + bt.midiNote + " (" + noteName(bt.midiNote) + ")"); }
  if (key == '=') { bt.midiNote = clamp127(bt.midiNote + 1); println("Band " + (selectedBand+1) + " note -> " + bt.midiNote + " (" + noteName(bt.midiNote) + ")"); }

  if (key == 'c') { int idx = min(selectedBand, MIDI_CCS.length-1); MIDI_CCS[idx] = clamp127(MIDI_CCS[idx]-1); println("Band " + (selectedBand+1) + " CC -> " + MIDI_CCS[idx]); }
  if (key == 'C') { int idx = min(selectedBand, MIDI_CCS.length-1); MIDI_CCS[idx] = clamp127(MIDI_CCS[idx]+1); println("Band " + (selectedBand+1) + " CC -> " + MIDI_CCS[idx]); }

  if (key == 't') { for (int i = 0; i < bands.length; i++) bands[i].midiNote = clamp127(bands[i].midiNote - 1); println("Transposed all notes -1"); }
  if (key == 'T') { for (int i = 0; i < bands.length; i++) bands[i].midiNote = clamp127(bands[i].midiNote + 1); println("Transposed all notes +1"); }

  if (key == ' ') { OSC_ENABLED = !OSC_ENABLED; }
  if (key == 'm' || key == 'M') { if (MIDI_ENABLED) allNotesOff(); MIDI_ENABLED = !MIDI_ENABLED; }
  if (key == 'e' || key == 'E') { toggleEventLog(); }
  if (key == 'r' || key == 'R') {
    if (EVENT_LOG_ENABLED) {
      eventMarkerCount++;
      String label = "mark-" + eventMarkerCount;
      logMarker(label);
      println("MARK -> " + label + " at " + millis() + "ms");
    } else {
      println("MARK ignored (log is off; press 'e' first).");
    }
  }

  if (key == 'l' || key == 'L') {
    USE_LIVE = !USE_LIVE;
    allNotesOff();
    switchSource();
  }
  if ((key == 'p' || key == 'P') && !USE_LIVE && player != null) {
    if (player.isPlaying()) player.pause(); else player.play();
  }

  if (key == 'b') { burstLearn(false); }
  if (key == 'B') { burstLearn(true); }
  if (key == 'd') { MidiOut.listOutputs(); }
  if (key == 'D') { if (midi != null) { allNotesOff(); midi.cycleToNext(); } }
  if (key == 's' || key == 'S') { saveMapping("mapping.json"); }
  if (key == 'o' || key == 'O') { loadMapping("mapping.json"); }
  if (key == 'h' || key == 'H') { SHOW_HELP = !SHOW_HELP; }
  if (key == 'k' || key == 'K') { startCalibration(); }

  surface.setTitle("Freq-Zone Triggers - L("+USE_LIVE+")  OSC("+OSC_ENABLED+")  MIDI("+MIDI_ENABLED+")");
}

void switchSource() {
  if (USE_LIVE) {
    if (player != null) { player.close(); player = null; }
    if (liveIn == null) liveIn = minim.getLineIn(Minim.MONO, AUDIO_BUF, AUDIO_SR);
    fft = new FFT(liveIn.bufferSize(), liveIn.sampleRate());
  } else {
    if (liveIn != null) { liveIn.close(); liveIn = null; }
    if (player == null) player = minim.loadFile(AUDIO_FILE, AUDIO_BUF);
    if (player != null) player.loop();
    fft = new FFT(player.bufferSize(), player.sampleRate());
  }
}

void focusLost() {
  allNotesOff();
}

void stop() {
  allNotesOff();
  closeEventLog();
  if (player != null) player.close();
  if (liveIn != null) liveIn.close();
  if (midi != null) midi.close();
  minim.stop();
  super.stop();
}
