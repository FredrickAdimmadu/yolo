import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

// Data class for isolate result
class IsolatePreprocessResult {
  final Float32List floatData;
  final double scale;
  final int padX;
  final int padY;

  IsolatePreprocessResult({
    required this.floatData,
    required this.scale,
    required this.padX,
    required this.padY,
  });
}

// Helper function to run preprocessing on a separate isolate
Future<IsolatePreprocessResult> preprocessOnIsolate(CameraImage image) {
  final isolateData = {
    'width': image.width,
    'height': image.height,
    'planeY': image.planes[0].bytes,
    'planeU': image.planes[1].bytes,
    'planeV': image.planes[2].bytes,
    'bytesPerRowY': image.planes[0].bytesPerRow,
    'uvRowStride': image.planes[1].bytesPerRow,
    'uvPixelStride': image.planes[1].bytesPerPixel!,
  };
  // Isolate.run takes a function and data, runs it on another thread
  return Isolate.run(() => _isolatePreprocess(isolateData));
}

// The function that performs heavy computations on the isolate
IsolatePreprocessResult _isolatePreprocess(Map<String, dynamic> data) {
  final width = data['width'] as int;
  final height = data['height'] as int;
  final planeY = data['planeY'] as Uint8List;
  final planeU = data['planeU'] as Uint8List;
  final planeV = data['planeV'] as Uint8List;
  final bytesPerRowY = data['bytesPerRowY'] as int;
  final uvRowStride = data['uvRowStride'] as int;
  final uvPixelStride = data['uvPixelStride'] as int;
  const inputSize = 640; // Model input size

  // 1. YUV -> RGB Conversion (Slow Dart code)
  final imgRgb = img.Image(width: width, height: height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final yp = y * bytesPerRowY + x;
      final uvIndex = (y >> 1) * uvRowStride + (x >> 1) * uvPixelStride;
      final Y = planeY[yp];
      final U = planeU[uvIndex];
      final V = planeV[uvIndex];
      int R = (Y + (1.370705 * (V - 128))).toInt().clamp(0, 255);
      int G = (Y - (0.698001 * (V - 128)) - (0.337633 * (U - 128)))
          .toInt()
          .clamp(0, 255);
      int B = (Y + (1.732446 * (U - 128))).toInt().clamp(0, 255);
      imgRgb.setPixelRgb(x, y, R, G, B); // Use setPixelRgb for efficiency
    }
  }

  // 2. Letterbox Resizing (Slow Dart code)
  final lbResult = _letterbox(imgRgb, inputSize);

  // 3. RGB -> Float32List Conversion (Slow Dart code, NCHW format)
  final floatData = _imageToFloat32(lbResult.image, size: inputSize);

  // Return the necessary data back to the main thread
  return IsolatePreprocessResult(
    floatData: floatData,
    scale: lbResult.scale,
    padX: lbResult.padX,
    padY: lbResult.padY,
  );
}

// --- Internal Helper Data Class ---
class _LetterboxResult {
  final img.Image image;
  final double scale;
  final int padX;
  final int padY;
  _LetterboxResult(this.image, this.scale, this.padX, this.padY);
}

// --- Internal Helper Functions (Only used by Isolate) ---
_LetterboxResult _letterbox(img.Image src, int size) {
  final scale = size / (src.width > src.height ? src.width : src.height);
  final newW = (src.width * scale).round();
  final newH = (src.height * scale).round();
  final resized = img.copyResize(src, width: newW, height: newH, interpolation: img.Interpolation.linear);
  final out = img.Image(width: size, height: size); // Creates black image by default
  // img.fill(out, color: img.ColorRgb8(0, 0, 0)); // Not needed if Image creates black
  final padX = ((size - newW) / 2).round();
  final padY = ((size - newH) / 2).round();
  img.compositeImage(out, resized, dstX: padX, dstY: padY); // Paste resized onto black
  return _LetterboxResult(out, scale, padX, padY);
}

Float32List _imageToFloat32(img.Image image, {required int size}) {
  final floats = Float32List(1 * 3 * size * size); // NCHW format
  int idx = 0;
  // Loop order NCHW
  for (int c = 0; c < 3; ++c) { // Channel (0=R, 1=G, 2=B)
    for (int y = 0; y < size; ++y) { // Height
      for (int x = 0; x < size; ++x) { // Width
        final pixel = image.getPixel(x, y);
        // Normalize to [0.0, 1.0] and assign based on channel
        floats[idx++] = (c == 0 ? pixel.r : (c == 1 ? pixel.g : pixel.b)) / 255.0;
      }
    }
  }
  return floats;
}


// --- Public Helper Data Class (Needed for parsing) ---
class LetterboxResult {
  final img.Image? tensorImage; // Nullable, as isolate doesn't return it
  final double scale;
  final int padX;
  final int padY;
  LetterboxResult(this.tensorImage, this.scale, this.padX, this.padY);
}