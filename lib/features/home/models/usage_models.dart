class UsageEntry {
  final DateTime start;
  final Duration duration;
  final String activity; // e.g., Washing Dishes
  final double liters;

  UsageEntry({
    required this.start,
    required this.duration,
    required this.activity,
    required this.liters,
  });
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
