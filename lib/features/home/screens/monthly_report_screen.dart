import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/theme_v2.dart';
import '../../../core/providers/usage_provider.dart';
import '../models/usage_models.dart';

class MonthlyReportScreen extends ConsumerStatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  ConsumerState<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
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

  void _jumpMonth(int delta) {
    final d = DateTime(_year, _month + delta, 1);
    setState(() {
      _year = d.year;
      _month = d.month;
    });
  }

  Future<void> _openMonthPicker() async {
    final result = await showModalBottomSheet<_Ym>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MonthPickerSheet(
        initialYear: _year,
        initialMonth: _month,
      ),
    );
    if (result != null) {
      setState(() {
        _year = result.year;
        _month = result.month;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final when = DateTime(_year, _month, 1);
    final asyncSummary = ref.watch(monthlySummaryProvider(when));

    final bg = AppThemeV2.bgNavy; // keep your theme color
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black.withOpacity(0.12),
        title: const Text('Monthly Report'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(monthlySummaryProvider(when).future),
          color: const Color(0xFF00F0B8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MonthHeader(
                      year: _year,
                      month: _month,
                      onPrev: () => _jumpMonth(-1),
                      onNext: () => _jumpMonth(1),
                      onOpenPicker: _openMonthPicker,
                    ),
                    const SizedBox(height: 12),

                    // KPIs
                    asyncSummary.when(
                      data: (s) => _KpiGrid(summary: s),
                      loading: () => const _KpiSkeleton(),
                      error: (_, __) => const _KpiSkeleton(),
                    ),
                    const SizedBox(height: 16),

                    // Chart
                    _SectionCard(
                      title: 'Daily Usage',
                      trailing: asyncSummary.when(
                        data: (s) => _ChartLegend(total: s.totalLiters, saved: s.savedLiters),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                        child: asyncSummary.when(
                          data: (s) => _UsageBarChart(summary: s),
                          loading: () => const SizedBox(
                            height: 220,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation(Color(0xFF00F0B8)),
                              ),
                            ),
                          ),
                          error: (e, st) => _ChartError(onRetry: () {
                            ref.invalidate(monthlySummaryProvider(when));
                          }),
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
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final int year;
  final int month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onOpenPicker;

  const _MonthHeader({
    required this.year,
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.onOpenPicker,
  });

  @override
  Widget build(BuildContext context) {
    final label = DateFormat.yMMMM().format(DateTime(year, month, 1));
    return Row(
      children: [
        _IconButtonCircle(icon: Icons.chevron_left, onTap: onPrev),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            onTap: onOpenPicker,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: AppGradient.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event, color: Colors.black87),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.expand_more, color: Colors.black87),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _IconButtonCircle(icon: Icons.chevron_right, onTap: onNext),
      ],
    );
  }
}

class _IconButtonCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconButtonCircle({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white10),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final MonthlySummary summary;
  const _KpiGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final items = <_Kpi>[
      _Kpi('Total', '${summary.totalLiters.toStringAsFixed(0)} L', Icons.opacity),
      _Kpi('Used', '${summary.totalLiters.toStringAsFixed(0)} L', Icons.water_drop),
      _Kpi('Saved', '${summary.savedLiters.toStringAsFixed(0)} L', Icons.savings),
    ];
    // Responsive: 2-up on phones, 3-up on tablets
    return LayoutBuilder(
      builder: (_, c) {
        final w = c.maxWidth;
        final crossAxisCount = w < 420 ? 2 : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.3,
          ),
          itemBuilder: (_, i) => _KpiCard(kpi: items[i]),
        );
      },
    );
  }
}

class _Kpi {
  final String title;
  final String value;
  final IconData icon;
  _Kpi(this.title, this.value, this.icon);
}

class _KpiCard extends StatelessWidget {
  final _Kpi kpi;
  const _KpiCard({required this.kpi});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradient.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(kpi.icon, color: Colors.black87, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kpi.title,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    )),
                const SizedBox(height: 4),
                Text(kpi.value,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiSkeleton extends StatelessWidget {
  const _KpiSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget box() => Container(
          decoration: BoxDecoration(
            color: const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(14),
          ),
        );
    return LayoutBuilder(
      builder: (_, c) {
        final w = c.maxWidth;
        final cols = w < 420 ? 2 : 3;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: cols,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.3,
          children: List.generate(3, (_) => box()),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final double total;
  final double saved;
  const _ChartLegend({required this.total, required this.saved});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Dot(label: 'Total', color: const Color(0xFF00B6FF)),
        const SizedBox(width: 12),
        _Dot(label: 'Saved', color: const Color(0xFF00F0B8)),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final String label;
  final Color color;
  const _Dot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _UsageBarChart extends StatelessWidget {
  final MonthlySummary summary;
  const _UsageBarChart({required this.summary});

  @override
  Widget build(BuildContext context) {
    final days = summary.litersPerDay.length;
    if (days == 0) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text('No data for this month', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    final maxY = (summary.litersPerDay.reduce((a, b) => a > b ? a : b) * 1.25).clamp(1, double.infinity);
    // Responsive chart width so labels don’t collide on phones
    final double perBar = 12; // bar width px
    final double perGroupSpace = 10; // spacing between days
    final double minWidth = days * (perBar + perGroupSpace) + 32;

    final groups = <BarChartGroupData>[
      for (var i = 0; i < days; i++)
        BarChartGroupData(
          x: i + 1,
          barsSpace: 0,
          barRods: [
            BarChartRodData(
              toY: summary.litersPerDay[i],
              width: perBar,
              gradient: const LinearGradient(colors: [Color(0xFF00F0B8), Color(0xFF00B6FF)]),
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final chartWidth = width < minWidth ? minWidth : width;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: chartWidth,
            height: 240,
            child: BarChart(
              BarChartData(
                maxY: maxY.toDouble(),
                alignment: BarChartAlignment.spaceBetween,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(color: Colors.white12, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (maxY / 4).ceilToDouble(),
                      reservedSize: 32,
                      getTitlesWidget: (v, meta) => Text(
                        v.toStringAsFixed(0),
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (days / 7).clamp(1, 5).toDouble(),
                      getTitlesWidget: (v, meta) {
                        final d = v.toInt();
                        if (d < 1 || d > days) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('$d', style: const TextStyle(color: Colors.white54, fontSize: 9)),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final day = group.x;
                      final liters = rod.toY;
                      return BarTooltipItem(
                        'Day $day\n${liters.toStringAsFixed(1)} L',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      );
                    },
                    // tooltipBgColor: Colors.black.withOpacity(0.7),
                  ),
                ),
                barGroups: groups,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChartError extends StatelessWidget {
  final VoidCallback onRetry;
  const _ChartError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Failed to load', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Insights extends StatelessWidget {
  final MonthlySummary summary;
  const _Insights({required this.summary});

  @override
  Widget build(BuildContext context) {
    final days = summary.litersPerDay.length == 0 ? 1 : summary.litersPerDay.length;
    final avg = summary.totalLiters / days;
    final minVal = summary.litersPerDay.isEmpty
        ? 0.0
        : summary.litersPerDay.reduce((a, b) => a < b ? a : b);
    final bestDayIndex = summary.litersPerDay.isEmpty
        ? 1
        : summary.litersPerDay.indexOf(minVal) + 1;

    return _SectionCard(
      title: 'Insights',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InsightRow(icon: Icons.trending_down, label: 'Average daily use', value: '${avg.toStringAsFixed(1)} L'),
            const SizedBox(height: 8),
            _InsightRow(icon: Icons.emoji_events, label: 'Best day (lowest use)', value: 'Day $bestDayIndex'),
            const SizedBox(height: 8),
            _InsightRow(icon: Icons.savings, label: 'Estimated saved', value: '${summary.savedLiters.toStringAsFixed(0)} L'),
          ],
        ),
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InsightRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// -------------------- Month Picker Sheet --------------------

class _Ym {
  final int year;
  final int month;
  _Ym(this.year, this.month);
}

class _MonthPickerSheet extends StatefulWidget {
  final int initialYear;
  final int initialMonth;

  const _MonthPickerSheet({
    required this.initialYear,
    required this.initialMonth,
  });

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final years = List<int>.generate(11, (i) => now.year - 5 + i); // from -5 to +5 years
    final months = List<int>.generate(12, (i) => i + 1);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0f152b),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 12),
          const Text('Select Month', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(
            height: 190,
            child: Row(
              children: [
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(initialItem: years.indexOf(_year)),
                    itemExtent: 34,
                    onSelectedItemChanged: (i) => setState(() => _year = years[i]),
                    children: years
                        .map((y) => Center(child: Text('$y', style: const TextStyle(color: Colors.white))))
                        .toList(),
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(initialItem: _month - 1),
                    itemExtent: 34,
                    onSelectedItemChanged: (i) => setState(() => _month = months[i]),
                    children: months
                        .map((m) => Center(
                              child: Text(DateFormat.MMM().format(DateTime(2000, m, 1)),
                                  style: const TextStyle(color: Colors.white)),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B6FF),
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () => Navigator.pop(context, _Ym(_year, _month)),
                    child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
