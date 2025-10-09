import 'dart:async';
import 'package:flutter/material.dart';
import 'bluetooth_service.dart';

class MockBluetoothService implements BluetoothService {
  final _ctrl = StreamController<String>.broadcast();
  Stream<String> get lines => _ctrl.stream;
  bool _connected = false;
  @override
  bool get isConnected => _connected;

  @override
  Future<void> connectWithPicker(BuildContext context) async {
    final sample = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => _MockPicker(),
    );
    if (sample == null) return;

    _connected = true;

    // Emit each line with small delay
    final lines = sample
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    for (final l in lines) {
      if (!_connected) break;
      _ctrl.add(l);
      await Future.delayed(const Duration(milliseconds: 180));
    }
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }
}

class _MockPicker extends StatelessWidget {
  const _MockPicker();

  @override
  Widget build(BuildContext context) {
    const demo = '''
Water tap opened
{"object":"Potato","tapOpenTime":0,"smartWaterUsed":0.10}
{"object":"Potato","tapOpenTime":1,"smartWaterUsed":0.15}
Detected: Dish
{"object":"Dish","tapOpenTime":2,"smartWaterUsed":0.30}
{"object":"Dish","tapOpenTime":3,"smartWaterUsed":0.45}
Water tap closed
''';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Mock device', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, demo),
              child: const Text('Play demo stream'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
