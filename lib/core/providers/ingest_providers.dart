import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ingest/usage_session_aggregator.dart';
import '../ingest/usage_event.dart';

final sessionAggregatorProvider = Provider<UsageSessionAggregator>((ref) {
  final aggr = UsageSessionAggregator(ref);
  aggr.start();
  ref.onDispose(aggr.dispose);
  return aggr;
});

/// Feed a single JSON line (from serial log) into the aggregator.
final feedJsonLineProvider = Provider<void Function(String)>((ref) {
  final aggr = ref.watch(sessionAggregatorProvider);
  return (line) {
    if (line.trim().isEmpty) return;
    final obj = jsonDecode(line) as Map<String, dynamic>;
    aggr.onEvent(UsageEvent.fromJson(obj));
  };
});

/// Replay a multi-line log block (each line = JSON object)
final replayLogProvider =
    Provider<Future<void> Function(String content, {double speed})>((ref) {
      final feed = ref.watch(feedJsonLineProvider);
      return (content, {double speed = 1.0}) async {
        final delayMs = (200 ~/ speed).clamp(1, 200);
        for (final line in LineSplitter.split(content)) {
          if (line.trim().isEmpty) continue;
          feed(line);
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      };
    });
