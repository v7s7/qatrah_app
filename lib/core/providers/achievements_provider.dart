// lib/core/providers/achievements_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'usage_provider.dart';
import '../../features/achievements/models/achievement.dart';
import '../../features/home/models/usage_models.dart';

final achievementsProvider = Provider.autoDispose<List<Achievement>>((ref) {
  // Establish *reactive* dependencies on the AsyncValues
  final recentAsync = ref.watch(recentUsageProvider);
  final now = DateTime.now();
  final summaryAsync = ref.watch(
    monthlySummaryProvider(DateTime(now.year, now.month, 1)),
  );

  // If either is still loading or errored, return a stable fallback
  final recent = recentAsync.maybeWhen(
    data: (v) => v,
    orElse: () => const <UsageEntry>[],
  );
  final summary = summaryAsync.maybeWhen(
    data: (s) => s,
    orElse: () => MonthlySummary(
      year: now.year,
      month: now.month,
      litersPerDay: const <double>[],
      totalLiters: 0,
      savedLiters: 0,
    ),
  );

  // Distinct days with any usage
  final daysWithAny = {
    for (final e in recent)
      DateTime(e.start.year, e.start.month, e.start.day).millisecondsSinceEpoch,
  }.length;

  // Monthly totals
  final savedLiters = summary.savedLiters;
  final totalThisMonth = summary.totalLiters;

  // Thresholds
  const kSaver100GalLiters = 378.5; // ~100 gal
  const kEco1000GalLiters = 3785.0; // ~1000 gal
  const kConsistentDays = 7.0;
  const kActiveTrackerLiters = 200.0;

  return [
    Achievement(
      id: 'water_saver',
      title: 'Water Saver',
      description: 'Saved 100 gallons',
      progress: savedLiters / kSaver100GalLiters,
      icon: 'water_drop',
    ),
    Achievement(
      id: 'consistent_saver',
      title: 'Consistent Saver',
      description: '7 days in a row',
      progress: daysWithAny / kConsistentDays,
      icon: 'calendar_today',
    ),
    Achievement(
      id: 'eco_warrior',
      title: 'Eco Warrior',
      description: 'Saved 1,000 gallons',
      progress: savedLiters / kEco1000GalLiters,
      icon: 'eco',
    ),
    Achievement(
      id: 'active_tracker',
      title: 'Active Tracker',
      description: '200+ liters this month',
      progress: totalThisMonth / kActiveTrackerLiters,
      icon: 'emoji_events',
    ),
  ];
});
