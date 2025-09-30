import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_usage_repository.dart';
import '../../features/home/models/usage_models.dart';

// Repository singleton
final usageRepositoryProvider = Provider<UsageRepository>((ref) {
  return LocalUsageRepository();
});

// List of recent usage
final recentUsageProvider = FutureProvider<List<UsageEntry>>((ref) async {
  final repo = ref.watch(usageRepositoryProvider);
  return repo.getRecentUsage();
});

// Monthly summary for a given month
final monthlySummaryProvider = FutureProvider.family<MonthlySummary, DateTime>((
  ref,
  when,
) async {
  final repo = ref.watch(usageRepositoryProvider);
  return repo.getMonthlySummary(when);
});

// Mutation: add usage -> invalidates lists/summaries
final addUsageEntryProvider = FutureProvider.family<void, UsageEntry>((
  ref,
  entry,
) async {
  final repo = ref.watch(usageRepositoryProvider);
  await repo.addUsage(entry);
  ref.invalidate(recentUsageProvider);
  // Also invalidate the month of this entry
  ref.invalidate(
    monthlySummaryProvider(DateTime(entry.start.year, entry.start.month, 1)),
  );
});
