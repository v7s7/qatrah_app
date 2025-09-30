import 'package:flutter/material.dart';
import '../../../core/theme/theme_v2.dart';

class BottomNavShell extends StatefulWidget {
  final List<Widget> pages;
  const BottomNavShell({super.key, required this.pages});

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV2.bgNavy,
      body: widget.pages[index],
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.black.withOpacity(0.15),
        indicatorColor: Colors.white.withOpacity(0.08),
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Usage',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Achievements',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
