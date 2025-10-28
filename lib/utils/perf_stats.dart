class PerfTracker {
  // We'll compute fps as an EMA (exponential moving average).
  double _fps = 0;
  DateTime? _lastFrameTime;
  double _lastInferenceMs = 0;

  void frameArrived({required double inferenceMs}) {
    final now = DateTime.now();
    if (_lastFrameTime != null) {
      final dt = now.difference(_lastFrameTime!).inMilliseconds;
      if (dt > 0) {
        final instFps = 1000.0 / dt;
        // EMA to smooth: fps = 0.8*fps + 0.2*inst
        _fps = _fps == 0 ? instFps : (_fps * 0.8 + instFps * 0.2);
      }
    }
    _lastFrameTime = now;
    _lastInferenceMs = inferenceMs;
  }

  double get fps => _fps;
  double get inferenceMs => _lastInferenceMs;
}
