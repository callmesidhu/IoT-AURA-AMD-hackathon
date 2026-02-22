from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Optional
from config.db import SessionLocal
from models.sensor_position import SensorPosition

router = APIRouter(prefix="/positions", tags=["positions"])


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
def create_position(data: SensorPositionCreate, db: Session = Depends(get_db)):
    pos = SensorPosition(
        name=data.name,
        lat=data.lat,
        lng=data.lng,
        sensor_type=data.sensor_type,
    )
    db.add(pos)
    db.commit()
    db.refresh(pos)
    return pos


@router.delete("/{position_id}")
def delete_position(position_id: int, db: Session = Depends(get_db)):
    pos = db.query(SensorPosition).filter(SensorPosition.id == position_id).first()
    if not pos:
        raise HTTPException(status_code=404, detail="Position not found")
    db.delete(pos)
    db.commit()
    return {"status": "deleted"}
