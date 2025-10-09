// lib/features/home/screens/home_dashboard.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_v2.dart';
import '../../../core/providers/usage_provider.dart'; // todayLitersProvider, weekLitersProvider, monthSummaryNowProvider
import '../../../core/providers/ingest_providers.dart'; // feedRawLineProvider

// Real BLE service with picker
import '../../../core/services/bluetooth_service.dart' as app;
import '../../../core/services/ble_uart_service.dart';

class HomeDashboard extends ConsumerStatefulWidget {
  const HomeDashboard({super.key});

  @override
  ConsumerState<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<HomeDashboard> {
  // ---- Bluetooth/Serial ingest state ----
  late final app.BluetoothService _ble = BleUartService();
  StreamSubscription<String>? _sub;

  bool _isConnected = false;
  String _status = 'Disconnected';

  // For status strip only (UI hints)
  String _lastDetected = '-';
  double _lastSmartLit = 0;

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
      await _ble.connectWithPicker(context); // picker appears
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
        _isConnected = _ble.isConnected;
        _status = _isConnected ? 'Connected' : 'Disconnected';
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _disconnect() async {
    await _ble.disconnect();
    await _sub?.cancel();
    _sub = null;
    setState(() {
      _isConnected = false;
      _status = 'Disconnected';
    });
  }

  // ---- Line handling (Arduino → central ingest) ----
  void _onLine(String raw) {
    final line = raw.trim();
    if (line.isEmpty) return;

    // Always forward to the central ingest (this commits sessions/entries)
    ref.read(feedRawLineProvider)(line);

    // Light-weight UI hints for the status strip
    final l = line.toLowerCase();

    if (l == '[' || l == ']') return; // ignore array delimiters

    if (l.startsWith('detected:')) {
      _lastDetected = line.split(':').last.trim();
      setState(() {});
      return;
    }

    if (l.startsWith('servo')) {
      final m = RegExp(r'\(([^)]+)\)\s*$').firstMatch(line);
      if (m != null) {
        _lastDetected = m.group(1)!.trim();
        setState(() {});
      }
      return;
    }

    // Read smartWaterUsed/object from JSON for display
    if (line.startsWith('{') && line.endsWith('}')) {
      try {
        final j = jsonDecode(line) as Map<String, dynamic>;
        final obj = (j['object'] as String?)?.trim();
        final lit = (j['smartWaterUsed'] as num?)?.toDouble();
        if (obj != null && obj.isNotEmpty) _lastDetected = obj;
        if (lit != null) _lastSmartLit = lit;
        setState(() {});
      } catch (_) {
        // ignore malformed JSON
      }
    }
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
