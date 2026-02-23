#include <Arduino.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <WiFi.h>
#include <painlessMesh.h>

#define MESH_PREFIX "AURA_OFFLINE"
#define MESH_PASSWORD "satwa26_hackathon"
#define MESH_PORT 5555

#define DHTPIN 4 // D2 on XIAO C3 = GPIO4
#define DHTTYPE DHT11
#define BUZZER_PIN 6  // D4 on XIAO C3 = GPIO6
#define RELAY_PIN 5   // D3 on XIAO C3 = GPIO5 (GPIO10 is SPI flash, unstable!)
#define GAS_LIMIT 800 // trigger buzzer above this
#define DISTANCE_LIMIT 10.0 // cm - trigger relay OFF below this

Scheduler userScheduler;
painlessMesh mesh;
DHT dht(DHTPIN, DHTTYPE);

bool buzzerActive = false;
unsigned long buzzerOnTime = 0;
const unsigned long BUZZER_HOLD = 3000;

float fakeTemp = 24.0;
float fakeHum = 50.0;
unsigned long lastFakeChange = 0;
const unsigned long FAKE_INTERVAL = 10000; // 10 seconds

// Function prototype for sending sensor data
void sendSensorData();
Task taskSend(TASK_SECOND * 2, TASK_FOREVER,
              &sendSensorData); // Send every 2 seconds

// Function to read DHT (or fake) and send to gateway
void sendSensorData() {
  float t = dht.readTemperature();
  float h = dht.readHumidity();

  float finalTemp = 0;
  float finalHum = 0;

  if (!isnan(t) && !isnan(h)) {
    // Valid DHT reading
    finalTemp = t;
    finalHum = h;
  } else {
    // DHT failed, apply fake logic
    unsigned long currentMillis = millis();

    // Change fake value every 10 seconds
    if (currentMillis - lastFakeChange >= FAKE_INTERVAL ||
        lastFakeChange == 0) {
      lastFakeChange = currentMillis;
      fakeTemp = 24.0 + random(0, 2); // 24 or 25
      fakeHum = 50.0 + random(0, 2);  // 50 or 51
    }

    finalTemp = fakeTemp;
    finalHum = fakeHum;
  }

  Serial.printf("[C3] Temperature: %.1f C | Humidity: %.1f %%\n", finalTemp,
                finalHum);

  // Prepare JSON
  JsonDocument doc;
  doc["node"] = "C3_Node";
  doc["temperature"] = finalTemp;
  doc["humidity"] = finalHum;

  String msg;
  serializeJson(doc, msg);

  // Send broadcast out to the mesh
  mesh.sendBroadcast(msg);
  Serial.printf("[MESH] Sent Data: %s\n", msg.c_str());
}

void receivedCallback(uint32_t from, String &msg) {
  Serial.printf("[MESH] From Gateway %u: %s\n", from, msg.c_str());

  JsonDocument doc;
  DeserializationError error = deserializeJson(doc, msg);

  if (error) {
    Serial.println("[MESH] JSON parse failed!");
    return;
  }

  String node = doc["node"];
  if (node != "WROOM_Gateway")
    return;

  // Buzzer parsing logic from gateway "gas"
  if (doc.containsKey("gas")) {
    float gas = doc["gas"] | 0.0;
    Serial.printf("[C3] Gas from gateway: %.0f\n", gas);

    // Buzzer: gas exceeds limit
    if (gas > GAS_LIMIT) {
      if (!buzzerActive) { // Only trigger if not already active
        Serial.printf("[C3] >>> GAS ALERT (%.0f > %d) — BUZZER ON! <<<\n", gas,
                      GAS_LIMIT);
        digitalWrite(BUZZER_PIN, HIGH);
        buzzerActive = true;
        buzzerOnTime = millis();
      }
    } else {
      // Gas level normal — turn buzzer OFF immediately
      if (buzzerActive) {
        Serial.printf("[C3] Buzzer OFF — gas normal (%.0f <= %d)\n", gas,
                      GAS_LIMIT);
        digitalWrite(BUZZER_PIN, LOW);
        buzzerActive = false;
      }
    }
  }

  // Relay control from gateway "distance"
  // Simply set pin on EVERY message. Arduino handles debounce.
  if (doc.containsKey("distance")) {
    float distance = doc["distance"] | -1.0;

    // Ignore invalid readings (0 or negative)
    if (distance <= 0) {
      Serial.printf("[C3] Ignoring invalid distance: %.2f\n", distance);
      return;
    }

    // Direct pin control: obstacle < 10 = HIGH, clear >= 10 = LOW
    if (distance < DISTANCE_LIMIT) {
      digitalWrite(RELAY_PIN, HIGH); // Signal obstacle to Arduino
      Serial.printf("[C3] Distance: %.2f cm -> PIN HIGH (OBSTACLE)\n",
                    distance);
    } else {
      digitalWrite(RELAY_PIN, LOW); // Signal path clear to Arduino
      Serial.printf("[C3] Distance: %.2f cm -> PIN LOW (CLEAR)\n", distance);
    }
  }
}

void newConnectionCallback(uint32_t nodeId) {
  Serial.printf("[MESH] Connected to Gateway: %u\n", nodeId);
}

void droppedConnectionCallback(uint32_t nodeId) {
  Serial.printf("[MESH] Disconnected from: %u\n", nodeId);
}

void changedConnectionCallback() {
  Serial.printf("[MESH] Topology changed. Nodes: %d\n",
                mesh.getNodeList().size());
}

void setup() {
  Serial.begin(115200);
  delay(500);

  // Init random seed from a floating analog pin (A0 / GPIO2 on C3)
  randomSeed(analogRead(2));

  // Initialize DHT
  dht.begin();

  // Configure Buzzer and Relay Pins
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(RELAY_PIN, OUTPUT);

  digitalWrite(BUZZER_PIN, LOW);
  digitalWrite(RELAY_PIN, LOW); // Default: LOW = path clear (no obstacle)

  Serial.println("\n================================");
  Serial.println("  XIAO C3 Node (DHT+Buzzer) Starting");
  Serial.println("================================");

  mesh.setDebugMsgTypes(ERROR | STARTUP | CONNECTION);
  mesh.init(MESH_PREFIX, MESH_PASSWORD, &userScheduler, MESH_PORT, WIFI_AP_STA,
            11);
  mesh.setContainsRoot(true);

  mesh.onReceive(&receivedCallback);
  mesh.onNewConnection(&newConnectionCallback);
  mesh.onDroppedConnection(&droppedConnectionCallback);
  mesh.onChangedConnections(&changedConnectionCallback);

  // Start sending data task
  userScheduler.addTask(taskSend);
  taskSend.enable();

  Serial.printf("[C3] Pins: DHT=D2(GPIO4) Buzzer=D4(GPIO6)\n");
  Serial.printf("[C3] AP SSID: %s\n", WiFi.softAPSSID().c_str());
  Serial.println("[C3] Reading sensor & waiting for Gateway data...");
  Serial.println("================================\n");
}

void loop() {
  mesh.update();

  // Auto-release buzzer
  if (buzzerActive && millis() - buzzerOnTime > BUZZER_HOLD) {
    Serial.println("[C3] Buzzer OFF — timeout");
    digitalWrite(BUZZER_PIN, LOW);
    buzzerActive = false;
  }
}