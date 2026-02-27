from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import List
from datetime import datetime, timezone
import asyncio
import cv2
import numpy as np
import urllib.request

from config.db import engine, Base
from models.sensor_position import SensorPosition  # ensure model is registered
from routes.sensor_positions import router as positions_router
from services.threat_detector import ThreatDetector

# Initialize the threat detector
threat_analyzer = ThreatDetector()

# Create DB tables on startup
Base.metadata.create_all(bind=engine)

app = FastAPI(title="AURA Sensor Dashboard")

# Global in-memory store for latest readings per sensor
latest_sensor_data = {}

# ----------------------------
# DroidCam Background Task
# ----------------------------
import os
from dotenv import load_dotenv

load_dotenv()

DROIDCAM_URL = os.getenv("DROIDCAM_URL", "http://192.168.1.4:4747/video")

# Try to load YOLOv8 model for Fire & Accident detection
FIRE_MODEL = None
try:
    from ultralytics import YOLO
    # We will use the pretrained yolov8m.pt model for now, which can detect cars, trucks, etc.
    # A true fire model would require a custom trained .pt file, but we will load yolov8m as a placeholder/base.
    FIRE_MODEL = YOLO("yolov8m.pt")
    print("Loaded YOLOv8 model successfully.")
except ImportError:
    print("Ultralytics not installed. Running without YOLO model.")
except Exception as e:
    print(f"Error loading YOLO model: {e}")

import threading

def poll_camera_fire_detection_sync():
    print(f"Starting DroidCam Fire/Accident Detection Polling on {DROIDCAM_URL}...")
    
    cap = cv2.VideoCapture(DROIDCAM_URL)
    
    while True:
        try:
            if not cap.isOpened():
                print("Reconnecting to DroidCam video stream...")
                cap.open(DROIDCAM_URL)
                import time
                time.sleep(2)
                continue

            ret, frame = cap.read()
            
            if ret and frame is not None:
                is_danger = False
                danger_type = ""
                confidence_val = 0.0
                
                if FIRE_MODEL is not None:
                    # Run YOLOv8 inference
                    results = FIRE_MODEL(frame, verbose=False)
                    
                    for r in results:
                        for box in r.boxes:
                            label = FIRE_MODEL.names[int(box.cls)]
                            conf = float(box.conf)
                            
                            # Example: check for Fire (if custom model) or cars/trucks for "accident" proxy
                            # We trigger danger if we see 'fire' or if we want to simulate an accident, 'car' with high conf in a specific zone.
                            # For hackathon purposes, we will flag 'fire', 'car', 'truck', 'bus' as potential hazards if confidence is very high.
                            if conf > 0.7:
                                if label.lower() in ["fire", "smoke", "accident", "car crash", "car", "truck"]:
                                    is_danger = True
                                    danger_type = label.upper()
                                    confidence_val = conf
                                    print(f"⚠️ DANGER DETECTED!! ({danger_type} - Confidence: {conf:.2f})")
                
                if is_danger:
                    # Push a websocket alert for the camera sensor
                    alert_payload = {
                        "sensor": "camera",
                        "value": int(confidence_val * 100),
                        "timestamp": datetime.now(timezone.utc).isoformat(),
                        "threat_level": "critical",
                        "alert": {
                            "title": f"{danger_type} DETECTED!",
                            "message": f"Camera detected {danger_type} with {confidence_val:.2f} confidence.",
                            "severity": "critical",
                            "sensor": "camera"
                        }
                    }
                    latest_sensor_data["camera"] = alert_payload
                    print(f"DEBUG: Camera Alert Sent - {danger_type}")
                    if manager:
                        asyncio.run_coroutine_threadsafe(manager.broadcast(alert_payload), loop)
                else:
                    # Notify safe state to clear alerts
                    safe_payload = {
                        "sensor": "camera",
                        "value": 0,
                        "timestamp": datetime.now().isoformat(),
                        "threat_level": "safe"
                    }
                    latest_sensor_data["camera"] = safe_payload
                    
                    if manager:
                        asyncio.run_coroutine_threadsafe(manager.broadcast(safe_payload), loop)
            else:
                print("Failed to read frame, reconnecting...")
                cap.release()
                
        except Exception as e:
            print(f"Error polling DroidCam: {e}")
            
        import time
        time.sleep(1)

@app.on_event("startup")
async def startup_event():
    global loop
    loop = asyncio.get_running_loop()
    threading.Thread(target=poll_camera_fire_detection_sync, daemon=True).start()

# ----------------------------
# CORS — allow browser connections from any origin on the LAN
# ----------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ----------------------------
# Sensor Positions REST API
# ----------------------------
app.include_router(positions_router)

# ----------------------------
# Serve frontend from /static
# ----------------------------
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/")
async def root():
    return FileResponse("static/index.html")

# ----------------------------
# Sensor Model
# ----------------------------

class LoginRequest(BaseModel):
    email: str
    password: str

class ValueOnly(BaseModel):
    value: float


# ----------------------------
# Authentication
# ----------------------------

@app.post("/login")
async def login(credentials: LoginRequest):
    # In a real app we'd verify standard DB User
    if not credentials.email or not credentials.password:
        return {"status": "error", "message": "Missing credentials"}
    
    # Check dummy combination or let anything in for demo
    user_name = credentials.email.split('@')[0].replace('.', ' ').title()
    if not user_name: user_name = "Aura Responder"

    return {
        "status": "success",
        "token": "aura-session-token-12345",
        "user": {
            "name": user_name,
            "email": credentials.email,
            "role": "Premium Member",
            "region": "Kerala Region",
            "id": "893-221"
        }
    }


# ----------------------------
# WebSocket Manager
# ----------------------------

class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        for connection in self.active_connections:
            await connection.send_json(message)


manager = ConnectionManager()


# ----------------------------
# WebSocket Endpoint
# ----------------------------

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()  # keep connection alive
    except WebSocketDisconnect:
        manager.disconnect(websocket)


# ----------------------------
# Sensor Endpoints (Arduino POSTs here)
# ----------------------------

async def process_sensor(sensor_name: str, value: float):
    # Base payload structure
    payload = {
        "sensor": sensor_name,
        "value": value,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }
    
    # Analyze threat level via ThreatDetector
    alert = threat_analyzer.analyze(sensor_name, value)
    
    if alert:
        payload["threat_level"] = alert["severity"]
        if alert["severity"] in ["warning", "critical"]:
            payload["alert"] = alert
    else:
        payload["threat_level"] = "safe"

    latest_sensor_data[sensor_name] = payload
    print(f"DEBUG: Received {sensor_name}: {value} | Threat: {payload.get('threat_level')}")
    await manager.broadcast(payload)  # push to all WebSocket clients (map)


@app.get("/sensor/all-data")
async def get_sensor_data():
    return list(latest_sensor_data.values())


@app.post("/sensor/temperature")
async def temperature(data: ValueOnly):
    await process_sensor("temperature", data.value)
    return {"status": "ok"}

@app.post("/sensor/earthquake")
async def earthquake(data: ValueOnly):
    await process_sensor("earthquake", data.value)
    return {"status": "ok"}

@app.post("/sensor/humidity")
async def humidity(data: ValueOnly):
    await process_sensor("humidity", data.value)
    return {"status": "ok"}


@app.post("/sensor/gas-leakage")
async def gas(data: ValueOnly):
    await process_sensor("gas-leakage", data.value)
    return {"status": "ok"}


@app.get("/evacuation/route")
async def get_evacuation_route(danger_lat: float, danger_lng: float):
    # Simulated routing around danger
    # Real app would use a routing engine like OSRM or Google Maps Directions
    # Generates a path that cuts through the danger (blocked)
    # And a path that routes around it in a semicircle (safe)
    
    offset = 0.005 # rough degree offset (~500m)
    
    start_point = [danger_lat - offset, danger_lng]
    end_point = [danger_lat + offset, danger_lng]
    
    # Blocked route goes straight through the danger point
    blocked_route = [start_point, [danger_lat, danger_lng], end_point]
    
    # Safe route curves around the danger point to the east
    safe_route = [
        start_point,
        [danger_lat - (offset/2), danger_lng + offset],
        [danger_lat, danger_lng + (offset * 1.5)],
        [danger_lat + (offset/2), danger_lng + offset],
        end_point
    ]
    
    return {
        "status": "success",
        "danger_zone": [danger_lat, danger_lng],
        "blocked_route": blocked_route,
        "safe_route": safe_route,
        "safe_exit": {
            "lat": end_point[0],
            "lng": end_point[1],
            "distance_m": int(offset * 111000 * 2),  # Rough degree-to-meter conversion
            "estimated_time_min": 3
        },
        "user_location": {
            "lat": start_point[0],
            "lng": start_point[1]
        }
    }


@app.post("/sensor/ultrasonic")
async def ultrasonic(data: ValueOnly):
    await process_sensor("ultra-sonic", data.value)
    return {"status": "ok"}


# ----------------------------
# Guide Content & Contacts API
# ----------------------------

@app.get("/guidelines")
async def get_guidelines():
    return [
        {
            "id": "ff_1",
            "threat_type": "Flash Flood",
            "title": "Immediate Actions for Flash Floods",
            "icon": "water",
            "color": "blue",
            "steps": [
                "Move immediately to higher ground.",
                "Do not walk or drive through flood waters (Turn Around, Don't Drown).",
                "Stay tuned to local weather stations and AURA alerts.",
                "Disconnect utilities and appliances if it is safe to do so."
            ]
        },
        {
            "id": "fire_1",
            "threat_type": "Structural Fire",
            "title": "Evacuation Protocol for Fires",
            "icon": "fire",
            "color": "red",
            "steps": [
                "Evacuate the building immediately using the safest route.",
                "Do not use elevators; use the stairs.",
                "If there is smoke, stay low to the ground.",
                "Call emergency services once safely outside."
            ]
        },
        {
            "id": "gas_1",
            "threat_type": "Gas Leak",
            "title": "Gas Leak Safety Guidelines",
            "icon": "warning",
            "color": "orange",
            "steps": [
                "Do not turn on or off any electrical switches.",
                "Evacuate the area immediately and leave doors open behind you.",
                "Do not use phones or lighters in the vicinity.",
                "Report the leak from a safe distance."
            ]
        },
        {
            "id": "earthquake_1",
            "threat_type": "Earthquake",
            "title": "Earthquake Safety Guidelines",
            "icon": "vibration",
            "color": "brown",
            "steps": [
                "Drop, Cover, and Hold On.",
                "Stay away from windows, glass, and heavy furniture.",
                "If outdoors, move away from buildings, streetlights, and utility wires.",
                "Do not use elevators. Wait for tremors to stop before moving."
            ]
        }
    ]

@app.get("/emergency-contacts")
async def get_emergency_contacts():
    return [
        {
            "id": "c1",
            "name": "State Emergency Relief",
            "number": "1070",
            "type": "General Emergency"
        },
        {
            "id": "c2",
            "name": "Fire & Rescue Department",
            "number": "101",
            "type": "Fire"
        },
        {
            "id": "c3",
            "name": "National Disaster Response (NDRF)",
            "number": "112",
            "type": "Disaster"
        },
        {
            "id": "c4",
            "name": "Medical Emergency (Ambulance)",
            "number": "108",
            "type": "Medical"
        }
    ]


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
