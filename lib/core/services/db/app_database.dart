import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static Database? _db;

  static Future<Database> instance() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'qatrah.db');

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE usage_entries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            activity TEXT NOT NULL,
            start_millis INTEGER NOT NULL,
            duration_min INTEGER NOT NULL,
            liters REAL NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE profile(
            id INTEGER PRIMARY KEY CHECK (id = 1),
            name TEXT,
            email TEXT,
            phone TEXT,
            username TEXT
          );
        ''');

        // Seed a profile row so updates are simple
        await db.insert('profile', {
          'id': 1,
          'name': 'Ghala',
          'email': 'Ghala@email.com',
          'phone': '123-456-789',
          'username': 'gh166',
        });
      },
    );
    return _db!;
  }
}
