import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shell widget that wraps top-level screens with a bottom navigation bar.
///
/// Provides tab switching between "Today" (active events) and "Upcoming"
/// (next 7 days) views. Uses [StatefulNavigationShell] to preserve state
/// across tabs.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.date_range_outlined),
            selectedIcon: Icon(Icons.date_range),
            label: 'Upcoming',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
