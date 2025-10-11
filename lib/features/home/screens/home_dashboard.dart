// lib/features/home/screens/home_dashboard.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_v2.dart';
import '../../../core/providers/usage_provider.dart'; // todayLitersProvider, weekLitersProvider, monthSummaryNowProvider
import '../../../core/providers/ingest_providers.dart'; // feedRawLineProvider

// Real BLE service with picker (singleton)
import '../../../core/services/bluetooth_service.dart' as app;
import '../../../core/services/ble_uart_service.dart';

class HomeDashboard extends ConsumerStatefulWidget {
  const HomeDashboard({super.key});

  @override
  ConsumerState<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<HomeDashboard>
    with AutomaticKeepAliveClientMixin {
  // ---- Bluetooth/Serial ingest state ----
  late final app.BluetoothService _ble = BleUartService(); // singleton
  StreamSubscription<String>? _sub;

  bool _isConnected = false;
  String _status = 'Disconnected';

  // For status strip only (UI hints)
  String _lastDetected = '-';
  double _lastSmartLit = 0;

  // Throttle UI rebuilds triggered by incoming BLE lines
  Timer? _uiTick;
  bool _uiDirty = false;
  void _scheduleUiRefresh([int ms = 120]) {
    _uiDirty = true;
    if (_uiTick != null) return;
    _uiTick = Timer(Duration(milliseconds: ms), () {
      _uiTick = null;
      if (!mounted) return;
      if (_uiDirty) {
        _uiDirty = false;
        setState(() {});
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Reflect current service state (survives page changes).
    _isConnected = _ble.isConnected;
    _status = _isConnected ? 'Connected' : 'Disconnected';
    _attachBle();
  }

  void _attachBle() {
    // (Re)attach listener to the shared BLE lines stream.
    _sub?.cancel();
    _sub = _ble.lines.listen(
      _onLine,
      onError: (e) {
        _status = 'Error';
        _isConnected = _ble.isConnected; // reflect actual state
        _scheduleUiRefresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      },
      onDone: () {
        // The stream should not normally close; if it does, reflect state.
        _isConnected = _ble.isConnected;
        _status = _isConnected ? 'Connected' : 'Disconnected';
        _scheduleUiRefresh();
      },
      cancelOnError: false,
    );
  }

  @override
  void dispose() {
    _uiTick?.cancel();
    _sub?.cancel(); // only cancel local listener; DO NOT disconnect BLE
    super.dispose();
  }

  // ---- Connection control ----
  Future<void> _connect() async {
    if (_ble.isConnected) {
      // Already connected; nothing to do.
      _isConnected = true;
      _status = 'Connected';
      _scheduleUiRefresh();
      return;
    }
    setState(() => _status = 'Connecting…');

    try {
      await _ble.connectWithPicker(context); // picker appears once
      // Listener is already attached; just refresh flags.
      _isConnected = _ble.isConnected;
      _status = _isConnected ? 'Connected' : 'Disconnected';
      _scheduleUiRefresh();
    } catch (e, st) {
      debugPrint('BLE connect error: $e\n$st');
      _status = 'Error';
      _isConnected = _ble.isConnected;
      _scheduleUiRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  // NOTE: Per product requirement "never disconnect unless app closes or ESP off",
  // we do NOT expose a disconnect action. BleUartService.disconnect() is a no-op.

  // ---- Line handling (Arduino → central ingest) ----
  void _onLine(String raw) {
    final line = raw.trim();
    if (line.isEmpty) return;

    // Always forward to the central ingest (this commits sessions/entries)
    ref.read(feedRawLineProvider)(line);

    // Update connection hint based on service & log tags
    if (line.contains('INFO: BLE connected') ||
        line.contains('INFO: BLE session ready')) {
      _isConnected = true;
      _status = 'Connected';
      _scheduleUiRefresh();
    } else if (line.contains('WARN: BLE disconnected')) {
      _isConnected = false;
      _status = 'Disconnected';
      _scheduleUiRefresh();
    }

    // Light-weight UI hints for the status strip
    final l = line.toLowerCase();

    if (l == '[' || l == ']') return; // ignore array delimiters

    if (l.startsWith('detected:')) {
      _lastDetected = line.split(':').last.trim();
      _scheduleUiRefresh();
      return;
    }

    if (l.startsWith('servo')) {
      final m = RegExp(r'\(([^)]+)\)\s*$').firstMatch(line);
      if (m != null) {
        _lastDetected = m.group(1)!.trim();
        _scheduleUiRefresh();
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
        _scheduleUiRefresh();
      } catch (_) {
        // ignore malformed JSON
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

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
          // BLE connect only (no disconnect to keep persistent link)
          IconButton(
            tooltip: _isConnected ? 'Connected' : 'Connect to device',
            onPressed: _isConnected ? null : _connect,
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

  @override
  bool get wantKeepAlive => true;
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

          // Make the textual area flexible to avoid overflow on small widths
          Expanded(
            child: Row(
              children: [
                // Status (ellipsized if too long)
                Expanded(
                  child: Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Connection dot stays visible
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),

                const SizedBox(width: 8),

                // Detected label (ellipsized)
                Flexible(
                  child: Text(
                    'Detected: $lastDetected',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),

                const SizedBox(width: 12),

                // Liters is short; keep as-is
                Text(
                  'Liters: ${lastLiters.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
