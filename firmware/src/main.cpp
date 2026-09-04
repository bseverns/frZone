#include <Arduino.h>

#include <array>
#include <cstdint>

namespace {

constexpr std::array<uint8_t, 4> kMuxSelectPins = {2, 3, 4, 5};
constexpr uint8_t kMuxAnalogPin = 26;  // GP26 / ADC0 / physical pin 31
constexpr uint8_t kButtonPin = 6;      // GP6 / physical pin 9, active low
constexpr uint8_t kMuxChannel = 0;

constexpr uint16_t kAdcMaximum = 4095;
constexpr uint8_t kAverageSamples = 4;
constexpr float kFilterAlpha = 0.25f;
constexpr uint16_t kAnalogDeadband = 10;
constexpr uint32_t kAnalogScanIntervalUs = 1000;
constexpr uint32_t kMuxSettleUs = 5;
constexpr uint32_t kDebounceMs = 20;

enum class EventType : uint8_t {
  ValueChanged,
  Pressed,
  Released,
};

enum class ControlId : uint8_t {
  A0 = 0,
  B0 = 8,
};

struct ControlEvent {
  ControlId controlId;
  EventType type;
  uint16_t value;
  uint32_t timestampMs;
};

bool analogInitialized = false;
float filteredAnalog = 0.0f;
uint16_t lastReportedAnalog = 0;
uint32_t lastAnalogScanUs = 0;

bool stableButtonPressed = false;
bool lastRawButtonPressed = false;
uint32_t lastButtonTransitionMs = 0;

const char* controlName(ControlId id) {
  switch (id) {
    case ControlId::A0:
      return "A0";
    case ControlId::B0:
      return "B0";
  }
  return "?";
}

const char* eventName(EventType type) {
  switch (type) {
    case EventType::ValueChanged:
      return "value";
    case EventType::Pressed:
      return "pressed";
    case EventType::Released:
      return "released";
  }
  return "unknown";
}

void emitControlEvent(const ControlEvent& event) {
  const float normalized = static_cast<float>(event.value) / 65535.0f;
  Serial.print("event t_ms=");
  Serial.print(event.timestampMs);
  Serial.print(" id=");
  Serial.print(controlName(event.controlId));
  Serial.print(" type=");
  Serial.print(eventName(event.type));
  Serial.print(" value=");
  Serial.print(event.value);
  Serial.print(" normalized=");
  Serial.println(normalized, 4);
}

void selectMuxChannel(uint8_t channel) {
  for (uint8_t bit = 0; bit < kMuxSelectPins.size(); ++bit) {
    digitalWrite(kMuxSelectPins[bit], (channel >> bit) & 0x01U);
  }
}

uint16_t readMuxAnalog() {
  selectMuxChannel(kMuxChannel);
  delayMicroseconds(kMuxSettleUs);

  // The first conversion after a mux change lets the ADC sample-and-hold settle.
  (void)analogRead(kMuxAnalogPin);

  uint32_t sum = 0;
  for (uint8_t sample = 0; sample < kAverageSamples; ++sample) {
    sum += static_cast<uint16_t>(analogRead(kMuxAnalogPin));
  }
  return static_cast<uint16_t>(sum / kAverageSamples);
}

uint16_t normalizeAnalog(uint16_t raw) {
  const uint32_t bounded = raw > kAdcMaximum ? kAdcMaximum : raw;
  return static_cast<uint16_t>((bounded * 65535UL + (kAdcMaximum / 2)) /
                               kAdcMaximum);
}

void scanAnalog(uint32_t nowUs, uint32_t nowMs) {
  if (static_cast<uint32_t>(nowUs - lastAnalogScanUs) <
      kAnalogScanIntervalUs) {
    return;
  }
  lastAnalogScanUs = nowUs;

  const uint16_t raw = readMuxAnalog();
  if (!analogInitialized) {
    filteredAnalog = static_cast<float>(raw);
    lastReportedAnalog = raw;
    analogInitialized = true;
    emitControlEvent({ControlId::A0, EventType::ValueChanged,
                      normalizeAnalog(raw), nowMs});
    return;
  }

  filteredAnalog += kFilterAlpha * (static_cast<float>(raw) - filteredAnalog);
  const uint16_t filtered = static_cast<uint16_t>(filteredAnalog + 0.5f);
  const uint16_t delta = filtered > lastReportedAnalog
                             ? filtered - lastReportedAnalog
                             : lastReportedAnalog - filtered;
  if (delta < kAnalogDeadband) {
    return;
  }

  lastReportedAnalog = filtered;
  emitControlEvent({ControlId::A0, EventType::ValueChanged,
                    normalizeAnalog(filtered), nowMs});
}

void scanButton(uint32_t nowMs) {
  const bool rawPressed = digitalRead(kButtonPin) == LOW;
  if (rawPressed != lastRawButtonPressed) {
    lastRawButtonPressed = rawPressed;
    lastButtonTransitionMs = nowMs;
  }

  if (rawPressed == stableButtonPressed ||
      static_cast<uint32_t>(nowMs - lastButtonTransitionMs) < kDebounceMs) {
    return;
  }

  stableButtonPressed = rawPressed;
  emitControlEvent({ControlId::B0,
                    stableButtonPressed ? EventType::Pressed
                                        : EventType::Released,
                    static_cast<uint16_t>(stableButtonPressed ? 65535U : 0U),
                    nowMs});
}

}  // namespace

void setup() {
  Serial.begin(115200);

  for (uint8_t pin : kMuxSelectPins) {
    pinMode(pin, OUTPUT);
    digitalWrite(pin, LOW);
  }
  pinMode(kMuxAnalogPin, INPUT);
  pinMode(kButtonPin, INPUT_PULLUP);
  analogReadResolution(12);

  stableButtonPressed = digitalRead(kButtonPin) == LOW;
  lastRawButtonPressed = stableButtonPressed;
  lastButtonTransitionMs = millis();

  // Do not wait for a serial monitor: the physical scan must always start.
  delay(20);
  Serial.println("frzone-surface stage=1 controls=A0,B0 adc_bits=12");
}

void loop() {
  const uint32_t nowUs = micros();
  const uint32_t nowMs = millis();
  scanAnalog(nowUs, nowMs);
  scanButton(nowMs);
}
