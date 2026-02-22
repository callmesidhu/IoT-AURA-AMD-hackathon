from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import List
from datetime import datetime

from config.db import engine, Base
from models.sensor_position import SensorPosition  # ensure model is registered
from routes.sensor_positions import router as positions_router

# Create DB tables on startup
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Satwa Sensor Dashboard")

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


@app.post("/sensor/ultra-sonic")
async def ultrasonic(data: ValueOnly):
    await process_sensor("ultra-sonic", data.value)
    return {"status": "ok"}