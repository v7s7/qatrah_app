class UsageEntry {
  /// Row id in the `usage_entries` table. Null for not-yet-persisted entries.
  final int? id; // <— new

  final DateTime start;
  final Duration duration;
  final String activity; // e.g., Washing Dishes
  final double liters;

  UsageEntry({
    this.id, // <— keep optional
    required this.start,
    required this.duration,
    required this.activity,
    required this.liters,
  });

  UsageEntry copyWith({
    int? id,
    DateTime? start,
    Duration? duration,
    String? activity,
    double? liters,
  }) {
    return UsageEntry(
      id: id ?? this.id,
      start: start ?? this.start,
      duration: duration ?? this.duration,
      activity: activity ?? this.activity,
      liters: liters ?? this.liters,
    );
  }
}

class MonthlySummary {
  final int year;
  final int month; // 1..12
  final List<double> litersPerDay; // length = days in month
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
