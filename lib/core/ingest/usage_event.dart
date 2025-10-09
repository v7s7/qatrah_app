class UsageEvent {
  final DateTime ts;
  final String ev; // "start" | "u" | "stop"
  final int sid;
  final String cls; // normalized object label ("dish", "potato", "hand", ...)

  final double? conf;
  final double? flow;
  final double? lit; // cumulative liters for THIS sub-activity

  // NEW: raw device fields (set on 'stop')
  final double? smart; // smartWaterUsed (global)
  final double? normal; // normalWaterUsed (global)
  final double? saved; // waterSaved (global)
  final double? tapSec; // tapOpenTime at last measurement (sec)

  UsageEvent({
    required this.ts,
    required this.ev,
    required this.sid,
    required this.cls,
    this.conf,
    this.flow,
    this.lit,
    this.smart,
    this.normal,
    this.saved,
    this.tapSec,
  });

  static UsageEvent fromJson(Map<String, dynamic> j) {
    final raw = (j['ts'] ?? j['t']) as num;
    final isSec = raw < 10_000_000_000;
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
      smart: (j['smart'] as num?)?.toDouble(),
      normal: (j['normal'] as num?)?.toDouble(),
      saved: (j['saved'] as num?)?.toDouble(),
      tapSec: (j['tapSec'] as num?)?.toDouble(),
    );
  }
}

// Keep this flexible so unknown labels show up nicely in UI.
String mapClassToActivity(String cls) {
  final c = cls.trim().toLowerCase();
  switch (c) {
    case 'dish':
    case 'dishes':
    case 'plate':
      return 'Washing Dishes';
    case 'hand':
    case 'hands':
      return 'Washing Hands';
    case 'fruit':
    case 'vegetable':
      return 'Washing Fruits';
    default:
      if (c.isEmpty) return 'Other';
      return 'Washing ${c[0].toUpperCase()}${c.substring(1)}';
  }
}
