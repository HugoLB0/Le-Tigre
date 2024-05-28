import cv2
import time
import threading
from flask import Flask, jsonify
from queue import Queue

app = Flask(__name__)

# Initialize webcam
cap = cv2.VideoCapture(0)
cap.set(3, 1280)  # Set width
cap.set(4, 720)   # Set height
cap.set(cv2.CAP_PROP_FPS, 30)  # Set frames per second

frame_queue = Queue(maxsize=1)

def capture_frames():
    while True:
        ret, frame = cap.read()
        if not ret:
            print("Failed to grab frame")
            break

        # Put the frame in the queue, replacing the previous one
        if not frame_queue.empty():
            try:
                frame_queue.get_nowait()
            except:
                pass
        frame_queue.put(frame)

        cv2.imshow('Webcam Stream', frame)
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()

@app.route('/capture', methods=['GET'])
def capture_frame():
    if frame_queue.empty():
        return jsonify({"error": "No frame available"}), 500
    
    frame = frame_queue.get()
    # Resize the frame to 1920x1080
    resized_frame = cv2.resize(frame, (1920, 1080))
    timestamp = time.strftime("%Y%m%d-%H%M%S")
    filename = f"capture_{timestamp}.png"
    cv2.imwrite(filename, resized_frame)
    return jsonify({"image_path": filename}), 200

@app.route('/shutdown', methods=['GET'])
def shutdown():
    cap.release()
    cv2.destroyAllWindows()
    return jsonify({"message": "Webcam stream stopped"}), 200

if __name__ == '__main__':
    # Start the frame capture and display in the main thread
    threading.Thread(target=app.run, kwargs={'host': '0.0.0.0', 'port': 3333}, daemon=True).start()
    capture_frames()
