import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'usage_provider.dart';

class Achievement {
  final String title;
  final String subtitle;
  final bool achieved;
  Achievement(this.title, this.subtitle, this.achieved);
}

final achievementsProvider = FutureProvider<List<Achievement>>((ref) async {
  // Source data
  final recent = await ref.watch(recentUsageProvider.future);
  final now = DateTime.now();
  final summary = await ref.watch(
    monthlySummaryProvider(DateTime(now.year, now.month, 1)).future,
  );

  // Distinct days with any usage in the recent list (for simple “streak-ish” metric)
  final daysWithAny = {
    for (final e in recent)
      DateTime(e.start.year, e.start.month, e.start.day).millisecondsSinceEpoch,
  }.length;

  // We’ll use monthly saved & total liters from the summary
  final savedLiters = summary.savedLiters;
  final totalThisMonth = summary.totalLiters;

  // Define thresholds (tune later)
  final a = Achievement(
    'Water Saver',
    'Saved 100 gallons',
    savedLiters >= 378.5, // ~100 gal in liters
  );

  final b = Achievement(
    'Consistent Saver',
    '7 days in a row',
    daysWithAny >= 7,
  );

  final c = Achievement(
    'Eco Warrior',
    'Saved 1,000 gallons',
    savedLiters >= 3785, // ~1000 gal
  );

  // Optional extra to show total usage based progress (also prevents “unused” vibes)
  final d = Achievement(
    'Active Tracker',
    '200+ liters tracked this month',
    totalThisMonth >= 200,
  );

  return [a, b, c, d];
});
