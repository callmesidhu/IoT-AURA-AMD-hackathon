FROM python:3.10-slim

WORKDIR /app

# Install system dependencies required by OpenCV and Ultralytics YOLO
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY . .

# Expose port 8000 for FastAPI
EXPOSE 8000

# Run Uvicorn server automatically on startup
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
