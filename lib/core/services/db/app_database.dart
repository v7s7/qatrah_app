import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static Database? _db;
  static String? _dbPath;

  static Future<Database> instance() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    _dbPath = p.join(dir.path, 'qatrah.db');

    _db = await openDatabase(
      _dbPath!,
      version: 3, // <-- bump to 3 (adds raw device fields)
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS usage_entries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            activity TEXT NOT NULL,
            start_millis INTEGER NOT NULL,
            duration_min INTEGER NOT NULL,             -- legacy (kept for back-compat)
            duration_secs INTEGER NOT NULL DEFAULT 0,  -- authoritative duration (sec)
            liters REAL NOT NULL,

            -- NEW: raw device fields captured at STOP
            object TEXT,
            tap_open_sec REAL,
            smart_global REAL,
            normal_global REAL,
            saved_global REAL
          );
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS profile(
            id INTEGER PRIMARY KEY CHECK (id = 1),
            name TEXT,
            email TEXT,
            phone TEXT,
            username TEXT
          );
        ''');

        // Seed a single profile row for convenience
        await db.insert('profile', {
          'id': 1,
          'name': 'Ghala',
          'email': 'Ghala@email.com',
          'phone': '123-456-789',
          'username': 'gh166',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_usage_start ON usage_entries(start_millis);',
        );
      },
      onUpgrade: (db, oldV, newV) async {
        // v2: add seconds column and backfill from minutes
        if (oldV < 2) {
          await db.execute(
            'ALTER TABLE usage_entries ADD COLUMN duration_secs INTEGER NOT NULL DEFAULT 0;',
          );
          await db.execute(
            'UPDATE usage_entries SET duration_secs = duration_min * 60 WHERE duration_secs = 0;',
          );
        }
        // v3: add raw device fields
        if (oldV < 3) {
          await db.execute('ALTER TABLE usage_entries ADD COLUMN object TEXT;');
          await db.execute(
            'ALTER TABLE usage_entries ADD COLUMN tap_open_sec REAL;',
          );
          await db.execute(
            'ALTER TABLE usage_entries ADD COLUMN smart_global REAL;',
          );
          await db.execute(
            'ALTER TABLE usage_entries ADD COLUMN normal_global REAL;',
          );
          await db.execute(
            'ALTER TABLE usage_entries ADD COLUMN saved_global REAL;',
          );
        }
      },
    );
    return _db!;
  }

  /// Delete the entire DB file (schema + data). Next call to instance() recreates it.
  static Future<void> reset() async {
    try {
      if (_db != null) {
        await _db!.close();
        _db = null;
      }
      if (_dbPath == null) {
        final dir = await getApplicationDocumentsDirectory();
        _dbPath = p.join(dir.path, 'qatrah.db');
      }
      await deleteDatabase(_dbPath!);
    } catch (_) {
      // swallow in dev
    }
  }

  /// Clear only usage rows (keep schema & profile)
  static Future<void> clearUsageOnly() async {
    final db = await instance();
    await db.delete('usage_entries');
  }
}
