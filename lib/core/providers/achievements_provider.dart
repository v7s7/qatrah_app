// lib/core/providers/achievements_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'usage_provider.dart';
import '../../features/achievements/models/achievement.dart';
import '../../features/home/models/usage_models.dart';

final achievementsProvider = Provider.autoDispose<List<Achievement>>((ref) {
  // Reactive input
  final recentAsync = ref.watch(recentUsageProvider);
  final now = DateTime.now();

  // Safe fallback
  final recent = recentAsync.maybeWhen(
    data: (v) => v,
    orElse: () => const <UsageEntry>[],
  );

  // Distinct active days
  final daysWithAny = {
    for (final e in recent)
      DateTime(e.start.year, e.start.month, e.start.day).millisecondsSinceEpoch,
  }.length;

  // Baseline faucet rate (L/s)
  const double kNormalRateLps = 0.25;

  // Lifetime saved (from all loaded entries)
  double lifetimeSavedL = 0.0;
  for (final e in recent) {
    final normal = kNormalRateLps * e.duration.inSeconds;
    final saved = normal - e.liters; // e.liters = smart used for that entry
    if (saved.isFinite && saved > 0) lifetimeSavedL += saved;
  }

  // This month saved
  final startOfMonth = DateTime(now.year, now.month, 1);
  double monthSavedL = 0.0;
  for (final e in recent.where((e) => !e.start.isBefore(startOfMonth))) {
    final normal = kNormalRateLps * e.duration.inSeconds;
    final saved = normal - e.liters;
    if (saved.isFinite && saved > 0) monthSavedL += saved;
  }

  // Money model (same as Home)
  const double kAedPerLiter = 0.43;
  final lifetimeMoneyAed = lifetimeSavedL * kAedPerLiter;

  // Targets
  const double kLifetimeTarget = 1000.0;      // liters
  const double kMonthlyTarget = 200.0;        // liters
  const double kConsistentDaysTarget = 7.0;   // days
  const double kLifetimeMoneyTarget = 500.0;  // AED

  return [
    Achievement(
      id: 'total_saved_all_time',
      title: 'All-time Saver',
      description: '${lifetimeSavedL.toStringAsFixed(1)} L saved in total',
      progress: (lifetimeSavedL / kLifetimeTarget).clamp(0.0, 1.0),
      icon: 'water_drop',
    ),
    Achievement(
      id: 'monthly_saver',
      title: 'Monthly Saver',
      description: '${monthSavedL.toStringAsFixed(1)} L saved this month',
      progress: (monthSavedL / kMonthlyTarget).clamp(0.0, 1.0),
      icon: 'verified',
    ),
    Achievement(
      id: 'consistent_saver',
      title: 'Consistency',
      description: 'Active on $daysWithAny day(s)',
      progress: (daysWithAny / kConsistentDaysTarget).clamp(0.0, 1.0),
      icon: 'calendar_today',
    ),
    Achievement(
      id: 'total_money_saved',
      title: 'Money Saved',
      description: '${lifetimeMoneyAed.toStringAsFixed(2)} AED saved in total',
      progress: (lifetimeMoneyAed / kLifetimeMoneyTarget).clamp(0.0, 1.0),
      icon: 'emoji_events',
    ),
  ];
});
