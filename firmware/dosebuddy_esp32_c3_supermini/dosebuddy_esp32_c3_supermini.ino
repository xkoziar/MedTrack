#include <Arduino.h>
#include <ArduinoJson.h>
#include <BLE2902.h>
#include <BLEAdvertising.h>
#include <BLECharacteristic.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEService.h>
#include <Preferences.h>

#include <algorithm>
#include <climits>
#include <sys/time.h>
#include <time.h>
#include <vector>

namespace Pins {
constexpr int button = 4;
constexpr int greenLed = 6;
constexpr int redLed = 7;
constexpr int buzzer = 5;
constexpr int batteryAdc = -1;
}

constexpr bool kButtonActiveLow = true;
constexpr bool kGreenLedActiveHigh = true;
constexpr bool kRedLedActiveHigh = true;
constexpr bool kBuzzerActiveHigh = true;

constexpr char kAdvertisedName[] = "DoseBuddy";
constexpr char kBleServiceUuid[] = "8f5a3a62-47ef-4f2b-9b4d-7d716b7b2201";
constexpr char kControlCharacteristicUuid[] =
    "8f5a3a62-47ef-4f2b-9b4d-7d716b7b2202";
constexpr char kEventCharacteristicUuid[] =
    "8f5a3a62-47ef-4f2b-9b4d-7d716b7b2203";

constexpr uint32_t kButtonDebounceMs = 35;
constexpr uint32_t kLoopDelayMs = 20;
constexpr uint32_t kDemoIdleTimeoutMs = 120000;
constexpr uint32_t kStatusIntervalMs = 60000;
constexpr size_t kConfirmedHistoryLimit = 48;
constexpr size_t kPendingEventLimit = 16;
constexpr time_t kMinValidEpoch = 1735689600;

constexpr int kBatteryEmptyMv = 3300;
constexpr int kBatteryFullMv = 4200;
constexpr float kBatteryDividerRatio = 2.0f;

struct RuntimeConfig {
  String displayName = kAdvertisedName;
  std::vector<String> manualIntervals;
  std::vector<String> medicationSlots;
  int earlyConfirmationMinutes = 30;
  int lateConfirmationMinutes = 15;
  bool hasConfig = false;
};

struct PendingEvent {
  String type;
  time_t scheduledAt = 0;
  time_t confirmedAt = 0;
};

struct DemoStepDefinition {
  const char* key;
  const char* title;
  const char* description;
  const char* message;
};

constexpr DemoStepDefinition kDemoSteps[] = {
    {"waiting", "Quiet waiting",
     "DoseBuddy is idle and waiting for the next scheduled interval.",
     "Tutorial: DoseBuddy is quietly waiting for the next interval."},
    {"interval_ready", "Interval ready",
     "A gentle green preview means the current interval can be confirmed now.",
     "Tutorial: the current interval is ready to be confirmed."},
    {"confirmed", "Confirmed on time",
     "A short green confirmation means the button was pressed in time and the interval was recorded.",
     "Tutorial: the interval was confirmed on time."},
    {"already_taken", "Already confirmed",
     "A double green pattern means this interval was already confirmed earlier.",
     "Tutorial: this interval was already confirmed."},
    {"missed_alert", "Missed interval",
     "A repeated red alert means the confirmation window passed and DoseBuddy needs attention.",
     "Tutorial: the interval was missed and DoseBuddy needs attention."},
    {"needs_sync", "Needs sync",
     "A red error pattern means the device needs a fresh time or schedule sync from the app.",
     "Tutorial: DoseBuddy needs a fresh sync from the app."},
};

constexpr size_t kDemoStepCount = sizeof(kDemoSteps) / sizeof(kDemoSteps[0]);

Preferences gPreferences;
RuntimeConfig gConfig;
std::vector<time_t> gConfirmedSlots;
std::vector<PendingEvent> gPendingEvents;

BLEServer* gServer = nullptr;
BLEAdvertising* gAdvertising = nullptr;
BLECharacteristic* gControlCharacteristic = nullptr;
BLECharacteristic* gEventCharacteristic = nullptr;
bool gAdvertisingConfigured = false;

bool gDeviceConnected = false;
bool gClientReadyForNotifications = false;
bool gAlarmActive = false;
bool gLastRawButtonPressed = false;
bool gStableButtonPressed = false;
bool gDemoModeActive = false;
bool gDemoStepNotificationPending = false;
bool gDemoFinishedNotificationPending = false;

time_t gAlarmSlot = 0;
time_t gLastAlertedSlot = 0;
time_t gLastPublishedNextDue = 0;
unsigned long gLastDebounceStartedAt = 0;
unsigned long gLastStatusSentAt = 0;
unsigned long gLastDemoInteractionAt = 0;
size_t gDemoStepIndex = 0;
size_t gPendingDemoStepIndex = 0;

String currentDeviceLabel();
bool buttonIsPressed();
bool hasValidClock();
time_t currentEpoch();
void configureAdvertising();
void startAdvertising();
void loadPersistedState();
void saveConfigToPrefs();
void saveConfirmedHistoryToPrefs();
void savePendingEventsToPrefs();
bool applySyncConfig(const JsonDocument& doc);
void handleControlPayload(const String& payload);
void handleButtonPress();
void maybeRaiseMissedAlert();
void maybePublishStatus(bool force = false, const String& overrideMessage = "");
void flushPendingEvents();
void queuePendingConfirmation(time_t scheduledAt, time_t confirmedAt);
void sendEventNotification(const String& type, time_t scheduledAt, time_t confirmedAt);
void sendStatusNotification(const String& message, bool force = false);
void playConfirmationPattern();
void playAlreadyTakenPattern();
void playIntervalReadyPattern();
void playMissedPattern();
void playErrorPattern();
void playTestPattern();
void startDemoMode();
void stopDemoMode(bool notify = true);
void advanceDemoMode();
void replayDemoStep();
void activateDemoStep(size_t stepIndex);
void sendDemoStepNotification(size_t stepIndex);
void sendDemoFinishedNotification();
void allOutputsOff();

class DoseBuddyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* server) override {
    (void)server;
    gDeviceConnected = true;
    gClientReadyForNotifications = false;
  }

  void onDisconnect(BLEServer* server) override {
    (void)server;
    gDeviceConnected = false;
    gClientReadyForNotifications = false;
    gDemoModeActive = false;
    gDemoStepIndex = 0;
    allOutputsOff();
    startAdvertising();
  }
};

class DoseBuddyControlCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* characteristic) override {
    handleControlPayload(characteristic->getValue());
  }
};

void setup() {
  Serial.begin(115200);
  delay(200);

  setenv("TZ", "UTC0", 1);
  tzset();

  pinMode(Pins::button, INPUT_PULLUP);
  pinMode(Pins::greenLed, OUTPUT);
  pinMode(Pins::redLed, OUTPUT);
  pinMode(Pins::buzzer, OUTPUT);
  if (Pins::batteryAdc >= 0) {
    pinMode(Pins::batteryAdc, INPUT);
  }
  allOutputsOff();

  gPreferences.begin("dosebuddy", false);
  loadPersistedState();

  BLEDevice::init(kAdvertisedName);
  gServer = BLEDevice::createServer();
  gServer->setCallbacks(new DoseBuddyServerCallbacks());

  BLEService* service = gServer->createService(kBleServiceUuid);

  gControlCharacteristic = service->createCharacteristic(
      kControlCharacteristicUuid,
      BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_READ);
  gControlCharacteristic->setCallbacks(new DoseBuddyControlCallbacks());
  gControlCharacteristic->setValue("{}");

  gEventCharacteristic = service->createCharacteristic(
      kEventCharacteristicUuid,
      BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_READ);
  gEventCharacteristic->addDescriptor(new BLE2902());
  gEventCharacteristic->setValue("{}");

  service->start();

  gAdvertising = BLEDevice::getAdvertising();
  startAdvertising();

  maybePublishStatus(true, "DoseBuddy booted and is waiting for the app.");
}

void loop() {
  if (gDemoStepNotificationPending) {
    gDemoStepNotificationPending = false;
    sendDemoStepNotification(gPendingDemoStepIndex);
  }

  if (gDemoFinishedNotificationPending) {
    gDemoFinishedNotificationPending = false;
    sendDemoFinishedNotification();
  }

  if (gDemoModeActive) {
    if (millis() - gLastDemoInteractionAt > kDemoIdleTimeoutMs) {
      stopDemoMode(true);
      sendStatusNotification(
          "DoseBuddy tutorial timed out. The device is back in normal mode.",
          true);
    }
    delay(kLoopDelayMs);
    return;
  }

  const bool rawPressed = buttonIsPressed();
  if (rawPressed != gLastRawButtonPressed) {
    gLastRawButtonPressed = rawPressed;
    gLastDebounceStartedAt = millis();
  }

  if ((millis() - gLastDebounceStartedAt) > kButtonDebounceMs &&
      rawPressed != gStableButtonPressed) {
    gStableButtonPressed = rawPressed;
    if (gStableButtonPressed) {
      handleButtonPress();
    }
  }

  maybeRaiseMissedAlert();
  maybePublishStatus();
  delay(kLoopDelayMs);
}

bool buttonIsPressed() {
  const bool levelHigh = digitalRead(Pins::button) == HIGH;
  return kButtonActiveLow ? !levelHigh : levelHigh;
}

void setGreenLed(bool on) {
  digitalWrite(Pins::greenLed, on == kGreenLedActiveHigh ? HIGH : LOW);
}

void setRedLed(bool on) {
  digitalWrite(Pins::redLed, on == kRedLedActiveHigh ? HIGH : LOW);
}

void setBuzzer(bool on) {
  digitalWrite(Pins::buzzer, on == kBuzzerActiveHigh ? HIGH : LOW);
}

void allOutputsOff() {
  setGreenLed(false);
  setRedLed(false);
  setBuzzer(false);
}

void pulseOutputs(bool green, uint8_t count, uint16_t onMs, uint16_t offMs) {
  for (uint8_t index = 0; index < count; ++index) {
    setGreenLed(green);
    setRedLed(!green);
    setBuzzer(true);
    delay(onMs);
    allOutputsOff();
    if (index + 1 < count) {
      delay(offMs);
    }
  }
}

void playConfirmationPattern() {
  pulseOutputs(true, 1, 160, 0);
}

void playAlreadyTakenPattern() {
  pulseOutputs(true, 2, 70, 90);
}

void playIntervalReadyPattern() {
  setGreenLed(true);
  delay(300);
  allOutputsOff();
  delay(120);
  setGreenLed(true);
  delay(300);
  allOutputsOff();
}

void playMissedPattern() {
  pulseOutputs(false, 3, 140, 120);
}

void playErrorPattern() {
  pulseOutputs(false, 1, 180, 0);
}

void playTestPattern() {
  setGreenLed(true);
  setBuzzer(true);
  delay(120);
  allOutputsOff();
  delay(80);
  setRedLed(true);
  setBuzzer(true);
  delay(120);
  allOutputsOff();
}

void configureAdvertising() {
  if (gAdvertising == nullptr || gAdvertisingConfigured) {
    return;
  }

  // Keep the full local name and the 128-bit service UUID in the primary
  // advertisement so Android service-filtered scans can match the packet
  // without depending on scan-response parsing.
  BLEAdvertisementData advertisementData;
  advertisementData.setName(String(kAdvertisedName));
  advertisementData.setCompleteServices(BLEUUID(kBleServiceUuid));
  gAdvertising->setAdvertisementData(advertisementData);

  gAdvertising->setScanResponse(false);
  gAdvertising->setMinPreferred(0x06);
  gAdvertising->setMaxPreferred(0x12);
  gAdvertising->setMinInterval(0x30);
  gAdvertising->setMaxInterval(0x60);
  gAdvertisingConfigured = true;

  // Raw advertising data is configured asynchronously in the ESP32 BLE
  // stack. Configure it once during boot and give the controller a brief
  // moment before the first start so the packet shape is stable.
  delay(120);
}

void sendDemoStepNotification(size_t stepIndex) {
  if (stepIndex >= kDemoStepCount) {
    return;
  }

  const DemoStepDefinition& step = kDemoSteps[stepIndex];
  DynamicJsonDocument doc(512);
  doc["type"] = "demo_step";
  doc["stepKey"] = step.key;
  doc["title"] = step.title;
  doc["description"] = step.description;
  doc["message"] = step.message;
  doc["index"] = static_cast<int>(stepIndex + 1);
  doc["total"] = static_cast<int>(kDemoStepCount);
  notifyJsonDocument(doc);
}

void sendDemoFinishedNotification() {
  DynamicJsonDocument doc(256);
  doc["type"] = "demo_finished";
  doc["message"] =
      "DoseBuddy tutorial finished. The device is back in normal mode.";
  notifyJsonDocument(doc);
}

void activateDemoStep(size_t stepIndex) {
  if (stepIndex >= kDemoStepCount) {
    return;
  }

  gDemoStepIndex = stepIndex;
  gPendingDemoStepIndex = stepIndex;
  gDemoStepNotificationPending = true;
  gLastDemoInteractionAt = millis();
  allOutputsOff();

  switch (stepIndex) {
    case 0:
      setGreenLed(true);
      delay(180);
      allOutputsOff();
      break;
    case 1:
      playIntervalReadyPattern();
      break;
    case 2:
      playConfirmationPattern();
      break;
    case 3:
      playAlreadyTakenPattern();
      break;
    case 4:
      playMissedPattern();
      break;
    case 5:
      playErrorPattern();
      break;
    default:
      break;
  }
}

void startDemoMode() {
  gClientReadyForNotifications = true;
  gDemoModeActive = true;
  gLastDemoInteractionAt = millis();
  gAlarmActive = false;
  gAlarmSlot = 0;
  gLastAlertedSlot = 0;
  gPreferences.putLong64("lastAlert", 0);
  activateDemoStep(0);
}

void stopDemoMode(bool notify) {
  gDemoModeActive = false;
  gDemoStepIndex = 0;
  gLastDemoInteractionAt = 0;
  allOutputsOff();

  if (notify) {
    gDemoFinishedNotificationPending = true;
  }
}

void advanceDemoMode() {
  if (!gDemoModeActive) {
    startDemoMode();
    return;
  }

  const size_t nextStep = gDemoStepIndex + 1;
  if (nextStep >= kDemoStepCount) {
    stopDemoMode(true);
    return;
  }

  activateDemoStep(nextStep);
}

void replayDemoStep() {
  if (!gDemoModeActive) {
    startDemoMode();
    return;
  }

  activateDemoStep(gDemoStepIndex);
}

String currentDeviceLabel() {
  return gConfig.displayName.isEmpty() ? String(kAdvertisedName) : gConfig.displayName;
}

bool hasValidClock() {
  return currentEpoch() >= kMinValidEpoch;
}

time_t currentEpoch() {
  return time(nullptr);
}

time_t startOfLocalDay(time_t epoch) {
  struct tm info;
  localtime_r(&epoch, &info);
  info.tm_hour = 0;
  info.tm_min = 0;
  info.tm_sec = 0;
  return mktime(&info);
}

time_t makeLocalDateTime(time_t dayStart, int hour, int minute) {
  struct tm info;
  localtime_r(&dayStart, &info);
  info.tm_hour = hour;
  info.tm_min = minute;
  info.tm_sec = 0;
  return mktime(&info);
}

int isoWeekday(time_t epoch) {
  struct tm info;
  localtime_r(&epoch, &info);
  return info.tm_wday == 0 ? 7 : info.tm_wday;
}

bool parseTimeText(const String& timeText, int& hourOut, int& minuteOut) {
  int separator = timeText.indexOf(':');
  if (separator <= 0) {
    return false;
  }

  const int hour = timeText.substring(0, separator).toInt();
  const int minute = timeText.substring(separator + 1).toInt();
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return false;
  }

  hourOut = hour;
  minuteOut = minute;
  return true;
}

String normalizeTimeText(const String& timeText) {
  int hour = 0;
  int minute = 0;
  if (!parseTimeText(timeText, hour, minute)) {
    return String();
  }

  char buffer[6];
  snprintf(buffer, sizeof(buffer), "%02d:%02d", hour, minute);
  return String(buffer);
}

bool parseMedicationSlot(const String& slotText, int& weekdayOut, int& hourOut, int& minuteOut) {
  const int separator = slotText.indexOf('|');
  if (separator <= 0) {
    return false;
  }

  const int weekday = slotText.substring(0, separator).toInt();
  if (weekday < 1 || weekday > 7) {
    return false;
  }

  if (!parseTimeText(slotText.substring(separator + 1), hourOut, minuteOut)) {
    return false;
  }

  weekdayOut = weekday;
  return true;
}

String formatIsoLocal(time_t epoch) {
  if (epoch <= 0) {
    return String();
  }

  struct tm info;
  localtime_r(&epoch, &info);
  char buffer[24];
  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%S", &info);
  return String(buffer);
}

bool parseIsoLocal(const String& isoText, time_t& epochOut) {
  int year = 0;
  int month = 0;
  int day = 0;
  int hour = 0;
  int minute = 0;
  int second = 0;

  if (sscanf(isoText.c_str(), "%d-%d-%dT%d:%d:%d", &year, &month, &day, &hour,
             &minute, &second) != 6) {
    return false;
  }

  struct tm info = {};
  info.tm_year = year - 1900;
  info.tm_mon = month - 1;
  info.tm_mday = day;
  info.tm_hour = hour;
  info.tm_min = minute;
  info.tm_sec = second;

  const time_t epoch = mktime(&info);
  if (epoch <= 0) {
    return false;
  }

  epochOut = epoch;
  return true;
}

void sortAndUniqueStrings(std::vector<String>& values) {
  std::sort(values.begin(), values.end(), [](const String& left, const String& right) {
    return left < right;
  });

  values.erase(std::unique(values.begin(), values.end(), [](const String& left, const String& right) {
                  return left == right;
                }),
               values.end());
}

bool isConfirmedSlot(time_t scheduledAt) {
  return std::find(gConfirmedSlots.begin(), gConfirmedSlots.end(), scheduledAt) !=
         gConfirmedSlots.end();
}

void rememberConfirmedSlot(time_t scheduledAt) {
  if (!isConfirmedSlot(scheduledAt)) {
    gConfirmedSlots.push_back(scheduledAt);
    std::sort(gConfirmedSlots.begin(), gConfirmedSlots.end());
    while (gConfirmedSlots.size() > kConfirmedHistoryLimit) {
      gConfirmedSlots.erase(gConfirmedSlots.begin());
    }
    saveConfirmedHistoryToPrefs();
  }
}

std::vector<time_t> collectCandidateSlots(time_t anchor, int daysBefore, int daysAfter) {
  std::vector<time_t> candidates;
  if (!hasValidClock() || !gConfig.hasConfig) {
    return candidates;
  }

  const time_t anchorDay = startOfLocalDay(anchor);

  for (int offset = -daysBefore; offset <= daysAfter; ++offset) {
    const time_t dayStart = anchorDay + static_cast<time_t>(offset) * 86400;
    const int weekday = isoWeekday(dayStart);

    for (const String& interval : gConfig.manualIntervals) {
      int hour = 0;
      int minute = 0;
      if (!parseTimeText(interval, hour, minute)) {
        continue;
      }

      candidates.push_back(makeLocalDateTime(dayStart, hour, minute));
    }

    for (const String& slot : gConfig.medicationSlots) {
      int slotWeekday = 0;
      int hour = 0;
      int minute = 0;
      if (!parseMedicationSlot(slot, slotWeekday, hour, minute)) {
        continue;
      }

      if (slotWeekday != weekday) {
        continue;
      }

      candidates.push_back(makeLocalDateTime(dayStart, hour, minute));
    }
  }

  std::sort(candidates.begin(), candidates.end());
  candidates.erase(std::unique(candidates.begin(), candidates.end()), candidates.end());
  return candidates;
}

bool findActiveSlot(time_t now, time_t& slotOut) {
  const std::vector<time_t> candidates = collectCandidateSlots(now, 1, 1);
  const time_t earlyWindow = static_cast<time_t>(gConfig.earlyConfirmationMinutes) * 60;
  const time_t lateWindow = static_cast<time_t>(gConfig.lateConfirmationMinutes) * 60;

  bool found = false;
  time_t bestSlot = 0;
  long bestDiff = LONG_MAX;

  for (time_t candidate : candidates) {
    if (now < candidate - earlyWindow || now > candidate + lateWindow) {
      continue;
    }

    const long diff = labs(static_cast<long>(now - candidate));
    if (!found || diff < bestDiff) {
      found = true;
      bestDiff = diff;
      bestSlot = candidate;
    }
  }

  if (!found) {
    return false;
  }

  slotOut = bestSlot;
  return true;
}

time_t findDisplayedNextDue(time_t now) {
  time_t activeSlot = 0;
  if (findActiveSlot(now, activeSlot)) {
    return activeSlot;
  }

  const std::vector<time_t> candidates = collectCandidateSlots(now, 0, 8);
  for (time_t candidate : candidates) {
    if (candidate >= now) {
      return candidate;
    }
  }

  return 0;
}

time_t findLatestExpiredUnconfirmedSlot(time_t now) {
  const std::vector<time_t> candidates = collectCandidateSlots(now, 2, 0);
  const time_t lateWindow = static_cast<time_t>(gConfig.lateConfirmationMinutes) * 60;

  time_t latestMissed = 0;
  for (time_t candidate : candidates) {
    if (candidate <= gLastAlertedSlot) {
      continue;
    }

    if (now <= candidate + lateWindow) {
      continue;
    }

    if (isConfirmedSlot(candidate)) {
      continue;
    }

    if (candidate > latestMissed) {
      latestMissed = candidate;
    }
  }

  return latestMissed;
}

int readBatteryPercent() {
  if (Pins::batteryAdc < 0) {
    return -1;
  }

  const int raw = analogRead(Pins::batteryAdc);
  if (raw <= 0) {
    return -1;
  }

  const float millivolts =
      (static_cast<float>(raw) / 4095.0f) * 3300.0f * kBatteryDividerRatio;
  const int clampedMv = static_cast<int>(millivolts);
  const int percent = map(clampedMv, kBatteryEmptyMv, kBatteryFullMv, 0, 100);
  return constrain(percent, 0, 100);
}

void startAdvertising() {
  if (gAdvertising != nullptr) {
    configureAdvertising();
    gAdvertising->start();
  }
}

void notifyJsonDocument(const JsonDocument& doc) {
  if (!gDeviceConnected || !gClientReadyForNotifications || gEventCharacteristic == nullptr) {
    return;
  }

  String payload;
  serializeJson(doc, payload);
  gEventCharacteristic->setValue(payload);
  gEventCharacteristic->notify();
}

void sendStatusNotification(const String& message, bool force) {
  if (!gDeviceConnected || !gClientReadyForNotifications) {
    return;
  }

  DynamicJsonDocument doc(384);
  doc["type"] = "status";
  doc["message"] = message;
  doc["alarmActive"] = gAlarmActive;

  const int batteryPercent = readBatteryPercent();
  if (batteryPercent >= 0) {
    doc["batteryLevel"] = batteryPercent;
  }

  const time_t now = currentEpoch();
  const time_t nextDue = hasValidClock() ? findDisplayedNextDue(now) : 0;
  if (nextDue > 0) {
    doc["nextDueAt"] = formatIsoLocal(nextDue);
  }

  notifyJsonDocument(doc);
  if (force || nextDue != gLastPublishedNextDue) {
    gLastPublishedNextDue = nextDue;
  }
  gLastStatusSentAt = millis();
}

void sendEventNotification(const String& type, time_t scheduledAt, time_t confirmedAt) {
  DynamicJsonDocument doc(320);
  doc["type"] = type;
  doc["scheduledAt"] = formatIsoLocal(scheduledAt);
  doc["confirmedAt"] = formatIsoLocal(confirmedAt);

  const int batteryPercent = readBatteryPercent();
  if (batteryPercent >= 0) {
    doc["batteryLevel"] = batteryPercent;
  }

  notifyJsonDocument(doc);
}

void queuePendingConfirmation(time_t scheduledAt, time_t confirmedAt) {
  if (gPendingEvents.size() >= kPendingEventLimit) {
    gPendingEvents.erase(gPendingEvents.begin());
  }

  gPendingEvents.push_back({"button_confirmed", scheduledAt, confirmedAt});
  savePendingEventsToPrefs();
}

void flushPendingEvents() {
  if (!gDeviceConnected || !gClientReadyForNotifications || gPendingEvents.empty()) {
    return;
  }

  for (const PendingEvent& event : gPendingEvents) {
    sendEventNotification(event.type, event.scheduledAt, event.confirmedAt);
    delay(120);
  }

  gPendingEvents.clear();
  savePendingEventsToPrefs();
}

void maybePublishStatus(bool force, const String& overrideMessage) {
  if (!gDeviceConnected || !gClientReadyForNotifications) {
    return;
  }

  const time_t now = currentEpoch();
  const time_t nextDue = hasValidClock() ? findDisplayedNextDue(now) : 0;
  const bool dueChanged = nextDue != gLastPublishedNextDue;
  const bool statusDue = force || dueChanged || (millis() - gLastStatusSentAt) >= kStatusIntervalMs;
  if (!statusDue) {
    return;
  }

  String message = overrideMessage;
  if (message.isEmpty()) {
    if (!gConfig.hasConfig) {
      message = "DoseBuddy is waiting for a schedule.";
    } else if (!hasValidClock()) {
      message = "DoseBuddy is waiting for time sync from the app.";
    } else if (gAlarmActive) {
      message = "A scheduled interval was missed.";
    } else if (nextDue > 0) {
      const time_t earlyWindow = static_cast<time_t>(gConfig.earlyConfirmationMinutes) * 60;
      if (now >= nextDue - earlyWindow && now <= nextDue) {
        message = "A medication interval is ready now.";
      } else {
        message = currentDeviceLabel() + " is ready for the next interval.";
      }
    } else {
      message = "No interval is configured right now.";
    }
  }

  sendStatusNotification(message, force);
}

void maybeRaiseMissedAlert() {
  if (!gConfig.hasConfig || !hasValidClock()) {
    return;
  }

  const time_t now = currentEpoch();
  const time_t missedSlot = findLatestExpiredUnconfirmedSlot(now);
  if (missedSlot <= 0) {
    return;
  }

  gAlarmActive = true;
  gAlarmSlot = missedSlot;
  gLastAlertedSlot = missedSlot;
  gPreferences.putLong64("lastAlert", static_cast<int64_t>(gLastAlertedSlot));

  playMissedPattern();

  if (gDeviceConnected && gClientReadyForNotifications) {
    DynamicJsonDocument doc(256);
    doc["type"] = "missed_alert";
    doc["scheduledAt"] = formatIsoLocal(missedSlot);
    const int batteryPercent = readBatteryPercent();
    if (batteryPercent >= 0) {
      doc["batteryLevel"] = batteryPercent;
    }
    notifyJsonDocument(doc);
  }
}

void handleButtonPress() {
  if (!gConfig.hasConfig || !hasValidClock()) {
    playErrorPattern();
    maybePublishStatus(true, "DoseBuddy needs a fresh sync from the app.");
    return;
  }

  const time_t now = currentEpoch();
  time_t activeSlot = 0;
  if (!findActiveSlot(now, activeSlot)) {
    playErrorPattern();
    maybePublishStatus(true, "No interval is due right now.");
    return;
  }

  if (isConfirmedSlot(activeSlot)) {
    playAlreadyTakenPattern();
    if (gDeviceConnected && gClientReadyForNotifications) {
      sendEventNotification("already_taken", activeSlot, now);
    }
    maybePublishStatus(true, "This interval was already confirmed.");
    return;
  }

  rememberConfirmedSlot(activeSlot);
  gAlarmActive = false;
  gAlarmSlot = 0;
  gLastAlertedSlot = 0;
  gPreferences.putLong64("lastAlert", 0);

  playConfirmationPattern();

  if (gDeviceConnected && gClientReadyForNotifications) {
    sendEventNotification("button_confirmed", activeSlot, now);
  } else {
    queuePendingConfirmation(activeSlot, now);
  }

  maybePublishStatus(true, "DoseBuddy confirmed the current interval.");
}

bool applySyncConfig(const JsonDocument& doc) {
  RuntimeConfig nextConfig = gConfig;
  nextConfig.displayName = String(doc["deviceName"] | kAdvertisedName);
  nextConfig.earlyConfirmationMinutes = doc["earlyConfirmationMinutes"] | 30;
  nextConfig.lateConfirmationMinutes = doc["lateConfirmationMinutes"] | 15;
  nextConfig.manualIntervals.clear();
  nextConfig.medicationSlots.clear();

  JsonArrayConst manualIntervals = doc["manualIntervals"].as<JsonArrayConst>();
  for (JsonVariantConst value : manualIntervals) {
    const String normalized = normalizeTimeText(String(value.as<const char*>()));
    if (!normalized.isEmpty()) {
      nextConfig.manualIntervals.push_back(normalized);
    }
  }

  JsonArrayConst medicationSlots = doc["medicationSlots"].as<JsonArrayConst>();
  if (!medicationSlots.isNull()) {
    for (JsonVariantConst value : medicationSlots) {
      const String slot = String(value.as<const char*>());
      int weekday = 0;
      int hour = 0;
      int minute = 0;
      if (parseMedicationSlot(slot, weekday, hour, minute)) {
        char buffer[10];
        snprintf(buffer, sizeof(buffer), "%d|%02d:%02d", weekday, hour, minute);
        nextConfig.medicationSlots.push_back(String(buffer));
      }
    }
  } else {
    JsonArrayConst medications = doc["medications"].as<JsonArrayConst>();
    for (JsonVariantConst medicationValue : medications) {
      JsonObjectConst medication = medicationValue.as<JsonObjectConst>();
      JsonArrayConst days = medication["scheduleDays"].as<JsonArrayConst>();
      JsonArrayConst times = medication["scheduleTimes"].as<JsonArrayConst>();
      for (JsonVariantConst dayValue : days) {
        const int weekday = dayValue.as<int>();
        if (weekday < 1 || weekday > 7) {
          continue;
        }

        for (JsonVariantConst timeValue : times) {
          const String normalized = normalizeTimeText(String(timeValue.as<const char*>()));
          if (normalized.isEmpty()) {
            continue;
          }

          nextConfig.medicationSlots.push_back(String(weekday) + "|" + normalized);
        }
      }
    }
  }

  sortAndUniqueStrings(nextConfig.manualIntervals);
  sortAndUniqueStrings(nextConfig.medicationSlots);

  time_t syncedAt = 0;
  const bool synced = parseIsoLocal(String(doc["syncedAt"] | ""), syncedAt);
  if (!synced) {
    return false;
  }

  timeval tv = {};
  tv.tv_sec = syncedAt;
  tv.tv_usec = 0;
  settimeofday(&tv, nullptr);

  nextConfig.hasConfig = true;
  gConfig = nextConfig;
  saveConfigToPrefs();

  gClientReadyForNotifications = true;
  maybePublishStatus(true, "DoseBuddy synced.");
  flushPendingEvents();
  return true;
}

void handleControlPayload(const String& payload) {
  DynamicJsonDocument doc(4096);
  const DeserializationError error = deserializeJson(doc, payload);
  if (error) {
    playErrorPattern();
    maybePublishStatus(true, "DoseBuddy received invalid data.");
    return;
  }

  const String type = String(doc["type"] | "");
  if (type == "sync_config") {
    const bool applied = applySyncConfig(doc);
    if (!applied) {
      playErrorPattern();
      maybePublishStatus(true, "DoseBuddy could not apply the sync payload.");
    }
    return;
  }

  if (type == "test_signal") {
    startDemoMode();
    return;
  }

  if (type == "start_demo") {
    gClientReadyForNotifications = true;
    startDemoMode();
    return;
  }

  if (type == "demo_replay") {
    gClientReadyForNotifications = true;
    replayDemoStep();
    return;
  }

  if (type == "demo_next") {
    gClientReadyForNotifications = true;
    advanceDemoMode();
    return;
  }

  if (type == "stop_demo") {
    stopDemoMode(true);
    return;
  }

  maybePublishStatus(true, "DoseBuddy received an unknown command.");
}

void loadPersistedState() {
  const String configJson = gPreferences.getString("cfg", "");
  if (!configJson.isEmpty()) {
    DynamicJsonDocument doc(4096);
    if (deserializeJson(doc, configJson) == DeserializationError::Ok) {
      gConfig.displayName = String(doc["deviceName"] | kAdvertisedName);
      gConfig.earlyConfirmationMinutes = doc["earlyConfirmationMinutes"] | 30;
      gConfig.lateConfirmationMinutes = doc["lateConfirmationMinutes"] | 15;
      gConfig.manualIntervals.clear();
      gConfig.medicationSlots.clear();

      JsonArrayConst manualIntervals = doc["manualIntervals"].as<JsonArrayConst>();
      for (JsonVariantConst value : manualIntervals) {
        gConfig.manualIntervals.push_back(String(value.as<const char*>()));
      }

      JsonArrayConst medicationSlots = doc["medicationSlots"].as<JsonArrayConst>();
      for (JsonVariantConst value : medicationSlots) {
        gConfig.medicationSlots.push_back(String(value.as<const char*>()));
      }

      sortAndUniqueStrings(gConfig.manualIntervals);
      sortAndUniqueStrings(gConfig.medicationSlots);
      gConfig.hasConfig = true;
    }
  }

  gConfirmedSlots.clear();
  const String confirmedJson = gPreferences.getString("confirmed", "");
  if (!confirmedJson.isEmpty()) {
    DynamicJsonDocument doc(2048);
    if (deserializeJson(doc, confirmedJson) == DeserializationError::Ok) {
      JsonArrayConst confirmedArray = doc.as<JsonArrayConst>();
      for (JsonVariantConst value : confirmedArray) {
        const int64_t epoch = value.as<int64_t>();
        if (epoch > 0) {
          gConfirmedSlots.push_back(static_cast<time_t>(epoch));
        }
      }
      std::sort(gConfirmedSlots.begin(), gConfirmedSlots.end());
    }
  }

  gPendingEvents.clear();
  const String pendingJson = gPreferences.getString("pending", "");
  if (!pendingJson.isEmpty()) {
    DynamicJsonDocument doc(2048);
    if (deserializeJson(doc, pendingJson) == DeserializationError::Ok) {
      JsonArrayConst pendingArray = doc.as<JsonArrayConst>();
      for (JsonVariantConst value : pendingArray) {
        JsonObjectConst object = value.as<JsonObjectConst>();
        time_t scheduledAt = 0;
        time_t confirmedAt = 0;
        if (!parseIsoLocal(String(object["scheduledAt"] | ""), scheduledAt)) {
          continue;
        }
        if (!parseIsoLocal(String(object["confirmedAt"] | ""), confirmedAt)) {
          continue;
        }

        gPendingEvents.push_back({String(object["type"] | "button_confirmed"), scheduledAt, confirmedAt});
      }
    }
  }

  gLastAlertedSlot = static_cast<time_t>(gPreferences.getLong64("lastAlert", 0));
  if (gLastAlertedSlot > 0 && !isConfirmedSlot(gLastAlertedSlot)) {
    gAlarmActive = true;
    gAlarmSlot = gLastAlertedSlot;
  }
}

void saveConfigToPrefs() {
  DynamicJsonDocument doc(2048);
  doc["deviceName"] = gConfig.displayName;
  doc["earlyConfirmationMinutes"] = gConfig.earlyConfirmationMinutes;
  doc["lateConfirmationMinutes"] = gConfig.lateConfirmationMinutes;

  JsonArray manualIntervals = doc.createNestedArray("manualIntervals");
  for (const String& interval : gConfig.manualIntervals) {
    manualIntervals.add(interval);
  }

  JsonArray medicationSlots = doc.createNestedArray("medicationSlots");
  for (const String& slot : gConfig.medicationSlots) {
    medicationSlots.add(slot);
  }

  String json;
  serializeJson(doc, json);
  gPreferences.putString("cfg", json);
}

void saveConfirmedHistoryToPrefs() {
  DynamicJsonDocument doc(2048);
  JsonArray confirmedArray = doc.to<JsonArray>();
  for (time_t value : gConfirmedSlots) {
    confirmedArray.add(static_cast<int64_t>(value));
  }

  String json;
  serializeJson(doc, json);
  gPreferences.putString("confirmed", json);
}

void savePendingEventsToPrefs() {
  DynamicJsonDocument doc(2048);
  JsonArray pendingArray = doc.to<JsonArray>();
  for (const PendingEvent& event : gPendingEvents) {
    JsonObject object = pendingArray.createNestedObject();
    object["type"] = event.type;
    object["scheduledAt"] = formatIsoLocal(event.scheduledAt);
    object["confirmedAt"] = formatIsoLocal(event.confirmedAt);
  }

  String json;
  serializeJson(doc, json);
  gPreferences.putString("pending", json);
}