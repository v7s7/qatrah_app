import 'package:sqflite/sqflite.dart';
import '../services/db/app_database.dart';
import '../../features/home/models/usage_models.dart';

abstract class UsageRepository {
  Future<List<UsageEntry>> getRecentUsage();
  Future<void> addUsage(UsageEntry entry);
  Future<MonthlySummary> getMonthlySummary(DateTime when);
}

class LocalUsageRepository implements UsageRepository {
  Future<Database> get _db async => AppDatabase.instance();

  @override
  Future<void> addUsage(UsageEntry entry) async {
    final db = await _db;
    await db.insert('usage_entries', {
      'activity': entry.activity,
      'start_millis': entry.start.millisecondsSinceEpoch,
      'duration_min': entry.duration.inMinutes,
      'liters': entry.liters,
    });
  }

  @override
  Future<List<UsageEntry>> getRecentUsage() async {
    final db = await _db;
    final rows = await db.query(
      'usage_entries',
      orderBy: 'start_millis DESC',
      limit: 200,
    );
    return rows.map((r) {
      return UsageEntry(
        activity: r['activity'] as String,
        start: DateTime.fromMillisecondsSinceEpoch(r['start_millis'] as int),
        duration: Duration(minutes: r['duration_min'] as int),
        liters: (r['liters'] as num).toDouble(),
      );
    }).toList();
  }

  @override
  Future<MonthlySummary> getMonthlySummary(DateTime when) async {
    final db = await _db;
    final first = DateTime(when.year, when.month, 1);
    final next = DateTime(when.year, when.month + 1, 1);
    final rows = await db.query(
      'usage_entries',
      where: 'start_millis >= ? AND start_millis < ?',
      whereArgs: [first.millisecondsSinceEpoch, next.millisecondsSinceEpoch],
    );

    // Aggregate per day
    final days = DateTime(when.year, when.month + 1, 0).day;
    final perDay = List<double>.filled(days, 0);
    double total = 0;
    for (final r in rows) {
      final start = DateTime.fromMillisecondsSinceEpoch(
        r['start_millis'] as int,
      );
      final liters = (r['liters'] as num).toDouble();
      total += liters;
      perDay[start.day - 1] += liters;
    }

    // Simple “saved” estimate (20% of total) until we get device baseline
    final saved = total * 0.2;

    return MonthlySummary(
      year: when.year,
      month: when.month,
      litersPerDay: perDay,
      totalLiters: total,
      savedLiters: saved,
    );
  }
}
