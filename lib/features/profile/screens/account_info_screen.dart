import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_v2.dart';
import '../../../core/providers/profile_provider.dart';

class AccountInfoScreen extends ConsumerWidget {
  const AccountInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncP = ref.watch(profileProvider);
    return Scaffold(
      backgroundColor: AppThemeV2.bgNavy,
      appBar: AppBar(
        title: const Text('Account Info'),
        backgroundColor: Colors.black.withOpacity(0.15),
      ),
      body: SafeArea(
        child: asyncP.when(
          data: (p) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _info('Name', p.name),
                _info('Email', p.email),
                _info('Phone', p.phone),
                _info('Username', p.username),
                const SizedBox(height: 24),
                _btn(
                  context,
                  'Edit Info',
                  () => Navigator.pushNamed(context, '/profile/edit'),
                ),
                const SizedBox(height: 12),
                _btn(
                  context,
                  'Change password',
                  () => Navigator.pushNamed(context, '/profile/password'),
                ),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(
            child: Text(
              'Failed to load',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _info(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(k, style: const TextStyle(color: Colors.white70)),
          const Spacer(),
          Text(
            v,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _btn(BuildContext c, String label, VoidCallback onTap) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      onPressed: onTap,
      child: Text(label),
    ),
  );
}
