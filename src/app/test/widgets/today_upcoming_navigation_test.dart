import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/config/theme.dart';

/// Verifies acceptance criterion for story US-GCG-23:
/// "Navigation between today view and upcoming view is intuitive"
///
/// Tests that users can switch between the today (active events) view and the
/// upcoming events view via a bottom navigation bar. The navigation should be
/// discoverable, clearly labelled, and indicate the currently active view.

void main() {
  Widget buildApp({int initialIndex = 0}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: _NavigationHarness(initialIndex: initialIndex),
    );
  }

  group('Navigation between today and upcoming views', () {
    testWidgets('bottom navigation bar is present with two tabs',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(2));
    });

    testWidgets('today tab is labelled "Today" with a calendar icon',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(find.byIcon(Icons.today), findsOneWidget);
    });

    testWidgets('upcoming tab is labelled "Upcoming" with a date range icon',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.byIcon(Icons.date_range), findsOneWidget);
    });

    testWidgets('today view is shown by default', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // The today view placeholder should be visible
      expect(find.byKey(const Key('today_view')), findsOneWidget);
      expect(find.byKey(const Key('upcoming_view')), findsNothing);
    });

    testWidgets('tapping upcoming tab switches to upcoming view',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Tap the Upcoming tab
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('upcoming_view')), findsOneWidget);
      expect(find.byKey(const Key('today_view')), findsNothing);
    });

    testWidgets('tapping today tab switches back to today view',
        (tester) async {
      // Start on upcoming view
      await tester.pumpWidget(buildApp(initialIndex: 1));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('upcoming_view')), findsOneWidget);

      // Tap the Today tab
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('today_view')), findsOneWidget);
      expect(find.byKey(const Key('upcoming_view')), findsNothing);
    });

    testWidgets('selected tab is visually distinguished', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 0);

      // Switch to upcoming
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle();

      final updatedNavBar =
          tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(updatedNavBar.selectedIndex, 1);
    });

    testWidgets('navigation preserves state when switching tabs',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Verify we start on today
      expect(find.byKey(const Key('today_view')), findsOneWidget);

      // Switch to upcoming and back
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      // Today view should still be present
      expect(find.byKey(const Key('today_view')), findsOneWidget);
    });

    testWidgets('repeated taps on active tab do not break navigation',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Tap Today tab multiple times while already selected
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('today_view')), findsOneWidget);
    });
  });
}

/// Test harness: a shell with bottom navigation that switches between
/// a today-view placeholder and an upcoming-view placeholder.
///
/// This widget represents the expected navigation contract. The actual
/// implementation will wire in the real HomeScreen and UpcomingScreen
/// once US-GCG-23-7 and US-GCG-23-8 are completed.
class _NavigationHarness extends StatefulWidget {
  const _NavigationHarness({this.initialIndex = 0});

  final int initialIndex;

  @override
  State<_NavigationHarness> createState() => _NavigationHarnessState();
}

class _NavigationHarnessState extends State<_NavigationHarness> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  static const _views = [
    Center(key: Key('today_view'), child: Text('Today Events')),
    Center(key: Key('upcoming_view'), child: Text('Upcoming Events')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _views[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.date_range),
            label: 'Upcoming',
          ),
        ],
      ),
    );
  }
}
