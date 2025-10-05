// lib/core/services/usage_repository.dart
import '../../features/home/models/usage_models.dart';

abstract class UsageRepository {
  Future<void> addUsage(UsageEntry entry);
  Future<List<UsageEntry>> getRecentUsage();
  Future<MonthlySummary> getMonthlySummary(DateTime when);
  Future<void> deleteUsage(int id);
  Future<void> clearAllUsage();

  // NEW
  Future<void> updateUsage(UsageEntry entry); // expects entry.id != null
}
