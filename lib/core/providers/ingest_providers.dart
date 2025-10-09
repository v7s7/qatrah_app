// lib/core/providers/ingest_providers.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ingest/usage_session_aggregator.dart';
import '../ingest/usage_event.dart';

/// Aggregator lifecycle (GC watchdog etc.)
final sessionAggregatorProvider = Provider<UsageSessionAggregator>((ref) {
  final aggr = UsageSessionAggregator(ref);
  aggr.start();
  ref.onDispose(aggr.dispose);
  return aggr;
});

/// Ingest that SPLITS one tap into multiple sub-activities when the object changes.
/// Converts device *global cumulative* smartWaterUsed into *per-activity cumulatives*
/// by resetting a baseline at each sub-activity start.
class _ArduinoIngest {
  final Ref ref;

  // Device cumulative (monotonic within a tap or globally)
  double _lastSmartLit = 0.0;
  double _lastNormalLit = 0.0; // optional passthrough
  double _lastSavedLit = 0.0; // optional passthrough
  double? _lastTapOpenSec; // last seen tapOpenTime (sec)

  // Tap anchor used with tapOpenTime to rebuild absolute timestamps
  DateTime? _tapOpenTs;

  // Current sub-activity (its own sid & baseline)
  int _sidCounter = 1;
  int? _activeSid;
  DateTime? _subStartTs;
  String _currentCls = 'hands';
  double _baselineLit = 0.0; // device cumulative at sub-activity start

  _ArduinoIngest(this.ref);

  void feed(String rawLine) {
    final line = rawLine.trim();
    if (line.isEmpty) return;

    // 1) Plain-text markers & hints
    if (_handlePlainMarker(line)) return;

    // 2) JSON (either device schema or direct UsageEvent)
    if (line.startsWith('{') && line.endsWith('}')) {
      try {
        final obj = jsonDecode(line) as Map<String, dynamic>;

        // Direct UsageEvent passthrough (already our schema)
        if (obj.containsKey('ev') && obj.containsKey('sid')) {
          ref.read(sessionAggregatorProvider).onEvent(UsageEvent.fromJson(obj));
          return;
        }

        _handleJsonMeasurement(obj);
      } catch (_) {
        // ignore malformed json
      }
    }
  }

  bool _handlePlainMarker(String line) {
    final l = line.toLowerCase().trim();

    // Ignore bracket delimiters when device dumps arrays
    if (l == '[' || l == ']') return true;

    // "Detected: Dish" -> split at last known measure time if available
    if (l.startsWith('detected:')) {
      final label = line.split(':').last.trim();
      if (label.isNotEmpty) {
        final newCls = _mapObjectToCls(label);
        _maybeSplitActivity(
          newCls,
          _tsFromLastTapSecOr(DateTime.now()),
          false,
          0,
        );
      }
      return true;
    }

    // "Servo1 rotated -30° (Dish)" -> label in parentheses as hint
    if (l.startsWith('servo')) {
      final m = RegExp(r'\(([^)]+)\)\s*$').firstMatch(line);
      if (m != null) {
        final hint = m.group(1)!.trim();
        if (hint.isNotEmpty) {
          final newCls = _mapObjectToCls(hint);
          _maybeSplitActivity(
            newCls,
            _tsFromLastTapSecOr(DateTime.now()),
            false,
            0,
          );
        }
        return true;
      }
    }

    // "Water tap opened" -> anchor; close any dangling sub-activity first
    if (l.contains('water tap opened')) {
      _tapOpenTs = DateTime.now();
      _lastTapOpenSec = 0.0;
      _closeSubActivity(ts: _tapOpenTs);
      return true;
    }

    // "Water tap closed" -> close at the timestamp of last measurement if we have it
    if (l.contains('water tap closed')) {
      final closeTs = _tsFromLastTapSecOr(DateTime.now());
      _closeSubActivity(ts: closeTs);
      _tapOpenTs = null;
      _lastTapOpenSec = null;
      return true;
    }

    return false;
  }

  void _handleJsonMeasurement(Map<String, dynamic> j) {
    // Example device line:
    // {"object":"Dish","tapOpenTime":5,"smartWaterUsed":1.250,"normalWaterUsed":2.000,"waterSaved":0.750}

    // Normalize class
    final object = (j['object'] as String?)?.trim();
    final newCls = object != null && object.isNotEmpty
        ? _mapObjectToCls(object)
        : _currentCls;

    // Timestamp from tapOpenTime (sec) if available
    final tSec = (j['tapOpenTime'] as num?)?.toDouble();
    final now = DateTime.now();
    final ts = (tSec != null)
        ? (() {
            _lastTapOpenSec = tSec;
            _tapOpenTs ??= now.subtract(
              Duration(milliseconds: (tSec * 1000).round()),
            );
            return _tapOpenTs!.add(
              Duration(milliseconds: (tSec * 1000).round()),
            );
          })()
        : now;

    // Update device cumulatives (monotonic per tap)
    final smartLit = (j['smartWaterUsed'] as num?)?.toDouble();
    if (smartLit != null) _lastSmartLit = smartLit;
    _lastNormalLit =
        (j['normalWaterUsed'] as num?)?.toDouble() ?? _lastNormalLit;
    _lastSavedLit = (j['waterSaved'] as num?)?.toDouble() ?? _lastSavedLit;

    // Ensure a sub-activity; split if class changed
    _maybeSplitActivity(newCls, ts, smartLit != null, smartLit ?? 0.0);

    // Emit an update with RELATIVE cumulative (since sub-activity start)
    if (_activeSid != null) {
      final rel = _lastSmartLit - _baselineLit;
      final safeRel = rel.isFinite && rel > 0 ? rel : 0.0;

      _emit(
        UsageEvent(
          ts: ts,
          ev: 'u',
          sid: _activeSid!,
          cls: _currentCls,
          lit: safeRel, // cumulative within this sub-activity
          // (raw device fields are only committed on 'stop' to avoid churn)
        ),
      );
    }
  }

  /// Start new sub-activity if none, or split if the class changed.
  void _maybeSplitActivity(
    String newCls,
    DateTime ts,
    bool hasLit,
    double lit,
  ) {
    if (_activeSid == null) {
      _startSubActivity(newCls, ts, hasLit ? lit : _lastSmartLit);
      return;
    }
    if (newCls != _currentCls) {
      _closeSubActivity(ts: ts);
      final baseline = hasLit ? lit : _lastSmartLit;
      _startSubActivity(newCls, ts, baseline);
    }
  }

  void _startSubActivity(
    String cls,
    DateTime ts,
    double baselineCumulativeLit,
  ) {
    _currentCls = cls;
    _baselineLit = baselineCumulativeLit;
    _activeSid = _sidCounter++;
    _subStartTs = ts;

    _emit(
      UsageEvent(
        ts: ts,
        ev: 'start',
        sid: _activeSid!,
        cls: _currentCls,
        lit: 0.0,
      ),
    );
  }

  void _closeSubActivity({DateTime? ts}) {
    if (_activeSid == null || _subStartTs == null) return;

    final endTs = ts ?? DateTime.now();
    final used = _lastSmartLit - _baselineLit;
    final safeUsed = used.isFinite && used > 0 ? used : 0.0;

    _emit(
      UsageEvent(
        ts: endTs,
        ev: 'stop',
        sid: _activeSid!,
        cls: _currentCls,
        lit: safeUsed,
        // Attach raw device snapshot so UI can display it
        smart: _lastSmartLit,
        normal: _lastNormalLit,
        saved: _lastSavedLit,
        tapSec: _lastTapOpenSec,
      ),
    );

    _activeSid = null;
    _subStartTs = null;
    _baselineLit = _lastSmartLit; // carry forward
  }

  void _emit(UsageEvent e) {
    ref.read(sessionAggregatorProvider).onEvent(e);
  }

  DateTime _tsFromLastTapSecOr(DateTime fallback) {
    if (_tapOpenTs != null && _lastTapOpenSec != null) {
      return _tapOpenTs!.add(
        Duration(milliseconds: (_lastTapOpenSec! * 1000).round()),
      );
    }
    return fallback;
  }

  /// Normalize common synonyms but preserve unknowns (so “potato”, “cup”, … display distinctly).
  String _mapObjectToCls(String label) {
    final v = label.trim().toLowerCase();
    if (v == 'dish' || v == 'dishes' || v == 'plate') return 'dish';
    if (v == 'hand' || v == 'hands') return 'hand';
    if (v == 'fruit' || v == 'vegetable') return 'fruit';
    return v;
  }
}

/// High-level feed for mixed Arduino lines (JSON + text).
final feedRawLineProvider = Provider<void Function(String)>((ref) {
  final ingest = _ArduinoIngest(ref);
  return (line) => ingest.feed(line);
});

/// Backwards-compatible JSON feed; falls back to raw parser for non-UsageEvent JSON.
final feedJsonLineProvider = Provider<void Function(String)>((ref) {
  final rawFeed = ref.watch(feedRawLineProvider);
  return (line) {
    final s = line.trim();
    if (s.isEmpty) return;

    if (s.startsWith('{') && s.endsWith('}')) {
      try {
        final obj = jsonDecode(s) as Map<String, dynamic>;
        if (obj.containsKey('ev') && obj.containsKey('sid')) {
          ref.read(sessionAggregatorProvider).onEvent(UsageEvent.fromJson(obj));
          return;
        }
      } catch (_) {
        // fall through
      }
    }
    rawFeed(s);
  };
});

/// Replay a multi-line log block (supports mixed content).
final replayLogProvider =
    Provider<Future<void> Function(String content, {double speed})>((ref) {
      final feed = ref.watch(feedRawLineProvider);
      return (content, {double speed = 1.0}) async {
        final delayMs = (200 ~/ speed).clamp(1, 200);
        for (final line in const LineSplitter().convert(content)) {
          final s = line.trim();
          if (s.isEmpty) continue;
          feed(s);
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      };
    });
