import javax.sound.midi.*;

public class MidiOut {
  private Receiver recv;
  private MidiDevice device;
  private int ch;
  public String lastDeviceName = "(none)";

  public MidiOut(String nameHint, int channel, boolean strict) {
    this.ch = Math.max(0, Math.min(15, channel));
    connect(nameHint, strict);
  }

  public void connect(String nameHint, boolean strict) {
    close();
    recv = null;

    device = findOutputDevice(nameHint);
    if (device != null) {
      try {
        device.open();
        recv = device.getReceiver();
        lastDeviceName = device.getDeviceInfo().getName();
        System.out.println("MIDI -> " + lastDeviceName);
      } catch (Exception e) {
        System.out.println("Failed to open preferred MIDI device: " + e);
      }
    }

    if (recv == null && !strict) {
      try {
        recv = MidiSystem.getReceiver();
        lastDeviceName = "System default receiver";
        System.out.println("MIDI -> " + lastDeviceName);
      } catch (Exception e) {
        System.out.println("No default MIDI receiver: " + e);
      }
    }

    if (recv == null) System.out.println("MIDI disabled (no matching output device).");
  }

  public static void listOutputs() {
    System.out.println("MIDI outputs (accept Receivers):");
    for (MidiDevice.Info info : MidiSystem.getMidiDeviceInfo()) {
      try {
        MidiDevice dev = MidiSystem.getMidiDevice(info);
        if (dev.getMaxReceivers() != 0) {
          System.out.println("  • " + info.getName() + " — " + info.getDescription() + " [" + info.getVendor() + "]");
        }
      } catch (Exception ignore) {}
    }
  }

  private MidiDevice findOutputDevice(String nameHint) {
    String hint = nameHint == null ? "" : nameHint.trim().toLowerCase();
    for (MidiDevice.Info info : MidiSystem.getMidiDeviceInfo()) {
      try {
        MidiDevice dev = MidiSystem.getMidiDevice(info);
        if (dev.getMaxReceivers() != 0) {
          String hay = (info.getName() + " " + info.getDescription() + " " + info.getVendor()).toLowerCase();
          if (hint.isEmpty() || hay.contains(hint)) return dev;
        }
      } catch (Exception ignore) {}
    }
    return null;
  }

  public void noteOn(int note, int vel) { send(ShortMessage.NOTE_ON,  note & 0x7F, vel & 0x7F); }
  public void noteOff(int note)         { send(ShortMessage.NOTE_OFF, note & 0x7F, 0); }
  public void cc(int ccNum, int val)    { send(ShortMessage.CONTROL_CHANGE, ccNum & 0x7F, val & 0x7F); }

  public void send(int command, int data1, int data2) {
    if (recv == null) return;
    try {
      ShortMessage msg = new ShortMessage();
      msg.setMessage(command, ch, data1, data2);
      recv.send(msg, -1);
    } catch (Exception e) {
      System.out.println("MIDI send error: " + e);
    }
  }

  public void close() {
    try { if (recv != null) recv.close(); } catch (Exception ignore) {}
    try { if (device != null && device.isOpen()) device.close(); } catch (Exception ignore) {}
    recv = null;
    device = null;
  }
}
