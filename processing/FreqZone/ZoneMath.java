/** Dependency-free zone math used by the Processing sketch and deterministic tests. */
public final class ZoneMath {
  private ZoneMath() {}

  public static final class Bounds {
    public final float loHz;
    public final float hiHz;

    Bounds(float loHz, float hiHz) {
      this.loHz = loHz;
      this.hiHz = hiHz;
    }
  }

  /** Inclusive FFT-bin span. */
  public static final class Span {
    public final int lo;
    public final int hi;

    public Span(int lo, int hi) {
      this.lo = lo;
      this.hi = hi;
    }

    public int count() {
      return hi - lo + 1;
    }
  }

  public static class Zone {
    public final String id;
    public String label;
    public float loHz;
    public float hiHz;
    public float threshold;
    public float hysteresis;
    public int cooldownMs;
    public int midiNote;
    public float attack = 0.40f;
    public float release = 0.15f;
    public float smooth;
    public boolean armed = true;
    public long lastTrigMs = -999999;
    public boolean calibrationInvalidated;

    public Zone(String id, String label, float loHz, float hiHz, float threshold,
                float hysteresis, int cooldownMs, int midiNote) {
      this.id = id;
      this.label = label;
      this.loHz = loHz;
      this.hiHz = hiHz;
      this.threshold = threshold;
      this.hysteresis = hysteresis;
      this.cooldownMs = cooldownMs;
      this.midiNote = midiNote;
    }

    public void setCenterWidth(float centerHz, float widthHz, float nyquistHz) {
      float safeWidth = Float.isFinite(widthHz) ? Math.max(0, widthHz) : 0;
      Bounds bounds = clampBounds(centerHz - safeWidth / 2f, centerHz + safeWidth / 2f, nyquistHz);
      loHz = bounds.loHz;
      hiHz = bounds.hiHz;
      resetAfterBoundsEdit();
    }

    public void resetAfterBoundsEdit() {
      smooth = 0;
      armed = false;
      lastTrigMs = -999999;
      calibrationInvalidated = true;
    }
  }

  public static Bounds clampBounds(float loHz, float hiHz, float nyquistHz) {
    float maxHz = Float.isFinite(nyquistHz) && nyquistHz > 0 ? nyquistHz : 0;
    float lo = Float.isFinite(loHz) ? Math.max(0, Math.min(loHz, maxHz)) : 0;
    float hi = Float.isFinite(hiHz) ? Math.max(0, Math.min(hiHz, maxHz)) : maxHz;
    if (hi < lo) {
      float swap = lo;
      lo = hi;
      hi = swap;
    }
    return new Bounds(lo, hi);
  }

  /**
   * Converts Hz to an inclusive span. The upper edge is exclusive except for
   * the Nyquist edge, so adjacent zones do not double-own a boundary bin.
   */
  public static Span binSpan(float loHz, float hiHz, float nyquistHz, int specSize) {
    if (specSize < 1) return new Span(0, 0);
    Bounds bounds = clampBounds(loHz, hiHz, nyquistHz);
    if (nyquistHz <= 0) return new Span(0, 0);
    float binsPerHz = (specSize - 1) / nyquistHz;
    int lo = clamp((int)Math.floor(bounds.loHz * binsPerHz), 0, specSize - 1);
    int hi = bounds.hiHz >= nyquistHz
      ? specSize - 1
      : clamp((int)Math.ceil(bounds.hiHz * binsPerHz) - 1, lo, specSize - 1);
    return new Span(lo, hi);
  }

  public static float sum(float[] spectrum, Span span) {
    if (spectrum == null || spectrum.length == 0) return 0;
    int lo = clamp(span.lo, 0, spectrum.length - 1);
    int hi = clamp(span.hi, lo, spectrum.length - 1);
    float total = 0;
    for (int i = lo; i <= hi; i++) total += spectrum[i];
    return total;
  }

  public static float mean(float[] spectrum, Span span) {
    if (spectrum == null || spectrum.length == 0) return 0;
    int lo = clamp(span.lo, 0, spectrum.length - 1);
    int hi = clamp(span.hi, lo, spectrum.length - 1);
    return sum(spectrum, new Span(lo, hi)) / (hi - lo + 1);
  }

  private static int clamp(int value, int lo, int hi) {
    return Math.max(lo, Math.min(value, hi));
  }
}
