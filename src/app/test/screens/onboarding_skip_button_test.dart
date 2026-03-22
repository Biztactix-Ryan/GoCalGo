import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/config/theme.dart';
import 'package:gocalgo/screens/onboarding_screen.dart';

void main() {
  bool completed = false;

  Widget buildOnboarding({List<OnboardingPage>? pages}) {
    completed = false;
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: OnboardingScreen(
        pages: pages ?? defaultOnboardingPages,
        onComplete: () => completed = true,
      ),
    );
  }

  group('Onboarding skip button availability', () {
    testWidgets('skip button is visible on the first screen', (tester) async {
      await tester.pumpWidget(buildOnboarding());

      expect(find.text('Skip'), findsOneWidget);
      expect(
        find.byKey(const Key('onboarding_skip')),
        findsOneWidget,
      );
    });

    testWidgets('skip button is visible on the second screen', (tester) async {
      await tester.pumpWidget(buildOnboarding());

      // Swipe to the second page
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('skip button is visible on the last screen', (tester) async {
      await tester.pumpWidget(buildOnboarding());

      // Swipe to page 2
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      // Swipe to page 3
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('skip button is visible on every page of a custom carousel',
        (tester) async {
      final pages = List.generate(
        5,
        (i) => OnboardingPage(
          title: 'Page ${i + 1}',
          description: 'Description ${i + 1}',
          icon: Icons.star,
        ),
      );

      await tester.pumpWidget(buildOnboarding(pages: pages));

      for (var i = 0; i < pages.length; i++) {
        expect(
          find.text('Skip'),
          findsOneWidget,
          reason: 'Skip button should be visible on page ${i + 1}',
        );

        if (i < pages.length - 1) {
          await tester.drag(find.byType(PageView), const Offset(-400, 0));
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('tapping skip calls onComplete', (tester) async {
      await tester.pumpWidget(buildOnboarding());

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
    });

    testWidgets('skip works from a middle page', (tester) async {
      await tester.pumpWidget(buildOnboarding());

      // Navigate to the second page
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
    });
  });
}
