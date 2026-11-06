public final class ZoneMathTest {
  private static final float EPSILON = 0.0001f;

  private static void assertNear(float expected, float actual, String message) {
    if (Math.abs(expected - actual) > EPSILON) {
      throw new AssertionError(message + ": expected " + expected + ", got " + actual);
    }
  }

  private static void assertEquals(int expected, int actual, String message) {
    if (expected != actual) {
      throw new AssertionError(message + ": expected " + expected + ", got " + actual);
    }
  }

  private static void assertTrue(boolean condition, String message) {
    if (!condition) throw new AssertionError(message);
  }

  public static void main(String[] args) {
    ZoneMath.Bounds bounds = ZoneMath.clampBounds(Float.NaN, 99999, 1000);
    assertNear(0, bounds.loHz, "invalid lower edge clamps to zero");
    assertNear(1000, bounds.hiHz, "upper edge clamps to Nyquist");

    ZoneMath.Span span = ZoneMath.binSpan(100, 200, 1000, 11);
    assertEquals(1, span.lo, "lower boundary owns its bin");
    assertEquals(1, span.hi, "upper boundary is exclusive when it lands on a bin");
    ZoneMath.Span degenerate = ZoneMath.binSpan(200, 200, 1000, 11);
    assertEquals(2, degenerate.lo, "degenerate range remains a safe one-bin span");
    assertEquals(2, degenerate.hi, "degenerate range remains a safe one-bin span");

    ZoneMath.Span overlapA = ZoneMath.binSpan(100, 300, 1000, 11);
    ZoneMath.Span overlapB = ZoneMath.binSpan(200, 400, 1000, 11);
    assertTrue(overlapA.hi >= overlapB.lo, "overlapping zones retain independent shared bins");

    float[] spectrum = {0, 2, 4, 8, 16};
    assertNear(6, ZoneMath.sum(spectrum, new ZoneMath.Span(1, 2)), "legacy sum remains available");
    assertNear(3, ZoneMath.mean(spectrum, new ZoneMath.Span(1, 2)), "mean is bin-count normalized");
    assertNear(3, ZoneMath.mean(new float[] {2, 4}, new ZoneMath.Span(0, 1)), "same average survives a narrower bin count");

    ZoneMath.Zone zone = new ZoneMath.Zone("zone-1", "Zone 1", 100, 300, 1, 1.1f, 120, 36);
    zone.smooth = 0.9f;
    zone.armed = true;
    zone.setCenterWidth(900, 400, 1000);
    assertNear(700, zone.loHz, "center/width updates lower boundary");
    assertNear(1000, zone.hiHz, "center/width clamps at Nyquist");
    assertNear(0, zone.smooth, "zone edits reset smoothing");
    assertTrue(!zone.armed, "zone edits disarm before a release observation");

    System.out.println("PASS ZoneMathTest");
  }
}
