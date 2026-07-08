import javax.sound.midi.*;
import java.util.ArrayList;
import java.util.List;

// MIDI output manager with device cycling and clean shutdown.
// Annotated like a studio notebook so students can see the plumbing without
// being buried in the Java Sound API.
public class MidiOut {
  private Receiver recv;
  private MidiDevice device;
  private int ch;
  private List<MidiDevice.Info> outputs = new ArrayList<MidiDevice.Info>();
  private int currentIndex = -1;
  private String lastDeviceName = "(none)";
  private static MidiDevice.Info activeOutputInfo = null;

  public MidiOut(String nameHint, int channel, boolean strict) {
    this.ch = Math.max(0, Math.min(15, channel));
    refreshOutputs();
    connectPreferred(nameHint, strict);
  }

  // List all output devices that look like routable machine MIDI ports.
  public static void listOutputs() {
    System.out.println("MIDI outputs openable by this sketch:");
    MidiDevice.Info[] infos = MidiSystem.getMidiDeviceInfo();
    int idx = 0;
    ArrayList<String> skipped = new ArrayList<String>();
    for (MidiDevice.Info info : infos) {
      OutputProbe probe = probeOutput(info);
      if (probe.available) {
        System.out.println(String.format("  %d: %s - %s [%s]", idx, info.getName(), info.getDescription(), info.getVendor()));
        idx++;
      } else if (probe.outputCandidate) {
        skipped.add(String.format("  - %s - %s [%s]: %s", info.getName(), info.getDescription(), info.getVendor(), probe.reason));
      }
    }
    if (idx == 0) System.out.println("  (no openable MIDI outputs found)");
    if (!skipped.isEmpty()) {
      System.out.println("Skipped MIDI output candidates:");
      for (String line : skipped) System.out.println(line);
    }
  }

  // Rotate to the next available output. Useful for hot-swapping IAC buses
  // mid-demo when a class laptop already has another DAW open.
  public void cycleToNext() {
    refreshOutputs();
    if (outputs.isEmpty()) {
      System.out.println("No MIDI outputs available to cycle.");
      return;
    }
    currentIndex = (currentIndex + 1) % outputs.size();
    MidiDevice.Info info = outputs.get(currentIndex);
    connectTo(info);
    System.out.println(String.format("Selected MIDI output %d/%d: %s", currentIndex + 1, outputs.size(), info.getName()));
  }

  // Human-readable current device name.
  public String getCurrentName() {
    return lastDeviceName;
  }

  public boolean isReady() {
    return recv != null;
  }

  public boolean reconnect(String nameHint, boolean strict) {
    close();
    refreshOutputs();
    connectPreferred(nameHint, strict);
    return isReady();
  }

  public boolean connectFirstAvailable() {
    close();
    refreshOutputs();
    if (outputs.isEmpty()) {
      System.out.println("No openable MIDI outputs found.");
      return false;
    }
    currentIndex = 0;
    connectTo(outputs.get(currentIndex));
    return isReady();
  }

  public void noteOn(int note, int vel) { send(ShortMessage.NOTE_ON,  note & 0x7F, vel & 0x7F); }
  public void noteOff(int note)         { send(ShortMessage.NOTE_OFF, note & 0x7F, 0); }
  public void cc(int ccNum, int val)    { send(ShortMessage.CONTROL_CHANGE, ccNum & 0x7F, val & 0x7F); }

  public void close() {
    // Close both receiver and device so we do not strand notes in SoftSynths.
    try { if (recv != null) recv.close(); } catch (Exception ignore) {}
    try { if (device != null && device.isOpen()) device.close(); } catch (Exception ignore) {}
    recv = null;
    device = null;
    lastDeviceName = "(none)";
    activeOutputInfo = null;
  }

  // ---------- Internal helpers ----------

  private void send(int command, int data1, int data2) {
    if (recv == null) return;
    try {
      ShortMessage msg = new ShortMessage();
      msg.setMessage(command, ch, data1, data2);
      recv.send(msg, -1);
    } catch (Exception e) {
      System.out.println("MIDI send error: " + e);
    }
  }

  private void refreshOutputs() {
    // Query devices each time because laptops in labs often have DAWs opening
    // and closing new virtual ports mid-session.
    outputs.clear();
    for (MidiDevice.Info info : MidiSystem.getMidiDeviceInfo()) {
      if (probeOutput(info).available) outputs.add(info);
    }
  }

  private static OutputProbe probeOutput(MidiDevice.Info info) {
    try {
      if (sameInfo(info, activeOutputInfo)) {
        return new OutputProbe(true, true, "");
      }

      MidiDevice dev = MidiSystem.getMidiDevice(info);
      int maxReceivers = dev.getMaxReceivers();
      if (maxReceivers == 0) {
        return new OutputProbe(false, false, "does not accept receivers");
      }
      if (isJavaInternalEndpoint(info)) {
        return new OutputProbe(false, true, "Java Sound internal endpoint, not a routable MIDI port");
      }

      // If this sketch already has the endpoint open, it is a real usable output.
      // Do not request another Receiver because some devices expose only one.
      boolean wasOpen = dev.isOpen();
      if (wasOpen) {
        return new OutputProbe(true, true, "");
      }

      Receiver testReceiver = null;
      try {
        dev.open();
        testReceiver = dev.getReceiver();
        return new OutputProbe(true, true, "");
      } catch (Exception e) {
        return new OutputProbe(false, true, friendlyError(e));
      } finally {
        try { if (testReceiver != null) testReceiver.close(); } catch (Exception ignore) {}
        try { if (dev.isOpen()) dev.close(); } catch (Exception ignore) {}
      }
    } catch (Exception e) {
      return new OutputProbe(false, true, friendlyError(e));
    }
  }

  private static String friendlyError(Exception e) {
    String msg = e.getMessage();
    if (msg == null || msg.trim().length() == 0) return e.getClass().getSimpleName();
    return e.getClass().getSimpleName() + ": " + msg;
  }

  private static boolean sameInfo(MidiDevice.Info a, MidiDevice.Info b) {
    if (a == null || b == null) return false;
    return a.getName().equals(b.getName())
      && a.getDescription().equals(b.getDescription())
      && a.getVendor().equals(b.getVendor())
      && a.getVersion().equals(b.getVersion());
  }

  private static boolean isJavaInternalEndpoint(MidiDevice.Info info) {
    String hay = (info.getName() + " " + info.getDescription() + " " + info.getVendor()).toLowerCase();
    return hay.contains("gervill")
      || hay.contains("real time sequencer")
      || hay.contains("java sound")
      || (hay.contains("software midi synthesizer") && (hay.contains("openjdk") || hay.contains("oracle")));
  }

  private static class OutputProbe {
    boolean available;
    boolean outputCandidate;
    String reason;

    OutputProbe(boolean available, boolean outputCandidate, String reason) {
      this.available = available;
      this.outputCandidate = outputCandidate;
      this.reason = reason;
    }
  }

  private void connectPreferred(String nameHint, boolean strict) {
    MidiDevice.Info target = null;
    String hint = nameHint == null ? "" : nameHint.trim().toLowerCase();
    for (int i = 0; i < outputs.size(); i++) {
      MidiDevice.Info info = outputs.get(i);
      String hay = (info.getName() + " " + info.getDescription() + " " + info.getVendor()).toLowerCase();
      if (!hint.isEmpty() && hay.contains(hint)) {
        target = info;
        currentIndex = i;
        break;
      }
    }
    if (target == null && !strict && !outputs.isEmpty()) {
      target = outputs.get(0);
      currentIndex = 0;
    }

    if (target != null) {
      connectTo(target);
    } else if (!strict) {
      try {
        recv = MidiSystem.getReceiver();
        device = null;
        lastDeviceName = "System default receiver";
        System.out.println("MIDI -> " + lastDeviceName);
      } catch (Exception e) {
        System.out.println("No default MIDI receiver: " + e);
      }
    } else {
      System.out.println("MIDI disabled (no matching output device).");
    }
  }

  private void connectTo(MidiDevice.Info info) {
    close();
    if (info == null) return;
    try {
      MidiDevice dev = MidiSystem.getMidiDevice(info);
      dev.open();
      recv = dev.getReceiver();
      device = dev;
      lastDeviceName = info.getName();
      activeOutputInfo = info;
      System.out.println("MIDI -> " + lastDeviceName);
    } catch (Exception e) {
      System.out.println("Failed to open MIDI device: " + e);
    }
  }
}
