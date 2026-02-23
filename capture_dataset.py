import cv2
import os

# Create folders if they don't exist
os.makedirs("dataset/fire", exist_ok=True)
os.makedirs("dataset/no_fire", exist_ok=True)

DROIDCAM_URL = "http://10.10.168.105:4747/video"
print(f"Connecting to {DROIDCAM_URL}...")

cap = cv2.VideoCapture(DROIDCAM_URL)

fire_count = len(os.listdir("dataset/fire"))
no_fire_count = len(os.listdir("dataset/no_fire"))

print("=========================================")
print("🔥 DATASET CAPTURE TOOL 🔥")
print("Press 'f' to save a FIRE image")
print("Press 'n' to save a NO FIRE image")
print("Press 'q' to quit")
print("=========================================")

while True:
    ret, frame = cap.read()
    if not ret:
        print("Failed to grab frame. Reconnecting...")
        cap = cv2.VideoCapture(DROIDCAM_URL)
        cv2.waitKey(2000)
        continue

    # Create a copy for the display to show status
    display = frame.copy()
    cv2.putText(display, f"Fire: {fire_count} | No Fire: {no_fire_count}", (10, 30),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
    cv2.putText(display, "Press 'f' for Fire, 'n' for No Fire, 'q' to Quit", (10, 60),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 1)

    cv2.imshow("Dataset Collection", display)

    key = cv2.waitKey(1) & 0xFF

    if key == ord('f'):
        filename = f"dataset/fire/fire_{fire_count}.jpg"
        cv2.imwrite(filename, frame)
        print(f"Saved {filename}")
        fire_count += 1
    elif key == ord('n'):
        filename = f"dataset/no_fire/nofire_{no_fire_count}.jpg"
        cv2.imwrite(filename, frame)
        print(f"Saved {filename}")
        no_fire_count += 1
    elif key == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
print("Collection stopped.")
