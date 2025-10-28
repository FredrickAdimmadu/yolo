import 'package:flutter/material.dart';
import '../models/detection_result.dart';

class DetectionPainter extends CustomPainter {
  final List<Detection> detections;

  DetectionPainter(this.detections);

  @override
  void paint(Canvas canvas, Size size) {
    final paintRect = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.tealAccent;

    final textBgPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.5);

    for (final det in detections) {
      // Clamp box to canvas
      final r = Rect.fromLTRB(
        det.box.left.clamp(0, size.width),
        det.box.top.clamp(0, size.height),
        det.box.right.clamp(0, size.width),
        det.box.bottom.clamp(0, size.height),
      );

      canvas.drawRect(r, paintRect);

      final label =
          "${det.label} ${(det.confidence * 100).toStringAsFixed(1)}%";

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: size.width);

      final bgRect = Rect.fromLTWH(
        r.left,
        r.top - (textPainter.height + 4),
        textPainter.width + 6,
        textPainter.height + 4,
      );

      canvas.drawRect(bgRect, textBgPaint);

      textPainter.paint(
        canvas,
        Offset(r.left + 3, r.top - (textPainter.height + 2)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant DetectionPainter oldDelegate) {
    return oldDelegate.detections != detections;
  }
}