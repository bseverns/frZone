#include <Arduino.h>

#include <array>
#include <cstdint>

namespace {

constexpr uint8_t kAnalogControlCount = 8;
constexpr uint8_t kButtonControlCount = 5;
constexpr uint8_t kControlCount = kAnalogControlCount + kButtonControlCount;

constexpr std::array<uint8_t, 4> kMuxSelectPins = {2, 3, 4, 5};
constexpr uint8_t kMuxAnalogPin = 26;  // GP26 / ADC0 / physical pin 31
constexpr std::array<uint8_t, kButtonControlCount> kButtonPins = {
    6, 7, 8, 9, 10};  // B0..B3, then SHIFT; all active low

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
  A1,
  A2,
  A3,
  A4,
  A5,
  A6,
  A7,
  B0,
  B1,
  B2,
  B3,
  Shift,
};

constexpr std::array<const char*, kControlCount> kControlNames = {
    "A0", "A1", "A2", "A3", "A4", "A5", "A6",
    "A7", "B0", "B1", "B2", "B3", "SHIFT"};

struct ControlEvent {
  ControlId controlId;
  EventType type;
  uint16_t value;
  uint32_t timestampMs;
};

struct AnalogState {
  bool initialized = false;
  float filtered = 0.0f;
  uint16_t lastReported = 0;
};

struct ButtonState {
  bool stablePressed = false;
  bool lastRawPressed = false;
  uint32_t lastTransitionMs = 0;
};

std::array<AnalogState, kAnalogControlCount> analogStates;
std::array<ButtonState, kButtonControlCount> buttonStates;
uint8_t currentAnalogIndex = 0;
uint32_t lastAnalogScanUs = 0;

ControlId analogControlId(uint8_t index) {
  return static_cast<ControlId>(index);
}

ControlId buttonControlId(uint8_t index) {
  return static_cast<ControlId>(kAnalogControlCount + index);
}

const char* controlName(ControlId id) {
  const uint8_t index = static_cast<uint8_t>(id);
  return index < kControlNames.size() ? kControlNames[index] : "?";
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

uint16_t readMuxAnalog(uint8_t channel) {
  selectMuxChannel(channel);
  delayMicroseconds(kMuxSettleUs);

  // Discard the first conversion after changing channels so the ADC
  // sample-and-hold does not carry charge from the previous potentiometer.
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

void scanNextAnalog(uint32_t nowUs, uint32_t nowMs) {
  if (static_cast<uint32_t>(nowUs - lastAnalogScanUs) <
      kAnalogScanIntervalUs) {
    return;
  }
  lastAnalogScanUs = nowUs;

  const uint8_t index = currentAnalogIndex;
  AnalogState& state = analogStates[index];
  const uint16_t raw = readMuxAnalog(index);

  if (!state.initialized) {
    state.filtered = static_cast<float>(raw);
    state.lastReported = raw;
    state.initialized = true;
    emitControlEvent({analogControlId(index), EventType::ValueChanged,
                      normalizeAnalog(raw), nowMs});
  } else {
    state.filtered +=
        kFilterAlpha * (static_cast<float>(raw) - state.filtered);
    const uint16_t filtered = static_cast<uint16_t>(state.filtered + 0.5f);
    const uint16_t delta = filtered > state.lastReported
                               ? filtered - state.lastReported
                               : state.lastReported - filtered;
    if (delta >= kAnalogDeadband) {
      state.lastReported = filtered;
      emitControlEvent({analogControlId(index), EventType::ValueChanged,
                        normalizeAnalog(filtered), nowMs});
    }
  }

  currentAnalogIndex =
      static_cast<uint8_t>((currentAnalogIndex + 1) % kAnalogControlCount);
}

void scanButtons(uint32_t nowMs) {
  for (uint8_t index = 0; index < kButtonControlCount; ++index) {
    ButtonState& state = buttonStates[index];
    const bool rawPressed = digitalRead(kButtonPins[index]) == LOW;

    if (rawPressed != state.lastRawPressed) {
      state.lastRawPressed = rawPressed;
      state.lastTransitionMs = nowMs;
    }

    if (rawPressed == state.stablePressed ||
        static_cast<uint32_t>(nowMs - state.lastTransitionMs) < kDebounceMs) {
      continue;
    }

    state.stablePressed = rawPressed;
    emitControlEvent(
        {buttonControlId(index),
         state.stablePressed ? EventType::Pressed : EventType::Released,
         static_cast<uint16_t>(state.stablePressed ? 65535U : 0U), nowMs});
  }
}

static_assert(kControlNames.size() == kControlCount,
              "Every physical control needs a stable event name");
static_assert(kButtonPins.size() == kButtonControlCount,
              "Every button needs a GPIO pin");

}  // namespace

void setup() {
  Serial.begin(115200);

  for (uint8_t pin : kMuxSelectPins) {
    pinMode(pin, OUTPUT);
    digitalWrite(pin, LOW);
  }
  pinMode(kMuxAnalogPin, INPUT);
  analogReadResolution(12);

  const uint32_t nowMs = millis();
  for (uint8_t index = 0; index < kButtonControlCount; ++index) {
    pinMode(kButtonPins[index], INPUT_PULLUP);
    const bool pressed = digitalRead(kButtonPins[index]) == LOW;
    buttonStates[index].stablePressed = pressed;
    buttonStates[index].lastRawPressed = pressed;
    buttonStates[index].lastTransitionMs = nowMs;
  }

  // Do not wait for a serial monitor: the physical scan must always start.
  delay(20);
  Serial.println(
      "frzone-surface stage=2 controls=A0-A7,B0-B3,SHIFT adc_bits=12");
}

void loop() {
  const uint32_t nowUs = micros();
  const uint32_t nowMs = millis();
  scanNextAnalog(nowUs, nowMs);
  scanButtons(nowMs);
}
