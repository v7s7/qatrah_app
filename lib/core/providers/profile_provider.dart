import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../services/db/app_database.dart';
import '../../features/profile/models/profile.dart';

class _ProfileRepo {
  Future<Database> get _db async => AppDatabase.instance();

  Future<Profile> fetch() async {
    final db = await _db;
    final rows = await db.query('profile', where: 'id = 1', limit: 1);
    final r = rows.first;
    return Profile(
      name: (r['name'] ?? '') as String,
      email: (r['email'] ?? '') as String,
      phone: (r['phone'] ?? '') as String,
      username: (r['username'] ?? '') as String,
    );
  }

  Future<void> save(Profile p) async {
    final db = await _db;
    await db.update('profile', {
      'name': p.name,
      'email': p.email,
      'phone': p.phone,
      'username': p.username,
    }, where: 'id = 1');
  }
}

final _profileRepoProvider = Provider((ref) => _ProfileRepo());

final profileProvider = FutureProvider<Profile>((ref) async {
  final repo = ref.watch(_profileRepoProvider);
  return repo.fetch();
});

final saveProfileProvider = FutureProvider.family<void, Profile>((
  ref,
  p,
) async {
  final repo = ref.watch(_profileRepoProvider);
  await repo.save(p);
  ref.invalidate(profileProvider);
});
