import 'package:flutter/material.dart';
import '../../../core/theme/theme_v2.dart';

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV2.bgNavy,
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.black.withOpacity(0.15),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => Navigator.pushNamed(context, '/report'),
            tooltip: 'Monthly Report',
          ),
        ],
      ),
      body: const SafeArea(
        // ... (keep the rest of your body as is)
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good morning, Ghala',
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
              SizedBox(height: 24),
              _UsageRing(),
              SizedBox(height: 24),
              Text(
                'You saved 2.1 L vs. normal faucet',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 24),
              _WeeklyRow(),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageRing extends StatelessWidget {
  const _UsageRing();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: CircularProgressIndicator(
              value: 0.64,
              strokeWidth: 14,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(Color(0xFF3CF6C8)),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '3.2L',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4),
              Text('Used Today', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyRow extends StatelessWidget {
  const _WeeklyRow();
  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'This week\nYou saved 14.5 L',
          style: TextStyle(color: Colors.white),
        ),
        Text(
          '6.30 AED\nsaved this month',
          textAlign: TextAlign.right,
          style: TextStyle(color: Colors.white),
        ),
      ],
    );
  }
}
