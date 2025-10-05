import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_v2.dart';
import '../../../core/providers/achievements_provider.dart';
import '../models/achievement.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // achievementsProvider is a synchronous Provider<List<Achievement>>
    final List<Achievement> list = ref.watch(achievementsProvider);

    return Scaffold(
      backgroundColor: AppThemeV2.bgNavy,
      appBar: AppBar(
        title: const Text('Achievements'),
        backgroundColor: Colors.black.withOpacity(0.15),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: list.isEmpty
              ? const Center(
                  child: Text(
                    'No achievements yet',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: AppGradient.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: list.map((a) => _tile(a)).toList(),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _tile(Achievement a) {
    final icon = _iconFor(a.icon);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.black87, size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + badge (if achieved)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        a.title,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (a.achieved)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Achieved',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),

                // Description
                Text(
                  a.description,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 8),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: a.progress.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.black26,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF0FD9C6)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'water_drop':
        return Icons.water_drop;
      case 'eco':
        return Icons.eco;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'calendar_today':
        return Icons.calendar_today;
      case 'verified':
        return Icons.verified;
      default:
        return Icons.star_outline;
    }
  }
}
