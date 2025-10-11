// lib/core/services/ble_uart_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

import 'bluetooth_service.dart' as app;
import 'ble_permissions.dart';

/// Internal shared hub so all BleUartService instances (e.g. after page
/// navigation) attach to the *same* connection + lines stream.
class _BleHub {
  final linesCtrl = StreamController<String>.broadcast();

  fbp.BluetoothDevice? device;
  fbp.BluetoothCharacteristic? notifyChar;

  StreamSubscription<List<int>>? notifySub;
  StreamSubscription<fbp.BluetoothConnectionState>? connSub;

  // Buffering for line splitting
  String buf = '';
  Timer? idleFlush;

  // Connection policy
  bool wantConnection = false; // sticky desire to stay connected
  bool connecting = false;
  bool isConnected = false;
  int reconnectAttempts = 0;
  Timer? reconnectTimer;

  void push(String s) {
    if (!linesCtrl.isClosed) linesCtrl.add(s);
  }

  Future<void> cleanupConnection() async {
    idleFlush?.cancel();
    idleFlush = null;

    try {
      await notifyChar?.setNotifyValue(false);
    } catch (_) {}
    await notifySub?.cancel();
    notifySub = null;

    await connSub?.cancel();
    connSub = null;

    notifyChar = null;
  }

  // We never null the device when pages change; only when the user truly
  // wants to forget the target (not used in the “persistent” mode).
  Future<void> disconnectDeviceObject() async {
    try {
      await device?.disconnect();
    } catch (_) {}
    device = null;
  }

  void scheduleIdleFlush() {
    idleFlush?.cancel();
    idleFlush = Timer(const Duration(milliseconds: 250), () {
      if (buf.trim().isEmpty) return;
      final b = buf;
      final looksJson = b.startsWith('{') && b.contains('}');
      final looksDetected = b.toLowerCase().contains('detected:');
      if (looksJson || looksDetected || b.length > 256) {
        final line = buf.trimRight();
        buf = '';
        push(line);
      }
    });
  }

  void onNotifyData(List<int> data) {
    final chunk = utf8.decode(data, allowMalformed: true);
    buf += chunk;

    // split on CR/LF, leave remainder
    while (true) {
      final iN = buf.indexOf('\n');
      final iR = buf.indexOf('\r');
      int cut;
      if (iN == -1 && iR == -1) break;
      if (iN == -1) {
        cut = iR;
      } else if (iR == -1) {
        cut = iN;
      } else {
        cut = iN < iR ? iN : iR;
      }
      final line = buf.substring(0, cut).trimRight();
      buf = buf.substring(cut + 1);
      if (line.isNotEmpty) push(line);
    }

    scheduleIdleFlush();
  }
}

// A single global hub across screens.
final _hub = _BleHub();

/// Lifecycle observer that triggers a fast reconnect when the app is resumed.
class _AppLifecycleReconnector with WidgetsBindingObserver {
  void attach() => WidgetsBinding.instance.addObserver(this);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_hub.wantConnection &&
          !_hub.isConnected &&
          !_hub.connecting &&
          _hub.device != null) {
        _hub.push('INFO: App resumed — trying to reconnect …');
        BleUartService._instance._connectToCurrentDevice();
      }
    }
  }
}

/// BLE client that lists **all** nearby devices (by name if available),
/// then connects and listens to Nordic UART TX notifications (if present).
/// Stability:
///  - Singleton service instance across pages
///  - Connection priority boost (Android)
///  - MTU 247 (with short settle delay)
///  - One-shot cache-clear retry on Android GATT 133
///  - Auto-reconnect with exponential backoff & resume on app focus
///  - Persistent watchdog to recover from any stray disconnect on navigation
class BleUartService implements app.BluetoothService {
  // --- Singleton ---
  static final BleUartService _instance = BleUartService._internal();
  factory BleUartService() => _instance;
  BleUartService._internal() {
    _lifecycle.attach();
    _startWatchdog(); // keep-alive across page changes
  }
  static final _AppLifecycleReconnector _lifecycle = _AppLifecycleReconnector();

  // Nordic UART (NUS) UUIDs.
  static final fbp.Guid _uartSvc = fbp.Guid(
    '6E400001-B5A3-F393-E0A9-E50E24DCCA9E',
  );
  static final fbp.Guid _txChar = fbp.Guid(
    '6E400003-B5A3-F393-E0A9-E50E24DCCA9E',
  ); // notify from device

  // GAP Device Name (optional nice-to-have after connect)
  static final fbp.Guid _gapSvc = fbp.Guid(
    '00001800-0000-1000-8000-00805f9b34fb',
  );
  static final fbp.Guid _devNameChar = fbp.Guid(
    '00002A00-0000-1000-8000-00805f9b34fb',
  );

  @override
  Stream<String> get lines => _hub.linesCtrl.stream;
  @override
  bool get isConnected => _hub.isConnected;

  // guard to avoid multiple pickers
  bool _pickerOpen = false;

  Timer? _watchdog;

  void _startWatchdog() {
    _watchdog?.cancel();
    // Every 4s, ensure we are reconnecting if desired.
    _watchdog = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!_hub.wantConnection) return;
      if (_hub.isConnected) return;
      if (_hub.connecting) return;
      if (_hub.device == null) return;

      // If no reconnect timer is scheduled (e.g., due to a provider/page GC),
      // immediately try to connect and then re-arm backoff if needed.
      if (_hub.reconnectTimer == null) {
        _hub.push('INFO: Watchdog: reconnecting …');
        try {
          await _connectToCurrentDevice();
        } catch (e) {
          // If it still fails, fall back to the normal backoff loop.
          _scheduleReconnect();
        }
      }
    });
  }

  // ---------- helpers ----------
  Future<void> _preflight() async {
    await ensureBlePermissions();

    final supported = await fbp.FlutterBluePlus.isSupported;
    if (!supported) {
      throw Exception('Bluetooth LE is not supported on this device.');
    }

    // Ensure adapter ON
    var state = await fbp.FlutterBluePlus.adapterState.first;
    if (state != fbp.BluetoothAdapterState.on) {
      try {
        await fbp.FlutterBluePlus.turnOn();
      } catch (_) {}
      state = await fbp.FlutterBluePlus.adapterState.first;
      if (state != fbp.BluetoothAdapterState.on) {
        throw Exception('Please turn ON Bluetooth and try again.');
      }
    }
  }

  void _listenConnectionState() {
    _hub.connSub?.cancel();
    final dev = _hub.device;
    if (dev == null) return;

    _hub.connSub = dev.connectionState.listen((state) {
      if (state == fbp.BluetoothConnectionState.connected) {
        _hub.isConnected = true;
        _hub.reconnectAttempts = 0;
        _hub.reconnectTimer?.cancel();
        _hub.reconnectTimer = null;
        _hub.push('INFO: BLE connected');
      } else if (state == fbp.BluetoothConnectionState.disconnected) {
        final was = _hub.isConnected;
        _hub.isConnected = false;
        if (was) _hub.push('WARN: BLE disconnected');

        // Keep trying forever while app is alive and user wanted a connection.
        if (_hub.wantConnection) {
          _scheduleReconnect();
        }
      }
    });
  }

  void _scheduleReconnect() {
    _hub.reconnectTimer?.cancel();
    final seconds = 1 << (_hub.reconnectAttempts.clamp(0, 5)); // up to 32s
    _hub.reconnectAttempts++;
    _hub.push('INFO: Reconnecting in ${seconds}s …');

    _hub.reconnectTimer = Timer(Duration(seconds: seconds), () async {
      _hub.reconnectTimer = null; // allow watchdog to intervene again
      if (!_hub.wantConnection || _hub.device == null) return;
      if (_hub.connecting) return;
      try {
        await _connectToCurrentDevice();
      } catch (e) {
        _hub.push('WARN: Reconnect failed: $e');
        _scheduleReconnect();
      }
    });
  }

  Future<void> _connectToCurrentDevice() async {
    if (_hub.connecting) return;
    final dev = _hub.device;
    if (dev == null) throw Exception('Internal error: no device selected');

    _hub.connecting = true;
    try {
      await _hub.cleanupConnection();

      // IMPORTANT: watch state *before* connect, so we see early transitions
      _listenConnectionState();

      Future<void> _doConnect() async {
        // Use autoConnect: false to avoid Android background connection path
        await dev.connect(
          timeout: const Duration(seconds: 20),
          autoConnect: false,
        );

        // Boost priority
        try {
          await dev.requestConnectionPriority(
            connectionPriorityRequest: fbp.ConnectionPriority.high,
          );
        } catch (_) {}

        // Small settle before MTU (prevents some Android 133s)
        await Future.delayed(const Duration(milliseconds: 250));

        // Negotiate MTU
        try {
          await dev.requestMtu(247);
        } catch (_) {}
      }

      // Attempt connect, recover once on Android GATT 133 by clearing cache.
      try {
        await _doConnect();
      } on fbp.FlutterBluePlusException catch (e) {
        final es = e.toString();
        final is133 =
            es.contains('android-code: 133') ||
            es.contains('ANDROID_SPECIFIC_ERROR') ||
            es.contains('GATT 133') ||
            es.contains('133');
        if (is133) {
          try {
            await dev.clearGattCache(); // Android only; ignore elsewhere
          } catch (_) {}
          await Future.delayed(const Duration(milliseconds: 400));
          await _doConnect();
        } else {
          rethrow;
        }
      }

      // Discover services & find NUS TX notify char
      final svcs = await dev.discoverServices();
      _hub.notifyChar = null;

      for (final s in svcs) {
        if (s.uuid == _uartSvc) {
          for (final c in s.characteristics) {
            if (c.uuid == _txChar) {
              _hub.notifyChar = c;
              break;
            }
          }
        }
        if (_hub.notifyChar != null) break;
      }

      if (_hub.notifyChar == null) {
        _hub.push('ERROR: NUS TX characteristic not found. Will retry.');
        throw Exception(
          'Connected, but Nordic UART (TX) characteristic was not found.',
        );
      }

      // Read Device Name (optional)
      try {
        for (final s in svcs) {
          if (s.uuid == _gapSvc) {
            for (final c in s.characteristics) {
              if (c.uuid == _devNameChar) {
                final dn = utf8
                    .decode(await c.read(), allowMalformed: true)
                    .trim();
                if (dn.isNotEmpty) _hub.push('INFO: Connected to $dn');
              }
            }
          }
        }
      } catch (_) {}

      // Subscribe to notifications
      await _hub.notifyChar!.setNotifyValue(true);
      _hub.notifySub?.cancel();
      final stream = _hub.notifyChar!.lastValueStream;
      _hub.notifySub = stream.listen(
        _hub.onNotifyData,
        onError: (e) => _hub.push('Error: $e'),
      );

      _hub.isConnected = true;
      _hub.push('INFO: BLE session ready');
    } finally {
      _hub.connecting = false;
    }
  }

  // ---------- public API ----------
  @override
  Future<void> connectWithPicker(BuildContext context) async {
    await _preflight();

    if (_hub.connecting) {
      _hub.push('INFO: Already connecting…');
      return;
    }
    if (_hub.isConnected) {
      _hub.push('INFO: Already connected.');
      return;
    }
    if (_pickerOpen) {
      _hub.push('INFO: Device picker already open.');
      return;
    }

    _pickerOpen = true;
    final picked = await showModalBottomSheet<fbp.ScanResult>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.black.withOpacity(0.9),
      builder: (_) => const _BlePickerSheet(),
    );
    _pickerOpen = false;

    if (picked == null) {
      _hub.push('INFO: Device picker dismissed.');
      return; // <-- no throw
    }

    // Stop scan before connecting
    try {
      await fbp.FlutterBluePlus.stopScan();
      await fbp.FlutterBluePlus.isScanning.where((s) => !s).first;
    } catch (_) {}

    _hub.wantConnection = true; // <-- sticky desire to stay connected
    _hub.device = picked.device;

    try {
      await _connectToCurrentDevice();
    } catch (e) {
      await _hub.cleanupConnection();
      _hub.push('WARN: Initial connect failed: $e');
      _scheduleReconnect();
    }
  }

  // In persistent mode, ignore routine disconnect requests (e.g., page dispose).
  @override
  Future<void> disconnect() async {
    _hub.push(
      'INFO: Persistent mode: ignoring disconnect (will stay connected)',
    );
    // If you need a real manual disconnect later, add a `forceDisconnect()`
    // that sets `_hub.wantConnection=false`, cancels timers, calls cleanup,
    // and then `_hub.device?.disconnect()`.
  }
}

/// Picker bottom sheet — lists **all** BLE devices (shows names when available)
class _BlePickerSheet extends StatefulWidget {
  const _BlePickerSheet();
  @override
  State<_BlePickerSheet> createState() => _BlePickerSheetState();
}

class _BlePickerSheetState extends State<_BlePickerSheet> {
  final Map<String, fbp.ScanResult> _byId = {};
  StreamSubscription<List<fbp.ScanResult>>? _sub;
  bool _scanning = false;
  DateTime _lastScanEnd = DateTime.fromMillisecondsSinceEpoch(0);

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    if (_scanning) return;

    // Cooldown to avoid Android status=6 (SCANNING_TOO_FREQUENTLY)
    final since = DateTime.now().difference(_lastScanEnd);
    if (since.inMilliseconds < 600) {
      await Future.delayed(Duration(milliseconds: 600 - since.inMilliseconds));
    }

    _safeSetState(() {
      _scanning = true;
      _byId.clear();
    });

    await _sub?.cancel();
    _sub = fbp.FlutterBluePlus.scanResults.listen((batch) {
      if (!mounted) return;
      bool changed = false;
      for (final r in batch) {
        final key = r.device.remoteId.str;
        final prev = _byId[key];

        if (prev == null ||
            prev.rssi != r.rssi ||
            prev.device.platformName != r.device.platformName ||
            prev.advertisementData.advName != r.advertisementData.advName) {
          _byId[key] = r;
          changed = true;
        }
      }
      if (changed) _safeSetState(() {});
    });

    if (await fbp.FlutterBluePlus.isScanning.first) {
      try {
        await fbp.FlutterBluePlus.stopScan();
      } catch (_) {}
      await fbp.FlutterBluePlus.isScanning.where((s) => !s).first;
    }

    await Future.delayed(const Duration(milliseconds: 250));

    Future<void> start() async {
      await fbp.FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 8),
        androidScanMode: fbp.AndroidScanMode.lowLatency,
      );
      await fbp.FlutterBluePlus.isScanning.where((s) => !s).first;
    }

    try {
      await start();
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 1200));
      try {
        await start();
      } catch (_) {}
    } finally {
      _lastScanEnd = DateTime.now();
      _safeSetState(() => _scanning = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    // ignore: discarded_futures
    fbp.FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sort by: has a human-friendly name first, then RSSI desc
    final items = _byId.values.toList()
      ..sort((a, b) {
        String an = a.device.platformName.isNotEmpty
            ? a.device.platformName
            : a.advertisementData.advName;
        String bn = b.device.platformName.isNotEmpty
            ? b.device.platformName
            : b.advertisementData.advName;
        final aHasName = an.isNotEmpty ? 1 : 0;
        final bHasName = bn.isNotEmpty ? 1 : 0;
        if (aHasName != bHasName) return bHasName - aHasName;
        return b.rssi.compareTo(a.rssi);
      });

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
              child: items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'No devices found.\n'
                          '• Ensure Bluetooth + (on older Android) Location are ON\n'
                          '• Make sure your device is advertising / connectable',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Colors.white12),
                      itemBuilder: (_, i) {
                        final r = items[i];
                        final displayName = r.device.platformName.isNotEmpty
                            ? r.device.platformName
                            : (r.advertisementData.advName.isNotEmpty
                                  ? r.advertisementData.advName
                                  : r.device.remoteId.str);
                        return ListTile(
                          title: Text(
                            displayName,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(onPressed: _startScan, child: const Text('Rescan')),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
