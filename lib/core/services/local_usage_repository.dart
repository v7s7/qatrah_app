import 'package:sqflite/sqflite.dart';
import '../services/db/app_database.dart';
import '../../features/home/models/usage_models.dart';
import 'usage_repository.dart' as repo;

class LocalUsageRepository implements repo.UsageRepository {
  Future<Database> get _db async => AppDatabase.instance();

  @override
  Future<void> addUsage(UsageEntry entry) async {
    final db = await _db;
    await db.insert('usage_entries', {
      'activity': entry.activity,
      'start_millis': entry.start.millisecondsSinceEpoch,
      'duration_min': entry.duration.inMinutes, // legacy (kept)
      'duration_secs': entry.duration.inSeconds, // authoritative
      'liters': entry.liters,

      // NEW: raw device fields (nullable)
      'object': entry.object,
      'tap_open_sec': entry.tapOpenSec,
      'smart_global': entry.smartGlobal,
      'normal_global': entry.normalGlobal,
      'saved_global': entry.savedGlobal,
    });
  }

  @override
  Future<void> updateUsage(UsageEntry entry) async {
    if (entry.id == null) return;
    final db = await _db;
    await db.update(
      'usage_entries',
      {
        'activity': entry.activity,
        'start_millis': entry.start.millisecondsSinceEpoch,
        'duration_min': entry.duration.inMinutes,
        'duration_secs': entry.duration.inSeconds,
        'liters': entry.liters,

        // NEW: raw device fields (nullable)
        'object': entry.object,
        'tap_open_sec': entry.tapOpenSec,
        'smart_global': entry.smartGlobal,
        'normal_global': entry.normalGlobal,
        'saved_global': entry.savedGlobal,
      },
      where: 'id = ?',
      whereArgs: [entry.id],
    );
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
      final secs =
          (r['duration_secs'] as int?) ??
          (((r['duration_min'] as int?) ?? 0) * 60);

      return UsageEntry(
        id: r['id'] as int?,
        activity: r['activity'] as String,
        start: DateTime.fromMillisecondsSinceEpoch(r['start_millis'] as int),
        duration: Duration(seconds: secs), // seconds-accurate
        liters: (r['liters'] as num).toDouble(),

        // NEW: raw device fields (nullable in DB)
        object: r['object'] as String?,
        tapOpenSec: (r['tap_open_sec'] as num?)?.toDouble(),
        smartGlobal: (r['smart_global'] as num?)?.toDouble(),
        normalGlobal: (r['normal_global'] as num?)?.toDouble(),
        savedGlobal: (r['saved_global'] as num?)?.toDouble(),
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

    final days = DateTime(when.year, when.month + 1, 0).day;
    final perDay = List<double>.filled(days, 0.0);
    double total = 0.0;

    for (final r in rows) {
      final start = DateTime.fromMillisecondsSinceEpoch(
        r['start_millis'] as int,
      );
      final liters = (r['liters'] as num).toDouble();
      total += liters;
      perDay[start.day - 1] += liters;
    }

    final saved = total * 0.20; // heuristic
    return MonthlySummary(
      year: when.year,
      month: when.month,
      litersPerDay: perDay,
      totalLiters: total,
      savedLiters: saved,
    );
  }

  @override
  Future<void> deleteUsage(int id) async {
    final db = await _db;
    await db.delete('usage_entries', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> clearAllUsage() async {
    final db = await _db;
    await db.delete('usage_entries');
  }
}
