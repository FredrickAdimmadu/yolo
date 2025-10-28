import 'package:flutter/material.dart';

class Detection {
  final Rect box;
  final String label;
  final double confidence;

  Detection({
    required this.box,
    required this.label,
    required this.confidence,
  });
}