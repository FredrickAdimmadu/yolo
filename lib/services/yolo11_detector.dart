import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'dart:math'; // For max/min

import '../models/detection_result.dart';
import '../utils/image_utils.dart';

// Standard COCO dataset class names (80 classes)
const List<String> cocoLabels = [
  'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train', 'truck', 'boat',
  'traffic light', 'fire hydrant', 'stop sign', 'parking meter', 'bench', 'bird', 'cat', 'dog',
  'horse', 'sheep', 'cow', 'elephant', 'bear', 'zebra', 'giraffe', 'backpack', 'umbrella',
  'handbag', 'tie', 'suitcase', 'frisbee', 'skis', 'snowboard', 'sports ball', 'kite',
  'baseball bat', 'baseball glove', 'skateboard', 'surfboard', 'tennis racket', 'bottle',
  'wine glass', 'cup', 'fork', 'knife', 'spoon', 'bowl', 'banana', 'apple', 'sandwich',
  'orange', 'broccoli', 'carrot', 'hot dog', 'pizza', 'donut', 'cake', 'chair', 'couch',
  'potted plant', 'bed', 'dining table', 'toilet', 'tv', 'laptop', 'mouse', 'remote',
  'keyboard', 'cell phone', 'microwave', 'oven', 'toaster', 'sink', 'refrigerator', 'book',
  'clock', 'vase', 'scissors', 'teddy bear', 'hair drier', 'toothbrush'
];

// Helper class for NMS candidates
class _DetectionCandidate {
  final Rect box;
  final String label;
  final double score;
  final int classIndex;

  _DetectionCandidate({
    required this.box,
    required this.label,
    required this.score,
    required this.classIndex,
  });
}


class YoloResult {
  final List<Detection> detections;
  final double inferenceMs;
  YoloResult({required this.detections, required this.inferenceMs});
}

class Yolo11Detector {
  OrtSession? _session;
  bool _isLoaded = false;
  final int _inputSize = 640;

  Future<void> loadModel(String assetPath) async {
    try {
      final modelData = await rootBundle.load(assetPath);
      final bytes = modelData.buffer.asUint8List();
      final sessionOptions = OrtSessionOptions();
      // sessionOptions.addNnapi(); // Consider for Android performance
      _session = OrtSession.fromBuffer(bytes, sessionOptions);
      sessionOptions.release();
      _isLoaded = true;
      print('✅ YOLOv8n (yolo11n.onnx) model loaded successfully');
    } catch (e) {
      print('❌ Error loading model: $e');
      _isLoaded = false;
    }
  }

  void close() {
    _session?.release();
    _isLoaded = false;
  }

  Future<YoloResult> infer(
      IsolatePreprocessResult isoResult,
      Size originalPreviewSize,
      ) async {
    if (!_isLoaded || _session == null) {
      print("⚠️ Model not loaded or session is null during infer call.");
      return YoloResult(detections: [], inferenceMs: 0);
    }

    final sw = Stopwatch()..start();
    List<Detection> detections = [];
    double inferenceMs = 0;
    OrtValueTensor? inputTensor;
    OrtRunOptions? runOptions;
    List<OrtValue?>? outputs;


    try {
      inputTensor = OrtValueTensor.createTensorWithDataList(
          isoResult.floatData, [1, 3, _inputSize, _inputSize]); // NCHW

      runOptions = OrtRunOptions();
      final inputs = {'images': inputTensor}; // Input name from Netron

      outputs = _session!.run(runOptions, inputs);

      inferenceMs = sw.elapsedMilliseconds.toDouble();
      sw.stop();

      final lb = LetterboxResult(null, isoResult.scale, isoResult.padX, isoResult.padY);
      detections = _parseDetections(outputs, lb, originalPreviewSize);

    } catch(e) {
      print("❌ Error during ONNX inference or parsing: $e");
      if (sw.isRunning) sw.stop();
      inferenceMs = sw.elapsedMilliseconds.toDouble();
      detections = [];
    } finally {
      inputTensor?.release();
      runOptions?.release();
      outputs?.forEach((o) => o?.release());
    }
    return YoloResult(detections: detections, inferenceMs: inferenceMs);
  }

  // --- PARSING LOGIC FOR [1, 84, 8400] ---
  List<Detection> _parseDetections(
      List<OrtValue?> outputs,
      LetterboxResult lb, // For coordinate mapping
      Size originalPreviewSize, // For coordinate mapping
          { double confidenceThreshold = 0.3, // Confidence threshold (applied to max class score)
        double iouThreshold = 0.45,     // IoU threshold for NMS
      }
      ) {
    if (outputs.isEmpty || outputs.first == null) {
      print('⚠️ _parseDetections: Model output list is empty or first element is null.');
      return [];
    }

    final firstOutput = outputs.first!;
    final outputValue = firstOutput.value;
    final outputType = outputValue.runtimeType;

    //  Output Debugging
    print("--- Model Output Debug Info ---");
    print("Output Type: $outputType");

    int outputOuterLength = 0;
    int? potentialNumAttributes;
    int? potentialNumProposals;

    if (outputValue is List) {
      outputOuterLength = outputValue.length;
      if(outputOuterLength == 1 && outputValue[0] is List) {
        List innerList1 = outputValue[0];
        potentialNumAttributes = innerList1.length;
        if(potentialNumAttributes > 0 && innerList1[0] is List) {
          List innerList2 = innerList1[0];
          potentialNumProposals = innerList2.length;
        }
      }
    }
    print("Inferred Shape (Batch, Attrs, Props?): [$outputOuterLength, $potentialNumAttributes, $potentialNumProposals]");
    print("-------------------------------");
    // --- End Debugging ---

    // --- Validate Expected Structure [1, 84, 8400] ---
    if (!(outputValue is List && outputOuterLength == 1 && potentialNumAttributes == 84 && potentialNumProposals == 8400)) {
      print("❌ Unexpected output structure. Expected List<List<List<double>>> representing [1, 84, 8400].");
      return []; // Cannot parse if structure is wrong
    }

    final int numAttributes = potentialNumAttributes!; // 84
    final int numProposals = potentialNumProposals!; // 8400

    // --- Cast and Access Output Data ---
    List<List<double>> outputDataTransposed; // Will be [84, 8400]

    try {
      List<dynamic> batchList = outputValue[0]; // Get the inner [84, 8400] list
      outputDataTransposed = batchList.map((dynamic attrList) {
        return (attrList as List).cast<double>().toList();
      }).toList();
      print("✅ Successfully cast nested list to [$numAttributes, $numProposals]");

    } catch (e) {
      print("❌ Error casting nested output data: $e");
      return [];
    }

    // --- Process Proposals ---
    List<_DetectionCandidate> candidates = [];
    for (int i = 0; i < numProposals; i++) { // Iterate through each of the 8400 proposals
      // Get class scores for proposal 'i' (attributes 4 to 83)
      double maxProb = 0.0;
      int cls = -1;
      for (int c = 4; c < numAttributes; c++) { // Start from index 4 for classes
        final double prob = outputDataTransposed[c][i];
        if (prob > maxProb) {
          maxProb = prob;
          cls = c - 4; // Class index (0-79)
        }
      }

      // Apply confidence threshold FIRST
      if (maxProb < confidenceThreshold) {
        continue;
      }

      // Extract box data for proposal 'i'
      final double x = outputDataTransposed[0][i]; // Center X
      final double y = outputDataTransposed[1][i]; // Center Y
      final double w = outputDataTransposed[2][i]; // Width
      final double h = outputDataTransposed[3][i]; // Height

      // Convert box from center [x,y,w,h] to top-left [x1,y1] (relative to _inputSize)
      final x1 = x - w / 2;
      final y1 = y - h / 2;

      // Map coordinates back to original preview image space
      final mappedX = (x1 - lb.padX) / lb.scale;
      final mappedY = (y1 - lb.padY) / lb.scale;
      final mappedW = w / lb.scale;
      final mappedH = h / lb.scale;

      // Create Rect (relative to original preview)
      final rect = Rect.fromLTWH(mappedX, mappedY, mappedW, mappedH);

      if (rect.width <= 0 || rect.height <= 0) continue; // Skip invalid boxes

      String label = (cls >= 0 && cls < cocoLabels.length) ? cocoLabels[cls] : 'class_$cls';

      candidates.add(_DetectionCandidate(
          box: rect, // Use the mapped rect
          label: label,
          score: maxProb, // Score used for NMS
          classIndex: cls
      ));
    }

    print("Found ${candidates.length} candidates above confidence threshold.");

    // --- Apply Non-Maximum Suppression (NMS) ---
    List<Detection> finalDetections = applyNMS(candidates, iouThreshold);

    // --- Post-NMS Clamping and Final List Creation ---
    List<Detection> clampedDetections = [];
    for(var det in finalDetections){
      final clampedX = det.box.left.clamp(0.0, originalPreviewSize.width);
      final clampedY = det.box.top.clamp(0.0, originalPreviewSize.height);
      final clampedRight = det.box.right.clamp(0.0, originalPreviewSize.width);
      final clampedBottom = det.box.bottom.clamp(0.0, originalPreviewSize.height);
      final clampedW = max(0.0, clampedRight - clampedX);
      final clampedH = max(0.0, clampedBottom - clampedY);

      if (clampedW > 0 && clampedH > 0) {
        clampedDetections.add(Detection(
            box: Rect.fromLTWH(clampedX, clampedY, clampedW, clampedH),
            label: det.label,
            confidence: det.confidence // This is the maxProb
        ));
      }
    }


    print("✅ Parsed ${clampedDetections.length} detections successfully after NMS and clamping.");
    return clampedDetections; // Return the final clamped list
  }

  // Fallback parser (not used if [1, 84, 8400] is detected)
  List<Detection> _parseFlatDetections(
      dynamic outputValue,
      LetterboxResult lb,
      Size originalPreviewSize,
      double confidenceThreshold,
      double iouThreshold) {
    // ... (This function remains as a fallback, but is less likely to be correct)
    print("Executing fallback flat parse...");
    List<double> floats;
    const int numAttrs = 85; // Assumes xywh + CONF + 80 classes

    if (outputValue is Float32List) { floats = outputValue.toList(); }
    else if (outputValue is List<double>) { floats = outputValue; }
    else if (outputValue is List) { try { floats = outputValue.cast<double>(); } catch (e) { print('❌ Flat fallback: Error casting: $e'); return []; } }
    else { print('❌ Flat fallback: Unknown type: ${outputValue.runtimeType}'); return []; }

    if (floats.isEmpty) return [];
    if (floats.length % numAttrs != 0) { print('❌ Flat fallback: Length (${floats.length}) not divisible by $numAttrs.'); return []; }

    final numBoxes = floats.length ~/ numAttrs;
    List<_DetectionCandidate> candidates = [];

    for (int i = 0; i < numBoxes; i++) {
      final offset = i * numAttrs;
      final x = floats[offset]; final y = floats[offset + 1];
      final w = floats[offset + 2]; final h = floats[offset + 3];
      final conf = floats[offset + 4];
      final classProbs = floats.sublist(offset + 5, offset + numAttrs);

      double maxProb = 0.0; int cls = -1;
      for (int c = 0; c < classProbs.length; c++) { if (classProbs[c] > maxProb) { maxProb = classProbs[c]; cls = c; } }

      final score = conf * maxProb;
      if (score < confidenceThreshold) continue;

      final x1 = x - w / 2; final y1 = y - h / 2;
      final mappedX = (x1 - lb.padX) / lb.scale; final mappedY = (y1 - lb.padY) / lb.scale;
      final mappedW = w / lb.scale; final mappedH = h / lb.scale;

      final rect = Rect.fromLTWH(mappedX, mappedY, mappedW, mappedH);
      if (rect.width <= 0 || rect.height <= 0) continue;

      String label = (cls >= 0 && cls < cocoLabels.length) ? cocoLabels[cls] : 'class_$cls';
      candidates.add(_DetectionCandidate(box: rect, label: label, score: score, classIndex: cls));
    }
    print("Flat fallback found ${candidates.length} candidates.");
    List<Detection> nmsResult = applyNMS(candidates, iouThreshold);

    List<Detection> clampedResult = [];
    for(var det in nmsResult){
      final clampedX = det.box.left.clamp(0.0, originalPreviewSize.width);
      final clampedY = det.box.top.clamp(0.0, originalPreviewSize.height);
      final clampedRight = det.box.right.clamp(0.0, originalPreviewSize.width);
      final clampedBottom = det.box.bottom.clamp(0.0, originalPreviewSize.height);
      final clampedW = max(0.0, clampedRight - clampedX);
      final clampedH = max(0.0, clampedBottom - clampedY);
      if (clampedW > 0 && clampedH > 0) {
        clampedResult.add(Detection(box: Rect.fromLTWH(clampedX, clampedY, clampedW, clampedH), label: det.label, confidence: det.confidence));
      }
    }
    return clampedResult;
  }


  // --- Non-Maximum Suppression (NMS) ---
  List<Detection> applyNMS(List<_DetectionCandidate> candidates, double iouThreshold) {
    if (candidates.isEmpty) return [];

    // Sort by score descending
    candidates.sort((a, b) => b.score.compareTo(a.score));

    List<Detection> selectedDetections = [];
    List<bool> active = List.filled(candidates.length, true);
    int numActive = candidates.length;

    for (int i = 0; i < candidates.length && numActive > 0; i++) {
      if (active[i]) {
        final candidate = candidates[i];
        selectedDetections.add(Detection(
            box: candidate.box,
            label: candidate.label,
            confidence: candidate.score));
        active[i] = false;
        numActive--;

        // Suppress overlapping boxes
        for (int j = i + 1; j < candidates.length; j++) {
          if (active[j]) {
            // Optional: Uncomment line below to apply NMS *per class*
            // if (candidates[j].classIndex != candidate.classIndex) continue;

            final double iou = calculateIoU(candidate.box, candidates[j].box);
            if (iou > iouThreshold) {
              active[j] = false;
              numActive--;
            }
          }
        }
      }
    }
    return selectedDetections;
  }

  // --- Calculate Intersection over Union (IoU) ---
  double calculateIoU(Rect box1, Rect box2) {
    final double xA = max(box1.left, box2.left);
    final double yA = max(box1.top, box2.top);
    final double xB = min(box1.right, box2.right);
    final double yB = min(box1.bottom, box2.bottom);

    final double interArea = max(0, xB - xA) * max(0, yB - yA);
    if (interArea <= 0) return 0.0;

    final double box1Area = box1.width * box1.height;
    final double box2Area = box2.width * box2.height;
    final double unionArea = box1Area + box2Area - interArea;

    if (unionArea <= 0) return 0.0;

    final double iou = interArea / unionArea;
    return iou.clamp(0.0, 1.0);
  }

} // End of class