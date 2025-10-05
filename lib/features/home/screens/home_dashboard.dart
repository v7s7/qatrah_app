import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode; // <-- add this
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_v2.dart';
import '../../../core/providers/usage_provider.dart'; // todayLitersProvider, weekLitersProvider, monthSummaryNowProvider

class HomeDashboard extends ConsumerWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double today = ref.watch(todayLitersProvider);
    final double week = ref.watch(weekLitersProvider);
    final monthSummary = ref.watch(monthSummaryNowProvider);

    final ringValue = (today / 5.0).clamp(0.0, 1.0);
    final savedLiters = monthSummary.maybeWhen(
      data: (s) => s.savedLiters,
      orElse: () => 0.0,
    );
    final savedAed = (savedLiters * 0.43).toStringAsFixed(2);

    return Scaffold(
      backgroundColor: AppThemeV2.bgNavy,
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.black.withOpacity(0.15),
        actions: [
          if (kDebugMode) // show only in debug builds
            IconButton(
              icon: const Icon(Icons.developer_mode),
              tooltip: 'Replay Serial Log',
              onPressed: () => Navigator.pushNamed(context, '/dev/replay'),
            ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => Navigator.pushNamed(context, '/report'),
            tooltip: 'Monthly Report',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Good morning, Ghala',
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: CircularProgressIndicator(
                        value: ringValue.isNaN ? 0.0 : ringValue,
                        strokeWidth: 14,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF3CF6C8),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${today.toStringAsFixed(1)}L',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Used Today',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'You saved ${savedLiters.toStringAsFixed(1)} L vs. normal faucet (this month)',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'This week\nYou used ${week.toStringAsFixed(1)} L',
                    style: const TextStyle(color: Colors.white),
                  ),
                  monthSummary.when(
                    data: (_) => Text(
                      '$savedAed AED\nsaved this month',
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: Colors.white),
                    ),
                    loading: () => const Text(
                      '…',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: Colors.white70),
                    ),
                    error: (_, __) => const Text(
                      '—',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
