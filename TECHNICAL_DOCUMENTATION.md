# Technical Documentation (Content for PDF)

# Technical Documentation
## YOLO Flutter Object Detection App

---

### 1. Project Overview

**Project Name:** YOLO Flutter Object Detection
**Version:** 1.0.0
**Description:** A high-performance, real-time object detection application for mobile platforms, built with Flutter. It uses the YOLOv11n (YOLOv8n) model via ONNX Runtime to identify and display bounding boxes for 80 classes of objects from a live camera feed.

---

### 2. Core Technologies

* **Flutter:** Cross-platform UI toolkit for building the application.
* **ONNX Runtime (`onnxruntime`):** The core inference engine. It executes the ONNX model file using native, hardware-accelerated code (e.g., NNAPI on Android, CoreML on iOS) for maximum speed.
* **Camera (`camera`):** Provides the live camera feed and image stream (`CameraImage`).
* **Image (`image`):** A Dart library used for all heavy image manipulation, which is performed in a background isolate.
* **Permission Handler (`permission_handler`):** Manages all logic for requesting and checking camera permissions.

---

### 3. Application Architecture & Data Flow

The app's architecture is designed to be highly responsive by separating heavy computation from the UI thread.



**Data Flow per Frame:**

1.  **Frame Capture (UI Thread):**
    * `DetectionPage` initializes a `CameraController` at `ResolutionPreset.low` to reduce data load.
    * `_controller.startImageStream()` listens for frames.
    * A frame counter (`_frameCount`) ensures only **1 in every 3 frames** is processed, preventing buffer overload and stabilizing FPS.

2.  **Pre-processing (Background Isolate):**
    * The `CameraImage` (in YUV420 format) is sent to `preprocessOnIsolate` in `image_utils.dart`. This function runs on a new background thread.
    * **Inside the Isolate:**
        * **YUV-to-RGB:** The planar YUV data is converted into a standard RGB `img.Image` object.
        * **Letterboxing:** The RGB image is resized to the model's input size (640x640), maintaining its aspect ratio. The remaining space is filled with black padding. The `scale` factor and `padX`/`padY` offsets are calculated and saved.
        * **Normalization:** The 640x640 letterboxed image is converted to a `Float32List`, with pixel values normalized from `[0-255]` to `[0.0-1.0]`.
        * **Formatting:** The list is structured in NCHW format: `[1 (Batch), 3 (Channels), 640 (Height), 640 (Width)]`.
    * An `IsolatePreprocessResult` object (containing the `Float32List` and letterbox data) is returned to the UI thread.

3.  **Inference (Native Code):**
    * Back on the UI thread, `yolo11_detector.dart` receives the `IsolatePreprocessResult`.
    * The `Float32List` is wrapped in an `OrtValueTensor`.
    * `_session.run()` is called. This is a fast, native (C++) operation that executes the `yolo11n.onnx` model.

4.  **Post-processing (UI Thread):**
    * The model returns a `List<List<List<double>>>` object with the shape `[1, 84, 8400]`.
    * `_parseDetections` correctly interprets this as `[Batch, Attributes, Proposals]`, where "Attributes" is 84 (`xywh` + 80 class scores) and "Proposals" is 8400 (the raw anchor box predictions).
    * The code iterates **8400 times** (once per proposal). For each proposal `i`:
        * It finds the highest class score (and its index `cls`) from the 80 class attributes (`outputDataTransposed[4][i]` to `outputDataTransposed[83][i]`).
        * If this score is above `confidenceThreshold`, it's kept as a candidate.
    * **NMS:** This model format *requires* manual NMS. The `applyNMS` function is called on all candidates to filter out overlapping boxes, keeping only the best one per object.
    * **Coordinate Mapping:** The coordinates of the final boxes (which are relative to the 640x640 letterboxed image) are mapped back to the *original* camera image's coordinate space using the `scale`, `padX`, and `padY` values from the pre-processing step.
    * The final `List<Detection>` is returned.

5.  **Render (UI Thread):**
    * `DetectionPage` calls `setState` with the new list of detections.
    * `CustomPaint` is rebuilt. Its `_DetectionPainter` class draws the bounding boxes.
    * The painter's `paint` method uses `MediaQuery` (`screenSize`) and the `previewSize` to correctly scale and position the boxes, handling screen aspect ratio (`BoxFit.cover`) and camera mirroring.

---

### 4. Key Pages & Components

#### `lib/main.dart`
* Initializes the app and handles the very first permission request.
* Uses a `ValueNotifier<PermissionStatus>` to hold the permission state.
* A `ValueListenableBuilder` builds the `home` widget, showing `PermissionDeniedPage` or `BottomNavPage` based on the notifier's value.

#### `lib/pages/permission_denied_page.dart`
* A `StatefulWidget` that implements `WidgetsBindingObserver`.
* Provides a user-friendly UI to request permission or open settings.
* The `didChangeAppLifecycleState` method detects when the user returns to the app (e.g., from settings).
* It then calls the `onPermissionGranted` callback, which triggers `_checkAndInitializeCameras` in `main.dart` to re-check the permission and update the `ValueNotifier`, causing an automatic navigation to the main app if permission is now granted.

#### `lib/pages/bottomnav_page.dart`
* The main app shell containing the `BottomNavigationBar`.
* Uses an **`IndexedStack`** as its body. This is crucial for performance, as it keeps all pages in the widget tree alive, preventing the `DetectionPage` and its `CameraController` from being disposed and re-initialized every time the user switches tabs.

#### `lib/pages/detection_page.dart`
* The primary interactive screen.
* Manages the `CameraController` lifecycle, including safe disposal in `dispose()` and `didChangeAppLifecycleState`.
* Manages the camera switch logic (`_switchCamera`), using an `_isSwitchingCamera` flag to prevent processing frames during the switch, which makes the transition near-instant.
* Renders the `CameraPreview` and the `_DetectionPainter` in a `Stack`.
* Displays FPS and Inference Time in a `Positioned` overlay.

#### `lib/services/yolo11_detector.dart`
* Encapsulates all logic related to the ONNX model.
* `loadModel()`: Loads the `assets/models/yolo11n.onnx` file into an `OrtSession`.
* `infer()`: Runs the inference on a single pre-processed frame.
* `_parseDetections()`: The complex logic for parsing the `[1, 84, 8400]` output, as described in the data flow.
* `applyNMS()` / `calculateIoU()`: Helper functions to perform Non-Maximum Suppression in Dart.

---

### 5. Build Configuration

* `pubspec.yaml`: Specifies all Flutter dependencies. `onnxruntime`, `camera`, `image`, and `permission_handler` are the most critical. `tflite_flutter` was *removed* to prevent build conflicts.
* `android/app/build.gradle.kts`:
    * Uses Kotlin Script (`.kts`) syntax.
    * Sets `multiDexEnabled = true`.
    * The `buildTypes.release` block is configured with `isMinifyEnabled = true` and `setProguardFiles` to enable R8 shrinking and apply custom rules.
* `android/app/proguard-rules.pro`:
    * This file is referenced by `build.gradle.kts`.
    * While `onnxruntime` does not strictly require rules, rules for other plugins (like `tflite_flutter` previously did) are placed here. Example:
        ```proguard
        -keep class org.tensorflow.lite.gpu.** { *; }
        -keep interface org.tensorflow.lite.gpu.** { *; }
        ```

---

### 6. Future Feature Roadmap

This project serves as a powerful foundation. Future development could expand its capabilities significantly:

* **ML Expansion (Google ML Kit):**
    * Integrate `google_mlkit_image_labeling` for general-purpose classification when no YOLO object is found.
    * Add `google_mlkit_text_recognition` to read text within detected boxes (e.g., on a 'stop sign').
    * Use `google_mlkit_face_detection` for enhanced 'person' detection with landmarks.
    * Implement `google_mlkit_barcode_scanning` to detect and scan barcodes/QR codes.
    * Compare performance with `google_mlkit_object_detection` (a simpler, built-in object detector).

* **Firebase & Cloud Backend:**
    * **User Accounts:** Implement **Firebase Auth** with **Google Sign-In** for user profiles.
    * **Secure Login:** Add **Local Auth** for biometric (fingerprint/face) login.
    * **Cloud Storage:** Save detection data (images, box coordinates, labels) to **Cloud Firestore** and store the source images/video clips in **Firebase Storage**.
    * **Usage Metrics:** Use **Firebase Analytics** to track which features are most popular.
    * **Custom Backend:** Develop a **Node.js** backend (e.g., on Google Cloud Run or Firebase Functions) for custom logic or data aggregation.

* **Monetization & Advanced Features:**
    * **In-App Purchases:** Integrate **Payment Gateways** (PayPal, Stripe) via `in_app_purchase`.
    * **Premium Tiers:** Offer **Subscription-Based Features**, such as:
        * Access to larger, more accurate models (e.g., `yolo11m.onnx` or `yolo11l.onnx`).
        * Cloud-based detection history and logbook.
        * Custom model training and deployment.
    * **Enhanced Analytics:** Build a web dashboard (using **Node.js** and **Google Cloud Platform**) with **More Robust Analytics** for users to review their detection history.
    * **Admin Tools:** Create **More Admin Features** for managing users and viewing platform-wide statistics.

## ABOUT ME
1. NAME: Fredrick Adimmadu.
2. BIO: Senior full-stack commercial software developer with 9 years of experienc out of which the past 7 years has been flutter/dart while utilising various tech stacks over my 9 years, such as: Google Cloud Platforrm, Firebase, Node.js, Payment gateways (PayPaal & Stripe), AI, ML, NLP, LLMS, etc..
3. EDUCATION: Master's Degree in Advanced Computer Science and Bachelor's Degree in Computer Science.
4. LinkedIn: Fredrick Adimmadu.

## APK Download url
https://drive.google.com/file/d/1-5zq-3mBsfy19XGKn68kKxA5_pCNOkZx/view?usp=drive_link

## Demo Video via Youtube
https://youtube.com/shorts/FeujGG822ZQ?si=Jot0Ow8K3FzXkSOx