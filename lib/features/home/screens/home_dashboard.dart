// lib/features/home/screens/home_dashboard.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_v2.dart';
import '../../../core/providers/usage_provider.dart'; // todayLitersProvider, weekLitersProvider, monthSummaryNowProvider
import '../../../core/providers/ingest_providers.dart'; // sessionAggregatorProvider
import '../../../core/ingest/usage_event.dart';

// OPTIONAL: replace with your real BT service when ready.
// The mock just needs: Stream<String> get lines;
// Connection calls below are best-effort and tolerate missing methods.
import '../../../core/services/mock_bluetooth_service.dart';

class HomeDashboard extends ConsumerStatefulWidget {
  const HomeDashboard({super.key});

  @override
  ConsumerState<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<HomeDashboard> {
  // ---- Bluetooth/Serial ingest state ----
  final _ble = MockBluetoothService(); // swap to real service later
  StreamSubscription<String>? _sub;

  bool _isConnected = false;
  String _status = 'Disconnected';
  String _lastDetected = '-';
  double _lastSmartLit = 0;

  // Current open session state (we transform Arduino lines → UsageEvent sequence)
  int _sidCounter = 1;
  int? _activeSid;
  DateTime? _sessionStart;
  String _pendingCls =
      'hands'; // default class until we see "Detected: X" or JSON

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ---- Connection control ----
  Future<void> _connect() async {
    if (_isConnected) return;
    setState(() => _status = 'Connecting…');

    try {
      // Some mocks expose start(), others connect()/open(). Call best-effort via dynamic.
      final d = _ble as dynamic;
      bool tried = false;

      try {
        await d.start();
        tried = true;
      } catch (_) {}
      if (!tried) {
        try {
          await d.connect();
          tried = true;
        } catch (_) {}
      }
      if (!tried) {
        try {
          await d.open();
          tried = true;
        } catch (_) {}
      }
      // It's fine if none exist; we can still listen to .lines if provided.

      _sub = _ble.lines.listen(
        _onLine,
        onError: (e) => setState(() => _status = 'Error: $e'),
        onDone: () => setState(() {
          _isConnected = false;
          _status = 'Disconnected';
        }),
        cancelOnError: false,
      );

      setState(() {
        _isConnected = true;
        _status = 'Connected';
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _disconnect() async {
    try {
      final d = _ble as dynamic;
      bool tried = false;

      try {
        await d.stop();
        tried = true;
      } catch (_) {}
      if (!tried) {
        try {
          await d.disconnect();
          tried = true;
        } catch (_) {}
      }
      if (!tried) {
        try {
          await d.close();
          tried = true;
        } catch (_) {}
      }
    } catch (_) {
      // ignore
    }

    await _sub?.cancel();
    _sub = null;

    setState(() {
      _isConnected = false;
      _status = 'Disconnected';
    });
  }

  // ---- Line handling (Arduino → UsageEvent) ----
  void _onLine(String raw) {
    final line = raw.trim();
    if (line.isEmpty) return;

    // 1) Handle plain-text markers
    if (_handlePlainMarker(line)) return;

    // 2) Handle JSON objects like:
    // {"object":"Dish","tapOpenTime":5,"smartWaterUsed":1.250,"normalWaterUsed":2.000,"waterSaved":0.750}
    if (line.startsWith('{') && line.endsWith('}')) {
      try {
        final obj = jsonDecode(line) as Map<String, dynamic>;
        _handleJsonMeasurement(obj);
      } catch (_) {
        // swallow malformed JSON; device noise shouldn't kill the stream
      }
    }
  }

  bool _handlePlainMarker(String line) {
    final l = line.toLowerCase().trim();

    // Ignore list delimiters from your sample payload
    if (l == '[' || l == ']') return true;

    // "Detected: Dish"
    if (l.startsWith('detected:')) {
      final label = line.split(':').last.trim();
      _lastDetected = label;
      _pendingCls = _mapObjectToCls(label);
      setState(() {});
      return true;
    }

    // "Servo1 rotated -30° (Dish)"  → read the label inside parentheses
    if (l.startsWith('servo')) {
      final m = RegExp(r'\(([^)]+)\)\s*$').firstMatch(line);
      if (m != null) {
        final label = m.group(1)!.trim();
        _lastDetected = label;
        _pendingCls = _mapObjectToCls(label);
        setState(() {});
        return true;
      }
    }

    // "Water tap opened"  → start session
    if (l.contains('water tap opened')) {
      _startSession();
      return true;
    }

    // "Water tap closed"  → stop session
    if (l.contains('water tap closed')) {
      _stopSession();
      return true;
    }

    return false;
  }

  void _handleJsonMeasurement(Map<String, dynamic> j) {
    // Expected keys (some may be missing):
    // object, tapOpenTime (secs), smartWaterUsed (L), normalWaterUsed (L), waterSaved (L)
    final object = (j['object'] as String?)?.trim();
    if (object != null && object.isNotEmpty) {
      _lastDetected = object;
      _pendingCls = _mapObjectToCls(object);
    }

    // If no session is active yet but numbers are coming, start one now.
    if (_activeSid == null) {
      _startSession();
    }

    // Use tapOpenTime (secs) if provided to create monotonic timestamps for aggregator deltas
    final tSec = (j['tapOpenTime'] as num?)?.toDouble();
    final now = DateTime.now();
    final ts = (tSec != null && _sessionStart != null)
        ? _sessionStart!.add(Duration(milliseconds: (tSec * 1000).round()))
        : now;

    final smartLit = (j['smartWaterUsed'] as num?)?.toDouble();
    if (smartLit != null) {
      _lastSmartLit = smartLit;
      // Emit an update with cumulative liters (preferred by aggregator)
      _emitEvent(
        UsageEvent(
          ts: ts,
          ev: 'u',
          sid: _activeSid!,
          cls: _pendingCls, // 'plate' | 'fruit' | 'hands'
          lit: smartLit,
        ),
      );
    }
  }

  void _startSession() {
    if (_activeSid != null) {
      // Defensive: close any dangling session first
      _stopSession();
    }
    _activeSid = _sidCounter++;
    _sessionStart = DateTime.now();
    _lastSmartLit = 0;
    // Emit 'start'
    _emitEvent(
      UsageEvent(
        ts: _sessionStart!,
        ev: 'start',
        sid: _activeSid!,
        cls: _pendingCls, // best-known class at open time
      ),
    );
  }

  void _stopSession() {
    if (_activeSid == null || _sessionStart == null) return;
    final ts = DateTime.now();
    // Emit 'stop' with the latest cumulative smart liters (if we have it)
    _emitEvent(
      UsageEvent(
        ts: ts,
        ev: 'stop',
        sid: _activeSid!,
        cls: _pendingCls,
        lit: _lastSmartLit > 0 ? _lastSmartLit : null,
      ),
    );
    _activeSid = null;
    _sessionStart = null;
    _lastSmartLit = 0;
  }

  void _emitEvent(UsageEvent e) {
    // Send directly into the same aggregator your replay uses
    ref.read(sessionAggregatorProvider).onEvent(e);
  }

  // Map Arduino object labels → our internal classifier codes
  // inside _ArduinoIngest
  String _mapObjectToCls(String label) {
    final v = label.trim().toLowerCase();

    // normalize common synonyms
    if (v == 'dish' || v == 'dishes' || v == 'plate') return 'dish';
    if (v == 'hand' || v == 'hands') return 'hand';

    // otherwise keep the actual object name so “potato”, “bottle”, “cup”, etc. survive
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final double today = ref.watch(todayLitersProvider);
    final double week = ref.watch(weekLitersProvider);
    final monthSummary = ref.watch(monthSummaryNowProvider);

    final ringValue = (today / 5.0).clamp(0.0, 1.0);
    final savedLiters = monthSummary.maybeWhen(
      data: (s) => s.savedLiters,
      orElse: () => 0.0,
    );
    final savedAed = (savedLiters * 0.43).toStringAsFixed(2);

    return Scaffold(
      backgroundColor: AppThemeV2.bgNavy,
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.black.withOpacity(0.15),
        actions: [
          // BLE connect/disconnect
          IconButton(
            tooltip: _isConnected ? 'Disconnect device' : 'Connect to device',
            onPressed: _isConnected ? _disconnect : _connect,
            icon: Icon(
              _isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
            ),
          ),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.developer_mode),
              tooltip: 'Replay Serial Log',
              onPressed: () => Navigator.pushNamed(context, '/dev/replay'),
            ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => Navigator.pushNamed(context, '/report'),
            tooltip: 'Monthly Report',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection/status strip
              _StatusStrip(
                connected: _isConnected,
                status: _status,
                lastDetected: _lastDetected,
                lastLiters: _lastSmartLit,
              ),
              const SizedBox(height: 16),

              const Text(
                'Good morning, Ghala',
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
              const SizedBox(height: 24),

              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: CircularProgressIndicator(
                        value: ringValue.isNaN ? 0.0 : ringValue,
                        strokeWidth: 14,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF3CF6C8),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${today.toStringAsFixed(1)}L',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Used Today',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Text(
                'You saved ${savedLiters.toStringAsFixed(1)} L vs. normal faucet (this month)',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'This week\nYou used ${week.toStringAsFixed(1)} L',
                    style: const TextStyle(color: Colors.white),
                  ),
                  monthSummary.when(
                    data: (_) => Text(
                      '$savedAed AED\nsaved this month',
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: Colors.white),
                    ),
                    loading: () => const Text(
                      '…',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: Colors.white70),
                    ),
                    error: (_, __) => const Text(
                      '—',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Small status banner for connection + latest detection
class _StatusStrip extends StatelessWidget {
  final bool connected;
  final String status;
  final String lastDetected;
  final double lastLiters;

  const _StatusStrip({
    required this.connected,
    required this.status,
    required this.lastDetected,
    required this.lastLiters,
  });

  @override
  Widget build(BuildContext context) {
    final bg = connected ? const Color(0x2200FF8A) : const Color(0x22FFFFFF);
    final dot = connected ? Colors.greenAccent : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(
            connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            color: Colors.white70,
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            'Detected: $lastDetected',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(width: 12),
          Text(
            'Liters: ${lastLiters.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
