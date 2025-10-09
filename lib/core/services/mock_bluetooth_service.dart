// lib/core/services/mock_bluetooth_service.dart
import 'dart:async';
import 'dart:convert';

/// Mock Bluetooth/Serial service that emits newline-delimited lines.
/// - Use `start()` / `stop()` (or connect/open / disconnect/close) from UI.
/// - Still supports the old `playSample(...)` method for compatibility.
class MockBluetoothService {
  final _controller = StreamController<String>.broadcast();
  Stream<String> get lines => _controller.stream;

  Timer? _timer;
  bool get _playing => _timer != null;

  // Default mixed sample (your Arduino-style output).
  String _sample = r'''
[ {"object":"Potato","tapOpenTime":3,"smartWaterUsed":0.900,"normalWaterUsed":1.500,"waterSaved":0.600}
{"object":"Potato","tapOpenTime":4,"smartWaterUsed":1.050,"normalWaterUsed":1.750,"waterSaved":0.700}
Detected: Dish
Servo1 rotated -30° (Dish)
{"object":"Dish","tapOpenTime":5,"smartWaterUsed":1.250,"normalWaterUsed":2.000,"waterSaved":0.750}
Detected: Dish
{"object":"Dish","tapOpenTime":6,"smartWaterUsed":1.450,"normalWaterUsed":2.250,"waterSaved":0.800}
{"object":"Dish","tapOpenTime":7,"smartWaterUsed":1.650,"normalWaterUsed":2.500,"waterSaved":0.850}
Water tap closed
Detected: Dish
Detected: Dish
Detected: Dish
Detected: Hand
Detected: Potato
Water tap opened
{"object":"Dish","tapOpenTime":0,"smartWaterUsed":1.850,"normalWaterUsed":2.750,"waterSaved":0.900}
Water tap closed]
''';

  int _lineDelayMs = 220;
  bool _loop = false;

  /// New: Start emitting the current sample.
  Future<void> start({
    String? sample,
    int lineDelayMs = 220,
    bool loop = false,
  }) async {
    if (_playing) return;
    if (sample != null) _sample = sample;
    _lineDelayMs = lineDelayMs;
    _loop = loop;

    final lines = const LineSplitter()
        .convert(_sample)
        .map((s) => s.trim())
        .toList();
    int i = 0;

    _timer = Timer.periodic(Duration(milliseconds: _lineDelayMs), (t) {
      if (i >= lines.length) {
        if (_loop) {
          i = 0;
        } else {
          stop();
          return;
        }
      }
      final line = lines[i++];
      if (line.isEmpty) return;
      _controller.add(line);
    });
  }

  /// New: Stop emitting.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  /// Old API kept for compatibility with your dev tools.
  Future<void> playSample(
    String sample, {
    int lineDelayMs = 120,
    bool loop = false,
  }) async {
    await stop();
    await start(sample: sample, lineDelayMs: lineDelayMs, loop: loop);
  }

  /// Convenience aliases so UI can call any of these names.
  Future<void> connect() => start();
  Future<void> disconnect() => stop();
  Future<void> open() => start();
  Future<void> close() => stop();

  /// Optional: feed one manual line (useful for quick tests).
  void feed(String line) {
    final s = line.trim();
    if (s.isNotEmpty) _controller.add(s);
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
