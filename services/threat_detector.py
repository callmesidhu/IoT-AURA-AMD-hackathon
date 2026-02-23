"""
Threat Detection Service
Real-time inference for hackathon demo.
Thresholds:
  - Gas: > 800 ppm = warning, > 1200 = critical
  - Ultrasonic: < 50 cm = warning, < 20 = critical
  - Temperature: > 30 C = warning, > 45 = critical
  - Humidity: > 60% = warning, > 85% = critical
"""
from datetime import datetime
from collections import deque

SAFE = "safe"
WARNING = "warning"
CRITICAL = "critical"

alert_history = deque(maxlen=50)

latest_sensor_values = {}


def _create_alert(sensor, severity, title, message, value):
    alert = {
        "id": len(alert_history) + 1,
        "sensor": sensor,
        "severity": severity,
        "title": title,
        "message": message,
        "value": value,
        "timestamp": datetime.utcnow().isoformat(),
        "acknowledged": False,
    }
    if severity != SAFE:
        alert_history.appendleft(alert)
    latest_sensor_values[sensor] = {"value": value, "threat_level": severity}
    return alert


class ThreatDetector:
    def __init__(self):
        print("[OK] Threat Detector initialized (all 4 sensors active)")

    def detect_temperature(self, temp_c):
        if temp_c <= 30:
            return _create_alert("temperature", SAFE,
                "Temperature Normal",
                f"Temperature at {temp_c:.1f} C -- safe range.", temp_c)
        elif temp_c <= 45:
            return _create_alert("temperature", WARNING,
                "High Temperature",
                f"Temperature elevated ({temp_c:.1f} C). Heat advisory.", temp_c)
        else:
            return _create_alert("temperature", CRITICAL,
                "EXTREME HEAT ALERT",
                f"Temperature critically high ({temp_c:.1f} C)! Possible fire!", temp_c)

    def detect_humidity(self, humidity_pct):
        if humidity_pct <= 60:
            return _create_alert("humidity", SAFE,
                "Humidity Normal",
                f"Humidity at {humidity_pct:.1f}% -- comfortable.", humidity_pct)
        elif humidity_pct <= 85:
            return _create_alert("humidity", WARNING,
                "Humidity Advisory",
                f"Humidity elevated ({humidity_pct:.1f}%). Monitor conditions.", humidity_pct)
        else:
            return _create_alert("humidity", CRITICAL,
                "HUMIDITY CRITICAL",
                f"Humidity at {humidity_pct:.1f}% -- extreme conditions!", humidity_pct)

    def detect_gas_threat(self, mq_value):
        if mq_value <= 800:
            return _create_alert("gas-leakage", SAFE,
                "Air Quality Normal",
                f"Gas level at {mq_value:.0f} ppm -- no hazard.", mq_value)
        elif mq_value <= 1200:
            return _create_alert("gas-leakage", WARNING,
                "Gas Detected -- Monitor",
                f"Elevated gas reading ({mq_value:.0f} ppm). Monitor area.", mq_value)
        else:
            return _create_alert("gas-leakage", CRITICAL,
                "SMOKE / GAS ALERT",
                f"Dangerous gas ({mq_value:.0f} ppm). Evacuate immediately!", mq_value)

    def detect_water_level(self, distance_cm):
        if distance_cm >= 50:
            return _create_alert("ultrasonic", SAFE,
                "Water Level Safe",
                f"Water at safe distance ({distance_cm:.1f} cm).", distance_cm)
        elif distance_cm >= 20:
            return _create_alert("ultrasonic", WARNING,
                "Rising Water Level",
                f"Water level rising ({distance_cm:.1f} cm). Monitor closely.", distance_cm)
        else:
            return _create_alert("ultrasonic", CRITICAL,
                "FLOOD WARNING -- EVACUATE",
                f"Critical water level ({distance_cm:.1f} cm)! Flash flood imminent!", distance_cm)

    def analyze(self, sensor_type, value):
        if sensor_type == "temperature":
            return self.detect_temperature(value)
        elif sensor_type == "humidity":
            return self.detect_humidity(value)
        elif sensor_type == "gas-leakage":
            return self.detect_gas_threat(value)
        elif sensor_type == "ultrasonic":
            return self.detect_water_level(value)
        return None
