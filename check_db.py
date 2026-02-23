from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from models import SensorReading

SQLALCHEMY_DATABASE_URL = "sqlite:///./sqlite.db"
engine = create_engine(SQLALCHEMY_DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)

db = SessionLocal()
readings = db.query(SensorReading).all()
print(f"Total readings in database: {len(readings)}")
for r in readings:
    print(f"ID: {r.id}, Temp: {r.temperature}, Humidity: {r.humidity}, Time: {r.timestamp}")
db.close()
