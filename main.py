from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import List
from datetime import datetime
import asyncio
import cv2
import numpy as np
import urllib.request

from config.db import engine, Base
from models.sensor_position import SensorPosition  # ensure model is registered
from routes.sensor_positions import router as positions_router

# Create DB tables on startup
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Satwa Sensor Dashboard")

# ----------------------------
# DroidCam Background Task
# ----------------------------
DROIDCAM_URL = "http://10.10.168.105:4747/video"

import os

# Try to load TensorFlow and the custom model
FIRE_MODEL = None
try:
    import tensorflow as tf
    if os.path.exists("fire_model.h5"):
        FIRE_MODEL = tf.keras.models.load_model("fire_model.h5")
        print("Loaded custom CNN fire_model.h5 successfully.")
except ImportError:
    print("TensorFlow not installed. Running without custom CNN model.")
except Exception as e:
    print(f"Error loading fire_model.h5: {e}")


async def poll_camera_fire_detection():
    print(f"Starting DroidCam Fire Detection Polling on {DROIDCAM_URL}...")
    
    # Use OpenCV VideoCapture for the stream
    cap = cv2.VideoCapture(DROIDCAM_URL)
    
    while True:
        try:
            if not cap.isOpened():
                print("Reconnecting to DroidCam video stream...")
                cap.open(DROIDCAM_URL)
                await asyncio.sleep(2)
                continue

            ret, frame = cap.read()
            
            if ret and frame is not None:
                print("Image captured from stream...")
                print("Image Reading...")
                is_fire = False
                fire_value = 0
                
                if FIRE_MODEL is not None:
                    # CNN Logic
                    img = cv2.resize(frame, (128, 128))
                    img = img / 255.0
                    img = np.expand_dims(img, axis=0)
                    prediction = FIRE_MODEL.predict(img, verbose=0)[0][0]
                    fire_value = int(prediction * 10000) # Scale to match legacy logic UI
                    
                    if prediction > 0.8:
                        is_fire = True
                        print(f"🔥 FIRE DETECTED!! (CNN Confidence: {prediction:.2f})")
                    else:
                        print(f"No fire detected. (CNN Confidence: {prediction:.2f})")
                else:
                    # Fallback HSV Logic
                    hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
                    # Reverted to stricter bounds to avoid false positives in room lighting
                    lower_bound = np.array([4, 150, 150])
                    upper_bound = np.array([25, 255, 255])
                    mask = cv2.inRange(hsv, lower_bound, upper_bound)
                    fire_pixels = cv2.countNonZero(mask)
                    total_pixels = frame.shape[0] * frame.shape[1]
                    fire_value = fire_pixels
                    
                    if fire_pixels > (total_pixels * 0.005): # reverted to 0.5%
                        is_fire = True
                        print(f"🔥 FIRE DETECTED!! ({fire_pixels} pixels via HSV)")
                    else:
                        print("No fire detected. (HSV)")
                        
                if is_fire:
                    # Push a websocket alert for the camera sensor
                    alert_payload = {
                        "sensor": "camera",
                        "value": fire_value,
                        "timestamp": datetime.utcnow().isoformat(),
                        "threat_level": "critical",
                        "alert": {
                            "title": "FIRE DETECTED!",
                            "message": "Camera detected fire flames in view.",
                            "severity": "critical",
                            "sensor": "camera"
                        }
                    }
                    if manager:
                        await manager.broadcast(alert_payload)
                else:
                    # Notify safe state to clear alerts
                    safe_payload = {
                        "sensor": "camera",
                        "value": fire_value,
                        "timestamp": datetime.utcnow().isoformat(),
                        "threat_level": "safe"
                    }
                    if manager:
                        await manager.broadcast(safe_payload)
            else:
                print("Failed to read frame, reconnecting...")
                cap.release()
                
        except Exception as e:
            print(f"Error polling DroidCam: {e}")
            
        await asyncio.sleep(1)

@app.on_event("startup")
async def startup_event():
    asyncio.create_task(poll_camera_fire_detection())

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
# Sensor Model
# ----------------------------

class ValueOnly(BaseModel):
    value: float


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
    payload = {
        "sensor": sensor_name,
        "value": value,
        "timestamp": datetime.utcnow().isoformat()
    }
    print(payload)
    await manager.broadcast(payload)  # push to all WebSocket clients (map)


@app.post("/sensor/temperature")
async def temperature(data: ValueOnly):
    await process_sensor("temperature", data.value)
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
        "safe_route": safe_route
    }


@app.post("/sensor/ultrasonic")
async def ultrasonic(data: ValueOnly):
    await process_sensor("ultra-sonic", data.value)
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
