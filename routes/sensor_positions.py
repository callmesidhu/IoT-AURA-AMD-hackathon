from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Optional
import hashlib
import json
import requests
from config.db import SessionLocal
from models.sensor_position import SensorPosition

router = APIRouter(prefix="/positions", tags=["positions"])


# ---------- Blockchain Integrity ----------

def generate_position_hash(pos_dict: dict, action: str) -> str:
    """Generates a SHA-256 hash for the sensor position data."""
    payload = {
        "action": action,
        "data": pos_dict
    }
    # Sort keys to ensure deterministic hash
    payload_str = json.dumps(payload, sort_keys=True)
    return hashlib.sha256(payload_str.encode('utf-8')).hexdigest()

def send_to_blockchain(sensor_id: int, data_hash: str):
    """Sends the hash to the local Rust blockchain service."""
    url = "http://localhost:3030/register"
    payload = {
        "sensor_id": sensor_id,
        "data_hash": data_hash
    }
    try:
        response = requests.post(url, json=payload, timeout=5)
        response.raise_for_status()
        print(f"✅ Blockchain sync success for sensor {sensor_id}: {response.json()}")
    except Exception as e:
        print(f"❌ Blockchain sync failed for sensor {sensor_id}: {e}")


# ---------- DB Dependency ----------

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ---------- Schemas ----------

class SensorPositionCreate(BaseModel):
    name: str
    lat: float
    lng: float
    sensor_type: str  # temperature | humidity | gas-leakage | ultra-sonic


class SensorPositionOut(BaseModel):
    id: int
    name: str
    lat: float
    lng: float
    sensor_type: str

    class Config:
        from_attributes = True


# ---------- Endpoints ----------

@router.get("", response_model=List[SensorPositionOut])
def list_positions(db: Session = Depends(get_db)):
    return db.query(SensorPosition).all()


@router.post("", response_model=SensorPositionOut)
def create_position(data: SensorPositionCreate, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    pos = SensorPosition(
        name=data.name,
        lat=data.lat,
        lng=data.lng,
        sensor_type=data.sensor_type,
    )
    db.add(pos)
    db.commit()
    db.refresh(pos)

    # Blockchain Anti-Tamper: Log Creation
    pos_dict = {
        "id": pos.id,
        "name": pos.name,
        "lat": pos.lat,
        "lng": pos.lng,
        "sensor_type": pos.sensor_type
    }
    data_hash = generate_position_hash(pos_dict, "CREATED")
    background_tasks.add_task(send_to_blockchain, pos.id, data_hash)

    return pos


@router.delete("/{position_id}")
def delete_position(position_id: int, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    pos = db.query(SensorPosition).filter(SensorPosition.id == position_id).first()
    if not pos:
        raise HTTPException(status_code=404, detail="Position not found")
        
    # Blockchain Anti-Tamper: Log Deletion before it is gone from DB
    pos_dict = {
        "id": pos.id,
        "name": pos.name,
        "lat": pos.lat,
        "lng": pos.lng,
        "sensor_type": pos.sensor_type
    }
    data_hash = generate_position_hash(pos_dict, "DELETED")

    db.delete(pos)
    db.commit()

    # Schedule the blockchain sync
    background_tasks.add_task(send_to_blockchain, position_id, data_hash)

    return {"status": "deleted"}
