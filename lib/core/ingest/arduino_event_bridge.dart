// Converts Arduino console lines (JSON + plain text) into UsageEvent stream.
// Handles:
//  - Lines like: {"object":"Dish","tapOpenTime":5,"smartWaterUsed":1.25,"normalWaterUsed":2.0,"waterSaved":0.75}
//  - "Detected: Dish"
//  - "Water tap opened" / "Water tap closed"
//
// Strategy:
//  - Start a session when we see either:
//      a) "Water tap opened", or
//      b) first JSON with tapOpenTime == 0
//  - For every JSON line, emit an 'update' with cumulative liters = smartWaterUsed
//  - Close the session on "Water tap closed" (emit 'stop' with last liters)

import 'dart:convert';
import 'package:qatrah_app/core/ingest/usage_event.dart';

class ArduinoEventBridge {
  int _sidCounter = 0;
  int? _currentSid;
  String _currentCls = 'other';
  double _lastLiters = 0.0;
  bool _tapOpen = false;
  DateTime? _lastJsonTs;

  // Map Arduino "object" → your classifier codes expected by mapClassToActivity()
  static String _clsFromObject(String? obj) {
    switch ((obj ?? '').toLowerCase()) {
      case 'dish':
        return 'plate';
      case 'potato':
        return 'fruit';
      case 'hand':
        return 'hands';
      default:
        return 'other';
    }
  }

  void processLine(String rawLine, void Function(UsageEvent) emit) {
    final line = rawLine.trim();
    if (line.isEmpty) return;

    // JSON?
    if (line.startsWith('{') && line.endsWith('}')) {
      try {
        final Map<String, dynamic> j = jsonDecode(line);
        _onJson(j, emit);
      } catch (_) {
        // ignore malformed JSON; Arduino can glitch mid-line
      }
      return;
    }

    // Status / detection lines
    final lower = line.toLowerCase();
    if (lower.startsWith('detected:')) {
      // e.g., "Detected: Dish"
      final detected = line.split(':').last.trim();
      _currentCls = _clsFromObject(detected);
      return;
    }
    if (lower.contains('water tap opened')) {
      _startIfNeeded(emit, preferredCls: _currentCls);
      return;
    }
    if (lower.contains('water tap closed')) {
      _stopIfNeeded(emit);
      return;
    }

    // Ignore other noise
  }

  void _onJson(Map<String, dynamic> j, void Function(UsageEvent) emit) {
    final now = DateTime.now();

    final obj = (j['object'] as String?)?.trim();
    final cls = _clsFromObject(obj);
    _currentCls = cls; // adopt most recent classification

    final tapOpenTime = (j['tapOpenTime'] as num?)
        ?.toDouble(); // seconds since open
    final smartUsed = (j['smartWaterUsed'] as num?)?.toDouble() ?? 0.0;
    // normalWaterUsed & waterSaved are available if you later want to track savings precisely

    // If we see tapOpenTime == 0, that’s a clean "start" marker.
    if (tapOpenTime != null && tapOpenTime == 0) {
      _startIfNeeded(emit, preferredCls: cls, ts: now);
    } else {
      // If we get JSON before any "start", start now (fallback).
      _startIfNeeded(emit, preferredCls: cls, ts: now);
    }

    // Emit update with cumulative liters (preferred by your aggregator)
    if (_currentSid != null) {
      _lastLiters = smartUsed;
      _lastJsonTs = now;
      emit(
        UsageEvent(
          ts: now,
          ev: 'update', // your aggregator accepts 'u' or 'update'
          sid: _currentSid!,
          cls: _currentCls,
          lit: _lastLiters,
          // Optionally compute flow from deltas if you want:
          // flow: _estimateFlow(now, _lastJsonTs, _lastLiters, smartUsed),
        ),
      );
    }
  }

  void _startIfNeeded(
    void Function(UsageEvent) emit, {
    String? preferredCls,
    DateTime? ts,
  }) {
    if (_currentSid != null && _tapOpen) {
      return; // already in a session
    }
    _sidCounter += 1;
    _currentSid = _sidCounter;
    _tapOpen = true;
    _lastLiters = 0.0;
    _lastJsonTs = ts ?? DateTime.now();
    _currentCls = preferredCls ?? _currentCls;

    emit(
      UsageEvent(
        ts: _lastJsonTs!,
        ev: 'start',
        sid: _currentSid!,
        cls: _currentCls,
        lit: 0.0,
      ),
    );
  }

  void _stopIfNeeded(void Function(UsageEvent) emit) {
    if (_currentSid == null || !_tapOpen) return;

    final ts = DateTime.now();
    emit(
      UsageEvent(
        ts: ts,
        ev: 'stop',
        sid: _currentSid!,
        cls: _currentCls,
        lit: _lastLiters, // pass latest cumulative liters
      ),
    );

    _currentSid = null;
    _tapOpen = false;
    _lastJsonTs = null;
    _lastLiters = 0.0;
  }
}
