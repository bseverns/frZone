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

  public MidiOut(String nameHint, int channel, boolean strict) {
    this.ch = Math.max(0, Math.min(15, channel));
    refreshOutputs();
    connectPreferred(nameHint, strict);
  }

  // List all devices that accept Receivers.
  public static void listOutputs() {
    System.out.println("MIDI outputs (accept Receivers):");
    for (MidiDevice.Info info : MidiSystem.getMidiDeviceInfo()) {
      try {
        MidiDevice dev = MidiSystem.getMidiDevice(info);
        if (dev.getMaxReceivers() != 0) {
          System.out.println("  - " + info.getName() + " - " + info.getDescription() + " [" + info.getVendor() + "]");
        }
      } catch (Exception ignore) {}
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
    connectTo(outputs.get(currentIndex));
  }

  // Human-readable current device name.
  public String getCurrentName() {
    return lastDeviceName;
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
      try {
        MidiDevice dev = MidiSystem.getMidiDevice(info);
        if (dev.getMaxReceivers() != 0) {
          outputs.add(info);
        }
      } catch (Exception ignore) {}
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
      System.out.println("MIDI -> " + lastDeviceName);
    } catch (Exception e) {
      System.out.println("Failed to open MIDI device: " + e);
    }
  }
}
