# YOLO Flutter - Real-Time Object Detection

A high-performance, real-time object detection application built in Flutter. This app uses the **YOLOv11n** model via **ONNX Runtime** to identify and track 80 different object classes from a live camera feed.

The app is heavily optimized for mobile devices by offloading all heavy image processing to a background **Isolate**, ensuring a smooth, high-FPS user interface.


---

## Core Features

* **Real-time Camera Preview:** Renders a high-FPS, full-screen live feed from the device camera.
* **Object Detection:** Performs real-time inference using the **YOLOv11n** (YOLOv8-based) model to identify 80 classes of objects from the COCO dataset.
* **Dynamic Overlays:** Draws AR-style bounding boxes, class labels, and confidence scores over detected objects using `CustomPaint`.
* **Performance Metrics:** Displays the live Frames Per Second (FPS) and model Inference Time (in ms) to monitor performance.
* **Camera Controls:** Includes a seamless toggle to switch between the front and rear-facing cameras.
* **High-Performance Architecture:** Uses a background **Isolate** for all heavy image processing (YUV conversion, resizing, padding) to keep the UI thread from freezing.
* **Responsive UI:** A clean, tabbed interface that adapts to device screen sizes and safe areas.
* **Robust Permission Handling:** A professional, user-friendly screen guides users to grant camera permission. It automatically detects when permission is granted from settings and launches the app.

---

## Technical Stack

* **Framework:** Flutter (SDK 3.x.x)
* **Core Dependencies:**
    * `camera`: For the live camera feed and image stream.
    * `onnxruntime`: For running native, hardware-accelerated ONNX model inference.
    * `image`: For high-performance image manipulation (YUV conversion, resizing).
    * `permission_handler`: For managing camera permissions gracefully.
* **Model:** `yolo11n.onnx` (a YOLOv8n model exported for ONNX) with a `[1, 84, 8400]` output shape.

---

## Getting Started

### 1. Prerequisites

* Flutter SDK (v3.0.0 or newer)
* An IDE (VS Code or Android Studio)
* A physical Android or iOS device (Camera streams do not work on most simulators)

### 2. Setup

1.  **Clone**
   

2.  **Get Dependencies**
    
    flutter pub get


3.  **Ensure Model is in Place**
    * Make sure your `yolo11n.onnx` model file is located in `assets/models/yolo11n.onnx`.
    * Verify `pubspec.yaml` has the asset registered:
        ```yaml
        flutter:
          assets:
            - assets/models/yolo11n.onnx
        ```

### 3. Running the App (Crucial!)

**DO NOT RUN IN DEBUG MODE.**
The app performs heavy image processing in Dart. Debug mode's JIT compiler is too slow and will cause the app to freeze, lag, and produce buffer errors.

You **must** run in Profile or Release mode.

#### **Option 1: Profile Mode (Recommended for Testing)**
Runs with release-level performance while still showing `print()` logs in your console.

1. flutter run --profile  or flutter build apk --



### **Future Feature Roadmap**
This project provides a strong foundation. Future enhancements could include:

ML Expansion (Google ML Kit):

1. Integrate google_mlkit_image_labeling for general-purpose image classification.

2. Add google_mlkit_text_recognition for Optical Character Recognition (OCR).

3. Use google_mlkit_face_detection for face-specific attributes.

4. Implement google_mlkit_barcode_scanning.

Firebase & Cloud Backend:

1. Use Firebase Auth with Google Sign-In for user accounts.

2. Implement Local Auth (biometrics) for secure login.

3. Save detection results (images, metadata) to Firebase Storage and Cloud Firestore.

4. Use Firebase Analytics to track feature usage.

5. Develop a Node.js backend on Google Cloud Platform for managing data and users.

Monetization & Advanced Features:

1. Implement Payment Gateways (PayPal, Stripe).

2. Create Subscription-Based Features (e.g., cloud storage for detection history, higher-accuracy models).

3. Build More Robust Analytics (e.g., charts of objects detected over time).

4. Create Admin Features (e.g., user management, viewing all user data).

## ABOUT ME
1. NAME: Fredrick Adimmadu.
2. BIO: Senior full-stack commercial software developer with 9 years of experienc out of which the past 7 years has been flutter/dart while utilising various tech stacks over my 9 years, such as: Google Cloud Platforrm, Firebase, Node.js, Payment gateways (PayPaal & Stripe), AI, ML, NLP, LLMS, etc..
3. EDUCATION: Master's Degree in Advanced Computer Science and Bachelor's Degree in Computer Science.
4. LinkedIn: Fredrick Adimmadu.

## APK Download url
https://drive.google.com/file/d/1-5zq-3mBsfy19XGKn68kKxA5_pCNOkZx/view?usp=drive_link

## Demo Video via Youtube
https://youtube.com/shorts/FeujGG822ZQ?si=Jot0Ow8K3FzXkSOx
