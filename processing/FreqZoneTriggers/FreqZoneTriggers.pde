/**
 * Freq-Zone Peak Triggers (Live/File) + OSC + MIDI
 * Ben-ready version — lightweight visualizer, config-at-top
 *
 * Requires Processing (Java mode), Minim, oscP5.
 * MIDI uses javax.sound.midi (no extra library).
 *
 * Controls:
 *   1 / 2          : select previous / next band
 *   [ / ]          : decrease / increase threshold of selected band
 *   ; / '          : decrease / increase hysteresis of selected band
 *   , / .          : decrease / increase cooldown (ms) of selected band
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

Minim minim;
AudioInput liveIn;
AudioPlayer player;
FFT fft;

// ======================= CONFIG =========================

// --- Source config
boolean USE_LIVE = true;                 // default input (toggle 'L')
String  AUDIO_FILE = "your_audio.mp3";   // put in data/ folder
int     AUDIO_BUF  = 2048;
float   AUDIO_SR   = 44100;

// --- Frequency bands (Hz) — endpoints; N bands = bounds.length-1
float[] BAND_BOUNDS = { 0, 200, 800, 3000, 8000, 20000 };

// --- Initial band configs (threshold, hysteresis, cooldown, MIDI note)
float[] INIT_THRESH     = { 9, 6, 4, 3, 2 };   // amplitude-ish (FFT sum)
float[] INIT_HYSTERESIS = { 1.5, 1.2, 1.1, 1.1, 1.0 }; // multiplier above thresh to re-arm
int[]   INIT_COOLDOWNMS = { 120, 120, 120, 140, 160 };
int[]   MIDI_NOTES      = { 36, 38, 42, 46, 49 };       // C1, D1, F#1, A#1, C#2 for ex.

// --- OSC config
boolean OSC_ENABLED = true;
String  OSC_HOST    = "127.0.0.1";
int     OSC_PORT    = 9000;

// --- MIDI config
boolean MIDI_ENABLED = true;
int     MIDI_CHANNEL = 0;           // [0..15]
int     MIDI_VELOCITY_MAX = 110;
int     MIDI_NOTE_LEN_MS  = 100;    // auto note-off after this many ms

// --- Viz config
boolean SHOW_SPECTRUM = true;

// ========================================================

OscP5 osc;
NetAddress oscDest;

SynthReceiver midi;  // simple wrapper for Java Sound MIDI
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

  // MIDI
  midi = new SynthReceiver(MIDI_CHANNEL);

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

    int iLo = freqToIndex(bt.fLo, fft.sampleRate(), fft.specSize());
    int iHi = freqToIndex(bt.fHi, fft.sampleRate(), fft.specSize());

    float sum = 0;
    for (int i = iLo; i <= iHi; i++) {
      sum += fft.getBand(i);
    }
    energies[b] = sum;
    if (sum > maxBar) maxBar = sum;

    // Trigger logic with hysteresis + cooldown
    long now = millis();

    // re-arm when energy falls sufficiently below threshold / hysteresis
    if (!bt.armed && sum < (bt.threshold / bt.hysteresis)) {
      bt.armed = true;
    }

    boolean cooled = (now - bt.lastTrigMs) >= bt.cooldownMs;
    if (bt.armed && cooled && sum >= bt.threshold) {
      // Fire!
      bt.lastTrigMs = now;
      bt.armed = false;

      // OSC
      if (OSC_ENABLED) sendOscTrigger(bt, sum);

      // MIDI
      if (MIDI_ENABLED) {
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
  int h = height/2;
  pushMatrix();
  translate(0, h);
  beginShape();
  for (int i = 0; i < fft.specSize(); i++) {
    float x = map(i, 0, fft.specSize()-1, 0, w);
    float y = -sqrt(fft.getBand(i)) * 12; // gentle gamma
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

    // small params
    textAlign(CENTER, BOTTOM);
    String s = String.format("T%.1f H%.2f C%dms N%d",
                             bt.threshold, bt.hysteresis, bt.cooldownMs, bt.midiNote);
    fill(b == selectedBand ? color(180, 240, 255) : 180);
    text(s, x + bw/2, h0 - 4);
  }
}

void drawOverlay() {
  fill(255);
  textAlign(LEFT, TOP);
  String src = USE_LIVE ? "LIVE" : "FILE";
  String play = (!USE_LIVE && player != null && player.isPlaying()) ? "▶" : "❚❚";
  text("Source: " + src + (USE_LIVE ? "" : "  " + play) +
       "   OSC: " + (OSC_ENABLED ? "ON" : "off") +
       "   MIDI: " + (MIDI_ENABLED ? "ON" : "off") +
       "   Band: " + (selectedBand+1) + "/" + bands.length +
       "   (1/2 sel, [/] thr, ;/' hyst, ,/. cool, L source, P play/pause, SPACE osc, M midi)",
       10, 10);
}

// ---------- Trigger helpers ----------

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

// ---------- MIDI helpers ----------

class PendingNoteOff {
  int note, whenMs;
  PendingNoteOff(int note, int whenMs) { this.note = note; this.whenMs = whenMs; }
}

void processNoteOffs() {
  int now = millis();
  for (int i = noteOffQueue.size()-1; i >= 0; i--) {
    PendingNoteOff p = noteOffQueue.get(i);
    if (now >= p.whenMs) {
      midi.noteOff(p.note);
      noteOffQueue.remove(i);
    }
  }
}

// simple MIDI wrapper using Java Sound
class SynthReceiver {
  Receiver recv;
  int ch;
  SynthReceiver(int channel) {
    ch = constrain(channel, 0, 15);
    try {
      // Prefer default receiver (often OS MIDI out); fallback to software synth
      try {
        recv = MidiSystem.getReceiver();
      } catch (Exception e) {
        Synthesizer synth = MidiSystem.getSynthesizer();
        synth.open();
        recv = synth.getReceiver();
      }
    } catch (Exception e) {
      println("MIDI unavailable: " + e);
      recv = null;
    }
  }
  void noteOn(int note, int vel) {
    if (recv == null) return;
    send(0x90 | (ch & 0x0F), note & 0x7F, vel & 0x7F);
  }
  void noteOff(int note) {
    if (recv == null) return;
    send(0x80 | (ch & 0x0F), note & 0x7F, 0);
  }
  void send(int status, int data1, int data2) {
    try {
      ShortMessage msg = new ShortMessage(status, data1, data2);
      recv.send(msg, -1);
    } catch (Exception e) {
      println("MIDI send error: " + e);
    }
  }
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

  if (key == ' ') { OSC_ENABLED = !OSC_ENABLED; }
  if (key == 'm' || key == 'M') { MIDI_ENABLED = !MIDI_ENABLED; }

  if (key == 'l' || key == 'L') {
    USE_LIVE = !USE_LIVE;
    switchSource();
  }
  if ((key == 'p' || key == 'P') && !USE_LIVE && player != null) {
    if (player.isPlaying()) player.pause(); else player.play();
  }

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
  minim.stop();
  super.stop();
}
