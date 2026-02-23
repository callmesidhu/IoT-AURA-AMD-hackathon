from sqlalchemy import Column, Integer, Float, DateTime
from datetime import datetime
from config.db import Base

class SensorReading(Base):
    __tablename__ = "sensor_readings"

    id = Column(Integer, primary_key=True, index=True)
    distance = Column(Float)
    timestamp = Column(DateTime, default=datetime.utcnow)