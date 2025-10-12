// lib/core/providers/usage_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/usage_repository.dart' as repo;
import '../services/local_usage_repository.dart';
import '../../features/home/models/usage_models.dart';
import 'achievements_provider.dart'; // if you made it reactive

final usageRepositoryProvider = Provider<repo.UsageRepository>((ref) {
  return LocalUsageRepository();
});

final recentUsageProvider = FutureProvider.autoDispose<List<UsageEntry>>((
  ref,
) async {
  final r = ref.watch(usageRepositoryProvider);
  return r.getRecentUsage();
});

final monthlySummaryProvider = FutureProvider.autoDispose
    .family<MonthlySummary, DateTime>((ref, when) async {
      final r = ref.watch(usageRepositoryProvider);
      return r.getMonthlySummary(when);
    });

final addUsageEntryProvider = FutureProvider.autoDispose
    .family<void, UsageEntry>((ref, entry) async {
      final r = ref.watch(usageRepositoryProvider);
      await r.addUsage(entry);

      ref.invalidate(recentUsageProvider);
      ref.invalidate(
        monthlySummaryProvider(
          DateTime(entry.start.year, entry.start.month, 1),
        ),
      );
      ref.invalidate(achievementsProvider); // ensures instant refresh
    });

// NEW: delete a single entry by id
final deleteUsageEntryProvider = FutureProvider.autoDispose.family<void, int>((
  ref,
  id,
) async {
  final r = ref.watch(usageRepositoryProvider);
  await r.deleteUsage(id);

  // Invalidate lists & summaries (use current month)
  ref.invalidate(recentUsageProvider);
  final now = DateTime.now();
  ref.invalidate(monthlySummaryProvider(DateTime(now.year, now.month, 1)));
  ref.invalidate(achievementsProvider);
});

// NEW: clear all usage rows
final clearAllUsageProvider = FutureProvider.autoDispose<void>((ref) async {
  final r = ref.watch(usageRepositoryProvider);
  await r.clearAllUsage();

  ref.invalidate(recentUsageProvider);
  final now = DateTime.now();
  ref.invalidate(monthlySummaryProvider(DateTime(now.year, now.month, 1)));
  ref.invalidate(achievementsProvider);
});
// -------- Computed providers for Home (dynamic dashboard) --------

/// Liters used today (sum over recent entries that start >= start of day)
final todayLitersProvider = Provider.autoDispose<double>((ref) {
  final recent = ref
      .watch(recentUsageProvider)
      .maybeWhen(data: (v) => v, orElse: () => const <UsageEntry>[]);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  return recent
      .where((e) => !e.start.isBefore(startOfDay))
      .fold<double>(0.0, (sum, e) => sum + e.liters);
});

/// Liters used this week (Mon..now). Adjust start day if you prefer Sat/Sun.
final weekLitersProvider = Provider.autoDispose<double>((ref) {
  final recent = ref
      .watch(recentUsageProvider)
      .maybeWhen(data: (v) => v, orElse: () => const <UsageEntry>[]);
  final now = DateTime.now();
 final start = DateTime(now.year, now.month, now.day)
     .subtract(const Duration(days: 6));
 return recent
     .where((e) => !e.start.isBefore(start))
     .fold<double>(0.0, (sum, e) => sum + e.liters);
});

/// Convenience: current month's summary as an AsyncValue for quick access on Home
final monthSummaryNowProvider =
    Provider.autoDispose<AsyncValue<MonthlySummary>>((ref) {
      final now = DateTime.now();
      return ref.watch(
        monthlySummaryProvider(DateTime(now.year, now.month, 1)),
      );
    });
final updateUsageEntryProvider = FutureProvider.autoDispose
    .family<void, UsageEntry>((ref, entry) async {
      final repository = ref.watch(usageRepositoryProvider);
      await repository.updateUsage(entry);

      // invalidate caches (same month as entry)
      ref.invalidate(recentUsageProvider);
      ref.invalidate(
        monthlySummaryProvider(
          DateTime(entry.start.year, entry.start.month, 1),
        ),
      );
    });
