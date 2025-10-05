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
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS usage_entries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            activity TEXT NOT NULL,
            start_millis INTEGER NOT NULL,
            duration_min INTEGER NOT NULL,
            liters REAL NOT NULL
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
      onUpgrade: (db, o, n) async {
        // Add future migrations here
      },
    );
    return _db!;
  }

  /// Gracefully close and delete the DB file.
  /// Next call to instance() will recreate schema and seed profile row.
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

  /// Optional: clear only usage rows (keep schema & profile)
  static Future<void> clearUsageOnly() async {
    final db = await instance();
    await db.delete('usage_entries');
  }
}
