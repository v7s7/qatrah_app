class UsageDraft {
  String activity;
  DateTime start;
  Duration duration;
  double liters;

  UsageDraft({
    required this.activity,
    required this.start,
    required this.duration,
    required this.liters,
  });

  factory UsageDraft.from({
    required String activity,
    DateTime? start,
    Duration? duration,
    double? liters,
  }) {
    return UsageDraft(
      activity: activity,
      start: start ?? DateTime.now(),
      duration: duration ?? const Duration(minutes: 5),
      liters: liters ?? 2,
    );
  }
}
