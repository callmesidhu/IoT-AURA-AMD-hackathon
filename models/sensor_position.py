from sqlalchemy import Column, Integer, String, Float, DateTime
from datetime import datetime
from config.db import Base


class SensorPosition(Base):
    __tablename__ = "sensor_positions"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    lat = Column(Float, nullable=False)
    lng = Column(Float, nullable=False)
    sensor_type = Column(String, nullable=False)  # temperature, humidity, gas-leakage, ultra-sonic, earthquake
    created_at = Column(DateTime, default=datetime.utcnow)
