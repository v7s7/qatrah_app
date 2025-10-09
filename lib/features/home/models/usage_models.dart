class UsageEntry {
  final int? id;

  final DateTime start;
  final Duration duration;
  final String activity; // UI label (e.g., Washing Dishes)
  final double liters; // liters for this sub-activity segment

  // NEW: raw device fields captured at STOP time of this segment
  final String? object; // e.g., "Dish", "Potato"
  final double? tapOpenSec; // last tapOpenTime (seconds)
  final double? smartGlobal; // device cumulative at STOP (L)
  final double? normalGlobal; // optional, passthrough if provided (L)
  final double? savedGlobal; // optional, passthrough if provided (L)

  UsageEntry({
    this.id,
    required this.start,
    required this.duration,
    required this.activity,
    required this.liters,
    this.object,
    this.tapOpenSec,
    this.smartGlobal,
    this.normalGlobal,
    this.savedGlobal,
  });

  UsageEntry copyWith({
    int? id,
    DateTime? start,
    Duration? duration,
    String? activity,
    double? liters,
    String? object,
    double? tapOpenSec,
    double? smartGlobal,
    double? normalGlobal,
    double? savedGlobal,
  }) {
    return UsageEntry(
      id: id ?? this.id,
      start: start ?? this.start,
      duration: duration ?? this.duration,
      activity: activity ?? this.activity,
      liters: liters ?? this.liters,
      object: object ?? this.object,
      tapOpenSec: tapOpenSec ?? this.tapOpenSec,
      smartGlobal: smartGlobal ?? this.smartGlobal,
      normalGlobal: normalGlobal ?? this.normalGlobal,
      savedGlobal: savedGlobal ?? this.savedGlobal,
    );
  }
}

class MonthlySummary {
  final int year;
  final int month;
  final List<double> litersPerDay;
  final double totalLiters;
  final double savedLiters;

  MonthlySummary({
    required this.year,
    required this.month,
    required this.litersPerDay,
    required this.totalLiters,
    required this.savedLiters,
  });
}
