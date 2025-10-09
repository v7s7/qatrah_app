// lib/core/services/ble_uart_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'bluetooth_service.dart' as app;

/// BLE Nordic UART (NUS) client that exposes a stream of **lines**.
/// Implements your app-level interface [app.BluetoothService].
class BleUartService implements app.BluetoothService {
  // NUS service/characteristics
  static final fbp.Guid _uartSvc = fbp.Guid(
    '6E400001-B5A3-F393-E0A9-E50E24DCCA9E',
  );
  static final fbp.Guid _txChar = fbp.Guid(
    '6E400003-B5A3-F393-E0A9-E50E24DCCA9E',
  ); // notify from device

  final _linesCtrl = StreamController<String>.broadcast();
  @override
  Stream<String> get lines => _linesCtrl.stream;

  fbp.BluetoothDevice? _device;
  fbp.BluetoothCharacteristic? _notifyChar;
  StreamSubscription<List<int>>? _notifySub;
  String _buf = '';

  @override
  bool get isConnected => _device != null;

  /// Scan → user picks a device → connect → subscribe to NUS notify char.
  @override
  Future<void> connectWithPicker(BuildContext context) async {
    // 1) Live scan + picker bottom sheet
    final picked = await showModalBottomSheet<fbp.ScanResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black.withOpacity(0.9),
      builder: (_) => const _BlePickerSheet(),
    );
    if (picked == null) return;

    // 2) Connect
    _device = picked.device;
    await _device!.connect(timeout: const Duration(seconds: 10));

    // 3) Discover services and find the UART notify characteristic
    final svcs = await _device!.discoverServices();
    for (final s in svcs) {
      if (s.uuid == _uartSvc) {
        for (final c in s.characteristics) {
          if (c.uuid == _txChar) {
            _notifyChar = c;
            break;
          }
        }
      }
    }
    if (_notifyChar == null) {
      await disconnect();
      throw Exception('UART characteristic not found on device');
    }

    // 4) Subscribe and buffer into newline-delimited lines
    await _notifyChar!.setNotifyValue(true);

    // flutter_blue_plus exposes onValueReceived / lastValueStream depending on version.
    final stream = _notifyChar!.lastValueStream; // works for recent versions

    _notifySub = stream.listen(
      (data) {
        final chunk = utf8.decode(data, allowMalformed: true);
        _buf += chunk;

        // Split on LF, keep partial line in buffer
        while (true) {
          final i = _buf.indexOf('\n');
          if (i < 0) break;
          final line = _buf.substring(0, i).trimRight(); // drop trailing \r
          _buf = _buf.substring(i + 1);
          if (line.isNotEmpty) _linesCtrl.add(line);
        }
      },
      onError: (e) {
        // Surface errors as a line (optional)
        _linesCtrl.add('Error: $e');
      },
    );
  }

  @override
  Future<void> disconnect() async {
    try {
      await _notifyChar?.setNotifyValue(false);
    } catch (_) {}
    await _notifySub?.cancel();
    _notifySub = null;
    _notifyChar = null;

    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
  }
}

/// Bottom sheet used by [BleUartService] to pick a device while scanning.
class _BlePickerSheet extends StatefulWidget {
  const _BlePickerSheet();

  @override
  State<_BlePickerSheet> createState() => _BlePickerSheetState();
}

class _BlePickerSheetState extends State<_BlePickerSheet> {
  final Map<String, fbp.ScanResult> _byId = {};
  StreamSubscription<List<fbp.ScanResult>>? _sub;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() => _scanning = true);

    _sub = fbp.FlutterBluePlus.scanResults.listen((batch) {
      setState(() {
        for (final r in batch) {
          _byId[r.device.remoteId.str] = r;
        }
      });
    });

    await fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));
    await fbp.FlutterBluePlus.isScanning.where((s) => !s).first;

    setState(() => _scanning = false);
  }

  @override
  void dispose() {
    _sub?.cancel();
    fbp.FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _byId.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.66,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Select a Bluetooth device',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            if (_scanning)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(),
              ),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Colors.white12),
                itemBuilder: (_, i) {
                  final r = items[i];
                  final name = r.device.platformName.isNotEmpty
                      ? r.device.platformName
                      : (r.advertisementData.advName.isNotEmpty
                            ? r.advertisementData.advName
                            : r.device.remoteId.str);
                  return ListTile(
                    title: Text(
                      name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'RSSI ${r.rssi}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    onTap: () => Navigator.pop(context, r),
                  );
                },
              ),
            ),
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
