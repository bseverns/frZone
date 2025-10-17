/**
 * Freq-Zone Peak Triggers (Live/File) + OSC + MIDI
 * Ben-ready — visual apps friendly (Signal Culture), IAC-targeted MIDI, CC stream, burst learn, save/load mapping
 *
 * Requires Processing (Java mode), Minim, oscP5.
 * MIDI uses javax.sound.midi (no extra library).
 *
 * Controls:
 *   1 / 2          : select previous / next band
 *   [ / ]          : decrease / increase threshold of selected band
 *   ; / '          : decrease / increase hysteresis of selected band
 *   , / .          : decrease / increase cooldown (ms) of selected band
 *   - / =          : selected band note down / up
 *   c / C          : selected band CC down / up
 *   i              : isolate (solo) the selected band for OSC/MIDI output
 *   t / T          : transpose all notes -1 / +1
 *   S / O          : Save / Load mapping (to data/mapping.json)
 *   B              : send MIDI-learn "burst" (CC sweeps + note taps)
 *   d / D          : list/select next available MIDI output in console
 *   L              : toggle Live vs File playback
 *   P              : play/pause file (when in file mode)
 *   SPACE          : toggle OSC sending
 *   M              : toggle MIDI sending
 */

import ddf.minim.*;
import ddf.minim.analysis.*;
import oscP5.*;
import netP5.*;
import javax.sound.midi.*;
import java.util.*;
import processing.data.*;
import java.io.*;

Minim minim;
AudioInput liveIn;
AudioPlayer player;
FFT fft;

// ======================= CONFIG =========================

// --- Source config
boolean USE_LIVE = true;                 // default input (toggle 'L')
String  AUDIO_FILE = "ReadySet.mp3";   // put in data/ folder
int     AUDIO_BUF  = 2048;
float   AUDIO_SR   = 44100;

// --- Frequency bands (Hz) — endpoints; N bands = bounds.length-1
float[] BAND_BOUNDS = { 0, 200, 800, 3000, 8000, 20000 };

// --- Initial band configs (threshold, hysteresis, cooldown, MIDI note)
float[] INIT_THRESH     = { 9, 6, 4, 3, 2 };           // amplitude-ish (FFT sum)
float[] INIT_HYSTERESIS = { 1.5, 1.2, 1.1, 1.1, 1.0 }; // multiplier above thresh to re-arm
int[]   INIT_COOLDOWNMS = { 120, 120, 120, 140, 160 };
int[]   MIDI_NOTES      = { 36, 38, 42, 46, 49 };      // C1, D1, F#1, A#1, C#2 for ex.

// --- OSC config
boolean OSC_ENABLED = true;
String  OSC_HOST    = "127.0.0.1";
int     OSC_PORT    = 9000;

// --- OSC energy stream (for visuals)
boolean SEND_OSC_ENERGY = true;
String  OSC_ENERGY_ADDR = "/bandEnergy";  // idx, fLo, fHi, energyN (0..1)

// --- MIDI config
boolean MIDI_ENABLED     = true;
int     MIDI_CHANNEL     = 0;           // [0..15]
int     MIDI_VELOCITY_MAX= 110;
int     MIDI_NOTE_LEN_MS = 100;         // auto note-off after this many ms

// Direct device targeting (macOS IAC Driver or other port)
String  MIDI_DEVICE_HINT = "IAC";       // e.g., "IAC", "IAC Driver", "Bus 1"
boolean MIDI_STRICT      = true;        // true: disable MIDI if not found (no SoftSynth fallback)

// --- Visual/MIDI options
boolean MIDI_SEND_NOTES = true;         // gates for drums/learn taps
boolean MIDI_SEND_CCS   = true;         // continuous per-band CC stream for visual apps

// Per-band CC numbers (match bands 1..N); used for streaming & burst
int[]   MIDI_CCS        = {20, 21, 22, 23, 24};
int     MIDI_CC_MIN     = 0;
int     MIDI_CC_MAX     = 127;

// Simple smoothing for CC/OSC energy (0..1; higher = smoother)
float   ENERGY_SMOOTH   = 0.25f;

// --- Viz config
boolean SHOW_SPECTRUM = true;

// --- Output control
boolean SOLO_SELECTED_BAND = false;      // when true, only the selected band drives OSC/MIDI

// ========================================================

OscP5 osc;
NetAddress oscDest;

MidiOut midi;  // device-targeted Java Sound MIDI out
ArrayList<PendingNoteOff> noteOffQueue = new ArrayList<>();

// per-band trigger state
class BandTrigger {
  int idx;
  float fLo, fHi;
  float threshold;       // energy threshold
  float hysteresis;      // arming multiplier
  int   cooldownMs;      // minimum time between triggers
  long  lastTrigMs;      // timestamp of last trigger
  boolean armed;         // re-arm when energy drops below threshold
  int   midiNote;
  float smooth;          // smoothed normalized energy 0..1

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

void settings() {
  size(960, 540);
}

void setup() {
  surface.setTitle("Freq-Zone Triggers  •  L("+USE_LIVE+")  OSC("+OSC_ENABLED+")  MIDI("+MIDI_ENABLED+")");
  minim = new Minim(this);

  if (USE_LIVE) {
    liveIn = minim.getLineIn(Minim.MONO, AUDIO_BUF, AUDIO_SR);
    fft = new FFT(liveIn.bufferSize(), liveIn.sampleRate());
  } else {
    player = minim.loadFile(AUDIO_FILE, AUDIO_BUF);
    player.loop();
    fft = new FFT(player.bufferSize(), player.sampleRate());
  }

  // Initialize band triggers
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

  // OSC
  osc = new OscP5(this, 0); // we only send; port 0 "no listen"
  oscDest = new NetAddress(OSC_HOST, OSC_PORT);

  // MIDI out
  midi = new MidiOut(MIDI_DEVICE_HINT, MIDI_CHANNEL, MIDI_STRICT);
  MidiOut.listOutputs();
  
  textFont(createFont("Menlo", 12));
  frameRate(60);
}

void draw() {
  background(12);

  // Source
  AudioSource src = USE_LIVE ? (AudioSource) liveIn : (AudioSource) player;
  if (src == null) return;
  fft.forward(src.mix);

  // Per-band energy + triggers
  float maxBar = 0;
  float[] energies = new float[bands.length];

  for (int b = 0; b < bands.length; b++) {
    BandTrigger bt = bands[b];

    int iLo = fft.freqToIndex(bt.fLo);
    int iHi = fft.freqToIndex(bt.fHi);

    float sum = 0;
    for (int i = iLo; i <= iHi; i++) {
      sum += fft.getBand(i);
    }
    energies[b] = sum;
    if (sum > maxBar) maxBar = sum;

    // Continuous energy: normalize around threshold and smooth
    float eN = constrain(map(sum, bt.threshold, bt.threshold*4f, 0, 1), 0, 1);
    bt.smooth = lerp(bt.smooth, eN, ENERGY_SMOOTH);

    boolean outputsActive = !SOLO_SELECTED_BAND || b == selectedBand;

    // Stream MIDI CC (for visual apps)
    if (MIDI_ENABLED && MIDI_SEND_CCS && midi != null) {
      int ccIndex = min(b, MIDI_CCS.length - 1);
      int ccNum   = MIDI_CCS[ccIndex];
      float smoothForOutput = outputsActive ? bt.smooth : 0;
      int ccVal   = (int)round(lerp(MIDI_CC_MIN, MIDI_CC_MAX, smoothForOutput));
      midi.cc(ccNum, ccVal);
    }

    // Stream OSC energy
    if (OSC_ENABLED && SEND_OSC_ENERGY) {
      OscMessage em = new OscMessage(OSC_ENERGY_ADDR);
      em.add(bt.idx);
      em.add(bt.fLo);
      em.add(bt.fHi);
      em.add(outputsActive ? bt.smooth : 0); // 0..1
      osc.send(em, oscDest);
    }

    // Trigger logic with hysteresis + cooldown
    long now = millis();

    // re-arm when energy falls sufficiently below threshold / hysteresis
    if (!bt.armed && sum < (bt.threshold / bt.hysteresis)) {
      bt.armed = true;
    }

    boolean cooled = (now - bt.lastTrigMs) >= bt.cooldownMs;
    if (bt.armed && cooled && sum >= bt.threshold && outputsActive) {
      // Fire!
      bt.lastTrigMs = now;
      bt.armed = false;

      // OSC pulse event
      if (OSC_ENABLED) sendOscTrigger(bt, sum);

      // MIDI note event
      if (MIDI_ENABLED && MIDI_SEND_NOTES) {
        int vel = constrain(round(map(sum, bt.threshold, bt.threshold*4, 60, MIDI_VELOCITY_MAX)), 1, 127);
        midi.noteOn(bt.midiNote, vel);
        noteOffQueue.add(new PendingNoteOff(bt.midiNote, now + MIDI_NOTE_LEN_MS));
      }
    }
  }

  // handle queued NoteOffs
  processNoteOffs();

  // Viz: spectrum (optionally) + band bars
  if (SHOW_SPECTRUM) drawSpectrum(fft);

  drawBandBars(energies, maxBar);

  // UI overlay
  drawOverlay();
}

void drawSpectrum(FFT fft) {
  stroke(80);
  noFill();
  int w = width;
  int h = height/3;
  // Keep the zero-line comfortably above the band bars drawn in drawBandBars().
  int bandBaseY = height/2 + 8;
  int baselineY = max(30, bandBaseY - 60);
  float amplitude = h * 0.5f; // swing half the vertical span around the center line

  int nBands = BAND_BOUNDS.length - 1;
  int[] bandHiIdx = new int[nBands];
  for (int b = 0; b < nBands; b++) {
    bandHiIdx[b] = freqToIndex(BAND_BOUNDS[b+1], AUDIO_SR, fft.specSize());
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
    float gamma = sqrt(fft.getBand(i)); // keep gentle gamma to soften spikes
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

    // small params (now includes note name)
    textAlign(CENTER, BOTTOM);
    String s = String.format("T%.1f H%.2f C%dms N%d(%s) CC%d",
                             bt.threshold, bt.hysteresis, bt.cooldownMs, bt.midiNote, noteName(bt.midiNote),
                             MIDI_CCS[min(b, MIDI_CCS.length-1)]);
    fill(b == selectedBand ? color(180, 240, 255) : 180);
    text(s, x + bw/2, h0 - 4);
  }
}

void drawOverlay() {
  fill(255);
  textAlign(LEFT, TOP);
  String src = USE_LIVE ? "LIVE" : "FILE";
  String play = (!USE_LIVE && player != null && player.isPlaying()) ? "PLAY" : "PAUSE";
  text("Source: " + src + (USE_LIVE ? "" : "  " + play) +
       "   OSC: " + (OSC_ENABLED ? "ON" : "off") +
       "   MIDI: " + (MIDI_ENABLED ? "ON" : "off") +
       "   Solo: " + (SOLO_SELECTED_BAND ? "SELECTED" : "all") +
       "   Band: " + (selectedBand+1) + "/" + bands.length +
       "   (1/2 sel, [/] thr, ;/' hyst, ,/. cool, -/= note, c/C CC, i solo, S/O save/load, B burst, d/D list, L source, P play, SPACE osc, M midi)",
       10, 10);
}

// ---------- Helpers ----------

int freqToIndex(float freq, float sampleRate, int specSize) {
  float nyquist = sampleRate / 2f;
  int idx = round(constrain((freq / nyquist) * (specSize - 1), 0, specSize - 1));
  return idx;
}

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

// Note helpers
String noteName(int note) {
  String[] names = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"};
  int n = constrain(note, 0, 127);
  int pc = n % 12;
  int oct = (n / 12) - 1;  // MIDI 60 -> C4
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
      midi.noteOff(p.note);
      noteOffQueue.remove(i);
    }
  }
}

// ---------- Save/Load mapping ----------
void saveMapping(String fname) {
  try {
    JSONObject root = new JSONObject();
    JSONArray jnotes = new JSONArray();
    for (int i = 0; i < bands.length; i++) jnotes.setInt(i, clamp127(bands[i].midiNote));
    root.setJSONArray("notes", jnotes);
    JSONArray jcc = new JSONArray();
    for (int i = 0; i < min(bands.length, MIDI_CCS.length); i++) jcc.setInt(i, clamp127(MIDI_CCS[i]));
    root.setJSONArray("ccs", jcc);
    String path = dataPath(fname);
    saveJSONObject(root, path);
    println("Saved mapping → " + path);
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

// ---------- MIDI Learn Burst (sends CC sweeps + note taps) ----------
void burstLearn() {
  if (!(MIDI_ENABLED && midi != null)) { 
    println("Burst: MIDI not enabled or device not open."); 
    return; 
  }
  final int n = min(bands.length, MIDI_CCS.length);
  final int[] ccNums = new int[n];
  for (int i = 0; i < n; i++) ccNums[i] = MIDI_CCS[i];
  final int[] notes = new int[n];
  for (int i = 0; i < n; i++) notes[i] = bands[i].midiNote;

  new Thread(new Runnable() {
    public void run() {
      try {
        println("Sending MIDI learn burst on " + n + " bands via " + (midi.lastDeviceName != null ? midi.lastDeviceName : "(device)"));
        // For each band: quick CC sweep 0->127->0 and a short note tap
        for (int i = 0; i < n; i++) {
          int cc = ccNums[i];
          // CC sweep
          midi.cc(cc, 0);      Thread.sleep(15);
          midi.cc(cc, 127);    Thread.sleep(15);
          midi.cc(cc, 0);      Thread.sleep(60);
          // Note tap (helps apps that learn off notes)
          if (MIDI_SEND_NOTES) {
            int note = notes[i];
            midi.noteOn(note, 100);
            Thread.sleep(50);
            midi.noteOff(note);
          }
          Thread.sleep(100);
        }
        println("Burst complete.");
      } catch (Exception e) {
        println("Burst error: " + e);
      }
    }
  }).start();
}

// ---------- Controls ----------

void keyPressed() {
  if (key == '1') { selectedBand = (selectedBand - 1 + bands.length) % bands.length; }
  if (key == '2') { selectedBand = (selectedBand + 1) % bands.length; }

  BandTrigger bt = bands[selectedBand];

  if (key == '[') bt.threshold = max(0.1, bt.threshold * 0.9);
  if (key == ']') bt.threshold = bt.threshold * 1.1;

  if (key == ';') bt.hysteresis = max(1.01, bt.hysteresis * 0.95);
  if (key == '\'') bt.hysteresis = bt.hysteresis * 1.05;

  if (key == ',') bt.cooldownMs = max(10, int(bt.cooldownMs * 0.9));
  if (key == '.') bt.cooldownMs = int(bt.cooldownMs * 1.1);

  if (key == '-') { bt.midiNote = clamp127(bt.midiNote - 1); println("Band " + (selectedBand+1) + " note → " + bt.midiNote + " (" + noteName(bt.midiNote) + ")"); }
  if (key == '=') { bt.midiNote = clamp127(bt.midiNote + 1); println("Band " + (selectedBand+1) + " note → " + bt.midiNote + " (" + noteName(bt.midiNote) + ")"); }

  if (key == 'c') { int idx = min(selectedBand, MIDI_CCS.length-1); MIDI_CCS[idx] = clamp127(MIDI_CCS[idx]-1); println("Band " + (selectedBand+1) + " CC → " + MIDI_CCS[idx]); }
  if (key == 'C') { int idx = min(selectedBand, MIDI_CCS.length-1); MIDI_CCS[idx] = clamp127(MIDI_CCS[idx]+1); println("Band " + (selectedBand+1) + " CC → " + MIDI_CCS[idx]); }

  if (key == 'i' || key == 'I') {
    SOLO_SELECTED_BAND = !SOLO_SELECTED_BAND;
    println("Solo " + (SOLO_SELECTED_BAND ? "ON (band " + (selectedBand+1) + ")" : "off"));
  }

  if (key == 't') { for (int i = 0; i < bands.length; i++) bands[i].midiNote = clamp127(bands[i].midiNote - 1); println("Transposed all notes -1"); }
  if (key == 'T') { for (int i = 0; i < bands.length; i++) bands[i].midiNote = clamp127(bands[i].midiNote + 1); println("Transposed all notes +1"); }

  if (key == ' ') { OSC_ENABLED = !OSC_ENABLED; }
  if (key == 'm' || key == 'M') { MIDI_ENABLED = !MIDI_ENABLED; }

  if (key == 'l' || key == 'L') {
    USE_LIVE = !USE_LIVE;
    switchSource();
  }
  if ((key == 'p' || key == 'P') && !USE_LIVE && player != null) {
    if (player.isPlaying()) player.pause(); else player.play();
  }

  if (key == 'B') { burstLearn(); }
  if (key == 'd' || key == 'D') { MidiOut.listOutputs(); }
  if (key == 's' || key == 'S') { saveMapping("mapping.json"); }
  if (key == 'o' || key == 'O') { loadMapping("mapping.json"); }

  surface.setTitle("Freq-Zone Triggers  •  L("+USE_LIVE+")  OSC("+OSC_ENABLED+")  MIDI("+MIDI_ENABLED+")");
}

void switchSource() {
  if (USE_LIVE) {
    if (player != null) { player.close(); player = null; }
    if (liveIn == null) liveIn = minim.getLineIn(Minim.MONO, AUDIO_BUF, AUDIO_SR);
    fft = new FFT(liveIn.bufferSize(), liveIn.sampleRate());
  } else {
    if (liveIn != null) { liveIn.close(); liveIn = null; }
    if (player == null) player = minim.loadFile(AUDIO_FILE, AUDIO_BUF);
    player.loop();
    fft = new FFT(player.bufferSize(), player.sampleRate());
  }
}

void stop() {
  // all pending note-offs to be safe
  for (PendingNoteOff p : noteOffQueue) { midi.noteOff(p.note); }
  noteOffQueue.clear();

  if (player != null) player.close();
  if (liveIn != null) liveIn.close();
  if (midi != null) midi.close();
  minim.stop();
  super.stop();
}
