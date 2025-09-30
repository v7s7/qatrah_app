import 'dart:async';
import 'package:qatrah_app/core/services/usage_repository.dart';
import 'package:qatrah_app/features/home/models/usage_models.dart';

class MockUsageRepository implements UsageRepository {
  // Seed with a few entries so the app has data.
  final List<UsageEntry> _entries = <UsageEntry>[
    UsageEntry(
      activity: 'Washing Dishes',
      start: DateTime.now().subtract(const Duration(days: 0, hours: 3)),
      duration: const Duration(minutes: 45),
      liters: 25,
    ),
    UsageEntry(
      activity: 'Washing Fruits',
      start: DateTime.now().subtract(const Duration(days: 0, hours: 8)),
      duration: const Duration(minutes: 10),
      liters: 15,
    ),
    UsageEntry(
      activity: 'Washing Hands',
      start: DateTime.now().subtract(const Duration(days: 3, hours: 18)),
      duration: const Duration(minutes: 5),
      liters: 2,
    ),
  ];

  @override
  Future<List<UsageEntry>> recentUsage() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final list = List<UsageEntry>.from(_entries);
    list.sort((a, b) => b.start.compareTo(a.start));
    return list;
  }

  @override
  Future<MonthlySummary> monthlySummary(DateTime when) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    // naive monthly aggregation from _entries:
    final first = DateTime(when.year, when.month, 1);
    final next = DateTime(when.year, when.month + 1, 1);
    final inMonth = _entries
        .where(
          (e) =>
              e.start.isAfter(
                first.subtract(const Duration(milliseconds: 1)),
              ) &&
              e.start.isBefore(next),
        )
        .toList();

    // Build a 28–31 length vector (use the actual month length)
    final daysInMonth = DateTime(when.year, when.month + 1, 0).day;
    final litersPerDay = List<double>.filled(daysInMonth, 0);
    double saved = 0;

    for (final e in inMonth) {
      final d = e.start.day - 1;
      litersPerDay[d] += e.liters;
      // silly “saved” estimate for demo:
      saved += (e.liters * 0.2);
    }

    final total = litersPerDay.fold<double>(0, (s, v) => s + v);

    return MonthlySummary(
      year: when.year,
      month: when.month,
      litersPerDay: litersPerDay,
      totalLiters: total,
      savedLiters: saved,
    );
  }

  @override
  Future<void> addUsage(UsageEntry entry) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _entries.add(entry);
  }
}
