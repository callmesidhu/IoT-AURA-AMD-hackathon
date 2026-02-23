#include <Arduino.h>
#include <Stepper.h>

// --- LOGIC LEVEL SHIFTER PINS ---
#define ESP_INPUT_PIN 2 // Connect to ESP32-C3 D3 (GPIO5)
#define RELAY_OUT_PIN 3 // Connect to Relay IN

// --- STEPPER MOTOR PINS ---
#define IN1 8
#define IN2 9
#define IN3 10
#define IN4 11

const int stepsPerRevolution = 2048;
Stepper myStepper(stepsPerRevolution, IN1, IN3, IN2, IN4);

// Variables for non-blocking motor control
int motorPhase = 0;
int currentStep = 0;
unsigned long lastActionTime = 0;

// Debounce and state variables
int lastStableReading = LOW;
unsigned long lastDebounceTime = 0;
const unsigned long DEBOUNCE_MS = 500;

bool obstacleDetected = false; // Initially false (clear)

void setup() {
  Serial.begin(9600);

  // C3 sends HIGH if obstacle, LOW if clear.
  // We use INPUT_PULLUP so if wire breaks, it defaults to HIGH (obstacle/safe
  // state)
  pinMode(ESP_INPUT_PIN, INPUT_PULLUP);
  pinMode(RELAY_OUT_PIN, OUTPUT);

  // Default: NO obstacle -> Relay should NOT be active.
  // Assuming Active-LOW relay module:
  // Output HIGH = Relay De-energized (OFF)
  // Output LOW = Relay Energized (ON/Activated)
  digitalWrite(RELAY_OUT_PIN, HIGH);

  myStepper.setSpeed(10); // 10 RPM

  Serial.println("System Started");
  Serial.println("Waiting for signals from C3...");
}

void loop() {
  int currentSignal = digitalRead(ESP_INPUT_PIN);

  // Software Debounce logic
  if (currentSignal != lastStableReading) {
    lastDebounceTime = millis();
    lastStableReading = currentSignal;
  }

  // Update state if signal has been stable
  if ((millis() - lastDebounceTime) > DEBOUNCE_MS) {
    bool newObstacleState = (currentSignal == HIGH);

    if (newObstacleState != obstacleDetected) {
      obstacleDetected = newObstacleState;

      // If obstacle -> Activate Relay (LOW for active-LOW relay)
      // If clear -> Deactivate Relay (HIGH for active-LOW relay)
      int desiredRelayOutput = obstacleDetected ? LOW : HIGH;
      digitalWrite(RELAY_OUT_PIN, desiredRelayOutput);

      Serial.print("\n============= STATE CHANGE =============\n");
      Serial.print("> Obstacle Detected (<10cm): ");
      Serial.println(obstacleDetected ? "YES" : "NO");
      Serial.print("> Relay Module: ");
      Serial.println(obstacleDetected ? "ACTIVATED (ON)" : "DEACTIVATED (OFF)");
      Serial.print("> Software Motor Status: ");
      Serial.println(obstacleDetected ? "STOPPED" : "RUNNING");
      Serial.println("========================================\n");
    }
  }

  // Debug Print every 3 seconds
  static unsigned long lastPrint = 0;
  if (millis() - lastPrint > 3000) {
    lastPrint = millis();
    Serial.print("[DEBUG] Pin 2 reads: ");
    Serial.print(currentSignal == HIGH ? "HIGH" : "LOW");
    Serial.print(" | Motor is currently: ");
    Serial.println(obstacleDetected ? "STOPPED" : "RUNNING");
  }

  // ========================================================
  // 2. NON-BLOCKING STEPPER MOTOR LOGIC
  // ========================================================
  // The motor will ONLY run if NO obstacle is detected!
  if (!obstacleDetected) {
    if (motorPhase == 0) {
      myStepper.step(1);
      currentStep++;
      if (currentStep >= stepsPerRevolution) {
        currentStep = 0;
        motorPhase = 1;
        lastActionTime = millis();
        Serial.println("Clockwise done. Waiting 2 seconds.");
      }
    } else if (motorPhase == 1) {
      if (millis() - lastActionTime >= 2000) {
        motorPhase = 2;
        Serial.println("Starting Counter-Clockwise...");
      }
    } else if (motorPhase == 2) {
      myStepper.step(-1);
      currentStep++;
      if (currentStep >= stepsPerRevolution) {
        currentStep = 0;
        motorPhase = 3;
        lastActionTime = millis();
        Serial.println("Counter-Clockwise done. Waiting 2 seconds.");
      }
    } else if (motorPhase == 3) {
      if (millis() - lastActionTime >= 2000) {
        motorPhase = 0;
        Serial.println("Starting Clockwise...");
      }
    }
  }
}