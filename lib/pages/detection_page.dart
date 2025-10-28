import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:math'; // For Point, max/min

import 'package:yolo/utils/image_utils.dart';
import '../services/yolo11_detector.dart';
import '../models/detection_result.dart';

class DetectionPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const DetectionPage({Key? key, required this.cameras}) : super(key: key);
  @override
  State<DetectionPage> createState() => _DetectionPageState();
}

class _DetectionPageState extends State<DetectionPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  late Yolo11Detector _detector;
  bool _isDetectorLoaded = false;
  CameraDescription? _selectedCamera;
  List<Detection> _detections = [];
  bool _isProcessing = false;
  bool _isSwitchingCamera = false; //  Flag to block processing during switch
  int _frameCount = 0; //  Frame counter for skipping frames
  DateTime? _lastFrameTime;
  double _fps = 0.0;
  double _lastInferenceMs = 0.0;
  Size? _lastPreviewSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.cameras.isNotEmpty) {
      try {
        _selectedCamera = widget.cameras.firstWhere(
                (c) => c.lensDirection == CameraLensDirection.back);
      } catch (e) {
        _selectedCamera = widget.cameras.first;
        print("⚠️ No back camera found, using first available camera.");
      }
    } else {
      _selectedCamera = null;
      print("❌ No cameras found on device.");
    }

    _initModelAndCamera();
  }

  Future<void> _initModelAndCamera() async {
    _detector = Yolo11Detector();
    await _detector.loadModel('assets/models/yolo11n.onnx');
    if (mounted) {
      setState(() => _isDetectorLoaded = true);
    }
    await _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCameraController();
    _detector.close();
    super.dispose();
  }

  Future<void> _disposeCameraController() async {
    if (_controller?.value.isStreamingImages ?? false) {
      try {
        await _controller?.stopImageStream();
        print("Camera stream stopped.");
      } catch (e) {
        print("Error stopping image stream: $e");
      }
    }
    try {
      await _controller?.dispose();
      print("Camera controller disposed.");
    } catch (e) {
      print("Error disposing camera controller: $e");
    }
    if (mounted) {
      setState(() {
        _controller = null;
        _isCameraInitialized = false;
        _lastPreviewSize = null;
      });
    }
  }


  Future<void> _initCamera() async {
    if (_selectedCamera == null) {
      print("❌ Cannot initialize camera: No camera selected or available.");
      if(mounted) setState(() => _isCameraInitialized = false);
      return;
    }


    print("Initializing camera: ${_selectedCamera!.name}");
    _controller = CameraController(
      _selectedCamera!,
      ResolutionPreset.low, // Use low for performance
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    _controller?.addListener(() {
      if (mounted) setState(() {});
      if (_controller?.value.hasError ?? false) {
        print('❌ Camera Error: ${_controller?.value.errorDescription}');
      }
    });

    try {
      await _controller!.initialize();
      _lastPreviewSize = _controller!.value.previewSize;
      await _controller!.startImageStream(_processCameraImage);
      if (mounted) {
        setState(() => _isCameraInitialized = true);
        print("✅ Camera Initialized and Stream Started (${_selectedCamera!.name})");
      }
    } catch (e) {
      print("❌ Error initializing camera ${_selectedCamera!.name}: $e");
      if (mounted) {
        setState(() => _isCameraInitialized = false);
      }
      await _disposeCameraController(); // Clean up if init fails
    }
  }

  //  --- SWITCH CAMERA  ---
  void _switchCamera() async {
    // Check if switch is safe
    if (widget.cameras.length < 2 || _selectedCamera == null || _isSwitchingCamera) return;

    // 1. Immediately block processing and set loading state
    setState(() {
      _isSwitchingCamera = true;  // Block _processCameraImage
      _isCameraInitialized = false; // Show loading spinner
      _detections = [];           // Clear old boxes
    });

    final targetLensDirection =
    _selectedCamera!.lensDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    CameraDescription? newCamera;
    try {
      newCamera = widget.cameras.firstWhere(
              (c) => c.lensDirection == targetLensDirection
      );
    } catch (e) {
      print("⚠️ Could not find camera with lens direction: $targetLensDirection");
      newCamera = null;
    }


    if (newCamera != null && newCamera != _selectedCamera) {
      print("Switching camera to ${newCamera.name}");

      // 2. Dispose old controller
      await _disposeCameraController();

      // 3. Update selection and re-initialize
      if (mounted) {
        setState(() { _selectedCamera = newCamera; });
        await _initCamera(); // This sets _isCameraInitialized = true on success
      }

    } else {
      print("❌ Could not switch camera. Re-enabling processing.");
      if (mounted) {
        // Re-enable if switch failed (e.g., no other camera found)
        setState(() => _isCameraInitialized = true);
      }
    }

    // 4. Unblock processing
    if (mounted) {
      setState(() => _isSwitchingCamera = false);
    }
  }
  // --- END SWITCH CAMERA ---


  void _processCameraImage(CameraImage image) async {
    //  Added _isSwitchingCamera and frame skipping
    _frameCount++;
    if (_frameCount % 3 != 0) return; // Skip 2/3 of frames

    if (!_isDetectorLoaded ||
        !_isCameraInitialized ||
        _controller == null ||
        !_controller!.value.isInitialized ||
        !_controller!.value.isStreamingImages ||
        _isProcessing ||
        _isSwitchingCamera || // Don't process if switching
        !mounted
    ) {
      return;
    }

    _isProcessing = true;

    try {
      final now = DateTime.now();
      if (_lastFrameTime != null) { /* FPS Calculation */ final dt = now.difference(_lastFrameTime!).inMilliseconds; if (dt > 0) _fps = 1000.0 / dt; }
      _lastFrameTime = now;

      final currentPreviewSize = _controller!.value.previewSize;
      if (currentPreviewSize == null || currentPreviewSize.isEmpty) {
        print("⚠️ Preview size is null or empty, skipping frame.");
        _isProcessing = false;
        return;
      }
      if(currentPreviewSize.width > 0 && currentPreviewSize.height > 0) {
        _lastPreviewSize = currentPreviewSize;
      }


      IsolatePreprocessResult isoResult = await preprocessOnIsolate(image);

      YoloResult result = await _detector.infer(
          isoResult, Size(currentPreviewSize.width, currentPreviewSize.height));

      _lastInferenceMs = result.inferenceMs;

      if (result.detections.isNotEmpty) {
        print("✅ Detections found: ${result.detections.length}");
      }

      if (mounted) {
        setState(() {
          _detections = result.detections;
        });
      }
    } catch (e) {
      print('❌ Error in _processCameraImage: $e');
    } finally {
      if(mounted){
        _isProcessing = false;
      }
    }
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // If controller is null, let initState handle it
    if (_controller == null) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // Don't check isInitialized, just dispose if controller exists
      _disposeCameraController();
    } else if (state == AppLifecycleState.resumed) {
      // Re-initialize camera only if it was disposed
      if (_controller == null) {
        print("Resuming app, re-initializing camera...");
        _initCamera();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bool isReady = _isCameraInitialized &&
        _isDetectorLoaded &&
        _controller != null &&
        _controller!.value.isInitialized &&
        _lastPreviewSize != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('YOLO Detection', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        actions: [
          if (widget.cameras.length > 1)
            IconButton(
              icon: Icon(
                  Icons.switch_camera,
                  // Disable button if not ready OR if currently switching
                  color: (isReady && !_isSwitchingCamera) ? Colors.white : Colors.grey
              ),
              onPressed: (isReady && !_isSwitchingCamera) ? _switchCamera : null,
              tooltip: 'Switch Camera',
            ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        top: false,
        bottom: false,
        child: isReady
            ? Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            ),

            if (_lastPreviewSize != null)
              CustomPaint(
                painter: _DetectionPainter(
                  detections: _detections,
                  previewSize: _lastPreviewSize!,
                  screenSize: screenSize,
                  lensDirection: _selectedCamera?.lensDirection,
                ),
              ),

            Positioned(
              left: 10,
              bottom: 10 + MediaQuery.of(context).padding.bottom,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('FPS: ${_fps.toStringAsFixed(1)}',
                        style: const TextStyle(color: Colors.white, fontSize: 14)),
                    Text('Inference: ${_lastInferenceMs.toStringAsFixed(1)} ms',
                        style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ],
        )
            : Center( // Show loading indicator
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 10),
              Text(
                  _isDetectorLoaded ? "Initializing Camera..." : "Loading Model...",
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Detection Painter
class _DetectionPainter extends CustomPainter {
  final List<Detection> detections;
  final Size previewSize;
  final Size screenSize;
  final CameraLensDirection? lensDirection;
  final Map<String, Color> _colorCache = {};
  final List<Color> _availableColors = Colors.primaries.map((c) => c.shade300).toList();
  int _colorIndex = 0;

  _DetectionPainter({
    required this.detections,
    required this.previewSize,
    required this.screenSize,
    this.lensDirection,
  });

  Color _getColorForLabel(String label) {
    return _colorCache.putIfAbsent(label, () {
      final color = _availableColors[_colorIndex % _availableColors.length];
      _colorIndex++;
      return color;
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (previewSize.isEmpty || previewSize.width <= 0 || previewSize.height <= 0) {
      print("Painter: Invalid previewSize $previewSize");
      return;
    }

    final double scaleX = size.width / previewSize.width;
    final double scaleY = size.height / previewSize.height;
    final double scale = max(scaleX, scaleY); // BoxFit.cover logic

    final double offsetX = (size.width - (previewSize.width * scale)) / 2;
    final double offsetY = (size.height - (previewSize.height * scale)) / 2;

    final bool mirror = lensDirection == CameraLensDirection.front;

    final paintStroke = Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 2.0;
    final paintFill = Paint()..style = PaintingStyle.fill;
    final textPainter = TextPainter(textDirection: TextDirection.ltr, maxLines: 1);

    for (final det in detections) {
      final color = _getColorForLabel(det.label);
      paintStroke.color = color;
      paintFill.color = color;

      // Map to scaled preview space
      double screenLeft = (det.box.left * scale) + offsetX;
      double screenTop = (det.box.top * scale) + offsetY;
      double screenRight = (det.box.right * scale) + offsetX;
      double screenBottom = (det.box.bottom * scale) + offsetY;

      if (mirror) {
        double oldLeft = screenLeft;
        screenLeft = size.width - screenRight;
        screenRight = size.width - oldLeft;
      }

      final rect = Rect.fromLTRB(
        screenLeft.clamp(0.0, size.width),
        screenTop.clamp(0.0, size.height),
        screenRight.clamp(0.0, size.width),
        screenBottom.clamp(0.0, size.height),
      );

      if (rect.width <= 0 || rect.height <= 0) continue;

      paintFill.color = paintFill.color = color.withOpacity(0.2);
      canvas.drawRect(rect, paintFill);
      canvas.drawRect(rect, paintStroke);

      final label = '${det.label} ${(det.confidence * 100).toStringAsFixed(0)}%';
      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      );
      textPainter.layout(maxWidth: max(0.0, size.width - rect.left - 5));

      final textBgRect = Rect.fromLTWH(
        rect.left,
        rect.top - (textPainter.height + 4),
        min(textPainter.width + 6, size.width - rect.left), // Prevent overflow
        textPainter.height + 4,
      );

      final clampedTextBgRect = Rect.fromLTRB(
          textBgRect.left.clamp(0.0, size.width),
          max(0.0, textBgRect.top),
          textBgRect.right.clamp(0.0, size.width),
          textBgRect.bottom.clamp(0.0, size.height)
      );

      if (clampedTextBgRect.width > 0 && clampedTextBgRect.height > 0) {
        paintFill.color = color;
        canvas.drawRect(clampedTextBgRect, paintFill);
        textPainter.paint(canvas, Offset(clampedTextBgRect.left + 3, clampedTextBgRect.top + 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DetectionPainter oldDelegate) =>
      oldDelegate.detections != detections ||
          oldDelegate.previewSize != previewSize ||
          oldDelegate.screenSize != screenSize ||
          oldDelegate.lensDirection != lensDirection;
}
