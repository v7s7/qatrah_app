// lib/core/ingest/usage_session_aggregator.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/home/models/usage_models.dart';
import '../providers/usage_provider.dart';
import 'usage_event.dart';

class _PendingSession {
  final int sid;
  String activity; // mutable so we can reflect mid-session class updates
  final DateTime start;
  double liters; // cumulative liters within this sub-activity
  DateTime lastUpdate;

  _PendingSession({
    required this.sid,
    required this.activity,
    required this.start,
    required this.liters,
    required this.lastUpdate,
  });
}

class UsageSessionAggregator {
  UsageSessionAggregator(this._ref);

  final Ref _ref;
  final Map<int, _PendingSession> _sessions = {};
  Timer? _gcTimer;

  // Start a watchdog to auto-close abandoned sessions (no 'u'/'stop')
  void start() {
    _gcTimer ??= Timer.periodic(const Duration(seconds: 2), (_) => _gc());
  }

  void dispose() {
    _gcTimer?.cancel();
    _gcTimer = null;
  }

  Future<void> onEvent(UsageEvent e) async {
    switch (e.ev) {
      case 'start':
        _onStart(e);
        break;
      case 'u':
      case 'update':
        _onUpdate(e);
        break;
      case 'stop':
        await _onStop(e);
        break;
      default:
        // ignore
        break;
    }
  }

  void _onStart(UsageEvent e) {
    final activity = mapClassToActivity(e.cls);
    _sessions[e.sid] = _PendingSession(
      sid: e.sid,
      activity: activity,
      start: e.ts,
      liters: e.lit ?? 0.0,
      lastUpdate: e.ts,
    );
  }

  void _onUpdate(UsageEvent e) {
    final s = _sessions[e.sid];
    if (s == null) return;

    // Prefer cumulative liters within the sub-activity; else integrate flow if present
    if (e.lit != null) {
      s.liters = e.lit!;
    } else if (e.flow != null) {
      final secs = e.ts.difference(s.lastUpdate).inMilliseconds / 1000.0;
      s.liters += (e.flow! * secs / 60.0); // LPM * seconds / 60
    }

    // If classification changed mid-session (defensive; normally each sub-activity uses a new sid)
    final newActivity = mapClassToActivity(e.cls);
    if (newActivity != s.activity) {
      s.activity = newActivity;
    }

    s.lastUpdate = e.ts;
  }

  Future<void> _onStop(UsageEvent e) async {
    final s = _sessions.remove(e.sid);
    if (s == null) return;

    final end = e.ts.isAfter(s.lastUpdate) ? e.ts : s.lastUpdate;
    final duration = end.difference(s.start);
    final liters = (e.lit ?? s.liters).clamp(0.0, 200.0); // sanity clamp

    if (duration.inSeconds <= 0 || liters <= 0) return;

    // Persist an entry; also attach raw device fields if present on the stop event
    final entry = UsageEntry(
      activity: s.activity, // latest activity (e.g., "Washing Dishes")
      start: s.start,
      duration: duration, // seconds-accurate if DB v2+ is applied
      liters: liters,

      // NEW: raw device snapshot to display in UI
      object: e.cls, // normalized object label (e.g., 'dish', 'potato', 'hand')
      tapOpenSec: e.tapSec, // last tapOpenTime (sec)
      smartGlobal: e.smart, // smartWaterUsed (global/cumulative)
      normalGlobal: e.normal, // normalWaterUsed (optional)
      savedGlobal: e.saved, // waterSaved (optional)
    );

    await _ref.read(addUsageEntryProvider(entry).future);
  }

  // Auto-close sessions with no updates for N seconds (fallback if we never get 'stop')
  Future<void> _gc() async {
    final now = DateTime.now();
    final stale = <int>[];
    for (final s in _sessions.values) {
      if (now.difference(s.lastUpdate).inSeconds > 5) {
        stale.add(s.sid);
      }
    }
    for (final sid in stale) {
      final s = _sessions.remove(sid);
      if (s == null) continue;

      final duration = now.difference(s.start);
      final liters = s.liters.clamp(0.0, 200.0);

      if (duration.inSeconds > 0 && liters > 0) {
        // GC path: we don't have the raw device snapshot here, so leave those null
        final entry = UsageEntry(
          activity: s.activity,
          start: s.start,
          duration: duration,
          liters: liters,
          object: null,
          tapOpenSec: null,
          smartGlobal: null,
          normalGlobal: null,
          savedGlobal: null,
        );
        await _ref.read(addUsageEntryProvider(entry).future);
      }
    }
  }
}
