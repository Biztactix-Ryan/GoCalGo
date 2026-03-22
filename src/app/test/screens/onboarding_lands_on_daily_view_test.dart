import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/config/theme.dart';
import 'package:gocalgo/screens/onboarding_screen.dart';

/// A minimal stand-in for the daily events view used only in this test.
/// The real HomeScreen requires Riverpod providers, so we verify the
/// navigation destination rather than the full widget tree.
class _FakeDailyEventsView extends StatelessWidget {
  const _FakeDailyEventsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GoCalGo')),
      body: const Center(child: Text('Daily Events')),
    );
  }
}

/// Builds a two-route app: onboarding → daily events view.
/// Mirrors the intended first-launch flow where completing onboarding
/// replaces the onboarding screen with the home (daily events) view.
Widget buildApp() {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    initialRoute: '/onboarding',
    routes: {
      '/onboarding': (context) => OnboardingScreen(
            onComplete: () {
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
      '/': (context) => const _FakeDailyEventsView(),
    },
  );
}

void main() {
  group('After onboarding, user lands on the daily events view', () {
    testWidgets('completing onboarding via "Get Started" navigates to daily view',
        (tester) async {
      await tester.pumpWidget(buildApp());

      // Verify we start on the onboarding screen
      expect(find.text("Today's Buffs"), findsOneWidget);

      // Navigate through all carousel pages
      for (var i = 0; i < defaultOnboardingPages.length - 1; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      // Last page should show "Get Started"
      expect(find.text('Get Started'), findsOneWidget);

      // Tap "Get Started" to complete onboarding
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // Verify we landed on the daily events view
      expect(find.text('GoCalGo'), findsOneWidget);
      expect(find.text('Daily Events'), findsOneWidget);
      // Onboarding content should be gone
      expect(find.text("Today's Buffs"), findsNothing);
      expect(find.text('Skip'), findsNothing);
    });

    testWidgets('skipping onboarding navigates to daily view',
        (tester) async {
      await tester.pumpWidget(buildApp());

      // Verify we start on the onboarding screen
      expect(find.text("Today's Buffs"), findsOneWidget);

      // Tap "Skip"
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // Verify we landed on the daily events view
      expect(find.text('GoCalGo'), findsOneWidget);
      expect(find.text('Daily Events'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
    });

    testWidgets('skipping from a middle page navigates to daily view',
        (tester) async {
      await tester.pumpWidget(buildApp());

      // Advance to page 2
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Flag Events'), findsOneWidget);

      // Skip from the middle
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // Verify we landed on the daily events view
      expect(find.text('GoCalGo'), findsOneWidget);
      expect(find.text('Daily Events'), findsOneWidget);
      expect(find.text('Flag Events'), findsNothing);
    });
  });
}
