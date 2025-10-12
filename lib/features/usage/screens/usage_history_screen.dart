import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/theme_v2.dart';
import '../../../core/providers/usage_provider.dart';
import '../../home/models/usage_models.dart';
import '../models/usage_draft.dart';

class UsageHistoryScreen extends ConsumerStatefulWidget {
  const UsageHistoryScreen({super.key});

  @override
  ConsumerState<UsageHistoryScreen> createState() => _UsageHistoryScreenState();
}

class _UsageHistoryScreenState extends ConsumerState<UsageHistoryScreen> {
  // 0: Today, 1: This Week, 2: This Month
  int _selected = 0;
  final Set<int> _removedIds = {}; // hide dismissed rows immediately

  // ------------------------------------
  Future<void> _openAddForm() async {
    await Navigator.pushNamed(
      context,
      '/usage/detail',
      arguments: UsageDraft.from(activity: 'Washing Dishes'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncList = ref.watch(recentUsageProvider);

    return Scaffold(
      backgroundColor: AppThemeV2.bgNavy,
      appBar: AppBar(
        title: const Text('Usage History'),
        backgroundColor: Colors.black.withOpacity(0.15),
        actions: [
          IconButton(
            tooltip: 'Clear all usage',
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Clear all usage?'),
                  content: const Text(
                    'This deletes every usage entry. This cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete All'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(clearAllUsageProvider.future);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All usage cleared')),
                );
                setState(() {
                  _removedIds.clear();
                });
              }
            },
          ),
        ],
      ),

      // Small offset so the FAB never overlaps content edges
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 12),
        child: FloatingActionButton(
          heroTag: 'add-one',
          tooltip: 'Add entry',
          onPressed: _openAddForm,
          child: const Icon(Icons.add),
        ),
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
                ],
              ),

              const SizedBox(height: 16),

              Expanded(
                child: asyncList.when(
                  data: (items) {
                    var filtered = _applyFilter(items, _selected);

                    // Hide any rows we already dismissed optimistically
                    filtered = filtered.where((e) {
                      final id = e.id;
                      return id == null ? true : !_removedIds.contains(id);
                    }).toList();

                    if (filtered.isEmpty) {
                      return const _EmptyState();
                    }

                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final e = filtered[i];
                        final subtitle = _formatRange(e.start, e.duration);

                        return Dismissible(
                          key: ValueKey(
                            e.id ?? '${e.start.millisecondsSinceEpoch}-$i',
                          ),
                          background: Container(
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          secondaryBackground: Container(
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (_) async {
                            if (e.id == null) return false;

                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete entry?'),
                                content: Text('${e.activity}\n$subtitle'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );

                            if (ok != true) return false;

                            // Optimistically hide now so the next build excludes it
                            setState(() {
                              _removedIds.add(e.id!);
                            });

                            // Real delete (invalidates providers)
                            await ref.read(
                              deleteUsageEntryProvider(e.id!).future,
                            );

                            return true;
                          },
                          onDismissed: (_) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Entry deleted')),
                            );
                          },
                          child: ListTile(
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
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/usage/detail',
                              arguments: e, // pass entry with id for editing
                            ),
                          ),
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

    Widget stat(String title, String value) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: stat("Today's Total", today)),
          const SizedBox(width: 8),
          Expanded(child: stat("This Week's Total", week)),
          const SizedBox(width: 8),
          Expanded(child: stat("This Month's Total", month)),
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
