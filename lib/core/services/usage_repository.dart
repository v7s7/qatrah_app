import 'package:qatrah_app/features/home/models/usage_models.dart';

abstract class UsageRepository {
  /// Recent usage entries (we use this for the Usage History screen).
  Future<List<UsageEntry>> recentUsage();

  /// Summary for a given month (first-of-month).
  Future<MonthlySummary> monthlySummary(DateTime when);

  /// Add a new usage entry.
  Future<void> addUsage(UsageEntry entry);
}
