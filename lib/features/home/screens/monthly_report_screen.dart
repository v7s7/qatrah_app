import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/theme_v2.dart';
import '../../../core/providers/usage_provider.dart'; // <- your file name
import '../models/usage_models.dart';

class MonthlyReportScreen extends ConsumerStatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  ConsumerState<MonthlyReportScreen> createState() =>
      _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends ConsumerState<MonthlyReportScreen> {
  late int _year;
  late int _month; // 1..12

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  @override
  Widget build(BuildContext context) {
    final when = DateTime(_year, _month, 1);
    final asyncSummary = ref.watch(monthlySummaryProvider(when));

    return Scaffold(
      backgroundColor: AppThemeV2.bgNavy,
      appBar: AppBar(
        title: const Text('Monthly Report'),
        backgroundColor: Colors.black.withOpacity(0.15),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Monthly Report',
                    style: TextStyle(fontSize: 22, color: Colors.white),
                  ),
                  _MonthDropdown(
                    year: _year,
                    month: _month,
                    onChanged: (y, m) => setState(() {
                      _year = y;
                      _month = m;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Summary cards
              asyncSummary.when(
                data: (MonthlySummary s) {
                  return Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'Total Water\nConsumption',
                          value: '${s.totalLiters.toStringAsFixed(0)} Liters',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Water\nUsed',
                          value: '${s.totalLiters.toStringAsFixed(0)} Liters',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Water\nSaved',
                          value: '${s.savedLiters.toStringAsFixed(0)} Liters',
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const _SummarySkeleton(),
                error: (_, __) => const _SummarySkeleton(),
              ),
              const SizedBox(height: 16),

              // Chart
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0x14FFFFFF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 12, 6, 8),
                  child: asyncSummary.when(
                    data: (s) => _UsageBarChart(summary: s),
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Color(0xFF3CF6C8)),
                      ),
                    ),
                    error: (_, __) => const Center(
                      child: Text(
                        'Failed to load',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Insights
              asyncSummary.when(
                data: (s) => _Insights(summary: s),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthDropdown extends StatelessWidget {
  final int year;
  final int month;
  final void Function(int year, int month) onChanged;

  const _MonthDropdown({
    required this.year,
    required this.month,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final months = List<int>.generate(12, (i) => i + 1);
    final monthName = DateFormat.MMMM().format(DateTime(year, month, 1));

    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: AppGradient.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButton<int>(
          value: month,
          iconEnabledColor: Colors.black,
          dropdownColor: Colors.white,
          items: months
              .map(
                (m) => DropdownMenuItem<int>(
                  value: m,
                  child: Text(
                    DateFormat.MMMM().format(DateTime(year, m, 1)),
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              )
              .toList(),
          onChanged: (m) {
            if (m == null) return;
            onChanged(year, m);
          },
          selectedItemBuilder: (ctx) => months
              .map(
                (m) => Center(
                  child: Text(
                    m == month
                        ? monthName
                        : DateFormat.MMMM().format(DateTime(year, m, 1)),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  const _SummaryCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        gradient: AppGradient.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    Widget box() => Container(
      height: 84,
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

class _UsageBarChart extends StatelessWidget {
  final MonthlySummary summary;
  const _UsageBarChart({required this.summary});

  @override
  Widget build(BuildContext context) {
    final maxY = (summary.litersPerDay.reduce((a, b) => a > b ? a : b) * 1.25)
        .ceilToDouble();
    final groups = <BarChartGroupData>[
      for (var i = 0; i < summary.litersPerDay.length; i++)
        BarChartGroupData(
          x: i + 1, // day index starting at 1
          barRods: [
            BarChartRodData(
              toY: summary.litersPerDay[i],
              width: 8,
              gradient: const LinearGradient(
                colors: [Color(0xFF00F0B8), Color(0xFF00B6FF)],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
    ];

    return BarChart(
      BarChartData(
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: Colors.white12, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (maxY / 4).ceilToDouble(),
              getTitlesWidget: (v, meta) => Text(
                v.toStringAsFixed(0),
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
              reservedSize: 28,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (summary.litersPerDay.length / 7)
                  .clamp(1, 5)
                  .toDouble(),
              getTitlesWidget: (v, meta) {
                final d = v.toInt();
                if (d < 1 || d > summary.litersPerDay.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '$d',
                    style: const TextStyle(color: Colors.white54, fontSize: 9),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: groups,
      ),
    );
  }
}

class _Insights extends StatelessWidget {
  final MonthlySummary summary;
  const _Insights({required this.summary});

  @override
  Widget build(BuildContext context) {
    final avg = summary.totalLiters / summary.litersPerDay.length;
    final bestDayIndex =
        summary.litersPerDay.indexOf(
          summary.litersPerDay.reduce((a, b) => a < b ? a : b),
        ) +
        1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Insights',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Text(
          '• Average daily use: ${avg.toStringAsFixed(1)} L',
          style: const TextStyle(color: Colors.white70),
        ),
        Text(
          '• Best day: day $bestDayIndex (lowest usage)',
          style: const TextStyle(color: Colors.white70),
        ),
        Text(
          '• Estimated saved: ${summary.savedLiters.toStringAsFixed(0)} L',
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}
