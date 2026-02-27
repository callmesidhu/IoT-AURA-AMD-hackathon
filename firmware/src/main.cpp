#include <Arduino.h>
#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <LiquidCrystal_I2C.h>
#include <WiFi.h>
#include <WiFiAP.h>
#include <Wire.h>
#include <painlessMesh.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>

// --- PIN DEFINITIONS ---
#define TRIG 5
#define ECHO 18
#define GAS_AO 35
#define GAS_DO 21
#define BUZZER 19
#define REDLED 2

// --- WIFI CREDENTIALS ---
const char *ssid = "SIM";
const char *password = "saintgitswifi";

// --- MESH CREDENTIALS (Matches C3 exactly!) ---
#define MESH_PREFIX "AURA_OFFLINE"
#define MESH_PASSWORD "satwa26_hackathon"
#define MESH_PORT 5555

// --- FASTAPI SERVER BASE URL ---
const char *serverBase = "http://10.10.168.229:8000";

// --- HARDWARE OBJECTS ---
LiquidCrystal_I2C lcd(0x27, 16, 2);
Adafruit_MPU6050 mpu;

long duration;
float distance;

// Cached sensor values from the mesh (C3)
float receivedTemp = NAN;
float receivedHum = NAN;

Scheduler userScheduler;
painlessMesh mesh;

unsigned long previousMillis = 0;
const long interval =
    10000; // 10 seconds — gives mesh breathing room between HTTP bursts
int httpFailCount = 0; // Track consecutive failures

// HTTP send queue — stores "endpoint|json" pairs to prevent blocking
// mesh.update()
String httpQueue[20];
int httpQueueHead = 0;
int httpQueueTail = 0;

void queuePost(String endpoint, String json) {
  int next = (httpQueueHead + 1) % 20;
  String entry = endpoint + "|" + json;
  if (next != httpQueueTail) {
    httpQueue[httpQueueHead] = entry;
    httpQueueHead = next;
  } else {
    Serial.println("[HTTP] Queue full — dropping oldest entry");
    httpQueueTail = (httpQueueTail + 1) % 20;
    httpQueue[httpQueueHead] = entry;
    httpQueueHead = next;
  }
}

// =========================================================
// POST HELPER — Sends JSON to a specific FastAPI endpoint
// =========================================================
void postToServer(String entry) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[HTTP] WiFi not connected — skipping POST.");
    return;
  }

  // Parse "endpoint|json" format
  int sep = entry.indexOf('|');
  if (sep < 0)
    return;
  String endpoint = entry.substring(0, sep);
  String json = entry.substring(sep + 1);

  String fullURL = String(serverBase) + endpoint;

  // Skip HTTP if server has been unresponsive (protect mesh from repeated
  // timeouts)
  if (httpFailCount >= 3) {
    httpFailCount = 0; // Reset and try again next cycle
    Serial.println("[HTTP] Server unresponsive — skipping to protect mesh");
    return;
  }

  HTTPClient http;
  http.setTimeout(1500); // 1.5s max — mesh dies if we block longer
  http.begin(fullURL);
  http.addHeader("Content-Type", "application/json");

  Serial.printf("[HTTP] POST %s : %s\n", endpoint.c_str(), json.c_str());
  int code = http.POST(json);

  if (code > 0) {
    Serial.printf("[HTTP] Response: %d\n", code);
    httpFailCount = 0; // Reset on success
  } else {
    Serial.printf("[HTTP] Error: %s\n", http.errorToString(code).c_str());
    httpFailCount++;
  }

  http.end();
}

// Helper to queue sensor data
void sendData(const char *endpoint, float value) {
  String json = "{\"value\":" + String(value, 2) + "}";
  queuePost(String(endpoint), json);
}

// =========================================================
// ULTRASONIC READER — 5 stable averaged readings
// =========================================================
float readUltrasonic() {
  float total = 0;
  int count = 0;

  for (int i = 0; i < 5; i++) {
    mesh.update();

    digitalWrite(TRIG, LOW);
    delayMicroseconds(2);
    digitalWrite(TRIG, HIGH);
    delayMicroseconds(10);
    digitalWrite(TRIG, LOW);

    duration = pulseIn(ECHO, HIGH, 30000);
    float d = duration * 0.0343 / 2;

    if (d > 0 && d < 400) {
      total += d;
      count++;
    }
    delay(10);
  }

  return (count > 0) ? (total / count) : 0;
}

// =========================================================
// MESH RECEIVER — Catches C3 Data & Formats for FastAPI
// =========================================================
void receivedCallback(uint32_t from, String &msg) {
  // Comment this out if it prints too much! It shows incoming raw C3 data.
  Serial.printf("\n[MESH] Received from %u: %s\n", from, msg.c_str());

  JsonDocument doc;
  DeserializationError error = deserializeJson(doc, msg);

  if (!error && doc["node"] == "C3_Node") {
    // Cache the sensor data coming from C3 so the main loop can send it
    if (doc.containsKey("temperature")) {
      receivedTemp = doc["temperature"];
    }
    if (doc.containsKey("humidity")) {
      receivedHum = doc["humidity"];
    }
  }
}

void newConnectionCallback(uint32_t nodeId) {
  Serial.printf("\n>>> [MESH SUCCESS] New Scout node connected: %u <<<\n",
                nodeId);
}

void droppedConnectionCallback(uint32_t nodeId) {
  Serial.printf("\n>>> [MESH WARNING] Node disconnected: %u <<<\n", nodeId);
}

void changedConnectionCallback() {
  Serial.printf("[MESH] Topology changed. Nodes: %d\n",
                mesh.getNodeList().size());
}

// =========================================================
// SETUP
// =========================================================
void setup() {
  Serial.begin(115200);
  delay(1000);

  // --- Sensor & Output Pins ---
  pinMode(TRIG, OUTPUT);
  pinMode(ECHO, INPUT);
  pinMode(GAS_AO, INPUT);
  pinMode(GAS_DO, INPUT);
  pinMode(BUZZER, OUTPUT);
  pinMode(REDLED, OUTPUT);

  Serial.println("\n================================");
  Serial.println("  ESP32 AURA Gateway Starting...");
  Serial.println("================================");

  // 1. Connect WiFi FIRST to lock onto channel (manual STA control)
  WiFi.mode(WIFI_AP_STA);
  delay(100);
  Serial.printf("[WiFi] Connecting to: %s\n", ssid);
  WiFi.begin(ssid, password);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  Serial.println();

  int wifiChannel = WiFi.channel();
  if (wifiChannel == 0)
    wifiChannel = 11; // Fallback to known channel

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("[WiFi] Connected! IP: %s | Channel: %d\n",
                  WiFi.localIP().toString().c_str(), wifiChannel);
  } else {
    Serial.printf("[WiFi] Not yet connected — will retry. Using channel %d\n",
                  wifiChannel);
  }

  // 2. Start mesh as AP-ONLY on the same channel
  //    WiFi.begin() controls STA, mesh controls AP — no conflict!
  mesh.setDebugMsgTypes(ERROR | STARTUP | CONNECTION);
  mesh.init(MESH_PREFIX, MESH_PASSWORD, &userScheduler, MESH_PORT, WIFI_AP,
            wifiChannel);

  mesh.onReceive(&receivedCallback);
  mesh.onNewConnection(&newConnectionCallback);
  mesh.onDroppedConnection(&droppedConnectionCallback);
  mesh.onChangedConnections(&changedConnectionCallback);
  mesh.setRoot(true);
  mesh.setContainsRoot(true);

  Serial.printf("[Mesh] AP SSID: %s | AP IP: %s | Channel: %d\n",
                WiFi.softAPSSID().c_str(), WiFi.softAPIP().toString().c_str(),
                wifiChannel);

  // 3. Initialize I2C LCD
  Wire.begin(4, 22);
  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("AURA Gateway");
  lcd.setCursor(0, 1);
  lcd.print("Ch");
  lcd.print(wifiChannel);
  lcd.print(" Active");

  delay(1000);
  lcd.clear();

  // 4. Initialize MPU6050
  if (!mpu.begin()) {
    Serial.println("Failed to find MPU6050 chip");
  } else {
    Serial.println("MPU6050 Found!");
    mpu.setAccelerometerRange(MPU6050_RANGE_8_G);
    mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);
  }

  Serial.println("================================\n");
}

// =========================================================
// LOOP
// =========================================================
void loop() {
  mesh.update();

  // Auto-reconnect WiFi (non-blocking — just triggers reconnect, no waiting)
  static unsigned long lastWifiCheck = 0;
  if (WiFi.status() != WL_CONNECTED && millis() - lastWifiCheck > 15000) {
    lastWifiCheck = millis();
    Serial.println("[WiFi] Reconnecting...");
    WiFi.begin(ssid, password);
  }

  // Process ONE queued HTTP POST per loop cycle
  if (httpQueueTail != httpQueueHead) {
    mesh.update();
    postToServer(httpQueue[httpQueueTail]);
    httpQueueTail = (httpQueueTail + 1) % 20;
    mesh.update();
  }

  // 10-Second Non-Blocking Sensor Loop
  unsigned long currentMillis = millis();
  if (currentMillis - previousMillis >= interval) {
    previousMillis = currentMillis;

    // --- Read Local Sensors (WROOM) ---
    float gasValue = analogRead(GAS_AO);
    int gasDigital = digitalRead(GAS_DO);
    distance = readUltrasonic();

    // Read MPU6050
    sensors_event_t a, g, temp;
    mpu.getEvent(&a, &g, &temp);
    float magnitude = sqrt(a.acceleration.x * a.acceleration.x + 
                           a.acceleration.y * a.acceleration.y + 
                           a.acceleration.z * a.acceleration.z);
    float earthquake_mag = abs(magnitude - 9.81); // Deviation from 1G

    // --- Get variables received from Mesh (C3) ---
    float temperature = receivedTemp;
    float humidity = receivedHum;

    // --- Serial Output ---
    Serial.println("\n------ SENSOR DATA ------");
    Serial.printf("Temp (from C3)  : %.1f C\n", temperature);
    Serial.printf("Humid(from C3)  : %.1f %%\n", humidity);
    Serial.printf("Gas (AO)        : %.0f\n", gasValue);
    Serial.printf("Gas (DO)        : %d\n", gasDigital);
    Serial.printf("Distance        : %.2f cm\n", distance);
    Serial.printf("Earthquake Dev  : %.2f m/s2\n", earthquake_mag);
    Serial.printf("Mesh nodes      : %d\n", mesh.getNodeList().size());
    Serial.println("-------------------------");

    // --- Broadcast sensor data to mesh (C3 listens for this to trigger buzzer)
    // ---
    {
      JsonDocument meshDoc;
      meshDoc["node"] = "WROOM_Gateway";
      meshDoc["distance"] = distance;
      meshDoc["gas"] = gasValue;
      String meshMsg;
      serializeJson(meshDoc, meshMsg);
      mesh.sendBroadcast(meshMsg);
      Serial.printf("[MESH] Broadcast: %s\n", meshMsg.c_str());
    }

    // --- LCD Display ---
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("T:");
    if (!isnan(temperature)) {
      lcd.print(temperature, 1);
      lcd.print("C H:");
      lcd.print(humidity, 0);
    } else {
      lcd.print("--C H:--");
    }
    lcd.print("%");

    lcd.setCursor(0, 1);
    lcd.print("D:");
    lcd.print(distance, 0);
    lcd.print(" G:");
    lcd.print((int)gasValue);

    // --- Alert Logic ---
    bool danger = false;

    if (distance > 0 && distance < 10) {
      danger = true;
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("Obstacle Alert!");
      lcd.setCursor(0, 1);
      lcd.print("Dist: ");
      lcd.print(distance, 1);
      lcd.print("cm");
    }

    if (gasDigital == HIGH) {
      danger = true;
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("Gas Leak Alert!");
      lcd.setCursor(0, 1);
      lcd.print("Val: ");
      lcd.print((int)gasValue);
    }

    if (!isnan(temperature) && temperature > 45) {
      danger = true;
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("High Temp Alert!");
      lcd.setCursor(0, 1);
      lcd.print(temperature, 1);
      lcd.print("C");
    }

    if (earthquake_mag > 2.0) {
      danger = true;
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("Earthquake!");
      lcd.setCursor(0, 1);
      lcd.print("Mag: ");
      lcd.print(earthquake_mag, 1);
    }

    // --- Buzzer & LED ---
    if (danger) {
      digitalWrite(REDLED, HIGH);
      digitalWrite(BUZZER, HIGH);
    } else {
      digitalWrite(REDLED, LOW);
      digitalWrite(BUZZER, LOW);
    }

    // --- Queue Data to FastAPI (one per endpoint) ---
    if (!isnan(temperature)) {
      sendData("/sensor/temperature", temperature);
    }

    if (!isnan(humidity)) {
      sendData("/sensor/humidity", humidity);
    }

    sendData("/sensor/gas-leakage", gasValue);
    sendData("/sensor/ultrasonic", distance);
    sendData("/sensor/earthquake", earthquake_mag);
  }
}
