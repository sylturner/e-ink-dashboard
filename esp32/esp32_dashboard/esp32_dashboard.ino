// E-ink dashboard client
//
// Speaks TRMNL's BYOS API (https://docs.trmnl.com/go/diy/byos), the same
// one TRMNL's own panels use. Wakes, asks /api/display what to show,
// downloads the image if it is new, draws it, sleeps. Everything happens
// in setup(); loop() is never reached.
//
// The device has no API key to begin with: on first boot it sends its
// MAC to /api/setup and stores the key it gets back in flash. One
// firmware image therefore covers every panel.
//
// Libraries: GxEPD2, ArduinoJson (v7).
//
// secrets.h must define:
//   WIFI_NAME, WIFI_PASSWORD, SERVER_BASE_URL
// e.g.
//   #define SERVER_BASE_URL "http://nastier.local:3000"

#include <WiFi.h>
#include <HTTPClient.h>
#include <SPI.h>
#include <ArduinoJson.h>
#include <GxEPD2_BW.h>
#include <gdey/GxEPD2_750_GDEY075T7.h>
#include <esp_sleep.h>
#include <driver/rtc_io.h>
#include <Preferences.h>
#include "secrets.h"
#include "types.h"

#define FIRMWARE_VERSION "3.0.0"
#define DEVICE_MODEL "esp32_dashboard"
#define TEST_MODE 0

// ---------- Wiring ----------
constexpr int PIN_PWR    = 6;
constexpr int PIN_BUSY   = 7;
constexpr int PIN_RST    = 8;
constexpr int PIN_DC     = 9;
constexpr int PIN_CS     = 10;
constexpr int PIN_DIN    = 11;  // SPI MOSI
constexpr int PIN_CLK    = 12;  // SPI SCK
constexpr int PIN_BUTTON = 4;   // must be an RTC-capable GPIO for ext0 wake

// Set to an ADC pin wired to a 2:1 divider on the battery, or -1 to skip.
constexpr int PIN_BATTERY = -1;
constexpr float BATTERY_DIVIDER = 2.0f;

// ---------- Panel ----------
constexpr uint16_t SCREEN_WIDTH  = 800;
constexpr uint16_t SCREEN_HEIGHT = 480;
constexpr size_t ROW_BYTES    = SCREEN_WIDTH / 8;          // 100
constexpr size_t BITMAP_BYTES = ROW_BYTES * SCREEN_HEIGHT; // 48,000

// ---------- Timing ----------
constexpr uint32_t WIFI_TIMEOUT_MS   = 20000;
constexpr uint32_t HTTP_TIMEOUT_MS   = 20000;
constexpr uint32_t LONG_PRESS_MS     = 900;
constexpr uint32_t BUTTON_SETTLE_MS  = 40;

constexpr uint32_t DEFAULT_SLEEP_S = 900;
constexpr uint32_t MIN_SLEEP_S     = 60;
constexpr uint32_t MAX_SLEEP_S     = 6UL * 60UL * 60UL;
constexpr uint32_t RETRY_SLEEP_S   = 300;
constexpr uint32_t MAX_BACKOFF_S   = 3600;

// Held open on cold boot and reset only, so there's a window to grab the
// USB port before the sketch sleeps and the port disappears.
constexpr uint32_t BOOT_HOLD_MS = 5000;

// Draw a splash on boot so a reset gives immediate visual confirmation
// the device is alive, before Wi-Fi has had a chance to fail. Costs one
// extra panel refresh, but only on boot, never on a scheduled wake.
#define SHOW_BOOT_SPLASH 1

// ---------- State that survives deep sleep ----------
// The API key lives in flash, not RTC memory: RTC_DATA_ATTR is cleared on
// power loss, so a battery swap would silently re-register the panel.
Preferences prefs;
String apiKey;

RTC_DATA_ATTR uint32_t bootCount     = 0;
RTC_DATA_ATTR uint32_t failureCount  = 0;
// The server's name for the image on the panel. It changes only when the
// image does, so a matching one means there is nothing to download.
RTC_DATA_ATTR char     lastFilename[40] = {0};
RTC_DATA_ATTR uint8_t  apBssid[6]    = {0};
RTC_DATA_ATTR int32_t  apChannel     = 0;
RTC_DATA_ATTR bool     apKnown       = false;

GxEPD2_BW<GxEPD2_750_GDEY075T7,
          GxEPD2_750_GDEY075T7::HEIGHT / 4>
  display(GxEPD2_750_GDEY075T7(PIN_CS, PIN_DC, PIN_RST, PIN_BUSY));

WakeReason wakeReason = WAKE_BOOT;
PressKind  pressKind  = PRESS_NONE;

// =====================================================================
// Helpers
// =====================================================================

bool readExactly(Stream& input, uint8_t* destination, size_t length)
{
  size_t received = 0;
  uint32_t lastProgress = millis();

  while (received < length)
  {
    size_t count = input.readBytes(destination + received, length - received);

    if (count == 0)
    {
      if (millis() - lastProgress > HTTP_TIMEOUT_MS) return false;
      delay(10);
      continue;
    }

    received += count;
    lastProgress = millis();
  }

  return true;
}

uint16_t readU16LE(const uint8_t* bytes)
{
  return uint16_t(bytes[0]) | (uint16_t(bytes[1]) << 8);
}

uint32_t readU32LE(const uint8_t* bytes)
{
  return uint32_t(bytes[0]) |
         (uint32_t(bytes[1]) << 8) |
         (uint32_t(bytes[2]) << 16) |
         (uint32_t(bytes[3]) << 24);
}

// The server turns this into a charge percentage, so the curve lives in
// one place (Device.battery_percent_for).
float readBatteryVolts()
{
  if (PIN_BATTERY < 0) return 0.0f;

  uint32_t total = 0;
  for (int i = 0; i < 8; i++)
  {
    total += analogReadMilliVolts(PIN_BATTERY);
    delay(2);
  }

  return (total / 8.0f) * BATTERY_DIVIDER / 1000.0f;
}

// What every request says about the panel itself.
void addDeviceHeaders(HTTPClient& http)
{
  http.addHeader("ID", WiFi.macAddress());
  http.addHeader("FW-Version", FIRMWARE_VERSION);
  http.addHeader("Model", DEVICE_MODEL);
  http.addHeader("Width", String(SCREEN_WIDTH));
  http.addHeader("Height", String(SCREEN_HEIGHT));
}

void beginRequest(HTTPClient& http)
{
  http.setTimeout(HTTP_TIMEOUT_MS);
  http.setConnectTimeout(HTTP_TIMEOUT_MS);
}

// =====================================================================
// Display
// =====================================================================

void showMessage(const char* title, const String& detail)
{
  display.setFullWindow();
  display.firstPage();

  do
  {
    display.fillScreen(GxEPD_WHITE);
    display.drawRect(20, 20, 760, 440, GxEPD_BLACK);

    display.setTextColor(GxEPD_BLACK);
    display.setTextSize(4);
    display.setCursor(55, 150);
    display.print(title);

    display.setTextSize(2);
    display.setCursor(55, 240);
    display.print(detail);
  }
  while (display.nextPage());
}

// =====================================================================
// Wi-Fi
// =====================================================================

bool connectToWiFi()
{
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);


  // Reusing the stored BSSID and channel skips the scan, which is
  // typically a second of radio time on every single wake.
  if (apKnown)
  {
    WiFi.begin(WIFI_NAME, WIFI_PASSWORD, apChannel, apBssid);
  }
  else
  {
    WiFi.begin(WIFI_NAME, WIFI_PASSWORD);
  }

  const uint32_t startedAt = millis();

  while (WiFi.status() != WL_CONNECTED)
  {
    if (millis() - startedAt > WIFI_TIMEOUT_MS)
    {
      if (apKnown)
      {
        // The cached AP may have moved channels. Forget it and retry
        // with a full scan once before giving up.
        Serial.println("Fast connect failed; falling back to scan");
        apKnown = false;
        WiFi.disconnect(true);
        delay(100);
        return connectToWiFi();
      }

      Serial.println("Wi-Fi timed out");
      return false;
    }

    delay(100);
  }

  memcpy(apBssid, WiFi.BSSID(), 6);
  apChannel = WiFi.channel();
  apKnown = true;

  Serial.printf("Wi-Fi up: %s  %d dBm  ch %d\n",
                WiFi.localIP().toString().c_str(),
                WiFi.RSSI(), (int)apChannel);
  Serial.print("ESP32 STA MAC Address: ");
  Serial.println(WiFi.macAddress());
  return true;
}

// =====================================================================
// Registration
// =====================================================================

bool registerDevice()
{
  HTTPClient http;
  beginRequest(http);
  if (!http.begin(String(SERVER_BASE_URL) + "/api/setup")) return false;

  addDeviceHeaders(http);

  const int status = http.GET();
  Serial.printf("Setup HTTP %d\n", status);

  if (status != HTTP_CODE_OK)
  {
    http.end();
    return false;
  }

  JsonDocument response;
  const DeserializationError error = deserializeJson(response, http.getString());
  http.end();

  if (error || (response["status"] | 0) != 200) return false;

  const String key = response["api_key"] | "";
  if (key.length() < 8 || key.length() > 128) return false;

  prefs.putString("api_key", key);
  apiKey = key;

  // The server draws the claim code on the first frame, so it is only
  // logged here rather than costing a panel refresh.
  Serial.printf("Registered; claim code %s\n", (const char*)(response["friendly_id"] | ""));
  return true;
}

// =====================================================================
// Fetch and draw
// =====================================================================

// Reads a 1-bit 800x480 BMP from the stream and draws it.
bool drawBmp(Stream& input, String& message)
{
  uint8_t header[62];
  if (!readExactly(input, header, sizeof(header)))
  {
    message = "Truncated header";
    return false;
  }

  const bool validBmp =
    header[0] == 'B' && header[1] == 'M' &&
    readU32LE(&header[10]) == 62 &&
    readU32LE(&header[18]) == SCREEN_WIDTH &&
    readU32LE(&header[22]) == SCREEN_HEIGHT &&
    readU16LE(&header[26]) == 1 &&
    readU16LE(&header[28]) == 1 &&
    readU32LE(&header[30]) == 0;

  if (!validBmp)
  {
    message = "Unexpected BMP format";
    return false;
  }

  uint8_t* bitmap = static_cast<uint8_t*>(ps_malloc(BITMAP_BYTES));
  if (bitmap == nullptr) bitmap = static_cast<uint8_t*>(malloc(BITMAP_BYTES));

  if (bitmap == nullptr)
  {
    message = "Out of memory";
    return false;
  }

  const uint16_t palette0 = header[54] + header[55] + header[56];
  const uint16_t palette1 = header[58] + header[59] + header[60];
  const bool paletteZeroIsBlack = palette0 < palette1;

  // BMP rows arrive bottom-to-top; GxEPD2 wants top-to-bottom.
  for (uint16_t row = 0; row < SCREEN_HEIGHT; row++)
  {
    uint8_t* target = bitmap + (SCREEN_HEIGHT - 1 - row) * ROW_BYTES;

    if (!readExactly(input, target, ROW_BYTES))
    {
      free(bitmap);
      message = "Incomplete image";
      return false;
    }

    if (paletteZeroIsBlack)
    {
      for (size_t i = 0; i < ROW_BYTES; i++) target[i] = ~target[i];
    }
  }

  Serial.println("Refreshing panel...");
  display.setFullWindow();
  display.firstPage();

  do
  {
    display.fillScreen(GxEPD_WHITE);
    display.drawBitmap(0, 0, bitmap,
                       SCREEN_WIDTH, SCREEN_HEIGHT, GxEPD_BLACK);
  }
  while (display.nextPage());

  free(bitmap);
  return true;
}

bool downloadAndDraw(const String& url, String& message)
{
  HTTPClient http;
  beginRequest(http);

  if (!http.begin(url))
  {
    message = "Bad image URL";
    return false;
  }

  http.addHeader("Accept", "image/bmp");

  const int status = http.GET();
  Serial.printf("Image HTTP %d\n", status);

  if (status != HTTP_CODE_OK)
  {
    http.end();
    message = "Image HTTP " + String(status);
    return false;
  }

  const bool drawn = drawBmp(*http.getStreamPtr(), message);
  http.end();
  return drawn;
}

FetchResult fetchAndDraw()
{
  FetchResult result;
  result.sleepSeconds = DEFAULT_SLEEP_S;

  HTTPClient http;
  beginRequest(http);

  if (!http.begin(String(SERVER_BASE_URL) + "/api/display"))
  {
    result.message = "Bad URL";
    return result;
  }

  addDeviceHeaders(http);
  http.addHeader("Access-Token", apiKey);
  http.addHeader("RSSI", String(WiFi.RSSI()));

  const float volts = readBatteryVolts();
  if (volts > 0.1f) http.addHeader("Battery-Voltage", String(volts, 2));

  // A button wake makes the server render a fresh frame.
  switch (wakeReason)
  {
    case WAKE_BUTTON: http.addHeader("Update-Source", "button");     break;
    case WAKE_TIMER:  http.addHeader("Update-Source", "timer");      break;
    default:          http.addHeader("Update-Source", "powercycle"); break;
  }

  // TRMNL's double-click; here, a long press. The server answers by
  // switching to the next dashboard.
  if (pressKind == PRESS_LONG) http.addHeader("special_function", "true");

  const int status = http.GET();
  Serial.printf("Display HTTP %d\n", status);

  if (status != HTTP_CODE_OK)
  {
    http.end();
    result.message = "HTTP " + String(status);
    return result;
  }

  JsonDocument response;
  const DeserializationError error = deserializeJson(response, http.getString());
  http.end();

  if (error)
  {
    result.message = "Unreadable response";
    return result;
  }

  const uint32_t requested = response["refresh_rate"] | 0;
  if (requested >= MIN_SLEEP_S && requested <= MAX_SLEEP_S)
  {
    result.sleepSeconds = requested;
  }

  const int apiStatus = response["status"] | -1;

  // Nothing to show yet: leave the panel alone and ask again later.
  if (apiStatus == 202)
  {
    result.ok = true;
    result.unchanged = true;
    return result;
  }

  // The server does not know this key -- the device row was deleted.
  // Drop it and register again on the next wake rather than failing forever.
  if (apiStatus == 500)
  {
    Serial.println("API key rejected; clearing for re-registration");
    prefs.remove("api_key");
    apiKey = "";
    result.message = "Re-registering";
    return result;
  }

  if (apiStatus != 0)
  {
    result.message = "Status " + String(apiStatus);
    return result;
  }

  const String imageUrl = response["image_url"] | "";
  const String filename = response["filename"] | "";

  // A press always redraws, so the person pressing sees the panel respond.
  if (pressKind == PRESS_NONE && filename.length() > 0 && filename == lastFilename)
  {
    result.ok = true;
    result.unchanged = true;
    Serial.println("Unchanged; skipping panel refresh");
    return result;
  }

  if (imageUrl.length() == 0)
  {
    result.message = "No image";
    return result;
  }

  if (!downloadAndDraw(imageUrl, result.message)) return result;

  // A name too long to keep is forgotten, so it can't match a stale one.
  if (filename.length() < sizeof(lastFilename))
  {
    strncpy(lastFilename, filename.c_str(), sizeof(lastFilename) - 1);
    lastFilename[sizeof(lastFilename) - 1] = '\0';
  }
  else
  {
    lastFilename[0] = '\0';
  }

  result.ok = true;
  return result;
}

// =====================================================================
// Button
// =====================================================================

// Woken by ext0 on a falling edge, so the button is down right now.
// Measure how long it stays down to tell short from long.
PressKind classifyPress()
{
  delay(BUTTON_SETTLE_MS);
  if (digitalRead(PIN_BUTTON) == HIGH) return PRESS_NONE;

  const uint32_t startedAt = millis();

  while (digitalRead(PIN_BUTTON) == LOW)
  {
    if (millis() - startedAt >= LONG_PRESS_MS)
    {
      Serial.println("Long press: next dashboard");
      // Wait for release so the press isn't re-read on the next wake.
      while (digitalRead(PIN_BUTTON) == LOW) delay(10);
      return PRESS_LONG;
    }
    delay(10);
  }

  Serial.println("Short press: force refresh");
  return PRESS_SHORT;
}

// =====================================================================
// Sleep
// =====================================================================

void sleepFor(uint32_t seconds)
{
  #if TEST_MODE
    Serial.printf("TEST_MODE: would sleep %lu s — staying awake\n",
                (unsigned long)seconds);
    Serial.flush();
  while (true) delay(1000);
  #endif

  if (seconds < MIN_SLEEP_S) seconds = MIN_SLEEP_S;
  if (seconds > MAX_SLEEP_S) seconds = MAX_SLEEP_S;

  Serial.printf("Sleeping %lu s\n", (unsigned long)seconds);
  Serial.flush();

  display.hibernate();

  WiFi.disconnect(true);
  WiFi.mode(WIFI_OFF);

  // E-ink holds its image with no power, so cut the panel rail.
  digitalWrite(PIN_PWR, LOW);

  const gpio_num_t wakePin = (gpio_num_t)PIN_BUTTON;
  rtc_gpio_pullup_en(wakePin);
  rtc_gpio_pulldown_dis(wakePin);
  esp_sleep_enable_ext0_wakeup(wakePin, 0);  // wake on LOW

  esp_sleep_enable_timer_wakeup((uint64_t)seconds * 1000000ULL);
  esp_deep_sleep_start();
}

// =====================================================================
// Main
// =====================================================================

void setup()
{
  Serial.begin(115200);
  uint32_t serialWait = millis();
  while (!Serial && millis() - serialWait < 3000) delay(10);
  delay(200);

  bootCount++;

  switch (esp_sleep_get_wakeup_cause())
  {
    case ESP_SLEEP_WAKEUP_TIMER: wakeReason = WAKE_TIMER;  break;
    case ESP_SLEEP_WAKEUP_EXT0:  wakeReason = WAKE_BUTTON; break;
    default:                     wakeReason = WAKE_BOOT;   break;
  }

  Serial.printf("\nBoot %lu, wake=%d\n", (unsigned long)bootCount, wakeReason);

  if (wakeReason == WAKE_BOOT)
  {
    // RTC memory survives a reset, not just deep sleep. Without clearing
    // the last filename, pressing RESET finds the image unchanged and the
    // panel never redraws -- so a reset looks like it did nothing.
    lastFilename[0] = '\0';
    failureCount = 0;

    Serial.printf("Cold boot: cleared last filename, holding %lu ms for USB\n",
                  (unsigned long)BOOT_HOLD_MS);
    Serial.flush();
    delay(BOOT_HOLD_MS);
  }

  pinMode(PIN_BUTTON, INPUT_PULLUP);

  // Holding the button through a cold boot clears the stored API key, so
  // a panel can be moved to another server without a reflash.
  if (wakeReason == WAKE_BOOT && digitalRead(PIN_BUTTON) == LOW)
  {
    Serial.println("Button held at boot: clearing stored API key");
    prefs.begin("dashboard", false);
    prefs.clear();
    prefs.end();
    showMessage("Reset", "Registration cleared");
    delay(2000);
  }

  if (wakeReason == WAKE_BUTTON)
  {
    pressKind = classifyPress();
  }

  pinMode(PIN_PWR, OUTPUT);
  digitalWrite(PIN_PWR, HIGH);
  delay(200);

  SPI.begin(PIN_CLK, -1, PIN_DIN, PIN_CS);

  // Pass initial=false after a deep-sleep wake; a full re-init on every
  // cycle is slow and unnecessary.
  display.init(115200, wakeReason == WAKE_BOOT);

#if SHOW_BOOT_SPLASH
  if (wakeReason == WAKE_BOOT)
  {
    showMessage("Starting up", String("Firmware ") + FIRMWARE_VERSION);
  }
#endif

  if (!connectToWiFi())
  {
    failureCount++;
    showMessage("No Wi-Fi", String(WIFI_NAME) + " unreachable");

    uint32_t backoff = RETRY_SLEEP_S * failureCount;
    if (backoff > MAX_BACKOFF_S) backoff = MAX_BACKOFF_S;
    sleepFor(backoff);
  }

  prefs.begin("dashboard", false);
  apiKey = prefs.getString("api_key", "");

  if (apiKey.length() == 0)
  {
    showMessage("Setting up", "Registering with server");

    if (!registerDevice())
    {
      failureCount++;
      showMessage("Setup failed", "Could not register");
      sleepFor(RETRY_SLEEP_S);
    }
  }

  FetchResult result = fetchAndDraw();

  if (result.ok)
  {
    failureCount = 0;
    sleepFor(result.sleepSeconds);
  }

  failureCount++;
  Serial.printf("Fetch failed: %s\n", result.message.c_str());

  // Show the first failure and then go quiet, so a transient blip after
  // a good render doesn't repeatedly wipe a dashboard someone is reading.
  if (failureCount == 1 || wakeReason == WAKE_BOOT)
  {
    showMessage("Dashboard unavailable", result.message);
  }

  uint32_t backoff = RETRY_SLEEP_S * failureCount;
  if (backoff > MAX_BACKOFF_S) backoff = MAX_BACKOFF_S;
  sleepFor(backoff);
}

void loop()
{
  // Never reached; setup() always ends in deep sleep.
}
