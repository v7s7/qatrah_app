class UsageEvent {
  final DateTime ts;
  final String ev; // "start" | "u" | "stop"
  final int sid; // session id from device
  final String cls; // "plate" | "fruit" | "hands" | ...
  final double? conf; // optional
  final double? flow; // liters per minute, optional
  final double? lit; // cumulative liters (preferred if provided)

  UsageEvent({
    required this.ts,
    required this.ev,
    required this.sid,
    required this.cls,
    this.conf,
    this.flow,
    this.lit,
  });

  static UsageEvent fromJson(Map<String, dynamic> j) {
    // Accept seconds or millis timestamps. If no 'ts' field, try 't'.
    final raw = (j['ts'] ?? j['t']) as num;
    final isSec = raw < 10_000_000_000; // crude check
    final ts = isSec
        ? DateTime.fromMillisecondsSinceEpoch(raw.toInt() * 1000)
        : DateTime.fromMillisecondsSinceEpoch(raw.toInt());

    return UsageEvent(
      ts: ts,
      ev: (j['ev'] as String).trim(),
      sid: (j['sid'] as num).toInt(),
      cls: (j['cls'] as String).trim(),
      conf: (j['conf'] as num?)?.toDouble(),
      flow: (j['flow'] as num?)?.toDouble(),
      lit: (j['lit'] as num?)?.toDouble(),
    );
  }
}

String mapClassToActivity(String cls) {
  switch (cls) {
    case 'plate':
      return 'Washing Dishes';
    case 'fruit':
      return 'Washing Fruits';
    case 'hands':
      return 'Washing Hands';
    default:
      return 'Other';
  }
}
