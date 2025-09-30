import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/theme_v2.dart';
import '../../../core/providers/usage_provider.dart';
import '../../home/models/usage_models.dart';

class UsageHistoryScreen extends ConsumerStatefulWidget {
  const UsageHistoryScreen({super.key});

  @override
  ConsumerState<UsageHistoryScreen> createState() => _UsageHistoryScreenState();
}

class _UsageHistoryScreenState extends ConsumerState<UsageHistoryScreen> {
  // 0: Today, 1: This Week, 2: This Month, 3: Custom (same as Month for now)
  int _selected = 0;

  // ---------- SEEDING HELPERS ----------
  Future<void> _addRandom() async {
    final now = DateTime.now();
    final rnd = Random();
    final activities = ['Washing Dishes', 'Washing Fruits', 'Washing Hands'];
    final minutes = [5, 10, 15, 20, 30, 45][rnd.nextInt(6)];
    final liters = [5, 8, 10, 12, 15, 18, 20, 25][rnd.nextInt(8)].toDouble();

    final entry = UsageEntry(
      activity: activities[rnd.nextInt(activities.length)],
      start: now.subtract(Duration(minutes: rnd.nextInt(60))),
      duration: Duration(minutes: minutes),
      liters: liters,
    );
    await ref.read(addUsageEntryProvider(entry).future);
  }

  Future<void> _seedWeek() async {
    final now = DateTime.now();
    final rnd = Random();
    for (int d = 0; d < 7; d++) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: d));
      final count = 1 + rnd.nextInt(3); // 1–3 entries per day
      for (int i = 0; i < count; i++) {
        final entry = UsageEntry(
          activity: [
            'Washing Dishes',
            'Washing Fruits',
            'Washing Hands',
          ][rnd.nextInt(3)],
          start: day.add(
            Duration(hours: 9 + rnd.nextInt(10), minutes: rnd.nextInt(60)),
          ),
          duration: Duration(minutes: [5, 10, 15, 20, 30][rnd.nextInt(5)]),
          liters: [5, 8, 10, 12, 15, 18, 20, 25][rnd.nextInt(8)].toDouble(),
        );
        await ref.read(addUsageEntryProvider(entry).future);
      }
    }
  }
  // ------------------------------------

  @override
  Widget build(BuildContext context) {
    final asyncList = ref.watch(recentUsageProvider);

    return Scaffold(
      backgroundColor: AppThemeV2.bgNavy,

      // FABs to seed data quickly
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'seed-week',
            tooltip: 'Seed week',
            onPressed: _seedWeek,
            child: const Icon(Icons.auto_awesome),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'add-one',
            tooltip: 'Add one entry',
            onPressed: _addRandom,
            child: const Icon(Icons.add),
          ),
        ],
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Usage History',
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _FilterChip(
                    'Today',
                    selected: _selected == 0,
                    onTap: () => setState(() => _selected = 0),
                  ),
                  _FilterChip(
                    'This Week',
                    selected: _selected == 1,
                    onTap: () => setState(() => _selected = 1),
                  ),
                  _FilterChip(
                    'This Month',
                    selected: _selected == 2,
                    onTap: () => setState(() => _selected = 2),
                  ),
                  _FilterChip(
                    'Custom',
                    selected: _selected == 3,
                    onTap: () => setState(() => _selected = 3),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Expanded(
                child: asyncList.when(
                  data: (items) {
                    final filtered = _applyFilter(items, _selected);
                    if (filtered.isEmpty) {
                      return const _EmptyState();
                    }
                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final e = filtered[i];
                        final subtitle = _formatRange(e.start, e.duration);
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          tileColor: const Color(0x14FFFFFF),
                          title: Text(
                            e.activity,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            subtitle,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.white70,
                          ),
                          onTap: () =>
                              Navigator.pushNamed(context, '/usage/detail'),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Color(0xFF3CF6C8)),
                    ),
                  ),
                  error: (_, __) => const Center(
                    child: Text(
                      'Failed to load',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              asyncList.when(
                data: (items) {
                  final filtered = _applyFilter(items, _selected);
                  final todayTotal = _sumLiters(_applyFilter(items, 0));
                  final weekTotal = _sumLiters(_applyFilter(items, 1));
                  final monthTotal = _sumLiters(_applyFilter(items, 2));

                  return _TotalsCard(
                    today: '${todayTotal.toStringAsFixed(0)} liters',
                    week: '${weekTotal.toStringAsFixed(0)} liters',
                    month: '${monthTotal.toStringAsFixed(0)} liters',
                    visible: filtered.isNotEmpty,
                  );
                },
                loading: () => const _TotalsSkeleton(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- helpers ----

  List<UsageEntry> _applyFilter(List<UsageEntry> items, int sel) {
    final now = DateTime.now();
    DateTime startRange;

    switch (sel) {
      case 0: // Today
        startRange = DateTime(now.year, now.month, now.day);
        break;
      case 1: // This week (Mon..now)
        final weekday = now.weekday; // Mon=1..Sun=7
        startRange = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: weekday - 1));
        break;
      case 2: // This month
      case 3: // Custom (same for now)
      default:
        startRange = DateTime(now.year, now.month, 1);
        break;
    }

    return items
        .where(
          (e) => e.start.isAfter(startRange) || _isSameDay(e.start, startRange),
        )
        .toList()
      ..sort((a, b) => b.start.compareTo(a.start)); // newest first
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  double _sumLiters(List<UsageEntry> items) =>
      items.fold<double>(0, (sum, e) => sum + e.liters);

  String _formatRange(DateTime start, Duration dur) {
    final end = start.add(dur);
    final d = DateFormat('MMM d').format(start);
    final s = DateFormat('h:mm a').format(start);
    final e = DateFormat('h:mm a').format(end);
    return '$d, $s–$e';
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(this.label, {required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? AppGradient.primary : null,
          color: selected ? null : const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final String today;
  final String week;
  final String month;
  final bool visible;
  const _TotalsCard({
    required this.today,
    required this.week,
    required this.month,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    Text t(String s) => Text(s, style: const TextStyle(color: Colors.white));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          t("Today's Total\n$today"),
          t("This Week's Total\n$week"),
          t("This Month's Total\n$month"),
        ],
      ),
    );
  }
}

class _TotalsSkeleton extends StatelessWidget {
  const _TotalsSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget box() => Container(
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(14),
      ),
    );
    return Row(
      children: [
        Expanded(child: box()),
        const SizedBox(width: 10),
        Expanded(child: box()),
        const SizedBox(width: 10),
        Expanded(child: box()),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No usage in this range',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}
